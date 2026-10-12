// Іспит за кодом сесії (ТЗ практики, розділ 5.2): вхід за кодом → ПІБ і
// група → інструкція → іспит із загальним таймером → здача → результат.
// Спроба живе в exam_attempts/{sessionId}_{uid}: набір питань фіксується на
// старті, кожна відповідь одразу зберігається, тож після перезавантаження
// студент продовжує з того самого місця. Правильність під час іспиту не
// показується й рахується лише під час здачі (exam-data.js → submitAttempt).
import { h, icon, toast, pushScreen, appBar, confirmDialog, openDialog, pickFiles, clear, spinner, emptyState } from '../ui.js';
import {
  db, auth, storage, doc, setDoc, updateDoc, getDocFromServer, serverTimestamp, increment, Timestamp,
  storageRef, uploadBytes, getDownloadURL,
} from '../firebase.js';
import { normalizeCode, getProfile, saveProfile } from '../access.js';
import { audio } from '../audio.js';
import {
  examConfig, attemptDeadline, pickTheory, signalPool, buildAudioItems, orderedOptions, answeredCount, fmtDateTime,
  countTheoryCorrect,
} from '../quiz-core.js';
import {
  findSession, attemptRef, attemptIdOf, loadExamKeys, submitAttempt, toDate, errorText,
} from '../exam-data.js';

const GREEN = '#1C3A1C';
const GOLD = '#D4A017';
const BLUE = '#1976D2';
const PURPLE = '#7B1FA2';
const ORANGE = '#EF6C00';
const FILE_EXT = ['pdf', 'doc', 'docx', 'txt', 'odt'];
const SAVE_DELAY = 500;

const pad = (n) => String(n).padStart(2, '0');
const clock = (ms) => {
  const s = Math.max(0, Math.ceil(ms / 1000));
  const hh = Math.floor(s / 3600);
  return hh ? `${hh}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}` : `${pad(Math.floor(s / 60))}:${pad(s % 60)}`;
};
const page = (title, back, ...content) => h('div', { class: 'page', style: { background: 'var(--bg)' } },
  appBar(title, { back, cls: 'brown' }), h('div', { class: 'body' }, ...content));

/** Чи можна зараз почати нову спробу (повертає текст причини або null). */
function sessionClosedReason(s, now = new Date()) {
  if (s.status !== 'active') return 'Сесію закрито або вона ще не активна.';
  const start = toDate(s.startsAt);
  if (start && now < start) return `Сесія ще не почалася. Початок: ${fmtDateTime(start)}.`;
  const end = toDate(s.deadline);
  if (end && now > end) return 'Сесія вже завершилася.';
  return null;
}

// Синхронізація з серверним часом: записуємо serverTimestamp і читаємо назад.
// Повертає свіжу спробу й зсув «сервер − пристрій» для таймера.
async function syncAttempt(ref) {
  const before = Date.now();
  await updateDoc(ref, { clientSyncAt: serverTimestamp() });
  const snap = await getDocFromServer(ref);
  const data = snap.data();
  const server = toDate(data.clientSyncAt);
  const offset = server ? server.getTime() - (before + Date.now()) / 2 : 0;
  return { attempt: data, offset };
}

// ── Вхід: код сесії ─────────────────────────────────────────────────────────
export function openExamEntry() {
  pushScreen(({ pop }) => {
    const code = h('input', { type: 'text', maxLength: 16, placeholder: 'Код сесії', autocomplete: 'off', spellcheck: false,
      style: { fontSize: '22px', fontWeight: 700, letterSpacing: '6px', textAlign: 'center', color: GREEN, textTransform: 'uppercase' } });
    const err = h('div', { class: 'err', hidden: true });
    const fail = (m) => { err.textContent = m; err.hidden = false; };
    const go = h('button', { class: 'btn block', style: { padding: '14px', marginTop: '8px' } }, 'Далі');

    const enter = async () => {
      err.hidden = true;
      const c = normalizeCode(code.value);
      if (c.length < 4) { fail('Введіть код сесії, який дав викладач'); return; }
      const user = auth.currentUser;
      if (!user) { fail('Увійдіть в акаунт'); return; }
      go.disabled = true;
      try {
        const session = await findSession(c);
        if (!session) { fail('Сесію не знайдено. Перевірте код.'); return; }
        const ref = attemptRef(session.id, user.uid);
        const snap = await getDocFromServer(ref);
        if (snap.exists()) {
          pop();
          await continueAttempt(session, snap.data());
          return;
        }
        const reason = sessionClosedReason(session);
        if (reason) { fail(reason); return; }
        let profile = await getProfile();
        if (!profile.fullName || !profile.group) {
          profile = await askProfile(profile);
          if (!profile) return;
        }
        pop();
        openIntro(session, profile);
      } catch (e) {
        fail(errorText(e));
      } finally { go.disabled = false; }
    };
    go.addEventListener('click', enter);
    code.addEventListener('keydown', (e) => { if (e.key === 'Enter') enter(); });
    setTimeout(() => code.focus(), 50);

    return page('Вхід до іспиту', pop, h('div', { class: 'body-inner', style: { maxWidth: '480px' } },
      h('div', { style: { textAlign: 'center', margin: '12px 0 24px' } },
        h('span', { class: 'mi', style: { fontSize: '56px', color: GREEN, background: 'rgba(28,58,28,.08)', borderRadius: '50%', padding: '20px' } }, 'school')),
      h('label', { class: 'field' }, h('span', {}, 'Код сесії'), code),
      err, go));
  });
}

/** Форма «Прізвище та ім'я» + «Група» перед першим іспитом; зберігає в users/{uid}. */
function askProfile(initial) {
  return new Promise((resolve) => {
    const fullName = h('input', { type: 'text', value: initial.fullName || '', placeholder: 'Прізвище Ім’я', autocomplete: 'name', maxLength: 80 });
    const group = h('input', { type: 'text', value: initial.group || '', placeholder: 'Напр. ЛГс-32', maxLength: 20 });
    const err = h('div', { class: 'err', hidden: true });
    const ok = h('button', { class: 'btn', onClick: async () => {
      const p = { fullName: fullName.value.trim(), group: group.value.trim() };
      if (p.fullName.split(/\s+/).length < 2) { err.textContent = 'Введіть прізвище та ім’я'; err.hidden = false; return; }
      if (!p.group) { err.textContent = 'Введіть групу'; err.hidden = false; return; }
      ok.disabled = true;
      try { await saveProfile(p); d.close(); resolve(p); } catch (e) { err.textContent = errorText(e); err.hidden = false; ok.disabled = false; }
    } }, 'Зберегти');
    const d = openDialog([
      h('h3', {}, 'Ваші дані для відомості'),
      h('div', { class: 's', style: { marginBottom: '12px' } }, 'Їх побачить викладач у результатах іспиту. Змінити можна в «Мій акаунт».'),
      h('label', { class: 'field' }, h('span', {}, 'Прізвище та ім’я'), fullName),
      h('label', { class: 'field' }, h('span', {}, 'Група'), group),
      err,
      h('div', { class: 'row' }, h('button', { class: 'btn text', onClick: () => { d.close(); resolve(null); } }, 'Скасувати'), ok),
    ], { dismissible: false });
    setTimeout(() => fullName.focus(), 50);
  });
}

/** Наявна спроба: здана → результат; триває → продовжити або автоздача. */
async function continueAttempt(session, attempt) {
  if (attempt.status === 'submitted') { openResult(session, attempt); return; }
  const wait = pushScreen(({ pop }) => page(session.title, pop, spinner()));
  try {
    const keys = await loadExamKeys(session);
    const { attempt: fresh, offset } = await syncAttempt(attemptRef(session.id, attempt.uid));
    const cfg = examConfig(session);
    const deadline = attemptDeadline(toDate(fresh.startedAt), cfg.timeLimitMin, toDate(session.deadline));
    const now = new Date(Date.now() + offset);
    wait.pop();
    if (session.status !== 'active' || (deadline && now >= deadline)) {
      const done = await submitAttempt(session, fresh, keys, { auto: true });
      toast(session.status !== 'active' ? 'Сесію закрито — іспит здано автоматично' : 'Час вичерпано — іспит здано автоматично', '', 4000);
      openResult(session, done, keys);
      return;
    }
    openRunner(session, fresh, keys, offset);
  } catch (e) {
    wait.pop();
    toast(errorText(e), 'err', 5000);
  }
}

// ── Інструкція перед стартом ────────────────────────────────────────────────
function openIntro(session, profile) {
  pushScreen(({ pop }) => {
    const s = session;
    const cfg = examConfig(s);
    const row = (ic, label, value) => h('div', { class: 'dk-row', style: { margin: '6px 0', gap: '8px' } },
      h('span', { class: 'mi', style: { fontSize: '18px', color: 'var(--grey-600)' } }, ic), h('span', { class: 's' }, `${label}:`), h('b', {}, value));
    const part = (ic, title, sub, color) => h('div', { class: 'dk-row', style: { margin: '6px 0', gap: '10px' } },
      h('span', { class: 'mi', style: { color } }, ic), h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, title), h('div', { class: 's' }, sub)));
    const rule = (text) => h('li', { style: { margin: '4px 0' } }, text);
    const end = toDate(s.deadline);
    const err = h('div', { class: 'err', hidden: true });
    const start = h('button', { class: 'btn block', style: { padding: '14px', marginTop: '16px' } }, icon('play_arrow'), 'Почати іспит');

    start.addEventListener('click', async () => {
      err.hidden = true;
      start.disabled = true;
      try {
        const attempt = await createAttempt(s, profile);
        const keys = attempt.keys;
        delete attempt.keys;
        const { attempt: fresh, offset } = await syncAttempt(attemptRef(s.id, attempt.uid));
        const deadline = attemptDeadline(toDate(fresh.startedAt), cfg.timeLimitMin, end);
        if (deadline) updateDoc(attemptRef(s.id, attempt.uid), { deadlineAt: Timestamp.fromDate(deadline) }).catch((e) => console.warn('deadlineAt', e));
        pop();
        openRunner(s, fresh, keys, offset);
      } catch (e) {
        err.textContent = e.userMessage || errorText(e);
        err.hidden = false;
        start.disabled = false;
      }
    });

    return page('Інструкція', pop, h('div', { class: 'body-inner', style: { maxWidth: '640px' } },
      h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { class: 'dk-row', style: { gap: '10px' } }, h('span', { class: 'mi', style: { color: GREEN, fontSize: '28px' } }, 'school'),
          h('div', { style: { fontSize: '17px', fontWeight: 700, color: GREEN } }, s.title)),
        h('hr'),
        row('person', 'Студент', profile.fullName), row('groups', 'Група', profile.group), row('tag', 'Код сесії', s.code),
        cfg.timeLimitMin ? row('timer', 'Час на іспит', `${cfg.timeLimitMin} хв`) : null,
        end ? row('event', 'Сесія доступна до', fmtDateTime(end)) : null,
        h('hr'),
        h('div', { class: 's', style: { fontWeight: 700, marginBottom: '4px' } }, 'Частини іспиту'),
        cfg.theory ? part('menu_book', 'Теоретичний тест', `${cfg.theory.count} питань · до ${cfg.theory.maxPoints} балів`, BLUE) : null,
        cfg.audio ? part('headphones', 'Аудіотест', `${cfg.audio.count} сигналів · до ${cfg.audio.maxPoints} балів`, PURPLE) : null,
        cfg.file ? part('upload_file', 'Файлове завдання', `до ${cfg.file.maxPoints} балів · перевіряє викладач`, ORANGE) : null),
      h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { class: 't', style: { marginBottom: '4px' } }, 'Правила'),
        h('ul', { style: { margin: 0, paddingLeft: '20px', fontSize: '14px', lineHeight: 1.5 } },
          rule('Одна спроба. Після здачі пройти повторно не можна.'),
          rule('Відповідь можна змінити до здачі — переходьте між питаннями кнопками або номерами.'),
          rule('Правильність відповідей не показується до завершення іспиту.'),
          rule('Кожна відповідь зберігається одразу: якщо сторінка закрилася, введіть код ще раз і продовжуйте.'),
          cfg.timeLimitMin ? rule('Таймер не зупиняється. Коли час вийде, іспит буде здано автоматично.') : null,
          cfg.audio ? rule('Для аудіотесту потрібні навушники. Сигнал можна прослухати кілька разів.') : null,
          rule('Не перемикайтеся на інші вкладки та застосунки — викладач бачить кількість виходів.'))),
      err, start));
  });
}

/** Створює спробу з зафіксованим набором питань. */
async function createAttempt(session, profile) {
  const cfg = examConfig(session);
  const keys = await loadExamKeys(session);
  const fail = (m) => Object.assign(new Error(m), { userMessage: m });
  let theory = null;
  let aud = null;
  if (cfg.theory) {
    const items = pickTheory(keys.questions, cfg.theory);
    if (!items.length) throw fail('Для теоретичної частини немає питань. Зверніться до викладача.');
    theory = { items, correct: null, total: items.length, points: null };
  }
  if (cfg.audio) {
    const pool = signalPool(keys.signals, cfg.audio);
    const items = buildAudioItems(pool, cfg.audio.count, Math.random, signalPool(keys.signals));
    if (!items.length) throw fail('Для аудіочастини немає сигналів з аудіо. Зверніться до викладача.');
    aud = { items, correct: null, total: items.length, points: null };
  }
  const user = auth.currentUser;
  const attempt = {
    sessionId: session.id, sessionCode: session.code, sessionTitle: session.title || '',
    uid: user.uid, email: (user.email || '').toLowerCase(), fullName: profile.fullName, group: profile.group,
    status: 'in_progress', startedAt: serverTimestamp(), submittedAt: null, deadlineAt: null,
    theory, audio: aud, file: cfg.file ? { fileUrl: null, fileName: null } : null,
    totalPoints: null, visibilityLeaves: 0, autoSubmitted: false,
  };
  await setDoc(attemptRef(session.id, user.uid), attempt);
  return { ...attempt, keys };
}

// ── Іспит ────────────────────────────────────────────────────────────────────
function openRunner(session, attempt, keys, offset) {
  const cfg = examConfig(session);
  const ref = attemptRef(session.id, attempt.uid);
  const deadline = attemptDeadline(toDate(attempt.startedAt), cfg.timeLimitMin, toDate(session.deadline));
  const serverNow = () => Date.now() + offset;
  const theoryItems = attempt.theory?.items || [];
  const audioItems = attempt.audio?.items || [];
  // Плаский список сторінок: спершу теорія, потім аудіо, наприкінці файл
  const pages = [
    ...theoryItems.map((it, i) => ({ part: 'theory', it, i })),
    ...audioItems.map((it, i) => ({ part: 'audio', it, i })),
    ...(cfg.file ? [{ part: 'file' }] : []),
  ];
  const questionCount = theoryItems.length + audioItems.length;

  pushScreen((ctx) => {
    let cur = Math.max(0, pages.findIndex((p) => p.it && p.it.answer == null));
    if (cur < 0 || cur >= pages.length) cur = 0;
    let finished = false;
    let submitting = false;
    let timer = null;
    let saveTimer = null;
    const dirty = new Set();
    let saving = null;

    const body = h('div', { class: 'body-inner', style: { maxWidth: '680px', paddingBottom: '32px' } });
    const timerEl = h('div', { style: { fontWeight: 700, fontSize: '18px', fontVariantNumeric: 'tabular-nums', color: '#fff' } });
    const saveEl = h('div', { style: { fontSize: '11px', color: 'rgba(255,255,255,.7)' } }, 'Збережено');
    const header = h('div', { style: { background: GREEN, color: '#fff', padding: '8px 16px', display: 'flex', alignItems: 'center', gap: '12px' } },
      h('div', { style: { flex: 1, minWidth: 0 } }), h('div', { style: { textAlign: 'right' } }, deadline ? timerEl : null, saveEl));
    const headLeft = header.firstChild;

    // ── Збереження відповідей (дебаунс 500 мс) ──
    const setSaveState = (text, bad = false) => { saveEl.textContent = text; saveEl.style.color = bad ? '#FFAB91' : 'rgba(255,255,255,.7)'; };
    const flush = async () => {
      clearTimeout(saveTimer);
      saveTimer = null;
      if (saving) await saving.catch(() => {});
      if (!dirty.size) return;
      const update = {};
      if (dirty.has('theory')) update['theory.items'] = theoryItems;
      if (dirty.has('audio')) update['audio.items'] = audioItems;
      dirty.clear();
      setSaveState('Зберігається…');
      saving = updateDoc(ref, update);
      try {
        await saving;
        setSaveState('Збережено');
      } catch (e) {
        console.warn('exam save', e);
        Object.keys(update).forEach((k) => dirty.add(k.split('.')[0]));
        setSaveState('Не збережено — повтор…', true);
        if (!finished) saveTimer = setTimeout(flush, 3000);
        throw e;
      } finally { saving = null; }
    };
    const scheduleSave = (part) => {
      dirty.add(part);
      setSaveState('Зберігається…');
      clearTimeout(saveTimer);
      saveTimer = setTimeout(() => flush().catch(() => {}), SAVE_DELAY);
    };

    // ── Захист від випадкових втрат ──
    const onBeforeUnload = (e) => { if (!finished) { flush().catch(() => {}); e.preventDefault(); e.returnValue = ''; } };
    const onVisibility = () => {
      if (document.visibilityState === 'hidden' && !finished) {
        updateDoc(ref, { visibilityLeaves: increment(1) }).catch((e) => console.warn('visibilityLeaves', e));
        flush().catch(() => {});
      }
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    document.addEventListener('visibilitychange', onVisibility);
    const cleanup = () => {
      clearInterval(timer);
      audio.stop();
      window.removeEventListener('beforeunload', onBeforeUnload);
      document.removeEventListener('visibilitychange', onVisibility);
    };
    // Кнопка «Назад» браузера закриває екран одразу — відповіді вже збережено,
    // повернутися можна, ввівши код ще раз (таймер іде далі).
    ctx.onPop = () => {
      cleanup();
      if (!finished) {
        flush().catch(() => {});
        toast('Іспит не завершено. Щоб продовжити, введіть код сесії ще раз.', '', 5000);
      }
    };
    const exit = async () => {
      if (await confirmDialog('Вийти з іспиту?', 'Відповіді збережено. Продовжити можна, ввівши код сесії ще раз. Таймер не зупиняється.',
        { okLabel: 'Вийти', cancelLabel: 'Залишитися', danger: true })) ctx.pop();
    };

    // ── Таймер ──
    const tick = () => {
      if (!deadline) return;
      const left = deadline.getTime() - serverNow();
      timerEl.textContent = clock(left);
      timerEl.style.color = left <= 60000 ? '#FF8A80' : left <= 300000 ? GOLD : '#fff';
      if (left <= 0 && !finished && !submitting) finish(true);
    };

    // ── Сторінки ──
    const answeredTotal = () => answeredCount(theoryItems) + answeredCount(audioItems);
    const optionButtons = (opts, it, part) => opts.map((o, k) => h('button', {
      class: 'tile', style: {
        width: '100%', textAlign: 'left', cursor: 'pointer',
        borderLeft: `4px solid ${it.answer === k ? GREEN : 'transparent'}`,
        background: it.answer === k ? 'rgba(28,58,28,.10)' : '',
      },
      onClick: () => { it.answer = k; scheduleSave(part); render(false); },
    }, h('span', { class: 'mi', style: { color: it.answer === k ? GREEN : 'var(--grey-500, #9e9e9e)' } }, it.answer === k ? 'radio_button_checked' : 'radio_button_unchecked'),
    h('span', { class: 'grow' }, o)));

    const grid = () => h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '6px', margin: '16px 0' } },
      pages.map((p, k) => {
        const answered = p.part === 'file' ? !!attempt.file?.fileName : p.it.answer != null;
        const color = p.part === 'theory' ? BLUE : p.part === 'audio' ? PURPLE : ORANGE;
        return h('button', {
          title: p.part === 'file' ? 'Файл' : `Питання ${k + 1}`,
          style: {
            width: '36px', height: '36px', borderRadius: '50%', fontWeight: 700, fontSize: '13px', cursor: 'pointer',
            border: `2px solid ${color}`, background: answered ? color : 'transparent', color: answered ? '#fff' : color,
            outline: k === cur ? `3px solid ${GOLD}` : 'none', outlineOffset: '1px',
          },
          onClick: () => { cur = k; audio.stop(); render(); },
        }, p.part === 'file' ? h('span', { class: 'mi', style: { fontSize: '18px' } }, 'attach_file') : String(k + 1));
      }));

    const theoryPage = (p) => {
      const q = keys.questionsById.get(p.it.qid);
      if (!q) return [h('div', { class: 'tile' }, 'Це питання видалено з банку питань. Перейдіть до наступного.')];
      return [h('div', { style: { fontSize: '16px', fontWeight: 600, margin: '12px 0', lineHeight: 1.5, whiteSpace: 'pre-wrap' } }, q.question),
        ...optionButtons(orderedOptions(q, p.it.order), p.it, 'theory')];
    };
    const audioPage = (p) => {
      const sig = keys.signalsById.get(p.it.signalId);
      const play = h('button', { class: 'play-big', style: { margin: '0 auto' }, disabled: !sig?.audioUrl,
        onClick: () => audio.play(sig.audioUrl).catch((e) => toast(`Помилка відтворення: ${e.message}`, 'err')) }, icon('play_arrow'));
      return [h('div', { style: { textAlign: 'center', margin: '12px 0' } }, play,
        h('div', { class: 's', style: { marginTop: '8px' } }, sig ? '🎺 Прослухайте сигнал (можна кілька разів) і оберіть його назву' : 'Аудіо недоступне')),
      ...optionButtons(p.it.options, p.it, 'audio')];
    };
    const filePage = () => {
      const f = attempt.file || {};
      const status = h('div', { class: 's', style: { margin: '8px 0' } }, f.fileName ? `Завантажено: ${f.fileName}` : 'Файл ще не додано (необов’язково)');
      const choose = h('button', { class: 'btn text block', style: { border: `1px dashed ${ORANGE}`, color: ORANGE, padding: '16px' }, onClick: async () => {
        const [file] = await pickFiles({ accept: FILE_EXT.map((e) => `.${e}`).join(',') });
        if (!file) return;
        const ext = file.name.split('.').pop().toLowerCase();
        if (!FILE_EXT.includes(ext)) { toast('Дозволені формати: PDF, DOC, DOCX, TXT, ODT', 'err'); return; }
        choose.disabled = true;
        status.textContent = 'Завантаження…';
        try {
          const r = storageRef(storage, `exam_files/${session.id}/${attemptIdOf(session.id, attempt.uid)}.${ext}`);
          await uploadBytes(r, file, { contentType: file.type || undefined });
          const fileUrl = await getDownloadURL(r);
          await updateDoc(ref, { file: { fileUrl, fileName: file.name } });
          attempt.file = { fileUrl, fileName: file.name };
          render();
        } catch (e) { toast(`Файл не завантажено: ${errorText(e)}`, 'err', 5000); status.textContent = 'Помилка завантаження'; choose.disabled = false; }
      } }, icon('attach_file'), f.fileName ? 'Замінити файл' : 'Вибрати файл');
      return [h('div', { class: 'tile', style: { display: 'block', borderLeft: `4px solid ${ORANGE}` } },
        h('div', { class: 't' }, 'Завдання'),
        h('div', { style: { whiteSpace: 'pre-wrap', margin: '8px 0' } }, cfg.file.description || '—'),
        h('div', { class: 's' }, `Максимум: ${cfg.file.maxPoints} балів · перевіряє викладач`)),
      h('div', { class: 's', style: { margin: '8px 0' } }, 'Дозволені формати: PDF, DOC, DOCX, TXT, ODT'),
      choose, status];
    };

    const render = (scrollTop = true) => {
      const p = pages[cur];
      const partLabel = p.part === 'theory' ? '📖 Теорія' : p.part === 'audio' ? '🎧 Аудіо' : '📎 Файлове завдання';
      clear(headLeft).append(
        h('div', { style: { fontSize: '12px', opacity: 0.75 } }, partLabel),
        h('div', { style: { fontWeight: 700 } }, p.part === 'file' ? 'Файл' : `Питання ${cur + 1} з ${questionCount}`));
      const prev = h('button', { class: 'btn text', disabled: cur === 0, onClick: () => { cur--; audio.stop(); render(); } }, icon('chevron_left'), 'Назад');
      const next = h('button', { class: 'btn', disabled: cur === pages.length - 1, onClick: () => { cur++; audio.stop(); render(); } }, 'Далі', icon('chevron_right'));
      clear(body).append(
        ...(p.part === 'theory' ? theoryPage(p) : p.part === 'audio' ? audioPage(p) : filePage()),
        h('div', { class: 'dk-row', style: { justifyContent: 'space-between', marginTop: '16px' } }, prev, next),
        grid(),
        h('div', { class: 's', style: { textAlign: 'center' } }, `Відповіді: ${answeredTotal()} з ${questionCount}`),
        h('button', { class: 'btn block', style: { padding: '14px', marginTop: '12px', background: '#5D4037' }, onClick: () => finish(false) },
          icon('task_alt'), 'Завершити іспит'));
      if (scrollTop) body.parentElement?.scrollTo?.(0, 0);
    };

    // ── Здача ──
    const finish = async (auto) => {
      if (finished || submitting) return;
      if (!auto) {
        const n = answeredTotal();
        const ok = await confirmDialog('Завершити іспит?',
          `Ви відповіли на ${n} з ${questionCount} питань.${n < questionCount ? ' Питання без відповіді буде зараховано як неправильні.' : ''} Після здачі змінити відповіді не можна.`,
          { okLabel: 'Завершити', cancelLabel: 'Повернутися' });
        if (!ok || finished || submitting) return;
      }
      submitNow(auto);
    };
    const submitNow = async (auto) => {
      if (finished || submitting) return;
      submitting = true;
      audio.stop();
      clear(body).append(h('div', { style: { textAlign: 'center', padding: '48px 0' } }, spinner(),
        h('div', { style: { marginTop: '12px' } }, auto ? 'Час вичерпано. Здаємо іспит…' : 'Здаємо іспит…')));
      try {
        await flush().catch(() => {});
        const done = await submitAttempt(session, { ...attempt, theory: attempt.theory && { ...attempt.theory, items: theoryItems }, audio: attempt.audio && { ...attempt.audio, items: audioItems } }, keys, { auto });
        finished = true;
        cleanup();
        ctx.onPop = null;
        ctx.pop();
        openResult(session, done, keys);
      } catch (e) {
        submitting = false;
        clear(body).append(emptyState('error_outline', 'Не вдалося здати іспит', errorText(e)),
          h('div', { style: { textAlign: 'center' } },
            h('button', { class: 'btn', onClick: () => submitNow(auto) }, icon('refresh'), 'Спробувати ще раз'),
            h('button', { class: 'btn text', onClick: render }, 'Повернутися до питань')));
      }
    };

    render();
    if (deadline) { tick(); timer = setInterval(tick, 1000); }
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(session.title, { back: exit, cls: 'brown' }),
      header,
      h('div', { class: 'body' }, body));
  });
}

// ── Результат ────────────────────────────────────────────────────────────────
function openResult(session, attempt, keysIn = null) {
  const cfg = examConfig(session);
  pushScreen(({ pop }) => {
    const review = h('div');
    const line = (label, part, max, color) => (part ? h('div', { class: 'tile', style: { borderLeft: `4px solid ${color}` } },
      h('div', { class: 'grow', style: { fontSize: '18px' } }, h('b', {}, `${label}: `), `${part.correct ?? 0} з ${part.total ?? 0} → `,
        h('b', { style: { color } }, `${part.points ?? 0} ${balWord(part.points ?? 0)}`)),
      h('span', { class: 's' }, `макс. ${max}`)) : null);
    const autoMax = (attempt.theory ? cfg.theory?.maxPoints ?? 0 : 0) + (attempt.audio ? cfg.audio?.maxPoints ?? 0 : 0);
    const submitted = toDate(attempt.submittedAt);

    if (cfg.showReview) {
      review.append(spinner());
      (keysIn ? Promise.resolve(keysIn) : loadExamKeys(session))
        .then((keys) => clear(review).append(h('div', { class: 'sec-title' }, 'Розбір відповідей'), ...reviewList(attempt, keys)))
        .catch((e) => clear(review).append(emptyState('error_outline', 'Не вдалося завантажити розбір', errorText(e))));
    }

    return page('Результат іспиту', pop, h('div', { class: 'body-inner', style: { maxWidth: '640px' } },
      h('div', { style: { textAlign: 'center', padding: '12px 0' } },
        h('span', { class: 'mi', style: { fontSize: '64px', color: '#2E7D32' } }, 'check_circle'),
        h('div', { style: { fontSize: '22px', fontWeight: 700, color: GREEN } }, 'Іспит здано'),
        h('div', { class: 's' }, [attempt.fullName, attempt.group].filter(Boolean).join(' · ')),
        h('div', { class: 's' }, `${session.title} · код ${session.code}`),
        submitted ? h('div', { class: 's' }, `Здано: ${fmtDateTime(submitted)}${attempt.autoSubmitted ? ' (автоматично)' : ''}`) : null),
      line('Теорія', attempt.theory, cfg.theory?.maxPoints ?? 0, BLUE),
      line('Аудіо', attempt.audio, cfg.audio?.maxPoints ?? 0, PURPLE),
      attempt.file ? h('div', { class: 'tile', style: { borderLeft: `4px solid ${ORANGE}` } },
        h('div', { class: 'grow' }, h('b', {}, 'Файлове завдання: '), attempt.file.fileName || 'файл не додано'),
        h('span', { class: 's', style: { color: ORANGE } }, 'оцінює викладач')) : null,
      h('div', { class: 'tile', style: { display: 'block', background: GREEN, color: '#fff', textAlign: 'center' } },
        h('div', { style: { fontSize: '14px', opacity: 0.8 } }, 'Разом'),
        h('div', { style: { fontSize: '30px', fontWeight: 700, color: GOLD } }, `${attempt.totalPoints ?? 0} з ${autoMax}`)),
      h('div', { class: 's', style: { textAlign: 'center', margin: '8px 0' } }, 'Покажіть цей екран викладачу.'),
      review,
      h('button', { class: 'btn block', style: { marginTop: '16px' }, onClick: pop }, icon('home'), 'Готово')));
  });
}

const balWord = (n) => {
  const a = Math.abs(n) % 100; const b = a % 10;
  if (a > 10 && a < 20) return 'балів';
  if (b === 1) return 'бал';
  if (b >= 2 && b <= 4) return 'бали';
  return 'балів';
};

/** Розбір відповідей спроби (студент після здачі, якщо дозволено, і адмін). */
export function reviewList(attempt, keys) {
  const tile = (n, title, chosen, correct, ok, extra) => h('div', { class: 'tile', style: { display: 'block', borderLeft: `4px solid ${ok ? '#2E7D32' : '#C62828'}` } },
    h('div', { class: 't', style: { fontSize: '14px' } }, `${n}. ${title}`),
    h('div', { class: 's' }, `Відповідь: ${chosen ?? 'немає'}`),
    ok ? null : h('div', { class: 's', style: { color: '#2E7D32' } }, `Правильно: ${correct ?? '—'}`),
    extra ? h('div', { class: 's', style: { marginTop: '4px', fontStyle: 'italic' } }, extra) : null);
  let n = 0;
  const out = [];
  (attempt.theory?.items || []).forEach((it) => {
    n++;
    const q = keys.questionsById.get(it.qid);
    if (!q) { out.push(tile(n, 'Питання видалено з банку', null, null, false)); return; }
    const opts = orderedOptions(q, it.order);
    const ok = countTheoryCorrect([it], keys.questionsById) === 1;
    out.push(tile(n, q.question, it.answer != null ? opts[it.answer] : null, q.options[Number(q.correctIndex) || 0], ok, q.explanation || null));
  });
  (attempt.audio?.items || []).forEach((it) => {
    n++;
    const s = keys.signalsById.get(it.signalId);
    const chosen = it.answer != null ? it.options[it.answer] : null;
    out.push(tile(n, '🎧 Сигнал', chosen, s?.name, !!s && chosen === s.name));
  });
  return out;
}

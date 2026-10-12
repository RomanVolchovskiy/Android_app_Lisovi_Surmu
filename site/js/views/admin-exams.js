// Управління іспитами (ТЗ практики, розділ 5.3): сесії, пресет заліку,
// живі результати, анулювання / примусова здача, ручні оцінки, CSV і друк.
// Сесії сумісні з exam_models.dart (додаток): нові поля лише додаються.
import { h, icon, toast, pushScreen, appBar, confirmDialog, openDialog, clear, spinner, emptyState } from '../ui.js';
import {
  db, auth, collection, doc, getDocs, getDocFromServer, setDoc, updateDoc, onSnapshot, query, where, orderBy,
  writeBatch, Timestamp,
} from '../firebase.js';
import { generateCode } from '../access.js';
import { waitForSignals } from '../data.js';
import { examConfig, signalPool, toCsv, fmtDateTime } from '../quiz-core.js';
import {
  SESSIONS, ATTEMPTS, SUBMISSIONS, PRACTICE_TAG, toDate, loadExamKeys, submitAttempt, errorText,
} from '../exam-data.js';
import { reviewList } from './exam.js';

const TOPICS = 'edu_topics';
const GREEN = '#1C3A1C';
const GOLD = '#D4A017';

const STATUS = {
  draft: { label: 'Чернетка', color: '#9E9E9E' },
  active: { label: 'Активна', color: '#2E7D32' },
  closed: { label: 'Закрита', color: '#C62828' },
};
const PARTS = {
  theory: { icon: 'menu_book', label: 'Теорія', color: '#1976D2' },
  audio: { icon: 'headphones', label: 'Аудіо', color: '#7B1FA2' },
  file: { icon: 'upload_file', label: 'Файл', color: '#EF6C00' },
};

// Пресет «Залік практики ЛГс-32» (ТЗ 5.3)
const PRESET = {
  title: 'Залік з навчальної практики ЛГс-32', group: 'ЛГс-32', timeLimitMin: 30, showReview: false,
  theoryTopicName: 'Підсумковий тест навчальної практики (20 питань)', theoryCount: 20, theoryMax: 20,
  audioTag: PRACTICE_TAG, audioCount: 10, audioMax: 6,
};

const pad = (n) => String(n).padStart(2, '0');
const int = (v) => { const n = parseInt(String(v).trim(), 10); return Number.isNaN(n) ? null : n; };
const totalMax = (s) => (s.theoryEnabled ? s.theoryMaxPoints || 0 : 0) + (s.audioEnabled ? s.audioMaxPoints || 0 : 0) + (s.fileEnabled ? s.fileMaxPoints || 0 : 0);
const withId = (d) => ({ ...d.data(), id: d.data().id || d.id });

const pill = (text, color) => h('span', { style: {
  padding: '3px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 600, color,
  background: `${color}1F`, border: `1px solid ${color}80`, whiteSpace: 'nowrap',
} }, text);

const partChip = (part, text) => h('span', { style: {
  display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 8px', borderRadius: '20px',
  fontSize: '11px', fontWeight: 600, color: PARTS[part].color, background: `${PARTS[part].color}1A`, border: `1px solid ${PARTS[part].color}4D`,
} }, h('span', { class: 'mi', style: { fontSize: '13px' } }, PARTS[part].icon), text);

const actBtn = (ic, label, color, onClick) => h('button', { class: 'btn text', style: { color, padding: '6px 8px', fontSize: '12px', gap: '4px' }, onClick },
  h('span', { class: 'mi', style: { fontSize: '16px' } }, ic), label);

async function copyText(text) {
  try { await navigator.clipboard.writeText(text); toast(`Скопійовано: ${text}`, 'ok'); } catch { toast('Не вдалося скопіювати', 'err'); }
}

// ── Список сесій ─────────────────────────────────────────────────────────────
export function openAdminExams() {
  pushScreen((ctx) => {
    let sessions = null;
    let counts = new Map(); // sessionId → { started, submitted }
    const body = h('div', { class: 'body-inner', style: { paddingBottom: '96px' } }, spinner());

    const fail = (e) => clear(body).append(emptyState('error_outline', 'Помилка завантаження', errorText(e)));
    const offSessions = onSnapshot(query(collection(db, SESSIONS), orderBy('createdAt', 'desc')),
      (snap) => { sessions = snap.docs.map(withId); draw(); }, fail);
    const offAttempts = onSnapshot(collection(db, ATTEMPTS), (snap) => {
      counts = new Map();
      snap.docs.forEach((d) => {
        const a = d.data();
        const c = counts.get(a.sessionId) || { started: 0, submitted: 0 };
        c.started++;
        if (a.status === 'submitted') c.submitted++;
        counts.set(a.sessionId, c);
      });
      draw();
    }, (e) => console.warn('exam_attempts', e));
    ctx.onPop = () => { offSessions(); offAttempts(); };

    const save = async (s, merge) => {
      try {
        await setDoc(doc(db, SESSIONS, s.id), s, merge ? { merge: true } : {});
        toast(merge ? `Сесію «${s.title}» збережено` : `Сесію «${s.title}» створено. Код: ${s.code}`, 'ok', 4000);
        return true;
      } catch (e) { toast(errorText(e), 'err'); return false; }
    };
    const create = () => openSessionForm(null, (s) => save(s, false));
    const edit = (existing) => openSessionForm(existing, (s) => save(s, true));

    const setStatus = async (s, status) => {
      try { await updateDoc(doc(db, SESSIONS, s.id), { status }); } catch (e) { toast(errorText(e), 'err'); }
    };

    // Сесія разом зі спробами й роботами — пакетами (ліміт батча 500 операцій)
    const remove = async (s) => {
      const c = counts.get(s.id);
      if (!await confirmDialog('Видалити сесію?',
        `Сесію «${s.title}» буде видалено разом з усіма спробами й результатами${c ? ` (${c.started})` : ''}. Це незворотно — спершу вивантажте CSV.`,
        { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
      try {
        const [atts, subs] = await Promise.all([
          getDocs(query(collection(db, ATTEMPTS), where('sessionId', '==', s.id))),
          getDocs(query(collection(db, SUBMISSIONS), where('sessionId', '==', s.id))),
        ]);
        const refs = [...atts.docs.map((d) => d.ref), ...subs.docs.map((d) => d.ref), doc(db, SESSIONS, s.id)];
        for (let i = 0; i < refs.length; i += 450) {
          const b = writeBatch(db);
          refs.slice(i, i + 450).forEach((r) => b.delete(r));
          await b.commit();
        }
        toast('Сесію видалено', 'ok');
      } catch (e) { toast(errorText(e), 'err'); }
    };

    const sessionCard = (s) => {
      const st = STATUS[s.status] ?? { label: s.status, color: '#9E9E9E' };
      const cfg = examConfig(s);
      const c = counts.get(s.id) || { started: 0, submitted: 0 };
      const start = toDate(s.startsAt);
      const end = toDate(s.deadline);
      return h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { style: { display: 'flex', alignItems: 'center', gap: '8px' } },
          h('div', { class: 't grow' }, s.title), pill(st.label, st.color)),
        h('div', { style: { display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap', margin: '8px 0' } },
          h('span', { class: 'mono', style: { background: GREEN, color: GOLD, fontWeight: 700, fontSize: '20px', letterSpacing: '4px', padding: '4px 12px', borderRadius: '8px' } }, s.code),
          h('button', { class: 'iconbtn', title: 'Копіювати код', onClick: () => copyText(s.code) }, icon('content_copy')),
          s.group ? h('span', { class: 's' }, s.group) : null,
          h('span', { class: 's' }, `${totalMax(s)} балів`),
          cfg.timeLimitMin ? h('span', { class: 's' }, `⏱ ${cfg.timeLimitMin} хв`) : null),
        start || end ? h('div', { class: 's', style: { marginBottom: '6px' } },
          [start ? `з ${fmtDateTime(start)}` : null, end ? `до ${fmtDateTime(end)}` : null].filter(Boolean).join(' ')) : null,
        h('div', { style: { display: 'flex', gap: '6px', flexWrap: 'wrap', alignItems: 'center' } },
          cfg.theory ? partChip('theory', `${cfg.theory.count} пит. · ${cfg.theory.maxPoints} б`) : null,
          cfg.audio ? partChip('audio', `${cfg.audio.count} сигн. · ${cfg.audio.maxPoints} б`) : null,
          cfg.file ? partChip('file', `${cfg.file.maxPoints} б`) : null,
          h('span', { class: 's', style: { marginLeft: 'auto' } }, `здано ${c.submitted} / розпочато ${c.started}`)),
        h('div', { style: { display: 'flex', alignItems: 'center', flexWrap: 'wrap', borderTop: '1px solid var(--grey-300, #ddd)', marginTop: '10px', paddingTop: '6px' } },
          s.status === 'active'
            ? actBtn('lock', 'Закрити', '#EF6C00', () => setStatus(s, 'closed'))
            : actBtn('play_arrow', 'Активувати', '#2E7D32', () => setStatus(s, 'active')),
          h('div', { class: 'grow' }),
          actBtn('bar_chart', 'Результати', GREEN, () => openResults(s)),
          actBtn('edit', 'Редагувати', '#5D4037', () => edit(s)),
          actBtn('delete_outline', 'Видалити', '#C62828', () => remove(s))));
    };

    const draw = () => {
      if (!sessions) return;
      clear(body);
      if (!sessions.length) {
        body.append(emptyState('event_note', 'Сесій ще немає'),
          h('div', { style: { textAlign: 'center' } }, h('button', { class: 'btn', onClick: create }, icon('add'), 'Створити першу сесію')));
        return;
      }
      sessions.forEach((s) => body.append(sessionCard(s)));
    };

    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Управління іспитами', { back: ctx.pop, cls: 'brown' }),
      h('div', { class: 'body' }, body),
      h('button', { class: 'fab', title: 'Нова сесія', onClick: create }, icon('add')));
  });
}

// ── Створення / редагування сесії ───────────────────────────────────────────
// existing = null — нова сесія (id = код); інакше код, дата створення й статус
// лишаються незмінними.
function openSessionForm(existing, onSave) {
  const e = existing || {};
  const ec = examConfig(e);
  pushScreen(async ({ pop }) => {
    let topics = [];
    const qCount = new Map();
    let signals = [];
    try {
      const [tSnap, qSnap, sigs] = await Promise.all([getDocs(collection(db, TOPICS)), getDocs(collection(db, 'edu_test_questions')), waitForSignals()]);
      topics = tSnap.docs.map((d) => ({ ...d.data(), id: d.id })).sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
      qSnap.docs.forEach((d) => { const t = d.data().topicId; qCount.set(t, (qCount.get(t) || 0) + 1); });
      signals = sigs;
    } catch (err) { toast(`Не вдалося завантажити теми й сигнали: ${errorText(err)}`, 'err'); }
    const withAudio = signalPool(signals);

    const field = (label, el) => h('label', { class: 'field' }, h('span', {}, label), el);
    const num = (value, min = 0) => h('input', { type: 'number', min, value: value ?? '' });
    const check = (label, checked) => {
      const cb = h('input', { type: 'checkbox', checked: !!checked });
      return { cb, el: h('label', { class: 'dk-row', style: { fontSize: '14px', margin: '6px 0', gap: '8px', cursor: 'pointer' } }, cb, label) };
    };
    const local = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    const dateField = (label, value) => {
      const c = check(label, !!value);
      const input = h('input', { type: 'datetime-local', value: local(value ?? new Date()), disabled: !value });
      c.cb.addEventListener('change', () => { input.disabled = !c.cb.checked; });
      return { cb: c.cb, input, el: h('div', {}, c.el, input) };
    };

    // Основне
    const title = h('input', { type: 'text', placeholder: 'Напр. Залік з навчальної практики', value: e.title ?? '' });
    const group = h('input', { type: 'text', placeholder: 'Напр. ЛГс-32', value: e.group ?? '' });
    const timeLimit = num(e.timeLimitMin ?? 30);
    const passing = num(e.passingScore ?? 60);
    const review = check('Показувати розбір відповідей після здачі', e.showReview);
    const startsAt = dateField('Доступна від', toDate(e.startsAt));
    const deadline = dateField('Доступна до', toDate(e.deadline));

    // Теорія: мультивибір тем (разом із прихованими) з кількістю питань
    const chosen = new Set(ec.theory?.topicIds ?? (e.theoryTopicId ? [e.theoryTopicId] : []));
    const topicBoxes = topics.map((t) => {
      const cb = h('input', { type: 'checkbox', checked: chosen.has(t.id) });
      cb.addEventListener('change', () => { if (cb.checked) chosen.add(t.id); else chosen.delete(t.id); onTopicsChanged(); });
      return h('label', { class: 'dk-row', style: { gap: '8px', padding: '4px 0', cursor: 'pointer', fontSize: '14px' } }, cb,
        h('span', { class: 'grow' }, t.name, t.hidden ? h('span', { class: 's', style: { marginLeft: '6px', color: '#EF6C00' } }, '(прихована)') : null),
        h('span', { class: 's' }, `${qCount.get(t.id) || 0} пит.`));
    });
    const theoryCount = num(ec.theory?.count ?? 20, 1);
    const theoryMax = num(e.theoryEnabled ? e.theoryMaxPoints : 20);
    const shuffleQ = check('Перемішувати питання', ec.theory?.shuffleQuestions ?? true);
    const shuffleO = check('Перемішувати варіанти відповідей', ec.theory?.shuffleOptions ?? true);
    const theoryPool = () => [...chosen].reduce((a, id) => a + (qCount.get(id) || 0), 0);
    let theoryCountTouched = !!existing;
    theoryCount.addEventListener('input', () => { theoryCountTouched = true; updatePreview(); });
    const onTopicsChanged = () => {
      if (!theoryCountTouched) theoryCount.value = Math.min(theoryPool(), 20) || 20;
      updatePreview();
    };

    // Аудіо: тег, ручний вибір сигналів або (старі сесії) рівень складності
    const initialSource = ec.audio?.signalIds ? 'manual' : (ec.audio?.difficulty && !ec.audio?.tag) ? 'difficulty' : 'tag';
    const source = h('select', {}, [['tag', 'За тегом'], ['manual', 'Вибрати сигнали вручну'], ['difficulty', 'За рівнем складності']]
      .map(([v, l]) => h('option', { value: v, selected: v === initialSource }, l)));
    const tag = h('input', { type: 'text', value: ec.audio?.tag ?? PRACTICE_TAG });
    const difficulty = h('select', {}, [['', 'Усі рівні'], ['easy', '🟢 Легкий'], ['medium', '🟡 Середній'], ['hard', '🔴 Важкий']]
      .map(([v, l]) => h('option', { value: v, selected: v === (ec.audio?.difficulty ?? '') }, l)));
    const picked = new Set(ec.audio?.signalIds ?? []);
    const signalBoxes = h('div', { style: { maxHeight: '260px', overflowY: 'auto', border: '1px solid #ddd', borderRadius: '8px', padding: '4px 8px' } },
      withAudio.map((s) => {
        const cb = h('input', { type: 'checkbox', checked: picked.has(s.id) });
        cb.addEventListener('change', () => { if (cb.checked) picked.add(s.id); else picked.delete(s.id); updatePreview(); });
        return h('label', { class: 'dk-row', style: { gap: '8px', padding: '3px 0', fontSize: '14px', cursor: 'pointer' } }, cb,
          h('span', { class: 'grow' }, s.name), (s.tags || []).length ? h('span', { class: 's' }, s.tags.join(', ')) : null);
      }));
    const tagBox = field('Тег сигналів', tag);
    const diffBox = field('Рівень складності', difficulty);
    const manualBox = h('div', { style: { marginBottom: '12px' } }, h('div', { class: 's', style: { marginBottom: '4px' } }, 'Сигнали з аудіо'), signalBoxes);
    const audioCount = num(ec.audio?.count ?? 10, 1);
    const audioMax = num(e.audioEnabled ? e.audioMaxPoints : 6);
    const audioSource = () => ({
      signalIds: source.value === 'manual' ? [...picked] : null,
      tag: source.value === 'tag' ? tag.value.trim() || null : null,
      difficulty: source.value === 'difficulty' ? difficulty.value || null : null,
    });
    const audioPool = () => {
      const src = audioSource();
      if (source.value === 'manual' && !src.signalIds.length) return [];
      if (source.value === 'tag' && !src.tag) return [];
      return signalPool(signals, src);
    };
    const showSource = () => {
      tagBox.hidden = source.value !== 'tag';
      manualBox.hidden = source.value !== 'manual';
      diffBox.hidden = source.value !== 'difficulty';
      updatePreview();
    };
    source.addEventListener('change', showSource);
    [tag, difficulty, audioCount].forEach((el) => el.addEventListener('input', updatePreviewLater));
    difficulty.addEventListener('change', updatePreviewLater);
    function updatePreviewLater() { updatePreview(); }

    // Файл (як у додатку)
    const fileMax = num(e.fileEnabled ? e.fileMaxPoints : 30);
    const fileDesc = h('textarea', { placeholder: 'Що студент має завантажити', value: e.fileTaskDescription ?? '' });

    const toggles = {};
    const sumLabel = h('span');
    const preview = h('div', { class: 'tile', style: { display: 'block', fontSize: '14px' } });
    const component = (part, label, fields, on) => {
      const cb = h('input', { type: 'checkbox', checked: on });
      const inner = h('div', { hidden: !on, style: { padding: '12px 4px 0' } }, fields);
      const box = h('div', { class: 'tile', style: { display: 'block', border: `1px solid ${on ? `${PARTS[part].color}80` : '#ddd'}` } },
        h('label', { style: { display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' } },
          h('span', { class: 'mi', style: { color: PARTS[part].color } }, PARTS[part].icon), h('span', { class: 't grow' }, label), cb),
        inner);
      cb.addEventListener('change', () => {
        inner.hidden = !cb.checked;
        box.style.borderColor = cb.checked ? `${PARTS[part].color}80` : '#ddd';
        updatePreview();
      });
      toggles[part] = { cb, inner, box };
      return box;
    };
    const two = (a, b) => h('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' } }, a, b);

    // Попередній підрахунок і валідація пулу
    const problems = () => {
      const out = [];
      if (toggles.theory?.cb.checked) {
        const pool = theoryPool(); const n = int(theoryCount.value) ?? 0;
        if (!chosen.size) out.push('Оберіть хоча б одну тему для теоретичної частини');
        else if (n < 1) out.push('Кількість питань має бути не менше 1');
        else if (n > pool) out.push(`У вибраних темах лише ${pool} питань, а потрібно ${n}`);
      }
      if (toggles.audio?.cb.checked) {
        const pool = audioPool().length; const n = int(audioCount.value) ?? 0;
        if (n < 1) out.push('Кількість сигналів має бути не менше 1');
        else if (n > pool) out.push(`У пулі лише ${pool} сигналів з аудіо, а потрібно ${n}`);
        else if (pool < 4 && withAudio.length < 4) out.push('Для варіантів відповіді потрібно щонайменше 4 сигнали з аудіо');
      }
      return out;
    };
    function updatePreview() {
      const on = (p) => !!toggles[p]?.cb.checked;
      const sum = (on('theory') ? int(theoryMax.value) ?? 0 : 0) + (on('audio') ? int(audioMax.value) ?? 0 : 0) + (on('file') ? int(fileMax.value) ?? 0 : 0);
      sumLabel.textContent = `Частини іспиту (разом: ${sum} балів)`;
      const parts = [];
      if (on('theory')) parts.push(`${theoryPool()} питань у пулі`);
      if (on('audio')) parts.push(`${audioPool().length} сигналів з аудіо`);
      const errs = problems();
      clear(preview).append(
        h('div', {}, h('b', {}, 'Пул: '), parts.length ? parts.join(', ') : '—'),
        ...errs.map((m) => h('div', { style: { color: '#C62828', marginTop: '4px' } }, `⚠ ${m}`)));
      preview.style.borderLeft = `4px solid ${errs.length ? '#C62828' : '#2E7D32'}`;
    }
    [theoryMax, audioMax, fileMax].forEach((el) => el.addEventListener('input', updatePreview));

    const applyPreset = () => {
      const p = PRESET;
      title.value = p.title; group.value = p.group; timeLimit.value = p.timeLimitMin; review.cb.checked = p.showReview;
      const t = topics.find((x) => (x.name || '').trim() === p.theoryTopicName);
      chosen.clear();
      if (t) chosen.add(t.id);
      topicBoxes.forEach((lb, i) => { lb.querySelector('input').checked = chosen.has(topics[i].id); });
      theoryCount.value = p.theoryCount; theoryMax.value = p.theoryMax; theoryCountTouched = true;
      shuffleQ.cb.checked = true; shuffleO.cb.checked = true;
      source.value = 'tag'; tag.value = p.audioTag; audioCount.value = p.audioCount; audioMax.value = p.audioMax;
      const setOn = (part, v) => { const tg = toggles[part]; tg.cb.checked = v; tg.inner.hidden = !v; tg.box.style.borderColor = v ? `${PARTS[part].color}80` : '#ddd'; };
      setOn('theory', true); setOn('audio', true); setOn('file', false);
      showSource();
      if (!t) toast(`Тему «${p.theoryTopicName}» не знайдено — оберіть тему вручну`, 'err', 5000);
      else toast('Форму заповнено пресетом', 'ok');
    };

    const uniqueCode = async () => {
      for (let i = 0; i < 10; i++) {
        const c = generateCode(6);
        if (!(await getDocFromServer(doc(db, SESSIONS, c))).exists()) return c;
      }
      throw new Error('Не вдалося згенерувати унікальний код');
    };

    const save = async () => {
      if (!title.value.trim()) { toast('Введіть назву сесії', 'err'); return; }
      const { theory, audio, file } = toggles;
      if (!theory.cb.checked && !audio.cb.checked && !file.cb.checked) { toast('Увімкніть хоча б одну частину', 'err'); return; }
      const errs = problems();
      if (errs.length) { toast(errs[0], 'err', 4000); return; }
      if (startsAt.cb.checked && deadline.cb.checked && new Date(startsAt.input.value) >= new Date(deadline.input.value)) {
        toast('«Доступна від» має бути раніше за «Доступна до»', 'err'); return;
      }
      saveBtn.disabled = true;
      try {
        const code = existing ? existing.code : await uniqueCode();
        const ids = [...chosen].filter((id) => topics.some((t) => t.id === id));
        const names = ids.map((id) => topics.find((t) => t.id === id)?.name).filter(Boolean);
        const src = audioSource();
        const session = {
          id: existing ? existing.id : code,
          code,
          title: title.value.trim(),
          group: group.value.trim(),
          createdAt: existing ? existing.createdAt : Timestamp.now(),
          createdBy: existing ? existing.createdBy ?? null : (auth.currentUser?.email || null),
          startsAt: startsAt.cb.checked ? Timestamp.fromDate(new Date(startsAt.input.value)) : null,
          deadline: deadline.cb.checked ? Timestamp.fromDate(new Date(deadline.input.value)) : null,
          status: existing ? existing.status : 'draft',
          passingScore: int(passing.value) ?? 60,
          timeLimitMin: int(timeLimit.value) ?? 0,
          showReview: review.cb.checked,
          theoryEnabled: theory.cb.checked,
          theoryTopicIds: theory.cb.checked ? ids : [],
          // для додатку: перша тема й назви всіх
          theoryTopicId: theory.cb.checked ? ids[0] ?? null : null,
          theoryTopicName: theory.cb.checked ? names.join(', ') || null : null,
          theoryMaxPoints: int(theoryMax.value) ?? 0,
          theoryQuestionCount: int(theoryCount.value) ?? 10,
          theoryShuffleQuestions: shuffleQ.cb.checked,
          theoryShuffleOptions: shuffleO.cb.checked,
          audioEnabled: audio.cb.checked,
          audioTag: audio.cb.checked ? src.tag : null,
          audioSignalIds: audio.cb.checked ? src.signalIds : null,
          audioDifficulty: audio.cb.checked ? src.difficulty : null,
          audioMaxPoints: int(audioMax.value) ?? 0,
          audioQuestionCount: int(audioCount.value) ?? 10,
          fileEnabled: file.cb.checked,
          fileMaxPoints: int(fileMax.value) ?? 0,
          fileTaskDescription: fileDesc.value.trim(),
        };
        if (await onSave(session)) pop();
      } catch (err) { toast(errorText(err), 'err'); } finally { saveBtn.disabled = false; }
    };
    const saveBtn = h('button', { class: 'btn block', style: { padding: '14px', marginTop: '12px' }, onClick: save }, existing ? 'Зберегти зміни' : 'Створити сесію');

    const form = h('div', { class: 'body-inner' },
      existing ? null : h('button', { class: 'btn text block', style: { border: `1px solid ${GREEN}`, color: GREEN, marginBottom: '12px' }, onClick: applyPreset },
        icon('auto_fix_high'), 'Пресет «Залік практики ЛГс-32»'),
      existing && existing.status !== 'draft' ? h('div', { class: 'tile', style: { display: 'block', background: '#FFF3E0', fontSize: '13px' } },
        'Сесія вже ', existing.status === 'active' ? 'активна' : 'закрита',
        '. Зміни частин і балів не перераховують уже розпочаті й здані спроби.') : null,
      h('div', { class: 'form-section' }, 'Основне'),
      field('Назва сесії *', title),
      two(field('Група', group), field('Обмеження часу, хв (0 — без обмеження)', timeLimit)),
      field('Прохідний бал', passing),
      review.el,
      h('div', { class: 'form-section' }, 'Вікно доступності (необов’язково)'),
      startsAt.el, deadline.el,
      h('div', { class: 'form-section' }, sumLabel),
      component('theory', 'Теоретична частина', [
        topics.length ? h('div', { style: { marginBottom: '12px' } }, h('div', { class: 's', style: { marginBottom: '4px' } }, 'Теми (пул питань)'), topicBoxes)
          : h('div', { class: 's', style: { marginBottom: '12px' } }, 'Тем ще немає — додайте їх в «Управлінні навчанням».'),
        two(field('Кількість питань', theoryCount), field('Макс. балів', theoryMax)),
        shuffleQ.el, shuffleO.el], !!e.theoryEnabled),
      component('audio', 'Аудіочастина', [
        field('Джерело сигналів', source), tagBox, manualBox, diffBox,
        two(field('Кількість сигналів', audioCount), field('Макс. балів', audioMax))], !!e.audioEnabled),
      component('file', 'Файлове завдання', [field('Макс. балів', fileMax), field('Опис завдання', fileDesc)], !!e.fileEnabled),
      preview,
      saveBtn);
    showSource();

    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(existing ? 'Редагування сесії' : 'Нова сесія іспиту', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, form));
  });
}

// ── Результати сесії ─────────────────────────────────────────────────────────
const STATUS_LABEL = { in_progress: 'Триває', submitted: 'Здано', graded: 'Оцінено' };

/**
 * Рядки відомості: спроби сайту (exam_attempts) + роботи з додатку
 * (exam_submissions без спроби). Ручна оцінка адміністратора з роботи має
 * пріоритет над автоматичною.
 */
function buildRows(session, attempts, subs) {
  const subById = new Map(subs.map((s) => [s.id, s]));
  const rows = attempts.map((a) => {
    const id = `${a.sessionId}_${a.uid}`;
    const sub = subById.get(id);
    subById.delete(id);
    const started = toDate(a.startedAt);
    const submitted = toDate(a.submittedAt);
    const tp = sub?.adminTheoryPoints ?? a.theory?.points ?? null;
    const ap = sub?.adminAudioPoints ?? a.audio?.points ?? null;
    const fp = sub?.adminFilePoints ?? null;
    const done = a.status === 'submitted';
    return {
      key: id, attempt: a, sub,
      name: a.fullName || '', group: a.group || '', email: a.email || '',
      status: sub?.status === 'graded' ? 'graded' : a.status,
      tc: done ? a.theory?.correct ?? null : null, tn: a.theory?.total ?? null, tp: done ? tp : null,
      ac: done ? a.audio?.correct ?? null : null, an: a.audio?.total ?? null, ap: done ? ap : null,
      fp, file: a.file,
      total: done ? (tp ?? 0) + (ap ?? 0) + (fp ?? 0) : null,
      started, submitted,
      minutes: started && submitted ? Math.max(0, Math.round((submitted - started) / 60000)) : null,
      leaves: a.visibilityLeaves ?? 0, auto: !!a.autoSubmitted,
    };
  });
  // Роботи, здані з мобільного додатку (без спроби)
  subById.forEach((sub) => {
    const tp = sub.adminTheoryPoints ?? sub.theoryAutoPoints ?? 0;
    const ap = sub.adminAudioPoints ?? sub.audioAutoPoints ?? 0;
    const fp = sub.adminFilePoints ?? null;
    rows.push({
      key: sub.id, attempt: null, sub,
      name: sub.studentName || '', group: sub.group || '', email: sub.email || '',
      status: sub.status === 'graded' ? 'graded' : 'submitted',
      tc: sub.theoryCorrect ?? null, tn: sub.theoryTotal ?? null, tp: session.theoryEnabled ? tp : null,
      ac: sub.audioCorrect ?? null, an: sub.audioTotal ?? null, ap: session.audioEnabled ? ap : null,
      fp, file: sub.fileUrl || sub.fileName ? { fileUrl: sub.fileUrl, fileName: sub.fileName } : null,
      total: tp + ap + (fp ?? 0), started: null, submitted: toDate(sub.submittedAt), minutes: null, leaves: null, auto: false,
      fromApp: true,
    });
  });
  return rows.sort((a, b) => a.name.localeCompare(b.name, 'uk') || a.key.localeCompare(b.key));
}

const CSV_HEADER = ['№', 'ПІБ', 'Група', 'Пошта', 'Статус', 'Теорія правильних', 'Теорія з', 'Теорія бали',
  'Аудіо правильних', 'Аудіо з', 'Аудіо бали', 'Разом балів', 'Початок', 'Здано', 'Тривалість хв', 'Виходи з вкладки', 'Автоздача'];

function exportCsv(session, rows) {
  const v = (x) => x ?? '';
  const data = rows.map((r, i) => [i + 1, r.name, r.group, r.email, STATUS_LABEL[r.status] ?? r.status,
    v(r.tc), v(r.tn), v(r.tp), v(r.ac), v(r.an), v(r.ap), v(r.total),
    fmtDateTime(r.started), fmtDateTime(r.submitted), v(r.minutes), v(r.leaves), r.auto ? 'так' : r.status === 'in_progress' ? '' : 'ні']);
  const blob = new Blob([toCsv([CSV_HEADER, ...data])], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const d = new Date();
  const a = h('a', { href: url, download: `Результати_${session.code}_${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}.csv`, style: { display: 'none' } });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}

/** Друк лише відомості: копія таблиці в #print-root, решту сторінки ховає @media print. */
function printTable(session, table) {
  document.getElementById('print-root')?.remove();
  const root = h('div', { id: 'print-root' },
    h('h2', {}, session.title),
    h('div', {}, [`Код: ${session.code}`, session.group ? `Група: ${session.group}` : null, `Надруковано: ${fmtDateTime(new Date())}`].filter(Boolean).join(' · ')),
    table.cloneNode(true));
  document.body.append(root);
  document.body.classList.add('printing');
  const done = () => { document.body.classList.remove('printing'); root.remove(); window.removeEventListener('afterprint', done); };
  window.addEventListener('afterprint', done);
  window.print();
}

function openResults(session) {
  pushScreen((ctx) => {
    const body = h('div', { class: 'body-inner', style: { maxWidth: 'none' } }, spinner());
    const summary = h('div');
    let attempts = null;
    let subs = null;
    let rows = [];
    let keysPromise = null;
    const keys = () => (keysPromise ??= loadExamKeys(session));
    const fail = (e) => clear(body).append(emptyState('error_outline', 'Помилка завантаження', errorText(e)));
    const offA = onSnapshot(query(collection(db, ATTEMPTS), where('sessionId', '==', session.id)),
      (snap) => { attempts = snap.docs.map((d) => d.data()); draw(); }, fail);
    const offS = onSnapshot(query(collection(db, SUBMISSIONS), where('sessionId', '==', session.id)),
      (snap) => { subs = snap.docs.map(withId); draw(); }, fail);
    ctx.onPop = () => { offA(); offS(); };

    const max = totalMax(session);
    const cfg = examConfig(session);

    const annul = async (r) => {
      if (!await confirmDialog('Анулювати спробу?', `Спробу «${r.name || r.email}» буде видалено, і студент зможе пройти іспит знову.`,
        { okLabel: 'Анулювати', cancelLabel: 'Скасувати', danger: true })) return;
      try {
        const b = writeBatch(db);
        if (r.attempt) b.delete(doc(db, ATTEMPTS, r.key));
        if (r.sub) b.delete(doc(db, SUBMISSIONS, r.sub.id));
        await b.commit();
        toast('Спробу анульовано', 'ok');
      } catch (e) { toast(errorText(e), 'err'); }
    };
    const forceSubmit = async (r) => {
      if (!await confirmDialog('Примусово здати?', `Іспит «${r.name || r.email}» буде здано з наявними відповідями.`,
        { okLabel: 'Здати', cancelLabel: 'Скасувати' })) return;
      try {
        await submitAttempt(session, r.attempt, await keys(), { byAdmin: true });
        toast('Іспит здано', 'ok');
      } catch (e) { toast(errorText(e), 'err'); }
    };

    const td = (v, style = {}) => h('td', { style }, v ?? '—');
    const draw = () => {
      if (!attempts || !subs) return;
      rows = buildRows(session, attempts, subs);
      clear(summary); clear(body);
      const done = rows.filter((r) => r.status !== 'in_progress');
      const avg = done.length ? Math.round(done.reduce((a, r) => a + (r.total ?? 0), 0) / done.length * 10) / 10 : 0;
      const stat = (v, l) => h('div', {}, h('div', { style: { color: GOLD, fontWeight: 700, fontSize: '20px' } }, String(v)), h('div', { style: { color: 'rgba(255,255,255,.6)', fontSize: '10px' } }, l));
      summary.append(h('div', { style: { background: GREEN, padding: '10px 20px', display: 'flex', alignItems: 'center', gap: '24px', flexWrap: 'wrap' } },
        stat(rows.length, 'Розпочали'), stat(done.length, 'Здали'), stat(rows.length - done.length, 'Триває'), stat(avg, `Середній бал / ${max}`),
        h('div', { class: 'grow' }), h('span', { class: 'mono', style: { color: GOLD } }, session.code)));
      if (!rows.length) { body.append(emptyState('people_outline', 'Ще ніхто не розпочав цю сесію')); return; }

      const heads = ['№', 'ПІБ', 'Група', 'Пошта', 'Статус', 'Теорія (прав./N)', 'Теорія, бали', 'Аудіо (прав./M)', 'Аудіо, бали',
        cfg.file ? 'Файл, бали' : null, 'Разом', 'Початок', 'Здано', 'Тривалість, хв', 'Виходи з вкладки', 'Авто', 'Дії'].filter((x) => x !== null);
      const statusColor = { in_progress: '#EF6C00', submitted: '#1976D2', graded: '#2E7D32' };
      const table = h('table', { class: 'exam-table' },
        h('thead', {}, h('tr', {}, heads.map((x) => h('th', {}, x)))),
        h('tbody', {}, rows.map((r, i) => {
          const acts = h('td', { class: 'no-print', style: { whiteSpace: 'nowrap' }, onClick: (e) => e.stopPropagation() },
            r.status === 'in_progress' && r.attempt ? h('button', { class: 'iconbtn', title: 'Примусово здати', onClick: () => forceSubmit(r) }, icon('task_alt')) : null,
            r.sub ? h('button', { class: 'iconbtn', title: 'Виставити / змінити оцінку', onClick: () => gradeDialog(session, r) }, icon('rate_review')) : null,
            h('button', { class: 'iconbtn', title: 'Анулювати спробу', style: { color: '#C62828' }, onClick: () => annul(r) }, icon('delete_outline')));
          return h('tr', { style: { cursor: 'pointer' }, onClick: () => openDetail(session, r, keys) },
            td(i + 1), td(r.name || '—', { fontWeight: 600 }), td(r.group), td(r.email),
            td(h('span', { style: { color: statusColor[r.status] ?? 'inherit', fontWeight: 600 } }, STATUS_LABEL[r.status] ?? r.status)),
            td(r.tn != null ? `${r.tc ?? '–'}/${r.tn}` : '—'), td(r.tp),
            td(r.an != null ? `${r.ac ?? '–'}/${r.an}` : '—'), td(r.ap),
            cfg.file ? td(r.fp) : null,
            td(r.total != null ? h('b', {}, String(r.total)) : '—'),
            td(fmtDateTime(r.started) || '—'), td(fmtDateTime(r.submitted) || '—'), td(r.minutes), td(r.leaves),
            td(r.auto ? 'так' : r.fromApp ? 'додаток' : ''), acts);
        })));
      body.append(h('div', { class: 'exam-table-wrap' }, table),
        h('div', { class: 's', style: { marginTop: '8px' } }, 'Клік по рядку — детальний розбір відповідей. Таблиця оновлюється автоматично.'));
    };

    const needRows = () => { if (!rows.length) { toast('Ще немає жодної спроби', 'err'); return false; } return true; };
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(session.title, { back: ctx.pop, cls: 'brown', actions: [
        h('button', { class: 'iconbtn', title: 'Експорт CSV', onClick: () => { if (needRows()) exportCsv(session, rows); } }, icon('download')),
        h('button', { class: 'iconbtn', title: 'Друк', onClick: () => { if (needRows()) printTable(session, body.querySelector('table')); } }, icon('print')),
      ] }),
      summary,
      h('div', { class: 'body' }, body));
  });
}

/** Детальний розбір відповідей студента. */
function openDetail(session, r, keys) {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner', style: { maxWidth: '680px' } },
      h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { class: 't' }, r.name || '—'),
        h('div', { class: 's' }, [r.group, r.email].filter(Boolean).join(' · ')),
        h('div', { class: 's' }, `Статус: ${STATUS_LABEL[r.status] ?? r.status}${r.auto ? ' (автоздача)' : ''}`),
        r.total != null ? h('div', { style: { marginTop: '6px', fontWeight: 700 } }, `Разом: ${r.total} з ${totalMax(session)}`) : null,
        r.file?.fileName ? h('div', { style: { marginTop: '6px' } }, r.file.fileUrl
          ? h('a', { href: r.file.fileUrl, target: '_blank', rel: 'noopener' }, `📎 ${r.file.fileName}`) : `📎 ${r.file.fileName}`) : null,
        r.sub?.adminNote ? h('div', { class: 's', style: { marginTop: '6px', fontStyle: 'italic' } }, `Коментар: ${r.sub.adminNote}`) : null));
    if (!r.attempt) {
      body.append(emptyState('phone_android', 'Роботу здано з мобільного додатку', 'Детальних відповідей немає — лише підсумок.'));
    } else {
      const list = h('div', {}, spinner());
      body.append(h('div', { class: 'sec-title' }, r.status === 'in_progress' ? 'Відповіді (іспит триває)' : 'Розбір відповідей'), list);
      keys().then((k) => clear(list).append(...reviewList(r.attempt, k)))
        .catch((e) => clear(list).append(emptyState('error_outline', 'Не вдалося завантажити', errorText(e))));
    }
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Відповіді студента', { back: pop, cls: 'brown', small: true }),
      h('div', { class: 'body' }, body));
  });
}

/** Ручна оцінка (як у додатку): порожнє поле не стирає попередню ручну оцінку. */
function gradeDialog(session, r) {
  const sub = r.sub;
  const s = session;
  const numIn = (v) => h('input', { type: 'number', min: 0, value: v ?? '' });
  const theory = numIn(sub.adminTheoryPoints ?? sub.theoryAutoPoints ?? 0);
  const audioIn = numIn(sub.adminAudioPoints ?? sub.audioAutoPoints ?? 0);
  const file = numIn(sub.adminFilePoints);
  const note = h('textarea', { value: sub.adminNote ?? '', style: { minHeight: '60px' } });
  const d = openDialog([
    h('h3', {}, `Оцінка: ${r.name || r.email}`),
    s.theoryEnabled ? h('label', { class: 'field' }, h('span', {}, `Теорія (авто ${sub.theoryAutoPoints ?? 0}, макс ${s.theoryMaxPoints})`), theory) : null,
    s.audioEnabled ? h('label', { class: 'field' }, h('span', {}, `Аудіо (авто ${sub.audioAutoPoints ?? 0}, макс ${s.audioMaxPoints})`), audioIn) : null,
    s.fileEnabled ? h('label', { class: 'field' }, h('span', {}, `Файл (макс ${s.fileMaxPoints})`), file) : null,
    h('label', { class: 'field' }, h('span', {}, 'Коментар (необов’язково)'), note),
    h('div', { class: 'row' },
      h('button', { class: 'btn text', onClick: () => d.close() }, 'Скасувати'),
      h('button', { class: 'btn', onClick: async (e) => {
        const btn = e.currentTarget;
        btn.disabled = true;
        const text = note.value.trim();
        const update = {
          adminTheoryPoints: int(theory.value) ?? sub.adminTheoryPoints ?? null,
          adminAudioPoints: int(audioIn.value) ?? sub.adminAudioPoints ?? null,
          adminFilePoints: int(file.value) ?? sub.adminFilePoints ?? null,
          adminNote: text || (sub.adminNote ?? null),
          status: 'graded',
        };
        try { await updateDoc(doc(db, SUBMISSIONS, sub.id), update); d.close(); toast('Оцінку збережено', 'ok'); }
        catch (err) { btn.disabled = false; toast(errorText(err), 'err'); }
      } }, 'Зберегти')),
  ]);
}

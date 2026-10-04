// Іспит за кодом (ExamEntryScreen + ExamTakingScreen): вхід за кодом сесії й
// іменем, теоретичний тест, аудіо тест з таймером, файлове завдання, здача.
// Ті самі колекції й поля, що в ExamService — результати бачить адмін-панель.
import { h, icon, toast, pushScreen, appBar, confirmDialog, pickFiles, clear, spinner, emptyState } from '../ui.js';
import {
  db, storage, collection, doc, getDocs, setDoc, query, where, limit, Timestamp,
  storageRef, uploadBytes, getDownloadURL,
} from '../firebase.js';
import { waitForSignals } from '../data.js';
import { audio } from '../audio.js';

const SESSIONS = 'exam_sessions';
const SUBMISSIONS = 'exam_submissions';
const AUDIO_SECONDS = 30;
const FILE_EXT = ['pdf', 'doc', 'docx', 'txt', 'odt'];
const GREEN = '#1C3A1C';
const GOLD = '#D4A017';

const toDate = (v) => (v?.toDate ? v.toDate() : v ? new Date(v) : null);
const pad = (n) => String(n).padStart(2, '0');
const fmt = (d) => `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}  ${pad(d.getHours())}:${pad(d.getMinutes())}`;
const shuffle = (a) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const scale = (correct, total, max) => (total && max ? Math.round(correct / total * max) : 0);
const totalMax = (s) => (s.theoryMaxPoints || 0) + (s.audioMaxPoints || 0) + (s.fileMaxPoints || 0);

async function sessionByCode(code) {
  const snap = await getDocs(query(collection(db, SESSIONS), where('code', '==', code), limit(1)));
  if (snap.empty) return null;
  const d = snap.docs[0];
  return { ...d.data(), id: d.data().id || d.id };
}

async function hasSubmitted(sessionId, name) {
  const snap = await getDocs(query(collection(db, SUBMISSIONS), where('sessionId', '==', sessionId), where('studentName', '==', name), limit(1)));
  return !snap.empty;
}

// ── Вхід: код сесії та ім'я ─────────────────────────────────────────────────
export function openExamEntry() {
  pushScreen(({ pop }) => {
    const code = h('input', { type: 'text', class: 'code-input', maxLength: 6, placeholder: '______', autocomplete: 'off', spellcheck: false,
      style: { fontSize: '24px', fontWeight: 700, letterSpacing: '8px', textAlign: 'center', color: GREEN, textTransform: 'uppercase' } });
    const name = h('input', { type: 'text', placeholder: 'Прізвище Ім’я', autocomplete: 'name' });
    const err = h('div', { class: 'err', hidden: true });
    const fail = (m) => { err.textContent = m; err.hidden = false; };
    const start = h('button', { class: 'btn block', style: { padding: '14px', marginTop: '8px' } }, 'Почати іспит');

    const enter = async () => {
      err.hidden = true;
      const c = code.value.trim().toUpperCase();
      const n = name.value.trim();
      if (c.length !== 6) { fail('Введіть 6-значний код сесії'); return; }
      if (!n) { fail('Введіть ваше ім’я'); return; }
      start.disabled = true;
      try {
        const session = await sessionByCode(c);
        if (!session) { fail('Сесію не знайдено. Перевірте код.'); return; }
        if (session.status !== 'active') { fail('Ця сесія вже закрита або ще не активна.'); return; }
        const deadline = toDate(session.deadline);
        if (deadline && Date.now() > deadline.getTime()) { fail('Час для здачі цієї сесії вичерпано.'); return; }
        if (await hasSubmitted(session.id, n)) { fail('Ви вже здали цю сесію.'); return; }
        pop();
        openExamTaking(session, n);
      } catch (e) { fail(`Помилка: ${e.message}`); } finally { start.disabled = false; }
    };
    start.addEventListener('click', enter);
    [code, name].forEach((el) => el.addEventListener('keydown', (e) => { if (e.key === 'Enter') enter(); }));
    setTimeout(() => code.focus(), 50);

    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Вхід до іспиту', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner', style: { maxWidth: '480px' } },
        h('div', { style: { textAlign: 'center', margin: '12px 0 24px' } },
          h('span', { class: 'mi', style: { fontSize: '56px', color: GREEN, background: 'rgba(28,58,28,.08)', borderRadius: '50%', padding: '20px' } }, 'school')),
        h('label', { class: 'field' }, h('span', {}, 'Код сесії'), code),
        h('label', { class: 'field' }, h('span', {}, 'Ваше ім’я'), name),
        err, start)));
  });
}

// ── Проходження іспиту ──────────────────────────────────────────────────────
function openExamTaking(session, studentName) {
  pushScreen((ctx) => {
    const s = session;
    let finished = false;
    let timer = null;
    const theory = { questions: [], correct: 0 };
    const aud = { questions: [], correct: 0 };
    let pickedFile = null;
    const body = h('div', { class: 'body-inner', style: { maxWidth: '640px' } });

    const stopAll = () => { clearInterval(timer); timer = null; audio.stop(); };
    ctx.onPop = stopAll;

    const exit = async () => {
      if (finished) { ctx.pop(); return; }
      if (await confirmDialog('Вийти з іспиту?', 'Прогрес буде втрачено. Ви впевнені?', { okLabel: 'Вийти', cancelLabel: 'Залишитись', danger: true })) ctx.pop();
    };

    const show = (...nodes) => { clear(body).append(...nodes); body.parentElement?.scrollTo?.(0, 0); };
    const progress = (cur, total, color) => h('div', { style: { margin: '4px 0 12px' } },
      h('div', { class: 's', style: { textAlign: 'right' } }, `${cur} / ${total}`),
      h('div', { style: { height: '6px', borderRadius: '3px', background: 'rgba(0,0,0,.08)', overflow: 'hidden' } },
        h('div', { style: { width: `${cur / total * 100}%`, height: '100%', background: color } })));

    // Варіанти відповіді: після вибору підсвічується правильна і обрана
    const options = (opts, correct, onAnswer) => {
      let answered = false;
      const btns = opts.map((o, k) => h('button', { class: 'tile', style: { width: '100%', textAlign: 'left', cursor: 'pointer', borderLeft: '4px solid transparent' }, onClick: () => {
        if (answered) return;
        answered = true;
        btns.forEach((b, j) => { b.style.borderLeftColor = j === correct ? '#2E7D32' : j === k ? '#C62828' : 'transparent'; });
        onAnswer(k);
      } }, h('span', { class: 'grow' }, o)));
      return { btns, lock: () => { answered = true; } };
    };

    // Порядок складових: теорія → аудіо → файл → здача
    const next = (after) => {
      if (after === 'intro' && s.theoryEnabled) return loadTheory();
      if ((after === 'intro' || after === 'theory') && s.audioEnabled) return loadAudio();
      if (after !== 'file' && s.fileEnabled) return fileStep();
      return submit();
    };

    // ── Вступ ──────────────────────────────────────────────────────────────
    const intro = () => {
      const row = (ic, label, value) => h('div', { class: 'dk-row', style: { margin: '6px 0', gap: '8px' } },
        h('span', { class: 'mi', style: { fontSize: '18px', color: 'var(--grey-600)' } }, ic), h('span', { class: 's' }, `${label}:`), h('b', {}, value));
      const part = (ic, title, sub, color) => h('div', { class: 'dk-row', style: { margin: '6px 0', gap: '10px' } },
        h('span', { class: 'mi', style: { color } }, ic), h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, title), h('div', { class: 's' }, sub)));
      const deadline = toDate(s.deadline);
      show(
        h('div', { class: 'tile', style: { display: 'block' } },
          h('div', { class: 'dk-row', style: { gap: '10px' } }, h('span', { class: 'mi', style: { color: GREEN, fontSize: '28px' } }, 'school'),
            h('div', { style: { fontSize: '17px', fontWeight: 700, color: GREEN } }, s.title)),
          h('hr'),
          row('person', 'Студент', studentName), row('tag', 'Код сесії', s.code),
          deadline ? row('timer', 'Дедлайн', fmt(deadline)) : null,
          row('check_circle_outline', 'Прохідний бал', `${s.passingScore ?? 60} балів`),
          h('hr'),
          h('div', { class: 's', style: { fontWeight: 700, marginBottom: '4px' } }, 'Складові іспиту'),
          s.theoryEnabled ? part('menu_book', 'Теоретичний тест', `${s.theoryMaxPoints} балів · ${s.theoryQuestionCount} питань`, '#1976D2') : null,
          s.audioEnabled ? part('headphones', 'Аудіо тест', `${s.audioMaxPoints} балів · ${s.audioQuestionCount} сигналів · ${AUDIO_SECONDS} с на відповідь`, '#7B1FA2') : null,
          s.fileEnabled ? part('upload_file', 'Файлове завдання', `${s.fileMaxPoints} балів · ручна перевірка`, '#EF6C00') : null,
          h('hr'),
          h('div', { class: 'dk-row', style: { justifyContent: 'space-between' } }, h('b', {}, 'Максимум балів'),
            h('span', { style: { fontSize: '18px', fontWeight: 700, color: GREEN } }, String(totalMax(s))))),
        h('button', { class: 'btn block', style: { padding: '14px', marginTop: '16px' }, onClick: () => next('intro') }, icon('play_arrow'), 'Розпочати іспит'));
    };

    // ── Теорія ─────────────────────────────────────────────────────────────
    const loadTheory = async () => {
      show(spinner());
      try {
        const snap = await getDocs(query(collection(db, 'edu_test_questions'), where('topicId', '==', s.theoryTopicId || '')));
        theory.questions = shuffle(snap.docs.map((d) => d.data())).slice(0, s.theoryQuestionCount || 10)
          .map((q) => ({ text: q.question, options: q.options || [], correct: Number(q.correctIndex) || 0 }));
      } catch (e) { toast(`Не вдалося завантажити питання: ${e.message}`, 'err'); theory.questions = []; }
      theoryQuestion(0);
    };
    const theoryQuestion = (i) => {
      const qs = theory.questions;
      if (!qs.length) {
        show(emptyState('help_outline', 'Питання для цієї теми не знайдено'),
          h('div', { style: { textAlign: 'center' } }, h('button', { class: 'btn', onClick: () => next('theory') }, 'Пропустити')));
        return;
      }
      const q = qs[i];
      const nextBtn = h('button', { class: 'btn block', hidden: true, onClick: () => (i < qs.length - 1 ? theoryQuestion(i + 1) : next('theory')) },
        i < qs.length - 1 ? 'Наступне питання' : 'Завершити теорію');
      const { btns } = options(q.options, q.correct, (k) => { if (k === q.correct) theory.correct++; nextBtn.hidden = false; });
      show(h('div', { class: 'sec-title' }, '📖 Теоретичний тест'), progress(i + 1, qs.length, '#1976D2'),
        h('div', { style: { fontSize: '16px', fontWeight: 600, margin: '12px 0', lineHeight: 1.5 } }, q.text), ...btns, nextBtn);
    };

    // ── Аудіо ──────────────────────────────────────────────────────────────
    const loadAudio = async () => {
      show(spinner());
      const signals = await waitForSignals();
      const seen = new Set();
      const pool = signals.filter((x) => x.audioUrl && !seen.has(x.audioUrl) && seen.add(x.audioUrl)
        && (!s.audioDifficulty || x.difficulty === s.audioDifficulty));
      const names = pool.map((x) => x.name);
      aud.questions = shuffle(pool.slice()).slice(0, s.audioQuestionCount || 10).map((x) => {
        const opts = shuffle([x.name, ...shuffle(names.filter((n) => n !== x.name)).slice(0, 3)]);
        return { url: x.audioUrl, options: opts, correct: opts.indexOf(x.name) };
      });
      audioQuestion(0);
    };
    const audioQuestion = (i) => {
      const qs = aud.questions;
      if (!qs.length) {
        show(emptyState('headphones', 'Немає аудіо сигналів для тесту'),
          h('div', { style: { textAlign: 'center' } }, h('button', { class: 'btn', onClick: () => next('audio') }, 'Пропустити')));
        return;
      }
      const q = qs[i];
      const go = () => { stopAll(); if (i < qs.length - 1) audioQuestion(i + 1); else next('audio'); };
      const nextBtn = h('button', { class: 'btn block', hidden: true, onClick: go }, i < qs.length - 1 ? 'Наступний сигнал' : 'Завершити аудіо тест');
      const { btns, lock } = options(q.options, q.correct, (k) => {
        clearInterval(timer); audio.stop();
        if (k === q.correct) aud.correct++;
        nextBtn.hidden = false;
      });
      let left = AUDIO_SECONDS;
      const clock = h('div', { style: { width: '44px', height: '44px', borderRadius: '50%', display: 'grid', placeItems: 'center', fontWeight: 700, color: '#fff', background: '#7B1FA2' } }, String(left));
      const play = h('button', { class: 'play-big', style: { margin: '0 auto' }, onClick: () => audio.play(q.url).catch((e) => toast(`Помилка відтворення: ${e.message}`, 'err')) }, icon('play_arrow'));
      clearInterval(timer);
      timer = setInterval(() => {
        left--;
        clock.textContent = String(Math.max(left, 0));
        if (left <= 10) clock.style.background = '#C62828';
        if (left <= 0) { clearInterval(timer); lock(); go(); } // час вийшов — відповідь не зарахована
      }, 1000);
      show(
        h('div', { class: 'dk-row', style: { justifyContent: 'space-between' } }, h('div', { class: 'sec-title' }, '🎧 Аудіо тест'), clock),
        progress(i + 1, qs.length, '#7B1FA2'),
        h('div', { style: { textAlign: 'center', margin: '12px 0' } }, play,
          h('div', { class: 's', style: { marginTop: '8px' } }, '🎺 Прослухайте сигнал і оберіть його назву')),
        ...btns, nextBtn);
    };

    // ── Файл ───────────────────────────────────────────────────────────────
    const fileStep = () => {
      const picked = h('div');
      const drawPicked = () => {
        clear(picked).append(pickedFile
          ? h('div', { class: 'tile' }, icon('description'), h('div', { class: 'grow' }, h('div', { class: 't' }, pickedFile.name), h('div', { class: 's' }, `${(pickedFile.size / 1024).toFixed(0)} КБ`)),
            h('button', { class: 'iconbtn', title: 'Прибрати', onClick: () => { pickedFile = null; drawPicked(); } }, icon('close')))
          : null);
        choose.lastChild.textContent = pickedFile ? 'Вибрати інший файл' : 'Вибрати файл';
      };
      const choose = h('button', { class: 'btn text block', style: { border: '1px dashed #EF6C00', color: '#EF6C00', padding: '16px' }, onClick: async () => {
        const [f] = await pickFiles({ accept: FILE_EXT.map((e) => `.${e}`).join(',') });
        if (!f) return;
        const ext = f.name.split('.').pop().toLowerCase();
        if (!FILE_EXT.includes(ext)) { toast('Дозволені формати: PDF, DOC, DOCX, TXT, ODT', 'err'); return; }
        pickedFile = f; drawPicked();
      } }, icon('attach_file'), h('span', {}, 'Вибрати файл'));
      show(
        h('div', { class: 'tile', style: { display: 'block', borderLeft: '4px solid #EF6C00' } },
          h('div', { class: 't' }, 'Завдання'),
          h('div', { style: { whiteSpace: 'pre-wrap', margin: '8px 0' } }, s.fileTaskDescription || '—'),
          h('div', { class: 's' }, `Максимум: ${s.fileMaxPoints} балів`)),
        h('div', { class: 'sec-title' }, 'Прикріпити файл'),
        h('div', { class: 's', style: { marginBottom: '8px' } }, 'Дозволені формати: PDF, DOC, DOCX, TXT, ODT'),
        choose, picked,
        h('button', { class: 'btn block', style: { padding: '14px', marginTop: '16px' }, onClick: () => submit() }, icon('send'), 'Здати іспит'),
        h('div', { class: 's', style: { textAlign: 'center', marginTop: '8px' } }, 'Файл необов’язковий'));
      drawPicked();
    };

    // ── Здача ──────────────────────────────────────────────────────────────
    const submit = async () => {
      stopAll();
      show(h('div', { style: { textAlign: 'center', padding: '48px 0' } }, spinner(), h('div', { style: { marginTop: '12px' } }, 'Надсилання результатів...')));
      const id = String(Date.now());
      let fileUrl = null;
      if (pickedFile) {
        try {
          const ext = pickedFile.name.includes('.') ? pickedFile.name.split('.').pop() : 'bin';
          const r = storageRef(storage, `exam_files/${s.id}/${id}.${ext}`);
          await uploadBytes(r, pickedFile, { contentType: pickedFile.type || undefined });
          fileUrl = await getDownloadURL(r);
        } catch (e) { toast(`Файл не завантажено: ${e.message}`, 'err', 5000); }
      }
      const sub = {
        id, sessionId: s.id, sessionCode: s.code, studentName,
        submittedAt: Timestamp.fromDate(new Date()),
        theoryCorrect: theory.correct, theoryTotal: theory.questions.length,
        theoryAutoPoints: scale(theory.correct, theory.questions.length, s.theoryMaxPoints),
        adminTheoryPoints: null,
        audioCorrect: aud.correct, audioTotal: aud.questions.length,
        audioAutoPoints: scale(aud.correct, aud.questions.length, s.audioMaxPoints),
        adminAudioPoints: null,
        fileUrl, fileName: pickedFile?.name ?? null, adminFilePoints: null,
        adminNote: null, status: 'pending',
      };
      try {
        await setDoc(doc(db, SUBMISSIONS, id), sub);
      } catch (e) {
        show(emptyState('error_outline', 'Не вдалося надіслати результати', e.message),
          h('div', { style: { textAlign: 'center' } }, h('button', { class: 'btn', onClick: () => submit() }, icon('refresh'), 'Спробувати ще раз')));
        return;
      }
      finished = true;
      done(sub);
    };

    const done = (sub) => {
      const auto = sub.theoryAutoPoints + sub.audioAutoPoints;
      const autoMax = (s.theoryEnabled ? s.theoryMaxPoints : 0) + (s.audioEnabled ? s.audioMaxPoints : 0);
      const scoreRow = (title, correct, total, pts, max, color) => h('div', { class: 'tile', style: { borderLeft: `4px solid ${color}` } },
        h('div', { class: 'grow' }, h('div', { class: 't' }, title), h('div', { class: 's' }, `${correct} правильних з ${total}`)),
        h('b', { style: { color } }, `${pts} / ${max}`));
      show(
        h('div', { style: { textAlign: 'center', padding: '16px 0' } },
          h('span', { class: 'mi', style: { fontSize: '72px', color: '#2E7D32' } }, 'check_circle'),
          h('div', { style: { fontSize: '22px', fontWeight: 700, color: GREEN } }, 'Іспит здано!'),
          h('div', { class: 's' }, `Дякуємо, ${studentName}!`)),
        s.theoryEnabled ? scoreRow('Теоретичний тест', sub.theoryCorrect, sub.theoryTotal, sub.theoryAutoPoints, s.theoryMaxPoints, '#1976D2') : null,
        s.audioEnabled ? scoreRow('Аудіо тест', sub.audioCorrect, sub.audioTotal, sub.audioAutoPoints, s.audioMaxPoints, '#7B1FA2') : null,
        s.fileEnabled ? h('div', { class: 'tile', style: { borderLeft: '4px solid #EF6C00' } },
          h('div', { class: 'grow' }, h('div', { class: 't' }, 'Файлове завдання'), h('div', { class: 's' }, sub.fileName || 'Файл не додано')),
          h('span', { class: 's', style: { color: '#EF6C00' } }, 'Очікує перевірки')) : null,
        autoMax ? h('div', { class: 'tile', style: { display: 'block', background: GREEN, color: '#fff' } },
          h('div', { class: 'dk-row', style: { justifyContent: 'space-between' } }, h('span', {}, 'Автоматична оцінка'),
            h('b', { style: { color: GOLD, fontSize: '18px' } }, `${auto} / ${autoMax} балів`)),
          s.fileEnabled ? h('div', { style: { fontSize: '12px', opacity: 0.7, marginTop: '4px' } }, 'Фінальна оцінка буде виставлена після перевірки файлу') : null) : null,
        h('button', { class: 'btn block', style: { marginTop: '16px' }, onClick: ctx.pop }, icon('home'), 'На головну'));
    };

    intro();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(s.title, { back: exit, cls: 'brown' }),
      h('div', { class: 'body' }, body));
  });
}

// Управління іспитами (AdminExamScreen): сесії іспитів, їх статус,
// результати студентів і ручне оцінювання. Ті самі колекції й поля, що в
// ExamService / exam_models.dart — сесії сумісні з мобільним додатком.
import { h, icon, toast, pushScreen, appBar, confirmDialog, openDialog, clear, spinner, emptyState } from '../ui.js';
import { db, collection, doc, getDocs, setDoc, updateDoc, deleteDoc, query, where, orderBy, Timestamp } from '../firebase.js';

const SESSIONS = 'exam_sessions';
const SUBMISSIONS = 'exam_submissions';
const TOPICS = 'edu_topics';

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

const toDate = (v) => (v?.toDate ? v.toDate() : v ? new Date(v) : null);
const pad = (n) => String(n).padStart(2, '0');
const fmt = (d) => (d ? `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}  ${pad(d.getHours())}:${pad(d.getMinutes())}` : '');
const int = (v) => { const n = parseInt(String(v).trim(), 10); return Number.isNaN(n) ? null : n; };
const totalMax = (s) => (s.theoryMaxPoints || 0) + (s.audioMaxPoints || 0) + (s.fileMaxPoints || 0);

// Бали роботи: ручна оцінка адміністратора має пріоритет над автоматичною
const theoryPts = (sub) => sub.adminTheoryPoints ?? sub.theoryAutoPoints ?? 0;
const audioPts = (sub) => sub.adminAudioPoints ?? sub.audioAutoPoints ?? 0;
const filePts = (sub) => sub.adminFilePoints ?? 0;
const totalPts = (sub) => theoryPts(sub) + audioPts(sub) + filePts(sub);

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const rnd = crypto.getRandomValues(new Uint32Array(6));
  return [...rnd].map((n) => chars[n % chars.length]).join('');
}

async function loadSessions() {
  const snap = await getDocs(query(collection(db, SESSIONS), orderBy('createdAt', 'desc')));
  return snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id }));
}

async function loadSubmissions(sessionId) {
  // Сортування на клієнті: where + orderBy вимагали б складеного індексу
  const snap = await getDocs(query(collection(db, SUBMISSIONS), where('sessionId', '==', sessionId)));
  return snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id }))
    .sort((a, b) => (toDate(a.submittedAt)?.getTime() ?? 0) - (toDate(b.submittedAt)?.getTime() ?? 0));
}

const pill = (text, color) => h('span', { style: {
  padding: '3px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 600, color,
  background: `${color}1F`, border: `1px solid ${color}80`, whiteSpace: 'nowrap',
} }, text);

const partChip = (part, points) => h('span', { style: {
  display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 8px', borderRadius: '20px',
  fontSize: '11px', fontWeight: 600, color: PARTS[part].color, background: `${PARTS[part].color}1A`, border: `1px solid ${PARTS[part].color}4D`,
} }, h('span', { class: 'mi', style: { fontSize: '13px' } }, PARTS[part].icon), `${points} ${PARTS[part].label.toLowerCase()}`);

const actBtn = (ic, label, color, onClick) => h('button', { class: 'btn text', style: { color, padding: '6px 8px', fontSize: '12px', gap: '4px' }, onClick },
  h('span', { class: 'mi', style: { fontSize: '16px' } }, ic), label);

// Поле CSV: лапки, якщо містить ';', '"' чи перенос рядка (RFC 4180).
const csvField = (v) => {
  const s = String(v ?? '');
  return /[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

// Експорт результатів сесії в CSV (UTF-8 з BOM, роздільник ';' — для Excel).
function exportResultsCsv(session, subs) {
  const max = totalMax(session);
  const statusLabel = (sub) => {
    if (sub.status !== 'graded') return 'Очікує';
    return totalPts(sub) >= (session.passingScore ?? 60) ? 'Зараховано' : 'Не зараховано';
  };
  const header = ['№', 'ПІБ', 'Статус', 'Теорія правильних', 'Теорія з', 'Теорія бали',
    'Аудіо правильних', 'Аудіо з', 'Аудіо бали', 'Файл', 'Разом балів', 'з', 'Здано', 'Коментар'];
  const rows = subs.map((sub, i) => [
    i + 1, sub.studentName, statusLabel(sub),
    sub.theoryCorrect ?? 0, sub.theoryTotal ?? 0, theoryPts(sub),
    sub.audioCorrect ?? 0, sub.audioTotal ?? 0, audioPts(sub),
    sub.fileName || '', totalPts(sub), max,
    fmt(toDate(sub.submittedAt)), sub.adminNote || '',
  ]);
  const text = [header, ...rows].map((r) => r.map(csvField).join(';')).join('\r\n');
  const blob = new Blob(['﻿' + text], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const d = new Date();
  const name = `Результати_${session.code}_${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}.csv`;
  const a = h('a', { href: url, download: name, style: { display: 'none' } });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}

export function openAdminExams() {
  pushScreen(({ pop }) => {
    let current = 'sessions';
    let sessions = [];
    const body = h('div', { class: 'body-inner', style: { paddingBottom: '96px' } });
    const tabs = h('div', { class: 'subtabs' }, [
      ['sessions', 'list_alt', 'Сесії'], ['results', 'bar_chart', 'Результати'],
    ].map(([id, ic, label]) => h('button', {
      class: id === current ? 'active' : '', 'data-id': id,
      onClick: () => { current = id; [...tabs.children].forEach((b) => b.classList.toggle('active', b.dataset.id === current)); draw(); },
    }, icon(ic), label)));

    const reload = async () => {
      clear(body).append(spinner());
      try { sessions = await loadSessions(); draw(); } catch (e) { clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); }
    };

    const create = () => openCreateSession(async (s) => {
      try {
        await setDoc(doc(db, SESSIONS, s.id), s);
        toast(`Сесію «${s.title}» створено. Код: ${s.code}`, 'ok', 4000);
        reload();
        return true;
      } catch (e) { toast(`Помилка збереження: ${e.message}`, 'err'); return false; }
    });

    const setStatus = async (s, status) => {
      try { await updateDoc(doc(db, SESSIONS, s.id), { status }); reload(); } catch (e) { toast(`Помилка: ${e.message}`, 'err'); }
    };

    const remove = async (s) => {
      if (!await confirmDialog('Видалити сесію?', `Сесія «${s.title}» буде видалена.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
      try { await deleteDoc(doc(db, SESSIONS, s.id)); reload(); } catch (e) { toast(`Помилка: ${e.message}`, 'err'); }
    };

    const sessionCard = (s) => {
      const st = STATUS[s.status] ?? { label: s.status, color: '#9E9E9E' };
      const deadline = toDate(s.deadline);
      return h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { style: { display: 'flex', alignItems: 'center', gap: '8px' } },
          h('div', { class: 't grow' }, s.title), pill(st.label, st.color)),
        h('div', { style: { display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap', margin: '8px 0' } },
          h('span', { class: 'mono', style: { background: '#1C3A1C', color: '#D4A017', fontWeight: 700, fontSize: '16px', letterSpacing: '4px', padding: '4px 12px', borderRadius: '8px' } }, s.code),
          h('span', { class: 's' }, `${totalMax(s)} балів`),
          deadline ? h('span', { class: 's', style: { display: 'inline-flex', alignItems: 'center', gap: '3px' } }, h('span', { class: 'mi', style: { fontSize: '14px' } }, 'timer'), fmt(deadline)) : null),
        h('div', { style: { display: 'flex', gap: '6px', flexWrap: 'wrap' } },
          s.theoryEnabled ? partChip('theory', s.theoryMaxPoints) : null,
          s.audioEnabled ? partChip('audio', s.audioMaxPoints) : null,
          s.fileEnabled ? partChip('file', s.fileMaxPoints) : null),
        h('div', { style: { display: 'flex', alignItems: 'center', flexWrap: 'wrap', borderTop: '1px solid var(--grey-300, #ddd)', marginTop: '10px', paddingTop: '6px' } },
          s.status === 'draft' ? actBtn('play_arrow', 'Активувати', '#2E7D32', () => setStatus(s, 'active')) : null,
          s.status === 'active' ? actBtn('lock', 'Закрити', '#EF6C00', () => setStatus(s, 'closed')) : null,
          s.status === 'closed' ? actBtn('lock_open', 'Відкрити', '#2E7D32', () => setStatus(s, 'active')) : null,
          h('div', { class: 'grow' }),
          actBtn('bar_chart', 'Результати', '#1C3A1C', () => openResults(s)),
          actBtn('delete_outline', 'Видалити', '#C62828', () => remove(s))));
    };

    const draw = () => {
      clear(body);
      if (current === 'sessions') {
        if (!sessions.length) {
          body.append(emptyState('event_note', 'Сесії відсутні'),
            h('div', { style: { textAlign: 'center' } }, h('button', { class: 'btn', onClick: create }, icon('add'), 'Створити першу сесію')));
          return;
        }
        sessions.forEach((s) => body.append(sessionCard(s)));
      } else {
        if (!sessions.length) { body.append(emptyState('bar_chart', 'Ще немає сесій')); return; }
        sessions.forEach((s) => body.append(h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => openResults(s) },
          icon('event_note'), h('div', { class: 'grow' }, h('div', { class: 't' }, s.title), h('div', { class: 's' }, `Код: ${s.code}`)), icon('chevron_right', ''))));
      }
    };

    reload();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Управління іспитами', { back: pop, cls: 'brown', actions: [
        h('button', { class: 'iconbtn', title: 'Оновити', onClick: reload }, icon('refresh')),
      ] }),
      tabs,
      h('div', { class: 'body' }, body),
      h('button', { class: 'fab', title: 'Створити сесію', onClick: create }, icon('add')));
  });
}

// ── Створення сесії (_CreateSessionScreen) ──────────────────────────────────
function openCreateSession(onSave) {
  pushScreen(async ({ pop }) => {
    let topics = [];
    try {
      const snap = await getDocs(collection(db, TOPICS));
      topics = snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id })).sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
    } catch (e) { toast(`Не вдалося завантажити теми: ${e.message}`, 'err'); }

    const field = (label, el) => h('label', { class: 'field' }, h('span', {}, label), el);
    const num = (value) => h('input', { type: 'number', min: 0, value });
    const title = h('input', { type: 'text', placeholder: 'Напр. Залік з мисливських сигналів' });
    const passing = num(60);
    const hasDeadline = h('input', { type: 'checkbox' });
    const week = new Date(Date.now() + 7 * 864e5);
    const local = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    const deadline = h('input', { type: 'datetime-local', value: local(week), min: local(new Date()), disabled: true });
    hasDeadline.addEventListener('change', () => { deadline.disabled = !hasDeadline.checked; });

    const topic = h('select', {}, h('option', { value: '' }, '— оберіть тему —'), topics.map((t) => h('option', { value: t.id }, t.name)));
    const theoryMax = num(40); const theoryCount = num(10);
    const difficulty = h('select', {}, [['', 'Усі рівні'], ['easy', '🟢 Легкий'], ['medium', '🟡 Середній'], ['hard', '🔴 Важкий']].map(([v, l]) => h('option', { value: v }, l)));
    const audioMax = num(30); const audioCount = num(10);
    const fileMax = num(30);
    const fileDesc = h('textarea', { placeholder: 'Що студент має завантажити' });

    const sumLabel = h('span');
    const toggles = {};
    const component = (part, title, fields) => {
      const cb = h('input', { type: 'checkbox' });
      const inner = h('div', { hidden: true, style: { padding: '12px 4px 0' } }, fields);
      const box = h('div', { class: 'tile', style: { display: 'block', border: '1px solid #ddd' } },
        h('label', { style: { display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' } },
          h('span', { class: 'mi', style: { color: PARTS[part].color } }, PARTS[part].icon),
          h('span', { class: 't grow' }, title), cb),
        inner);
      cb.addEventListener('change', () => {
        inner.hidden = !cb.checked;
        box.style.borderColor = cb.checked ? `${PARTS[part].color}80` : '#ddd';
        updateSum();
      });
      toggles[part] = cb;
      return box;
    };
    const two = (a, b) => h('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' } }, a, b);

    const updateSum = () => {
      const sum = (toggles.theory?.checked ? int(theoryMax.value) ?? 0 : 0)
        + (toggles.audio?.checked ? int(audioMax.value) ?? 0 : 0)
        + (toggles.file?.checked ? int(fileMax.value) ?? 0 : 0);
      sumLabel.textContent = `Складові іспиту (загалом: ${sum} балів)`;
    };
    [theoryMax, audioMax, fileMax].forEach((el) => el.addEventListener('input', updateSum));

    const save = async () => {
      if (!title.value.trim()) { toast('Введіть назву сесії', 'err'); return; }
      const { theory, audio, file } = toggles;
      if (!theory.checked && !audio.checked && !file.checked) { toast('Оберіть хоча б одну складову', 'err'); return; }
      if (theory.checked && !topic.value) { toast('Оберіть тему для теоретичного тесту', 'err'); return; }
      if (hasDeadline.checked && !deadline.value) { toast('Вкажіть дату дедлайну', 'err'); return; }
      const now = new Date();
      const t = topics.find((x) => x.id === topic.value);
      const session = {
        id: String(now.getTime()),
        code: generateCode(),
        title: title.value.trim(),
        createdAt: Timestamp.fromDate(now),
        deadline: hasDeadline.checked ? Timestamp.fromDate(new Date(deadline.value)) : null,
        status: 'draft',
        passingScore: int(passing.value) ?? 60,
        theoryEnabled: theory.checked,
        theoryTopicId: theory.checked ? topic.value : null,
        theoryTopicName: theory.checked ? t?.name ?? null : null,
        theoryMaxPoints: int(theoryMax.value) ?? 0,
        theoryQuestionCount: int(theoryCount.value) ?? 10,
        audioEnabled: audio.checked,
        audioDifficulty: difficulty.value || null,
        audioMaxPoints: int(audioMax.value) ?? 0,
        audioQuestionCount: int(audioCount.value) ?? 10,
        fileEnabled: file.checked,
        fileMaxPoints: int(fileMax.value) ?? 0,
        fileTaskDescription: fileDesc.value.trim(),
      };
      saveBtn.disabled = true;
      try { if (await onSave(session)) pop(); } finally { saveBtn.disabled = false; }
    };
    const saveBtn = h('button', { class: 'btn block', style: { padding: '14px', marginTop: '12px' }, onClick: save }, 'Створити сесію');

    const form = h('div', { class: 'body-inner' },
      h('div', { class: 'form-section' }, 'Основне'),
      field('Назва сесії *', title),
      field('Прохідний бал', passing),
      h('label', { class: 'dk-row', style: { fontSize: '14px', marginBottom: '8px' } }, hasDeadline, ' Дедлайн здачі'),
      field('Здати до', deadline),
      h('div', { class: 'form-section' }, sumLabel),
      component('theory', 'Теоретичний тест', [
        topics.length ? field('Тема', topic) : h('div', { class: 's', style: { marginBottom: '12px' } }, 'Тем ще немає — додайте їх в «Управлінні навчанням».'),
        two(field('Макс балів', theoryMax), field('К-сть питань', theoryCount))]),
      component('audio', 'Аудіо тест сигналів', [
        field('Рівень складності', difficulty),
        two(field('Макс балів', audioMax), field('К-сть сигналів', audioCount))]),
      component('file', 'Файлове завдання', [field('Макс балів', fileMax), field('Опис завдання', fileDesc)]),
      saveBtn);
    updateSum();

    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Нова сесія іспиту', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, form));
  });
}

// ── Результати сесії (_SessionResultsScreen) ────────────────────────────────
function openResults(session) {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner' });
    const summary = h('div');
    const max = totalMax(session);
    let subs = [];

    const load = async () => {
      clear(summary); clear(body).append(spinner());
      try { subs = await loadSubmissions(session.id); } catch (e) { clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); return; }
      clear(body);
      if (!subs.length) { body.append(emptyState('people_outline', 'Ніхто ще не здав цю сесію')); return; }
      const graded = subs.filter((s) => s.status === 'graded').length;
      const avg = Math.round(subs.reduce((a, s) => a + totalPts(s), 0) / subs.length);
      const stat = (v, l) => h('div', {}, h('div', { style: { color: '#D4A017', fontWeight: 700, fontSize: '20px' } }, String(v)), h('div', { style: { color: 'rgba(255,255,255,.6)', fontSize: '10px' } }, l));
      summary.append(h('div', { style: { background: '#1C3A1C', padding: '10px 20px', display: 'flex', alignItems: 'center', gap: '24px' } },
        stat(subs.length, 'Здали'), stat(graded, 'Перевірено'), stat(avg, 'Середній бал'),
        h('div', { class: 'grow' }), h('span', { style: { color: 'rgba(255,255,255,.55)', fontSize: '12px' } }, `/ ${max}`)));
      subs.forEach((sub) => body.append(submissionCard(sub)));
    };

    const mini = (part, pts, partMax, manual) => h('div', { style: { marginRight: '14px' } },
      h('div', { style: { fontSize: '10px', color: 'var(--grey-500, #9e9e9e)' } }, PARTS[part].label),
      h('div', { style: { fontSize: '13px', fontWeight: 600, color: PARTS[part].color } }, `${pts}/${partMax}`, manual ? ' ✎' : ''));

    const fileLink = (sub) => (sub.fileUrl
      ? h('a', { href: sub.fileUrl, target: '_blank', rel: 'noopener', style: { display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '12px', color: 'var(--primary)' } },
        h('span', { class: 'mi', style: { fontSize: '14px' } }, 'attach_file'), sub.fileName || 'Відкрити файл')
      : h('span', { class: 's' }, sub.fileName));

    const submissionCard = (sub) => {
      const total = totalPts(sub);
      const isGraded = sub.status === 'graded';
      const passed = total >= (session.passingScore ?? 60);
      return h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { style: { display: 'flex', alignItems: 'center', gap: '8px' } },
          h('div', { class: 't grow' }, sub.studentName),
          isGraded ? pill(passed ? 'Зараховано' : 'Не зараховано', passed ? '#2E7D32' : '#C62828') : pill('Очікує', '#EF6C00')),
        h('div', { class: 's', style: { margin: '4px 0 8px' } }, fmt(toDate(sub.submittedAt))),
        h('div', { style: { display: 'flex', alignItems: 'flex-end' } },
          session.theoryEnabled ? mini('theory', theoryPts(sub), session.theoryMaxPoints, sub.adminTheoryPoints != null) : null,
          session.audioEnabled ? mini('audio', audioPts(sub), session.audioMaxPoints, sub.adminAudioPoints != null) : null,
          session.fileEnabled ? mini('file', filePts(sub), session.fileMaxPoints, sub.adminFilePoints != null) : null,
          h('div', { class: 'grow' }),
          h('div', { style: { fontSize: '16px', fontWeight: 700, color: '#1C3A1C' } }, `${total} / ${max}`)),
        sub.fileName ? h('div', { style: { marginTop: '6px' } }, fileLink(sub)) : null,
        sub.adminNote ? h('div', { class: 's', style: { marginTop: '4px', fontStyle: 'italic' } }, `Коментар: ${sub.adminNote}`) : null,
        h('button', { class: 'btn text block', style: { marginTop: '8px', border: '1px solid #1C3A1C', color: '#1C3A1C' }, onClick: () => gradeDialog(sub) },
          icon('rate_review'), isGraded ? 'Редагувати оцінку' : 'Виставити оцінку'));
    };

    const gradeDialog = (sub) => {
      const numIn = (v) => h('input', { type: 'number', min: 0, value: v ?? '' });
      const theory = numIn(sub.adminTheoryPoints ?? sub.theoryAutoPoints ?? 0);
      const audio = numIn(sub.adminAudioPoints ?? sub.audioAutoPoints ?? 0);
      const file = numIn(sub.adminFilePoints);
      const note = h('textarea', { value: sub.adminNote ?? '', style: { minHeight: '60px' } });
      const s = session;
      const d = openDialog([
        h('h3', {}, `Оцінка: ${sub.studentName}`),
        s.theoryEnabled ? [h('div', { class: 's' }, `Теорія (авто: ${sub.theoryAutoPoints ?? 0} / ${s.theoryMaxPoints})`),
          h('label', { class: 'field' }, h('span', {}, `Балів за теорію (макс ${s.theoryMaxPoints})`), theory)] : null,
        s.audioEnabled ? [h('div', { class: 's' }, `Аудіо (авто: ${sub.audioAutoPoints ?? 0} / ${s.audioMaxPoints})`),
          h('label', { class: 'field' }, h('span', {}, `Балів за аудіо (макс ${s.audioMaxPoints})`), audio)] : null,
        s.fileEnabled ? [sub.fileUrl ? h('div', { style: { marginBottom: '8px' } }, fileLink(sub)) : null,
          h('label', { class: 'field' }, h('span', {}, `Балів за файл (макс ${s.fileMaxPoints})`), file)] : null,
        h('label', { class: 'field' }, h('span', {}, 'Коментар (необов’язково)'), note),
        h('div', { class: 'row' },
          h('button', { class: 'btn text', onClick: () => d.close() }, 'Скасувати'),
          h('button', { class: 'btn', onClick: async (e) => {
            const btn = e.currentTarget;
            btn.disabled = true;
            const text = note.value.trim();
            // як copyWith у Flutter: порожнє поле не стирає попередню ручну оцінку
            const update = {
              adminTheoryPoints: int(theory.value) ?? sub.adminTheoryPoints ?? null,
              adminAudioPoints: int(audio.value) ?? sub.adminAudioPoints ?? null,
              adminFilePoints: int(file.value) ?? sub.adminFilePoints ?? null,
              adminNote: text || (sub.adminNote ?? null),
              status: 'graded',
            };
            try { await updateDoc(doc(db, SUBMISSIONS, sub.id), update); d.close(); toast('Оцінку збережено', 'ok'); load(); }
            catch (err) { btn.disabled = false; toast(`Помилка: ${err.message}`, 'err'); }
          } }, 'Зберегти')),
      ]);
    };

    load();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(session.title, { back: pop, cls: 'brown', actions: [
        h('button', { class: 'iconbtn', title: 'Експортувати CSV', onClick: () => {
          if (!subs.length) { toast('Ще немає жодної зданої роботи', 'err'); return; }
          exportResultsCsv(session, subs);
        } }, icon('download')),
        h('button', { class: 'iconbtn', title: 'Оновити', onClick: load }, icon('refresh')),
      ] }),
      summary,
      h('div', { class: 'body' }, body));
  });
}

// Розділ «Практика» (нижня навігація, #/practice): послідовність робіт
// навчальної практики за «Покроковою інструкцією студента». Кожен крок —
// відмітка, файли, щоденник, таблиці самоконтролю або автоматичний результат
// тестів/іспиту; угорі — бали, допуск до заліку й підсумкова оцінка.
import { h, icon, toast, clear, emptyState, pushScreen, appBar, spinner, pickFiles, confirmDialog, onScreenClosed } from '../ui.js';
import {
  STAGES, stepStatus, totals, nextStep, MAX_CURRENT, MAX_EXAM, ADMISSION_MIN,
  BREATH_DATES, BREATH_EXERCISES, DIARY_FIELDS, TRACKED_SIGNALS, SIGNAL_SKILLS, bestByTopic,
} from '../practice-core.js';
import { loadMyPractice, saveWork, uploadStepFile, deleteStepFile, FILE_ACCEPT } from '../practice-data.js';
import {
  eduCol, visibleTopics, openTopic, openMyResults, openPlanScreen, startTheoryQuiz, startAudioTest, openFlashcards, PRACTICE_TAG,
} from './education.js';
import { openExamEntry } from './exam.js';
import { openMetronome } from './trainer-metronome.js';
import { openAccount } from './access.js';

export const STATE_STYLE = {
  todo: { color: '#757575', bg: '#F1F1F1', ic: 'radio_button_unchecked' },
  done: { color: '#2E7D32', bg: '#E8F5E9', ic: 'check_circle' },
  review: { color: '#1565C0', bg: '#E3F2FD', ic: 'hourglass_top' },
  revise: { color: '#C62828', bg: '#FFEBEE', ic: 'replay' },
  graded: { color: '#2E7D32', bg: '#E8F5E9', ic: 'verified' },
  teacher: { color: '#8D6E63', bg: '#EFEBE9', ic: 'person' },
};

export function statusChip(st) {
  const s = STATE_STYLE[st.state] || STATE_STYLE.todo;
  return h('div', { style: { display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 8px', borderRadius: '12px', background: s.bg, color: s.color, fontSize: '12px', fontWeight: 600, marginTop: '4px', lineHeight: 1.3 } },
    h('span', { class: 'mi', style: { fontSize: '16px' } }, s.ic), st.label);
}

/** Картка підсумку: виконано, поточні бали, залік, разом, оцінка. */
export function summaryCard(t) {
  const pct = Math.round((t.done / t.count) * 100);
  const cell = (label, value, sub, color) => h('div', { style: { flex: '1 1 140px', background: '#fff', borderRadius: '10px', padding: '10px 12px' } },
    h('div', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px' } }, label),
    h('div', { style: { fontSize: '22px', fontWeight: 700, color: color || 'var(--primary-dark)' } }, value),
    sub ? h('div', { class: 's', style: { fontSize: '12px', color: 'var(--grey-600)' } }, sub) : null);
  return h('div', { class: 'tile', style: { display: 'block', background: 'rgba(47,79,47,.08)', boxShadow: 'none' } },
    h('div', { class: 'dk-row', style: { justifyContent: 'space-between', marginBottom: '6px' } },
      h('div', { class: 't' }, `Виконано ${t.done} з ${t.count} пунктів`),
      t.review ? h('div', { class: 's', style: { color: '#1565C0', fontWeight: 600 } }, `на перевірці: ${t.review}`) : null),
    h('div', { style: { height: '8px', borderRadius: '4px', background: '#fff', overflow: 'hidden', marginBottom: '10px' } },
      h('div', { style: { width: `${pct}%`, height: '100%', background: 'var(--primary-light)' } })),
    h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '8px' } },
      cell('Поточна робота', `${t.current} / ${MAX_CURRENT}`, t.admitted ? 'Допуск до заліку ✓' : `для допуску — ${ADMISSION_MIN}`, t.admitted ? '#2E7D32' : undefined),
      cell('Залік', `${t.exam} / ${MAX_EXAM}`, 'тест 20 · аудіо 6 · сигнал 8 · ритм 6'),
      cell('Загальна кількість балів', `${t.total} / 100`, t.exam > 0 ? `${t.grade.ects} · ${t.grade.nat}` : 'оцінка — після заліку', 'var(--brown-800, #4E342E)')));
}

const fmtSize = (n) => (n > 1048576 ? `${(n / 1048576).toFixed(1)} МБ` : `${Math.max(1, Math.round(n / 1024))} КБ`);

/** Список файлів кроку (посилання; кнопка видалення — якщо onDelete). */
export function fileList(files = [], onDelete) {
  if (!files.length) return null;
  return h('div', {}, files.map((f) => h('div', { class: 'dk-row', style: { padding: '6px 0', borderBottom: '1px solid #eee', gap: '8px' } },
    icon(/^image\//.test(f.type) ? 'image' : 'description'),
    h('a', { href: f.url, target: '_blank', rel: 'noopener', class: 'grow', style: { color: 'var(--primary)', wordBreak: 'break-all' } }, f.name),
    h('span', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px' } }, fmtSize(f.size || 0)),
    onDelete ? h('button', { class: 'iconbtn', title: 'Видалити файл', onClick: () => onDelete(f) }, icon('delete')) : null)));
}

/** Перегляд заповнених щоденника, таблиць — для викладача (і як підсумок). */
export function diaryView(entry = {}) {
  return h('div', {}, DIARY_FIELDS.map(([k, label]) => h('div', { style: { marginBottom: '8px' } },
    h('div', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px' } }, label),
    h('div', { style: { whiteSpace: 'pre-wrap' } }, entry[k] || '—'))));
}
export function breathView(table = {}) {
  return h('table', { style: { width: '100%', fontSize: '13px', borderCollapse: 'collapse' } },
    h('tr', {}, h('th', { style: { textAlign: 'left' } }, 'Дата'), BREATH_EXERCISES.map((e, i) => h('th', { title: e }, `${i + 1}`)), h('th', {}, 'Видих, с')),
    BREATH_DATES.map((d) => h('tr', {}, h('td', {}, d), BREATH_EXERCISES.map((_, i) => h('td', { style: { textAlign: 'center' } }, table[d]?.ex?.[i] ? '+' : '')),
      h('td', { style: { textAlign: 'center' } }, table[d]?.sec ?? ''))));
}
export function signalsView(table = {}) {
  return h('table', { style: { width: '100%', fontSize: '13px', borderCollapse: 'collapse' } },
    h('tr', {}, h('th', { style: { textAlign: 'left' } }, 'Сигнал'), SIGNAL_SKILLS.map(([, l]) => h('th', {}, l))),
    TRACKED_SIGNALS.map((s) => h('tr', {}, h('td', {}, s), SIGNAL_SKILLS.map(([k]) => h('td', { style: { textAlign: 'center' } }, table[s]?.[k] ? '✓' : '')))));
}

// ── Екран розділу ────────────────────────────────────────────────────────────

let state = null;     // { uid, profile, work, grades, ctx, days }
let rerender = null;

export function renderPractice(container) {
  const body = h('div', { class: 'list' }, spinner());
  container.append(body);
  let alive = true;
  const load = async () => {
    try {
      const [data, days] = await Promise.all([loadMyPractice(), eduCol('practical_topics').catch(() => [])]);
      if (!alive) return;
      state = { ...data, days };
      draw();
    } catch (e) { if (alive) clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); }
  };
  const draw = () => clear(body).append(buildMain());
  rerender = draw;
  // після тесту, іспиту, «Мій акаунт» тощо — оновити автоматичні статуси
  const off = onScreenClosed((depth) => { if (depth === 0 && alive) load(); });
  load();
  return () => { alive = false; off(); rerender = null; };
}

const dayTopic = (n) => (state.days || []).find((t) => new RegExp(`^\\s*День\\s*${n}\\b`).test(t.name || ''));

function buildMain() {
  const { work, grades, ctx } = state;
  const t = totals(work, grades, ctx);
  const next = nextStep(work, grades, ctx);
  const quick = (ic, label, onClick) => h('button', { class: 'chip', style: { height: 'auto', padding: '6px 12px' }, onClick }, icon(ic), label);
  const nodes = [
    summaryCard(t),
    next ? h('div', { class: 'tile', style: { cursor: 'pointer', borderLeft: '4px solid var(--gold)' }, onClick: () => openStep(next) },
      icon('arrow_forward'), h('div', { class: 'grow' }, h('div', { class: 's' }, 'Далі'), h('div', { class: 't' }, next.title)), icon('chevron_right')) : null,
    h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '8px', margin: '4px 0 8px' } },
      quick('history', 'Мої результати', openMyResults),
      quick('checklist', 'План навчання', openPlanScreen),
      quick('school', 'Іспит: ввести код', () => openExamEntry())),
  ];
  let num = 0;
  for (const stage of STAGES) {
    const sts = stage.steps.map((s) => stepStatus(s, work, grades, ctx));
    const ok = sts.filter((s) => ['done', 'graded', 'review'].includes(s.state)).length;
    const topic = stage.day ? dayTopic(stage.day) : null;
    nodes.push(h('div', { class: 'sec-title', style: { display: 'flex', alignItems: 'baseline', gap: '8px', flexWrap: 'wrap', marginTop: '18px' } },
      h('span', { class: 'grow' }, stage.title),
      h('span', { class: 's', style: { fontWeight: 400, color: 'var(--grey-600)', fontSize: '12px' } }, `${stage.date} · ${ok}/${stage.steps.length}`)));
    if (topic) {
      nodes.push(h('button', { class: 'btn text', style: { justifyContent: 'flex-start', padding: '4px 8px', marginBottom: '4px' }, onClick: () => openTopic(topic, 'practical_materials') },
        icon('folder_open'), 'Матеріали дня і «Пробний тест дня»'));
    }
    stage.steps.forEach((step, i) => {
      num++;
      const st = sts[i];
      const style = STATE_STYLE[st.state] || STATE_STYLE.todo;
      nodes.push(h('div', { class: 'tile', style: { cursor: 'pointer', alignItems: 'flex-start', borderLeft: `4px solid ${style.color}` }, onClick: () => openStep(step) },
        h('div', { style: { width: '30px', height: '30px', borderRadius: '50%', background: style.bg, color: style.color, display: 'grid', placeItems: 'center', fontWeight: 700, fontSize: '13px', flex: 'none' } }, `${num}`),
        h('div', { class: 'grow' },
          h('div', { class: 't', style: { fontSize: '14px' } }, step.title),
          statusChip(st)),
        icon('chevron_right')));
    });
  }
  return h('div', {}, nodes);
}

// ── Екран кроку ──────────────────────────────────────────────────────────────

function openStep(step) {
  pushScreen((ctx) => {
    const body = h('div', { class: 'body-inner' });
    const draw = () => clear(body).append(...stepContent(step, draw));
    draw();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(step.title, { back: ctx.pop, small: true }), h('div', { class: 'body' }, body));
  });
}

/** Зберегти й перемалювати і крок, і головний список. */
async function persist(patch, redraw, okText = 'Збережено') {
  try {
    await saveWork(patch, state.profile);
    // локально — та сама зміна (merge одного рівня глибини, як у Firestore)
    for (const [k, v] of Object.entries(patch)) state.work[k] = { ...(state.work[k] || {}), ...v };
    toast(okText, 'ok');
  } catch (e) { toast(`Не збережено: ${e.code === 'permission-denied' ? 'немає доступу (підтвердіть пошту)' : e.message}`, 'err', 5000); }
  redraw(); rerender?.();
}

function stepContent(step, redraw) {
  const { work, grades, ctx } = state;
  const st = stepStatus(step, work, grades, ctx);
  const g = grades[step.id];
  const out = [
    h('div', { class: 'tile', style: { display: 'block' } },
      step.hint ? h('div', { style: { lineHeight: 1.5 } }, step.hint) : null,
      step.due ? h('div', { class: 's', style: { marginTop: '6px', color: 'var(--grey-600)' } }, `Здати до ${step.due}`) : null,
      statusChip(st),
      g?.comment ? h('div', { style: { marginTop: '8px', padding: '8px', background: '#FFF8E1', borderRadius: '8px' } },
        h('b', {}, 'Коментар викладача: '), g.comment) : null),
  ];
  const kind = KINDS[step.kind];
  if (kind) out.push(...[].concat(kind(step, st, redraw)).filter(Boolean));
  return out;
}

const KINDS = {
  profile: () => h('button', { class: 'btn block', onClick: () => openAccount() }, icon('person'), 'Відкрити «Мій акаунт» → «Мої дані»'),

  check: (step, st, redraw) => {
    const s = state.work.steps?.[step.id] || {};
    return [
      step.action?.type === 'metronome' ? h('button', { class: 'btn text block', style: { marginBottom: '8px', border: '1px solid var(--primary)' }, onClick: () => openMetronome() }, icon('timer'), 'Відкрити метроном') : null,
      step.action?.type === 'cards' ? h('button', { class: 'btn text block', style: { marginBottom: '8px', border: '1px solid var(--primary)' }, onClick: openCards }, icon('style'), 'Флеш-картки') : null,
      s.done
        ? h('button', { class: 'btn text block', onClick: () => persist({ steps: { [step.id]: { done: false } } }, redraw, 'Відмітку знято') }, icon('undo'), 'Зняти відмітку')
        : h('button', { class: 'btn block', onClick: () => persist({ steps: { [step.id]: { done: true, doneAt: Date.now() } } }, redraw, 'Виконано') }, icon('check'), 'Позначити виконаним'),
    ];
  },

  submit: (step, st, redraw) => {
    const s = state.work.steps?.[step.id] || {};
    const files = s.files || [];
    const locked = st.state === 'graded';
    const note = h('textarea', { placeholder: 'Коментар для викладача (необов’язково)', disabled: locked }, s.note || '');
    const status = h('div', { class: 's', style: { margin: '6px 0' } });
    const add = async () => {
      const picked = await pickFiles({ accept: FILE_ACCEPT, multiple: true });
      if (!picked.length) return;
      const added = [];
      for (const [i, f] of picked.entries()) {
        status.textContent = `Завантаження ${i + 1} з ${picked.length}: ${f.name}…`;
        try { added.push(await uploadStepFile(step.id, f)); } catch (e) { toast(e.code === 'storage/unauthorized' ? 'Немає доступу до сховища (підтвердіть пошту)' : e.message, 'err', 6000); }
      }
      status.textContent = '';
      if (added.length) await persist({ steps: { [step.id]: { ...s, files: [...files, ...added] } } }, redraw, `Додано файлів: ${added.length}`);
    };
    const del = async (f) => {
      if (!(await confirmDialog('Видалити файл?', f.name, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true }))) return;
      try { await deleteStepFile(f); } catch (e) { toast(e.message, 'err'); return; }
      await persist({ steps: { [step.id]: { ...s, files: files.filter((x) => x.path !== f.path) } } }, redraw, 'Файл видалено');
    };
    const submit = () => {
      if (step.fileRequired && !files.length) { toast('Спершу додайте хоча б один файл (фото або документ)', 'err'); return; }
      persist({ steps: { [step.id]: { ...s, note: note.value.trim(), done: true, submittedAt: Date.now() } } }, redraw, 'Здано на перевірку');
    };
    return [
      h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { class: 't', style: { marginBottom: '6px' } }, `Файли${step.fileRequired ? ' (обов’язково)' : ' (за потреби)'}`),
        fileList(files, locked ? null : del) || h('div', { class: 's', style: { color: 'var(--grey-600)' } }, 'Ще немає файлів. Можна фото сторінок зошита/щоденника, PDF, DOCX, PPTX — до 20 МБ.'),
        status,
        locked ? null : h('button', { class: 'btn text block', style: { border: '1px dashed var(--primary)', marginTop: '8px' }, onClick: add }, icon('attach_file'), 'Додати файли')),
      h('label', { class: 'field' }, h('span', {}, 'Коментар'), note),
      locked ? null
        : st.state === 'review'
          ? h('div', {},
            h('button', { class: 'btn block', style: { marginBottom: '8px' }, onClick: submit }, icon('save'), 'Оновити здану роботу'),
            h('button', { class: 'btn text block', onClick: () => persist({ steps: { [step.id]: { ...s, done: false } } }, redraw, 'Здачу скасовано') }, icon('undo'), 'Скасувати здачу'))
          : h('button', { class: 'btn block', onClick: submit }, icon('task_alt'), st.state === 'revise' ? 'Здати повторно' : 'Позначити виконаним і здати на перевірку'),
    ];
  },

  quiz: (step) => quizButtons(step.topics),
  retest: (step) => quizButtons(step.topics, step.threshold),

  audio: () => [
    h('button', { class: 'btn block', style: { marginBottom: '8px' }, onClick: () => startAudioTest({ tag: PRACTICE_TAG }) }, icon('campaign'), 'Аудіотест «Сигнали практики»'),
    h('button', { class: 'btn text block', onClick: () => startAudioTest('easy') }, icon('headphones'), 'Аудіотест — легкий рівень'),
  ],

  diary: (step, st, redraw) => {
    const entry = state.work.diary?.[`d${step.day}`] || {};
    const inputs = DIARY_FIELDS.map(([k, label]) => [k, h('label', { class: 'field' }, h('span', {}, label), h('textarea', { rows: 4 }, entry[k] || ''))]);
    const topic = dayTopic(step.day);
    return [
      topic ? h('button', { class: 'btn text', style: { marginBottom: '8px' }, onClick: () => openTopic(topic, 'practical_materials') }, icon('folder_open'), 'Матеріали дня') : null,
      ...inputs.map(([, el]) => el),
      h('button', { class: 'btn block', onClick: () => {
        const val = Object.fromEntries(inputs.map(([k, el]) => [k, el.querySelector('textarea').value.trim()]));
        persist({ diary: { [`d${step.day}`]: val } }, redraw);
      } }, icon('save'), 'Зберегти запис'),
    ];
  },

  breath: (step, st, redraw) => {
    const table = state.work.breath || {};
    const rows = BREATH_DATES.map((d) => {
      const boxes = BREATH_EXERCISES.map((_, i) => h('input', { type: 'checkbox', checked: !!table[d]?.ex?.[i] }));
      const sec = h('input', { type: 'number', min: 0, max: 300, value: table[d]?.sec ?? '', style: { width: '64px' } });
      return { d, boxes, sec, el: h('tr', {}, h('td', {}, d), boxes.map((b) => h('td', { style: { textAlign: 'center' } }, b)), h('td', {}, sec)) };
    });
    return [
      h('div', { class: 'tile', style: { display: 'block', overflowX: 'auto' } },
        h('div', { class: 's', style: { marginBottom: '6px' } }, BREATH_EXERCISES.map((e, i) => `${i + 1} — ${e}`).join(' · ')),
        h('table', { style: { width: '100%', borderCollapse: 'collapse' } },
          h('tr', {}, h('th', { style: { textAlign: 'left' } }, 'Дата'), BREATH_EXERCISES.map((_, i) => h('th', {}, `${i + 1}`)), h('th', {}, 'Видих, с')),
          rows.map((r) => r.el))),
      h('button', { class: 'btn block', onClick: () => {
        const val = Object.fromEntries(rows.map((r) => [r.d, { ex: r.boxes.map((b) => b.checked), sec: r.sec.value === '' ? null : Number(r.sec.value) }]));
        persist({ breath: val }, redraw);
      } }, icon('save'), 'Зберегти таблицю'),
    ];
  },

  signals: (step, st, redraw) => {
    const table = state.work.signals || {};
    const rows = TRACKED_SIGNALS.map((s) => ({ s, boxes: SIGNAL_SKILLS.map(([k]) => [k, h('input', { type: 'checkbox', checked: !!table[s]?.[k] })]) }));
    return [
      h('div', { class: 'tile', style: { display: 'block', overflowX: 'auto' } },
        h('table', { style: { width: '100%', borderCollapse: 'collapse', fontSize: '14px' } },
          h('tr', {}, h('th', { style: { textAlign: 'left' } }, 'Сигнал'), SIGNAL_SKILLS.map(([, l]) => h('th', { style: { fontSize: '12px' } }, l))),
          rows.map((r) => h('tr', {}, h('td', { style: { padding: '4px 0' } }, r.s), r.boxes.map(([, b]) => h('td', { style: { textAlign: 'center' } }, b)))))),
      h('button', { class: 'btn block', onClick: () => {
        const val = Object.fromEntries(rows.map((r) => [r.s, Object.fromEntries(r.boxes.map(([k, b]) => [k, b.checked]))]));
        persist({ signals: val }, redraw);
      } }, icon('save'), 'Зберегти'),
    ];
  },

  exam: () => h('button', { class: 'btn block', onClick: () => openExamEntry() }, icon('school'), 'Ввести код сесії'),
  teacher: () => null,
};

function quizButtons(topics, threshold) {
  const best = bestByTopic(state.ctx.quizResults);
  const wrap = h('div', {}, spinner());
  visibleTopics().then((all) => {
    clear(wrap).append(...topics.map((n) => {
      const t = all.find((x) => new RegExp(`Тема\\s+${n}\\b`).test(x.name || ''));
      const b = best[n];
      const ok = b != null && (threshold == null || b >= threshold);
      return h('div', { class: 'tile' },
        h('span', { class: 'mi', style: { color: ok ? '#2E7D32' : 'var(--grey-500)' } }, ok ? 'check_circle' : 'radio_button_unchecked'),
        h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, t?.name || `Тема ${n}`),
          h('div', { class: 's' }, b != null ? `Найкращий результат: ${b} %` : 'Ще не пройдено')),
        t ? h('button', { class: 'btn', style: { padding: '6px 14px' }, onClick: () => startTheoryQuiz(t, false) }, 'Пройти') : h('span', { class: 's' }, 'тему не знайдено'));
    }));
  }).catch((e) => clear(wrap).append(emptyState('error_outline', 'Помилка', e.message)));
  return wrap;
}

function openCards() {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner' }, spinner());
    visibleTopics().then((topics) => clear(body).append(...(topics.length ? topics.map((t) => h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => openFlashcards(t) },
      icon('style'), h('div', { class: 'grow t' }, t.name), icon('chevron_right'))) : [emptyState('style', 'Теми ще не додані')])))
      .catch((e) => clear(body).append(emptyState('error_outline', 'Помилка', e.message)));
    return h('div', { class: 'page', style: { background: 'var(--bg)' } }, appBar('Флеш-картки', { back: pop, small: true }), h('div', { class: 'body' }, body));
  });
}


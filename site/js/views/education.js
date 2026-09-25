// Вкладка «Навчання» (EducationScreen): теоретичні та практичні матеріали,
// план навчання, флеш-картки, тестування.
import { h, icon, toast, clear, emptyState, pushScreen, appBar, spinner, promptDialog } from '../ui.js';
import { db, collection, getDocs, query, where } from '../firebase.js';
import { getSignals, isYouTube, youTubeId, mediaUrl, driveId } from '../data.js';
import { audio } from '../audio.js';
import { openVideo } from './video.js';
import { openNotation } from './notation.js';
import { openMagicHorn } from './trainer-horn.js';
import { openMetronome } from './trainer-metronome.js';

const cache = {};
/** Скидає кеш — після змін в адмін-панелі навчання розділ підтягне свіжі дані. */
export function invalidateEducationCache() { Object.keys(cache).forEach((k) => delete cache[k]); }
async function col(name, filterField, filterValue) {
  const key = filterField ? `${name}:${filterValue}` : name;
  if (cache[key]) return cache[key];
  const q = filterField ? query(collection(db, name), where(filterField, '==', filterValue)) : collection(db, name);
  const snap = await getDocs(q);
  const rows = snap.docs.map((d) => ({ _doc: d.id, ...d.data() }));
  rows.sort((a, b) => (a.sortOrder ?? a.order ?? 0) - (b.sortOrder ?? b.order ?? 0));
  cache[key] = rows;
  return rows;
}

const SUBTABS = [
  { id: 'theory', icon: 'menu_book', label: 'Теоретичні матеріали' },
  { id: 'practice', icon: 'assignment', label: 'Практичні матеріали' },
  { id: 'plan', icon: 'checklist', label: 'План навчання' },
  { id: 'cards', icon: 'style', label: 'Флеш-картки' },
  { id: 'tests', icon: 'quiz', label: 'Тестування' },
  { id: 'trainers', icon: 'fitness_center', label: 'Навчальні тренажери' },
];

export function renderEducation(container) {
  let current = 'theory';
  const body = h('div', { class: 'list' });
  const tabs = h('div', { class: 'subtabs scroll' }, SUBTABS.map((t) => h('button', { class: t.id === current ? 'active' : '', 'data-id': t.id, onClick: () => set(t.id) }, icon(t.icon), t.label)));
  const set = (id) => { current = id; [...tabs.children].forEach((b) => b.classList.toggle('active', b.dataset.id === id)); render(); };
  const render = async () => {
    clear(body).append(spinner());
    try {
      const view = { theory: theoryTab, practice: practiceTab, plan: planTab, cards: cardsTab, tests: testsTab, trainers: trainersTab }[current];
      const el = await view();
      if (current === (tabs.querySelector('.active')?.dataset.id)) clear(body).append(el);
    } catch (e) { clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); }
  };
  container.append(tabs, body);
  render();
}

// ── Список тем ───────────────────────────────────────────────────────────────
function topicList(topics, ic, emptyHint, onOpen) {
  if (!topics.length) return emptyState(ic, emptyHint);
  return h('div', {}, topics.map((t, i) => h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => onOpen(t) },
    h('div', { style: { width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(47,79,47,.1)', display: 'grid', placeItems: 'center', color: 'var(--primary)', fontWeight: 700 } }, `${i + 1}`),
    h('div', { class: 'grow' }, h('div', { class: 't' }, t.name), t.description ? h('div', { class: 's' }, t.description) : null),
    icon('chevron_right'))));
}

async function theoryTab() {
  const topics = await col('edu_topics');
  return topicList(topics, 'menu_book', 'Адмін ще не додав теми', (t) => openTopic(t, 'edu_learning_materials'));
}
async function practiceTab() {
  const topics = await col('practical_topics');
  return topicList(topics, 'assignment', 'Практичні завдання ще не додані', (t) => openTopic(t, 'practical_materials'));
}

const MATERIAL_TYPES = [
  ['text', 'article', 'Текстові матеріали', '#2F4F2F'],
  ['video', 'videocam', 'Відео', '#1565C0'],
  ['audio', 'headphones', 'Аудіо', '#C62828'],
  ['presentation', 'slideshow', 'Презентації', '#BF360C'],
  ['infographic', 'bar_chart', 'Інфографіка', '#6A1B9A'],
  ['image', 'image', 'Зображення', '#2E7D32'],
];

function openTopic(topic, materialsCol) {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner' }, spinner());
    const page = h('div', { class: 'page', style: { background: 'var(--bg)' } }, appBar(topic.name, { back: pop, small: true }), h('div', { class: 'body' }, body));
    col(materialsCol, 'topicId', topic.id).then((materials) => fillTopic(body, materials))
      .catch((e) => clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)));
    return page;
  });
}

function fillTopic(body, materials) {
    clear(body);
    if (!materials.length) { body.append(emptyState('folder_open', 'Матеріали ще не додані')); return; }
    for (const [type, ic, label, color] of MATERIAL_TYPES) {
      const items = materials.filter((m) => m.type === type);
      if (!items.length) continue;
      body.append(h('div', { class: 'sec-title', style: { color } }, icon(ic), ` ${label}`));
      for (const m of items) {
        const thumb = thumbnailUrl(m);
        body.append(h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => openMaterial(m) },
          thumb ? h('img', { src: thumb, style: { width: '72px', height: '48px', objectFit: 'cover', borderRadius: '8px' }, onError: (e) => e.target.remove() })
            : h('div', { style: { width: '44px', height: '44px', borderRadius: '10px', background: `${color}1f`, display: 'grid', placeItems: 'center', color } }, icon(ic)),
          h('div', { class: 'grow' }, h('div', { class: 't' }, m.name), h('div', { class: 's' }, 'Переглянути')),
          icon('open_in_new')));
      }
    }
}

function thumbnailUrl(m) {
  if (m.thumbnailUrl) return mediaUrl(m.thumbnailUrl);
  const yt = youTubeId(m.driveUrl || '');
  return yt ? `https://img.youtube.com/vi/${yt}/mqdefault.jpg` : null;
}

/** Google Docs/Slides/Drive → URL попереднього перегляду (DriveFileViewerScreen). */
function previewUrl(url) {
  let m;
  if ((m = url.match(/docs\.google\.com\/document\/d\/([^/]+)/))) return `https://docs.google.com/document/d/${m[1]}/preview`;
  if ((m = url.match(/docs\.google\.com\/presentation\/d\/([^/]+)/))) return `https://docs.google.com/presentation/d/${m[1]}/preview`;
  if ((m = url.match(/docs\.google\.com\/spreadsheets\/d\/([^/]+)/))) return `https://docs.google.com/spreadsheets/d/${m[1]}/preview`;
  const id = driveId(url);
  if (id && !url.includes('firebasestorage')) return `https://drive.google.com/file/d/${id}/preview`;
  return null;
}

function openMaterial(m) {
  const url = (m.driveUrl || '').trim();
  if (!url) { toast('Посилання не вказано'); return; }
  if (m.type === 'video' || isYouTube(url)) { openVideo(url, m.name); return; }
  if (m.type === 'audio' && url.includes('firebasestorage')) { audio.play(url).catch((e) => toast(`Помилка відтворення: ${e.message}`, 'err')); return; }
  const preview = previewUrl(url);
  if (!preview) { window.open(url, '_blank', 'noopener'); return; }
  pushScreen(({ pop }) => h('div', { class: 'page' },
    appBar(m.name, { back: pop, small: true, actions: [h('a', { class: 'iconbtn', href: url, target: '_blank', rel: 'noopener', title: 'Відкрити в новій вкладці' }, icon('open_in_new'))] }),
    h('iframe', { src: preview, style: { flex: 1, border: 0, width: '100%', background: '#fff' }, allow: 'autoplay; fullscreen' })));
}

// ── План навчання ────────────────────────────────────────────────────────────
const LEVELS = [
  ['basic', 'Базовий рівень', 'Основи та фундаментальні знання', '#2E7D32', 'signal_cellular_alt_1_bar'],
  ['standard', 'Стандартний рівень', 'Загальний курс підготовки', '#1565C0', 'signal_cellular_alt_2_bar'],
  ['professional', 'Професійний рівень', 'Поглиблене вивчення дисципліни', '#F57F17', 'signal_cellular_alt'],
  ['expert', 'Експертний рівень', 'Повна програма для фахівців', '#C62828', 'military_tech'],
];
const DONE_KEY = 'study_plan_done';
const doneSet = () => { try { return new Set(JSON.parse(localStorage.getItem(DONE_KEY) || '[]')); } catch { return new Set(); } };

async function planTab() {
  const [plan, theory, practical] = await Promise.all([col('study_plan'), col('edu_topics'), col('practical_topics')]);
  const topicName = (e) => (e.topicType === 'practical' ? practical : theory).find((t) => t.id === e.topicId)?.name || '(тема видалена)';
  const wrap = h('div', {});
  wrap.append(h('div', { class: 'sec-title', style: { marginTop: 0 } }, 'Тематичний план'));
  for (const [key, label, desc, color, ic] of LEVELS) {
    const entries = plan.filter((e) => e.level === key);
    const hours = entries.reduce((s, e) => s + (Number(e.hours) || 0), 0);
    wrap.append(h('div', { class: 'tile', style: { cursor: entries.length ? 'pointer' : 'default', borderLeft: `4px solid ${color}` },
      onClick: () => entries.length && openPlanLevel(label, color, entries, topicName) },
      h('div', { style: { width: '44px', height: '44px', borderRadius: '12px', background: `${color}1f`, display: 'grid', placeItems: 'center', color } }, icon(ic)),
      h('div', { class: 'grow' }, h('div', { class: 't' }, label), h('div', { class: 's' }, `${desc} · ${entries.length} тем · ${hours} год`)),
      entries.length ? icon('chevron_right') : null));
  }
  return wrap;
}

function openPlanLevel(label, color, entries, topicName) {
  pushScreen(({ pop }) => {
    const done = doneSet();
    const rows = entries.map((e, i) => {
      const cb = h('input', { type: 'checkbox', checked: done.has(e.id), onChange: () => {
        const d = doneSet(); cb.checked ? d.add(e.id) : d.delete(e.id);
        try { localStorage.setItem(DONE_KEY, JSON.stringify([...d])); } catch { /* ignore */ }
      } });
      return h('div', { class: 'tile', style: { padding: '10px 14px' } },
        h('div', { style: { width: '28px', fontWeight: 700, color } }, `${i + 1}`),
        h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, topicName(e)),
          h('div', { class: 's' }, `${e.topicType === 'practical' ? 'Практична' : 'Теоретична'} · ${e.hours || 0} год`)),
        h('label', { style: { display: 'flex', alignItems: 'center', gap: '4px', fontSize: '11px', color: 'var(--grey-600)' } }, 'Виконано', cb));
    });
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(label, { back: pop, small: true }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' }, rows)));
  });
}

// ── Флеш-картки ──────────────────────────────────────────────────────────────
async function cardsTab() {
  const topics = await col('edu_topics');
  return topicList(topics, 'style', 'Адмін ще не додав теми', openFlashcards);
}

async function openFlashcards(topic) {
  const cards = (await col('edu_flashcards', 'topicId', topic.id)).slice();
  if (!cards.length) { toast('До цієї теми ще не додані картки'); return; }
  pushScreen(({ pop }) => {
    let i = 0, shown = false;
    const counter = h('div', { style: { textAlign: 'center', color: 'var(--grey-600)', margin: '8px 0' } });
    const q = h('div', { style: { fontSize: '18px', fontWeight: 600, textAlign: 'center', lineHeight: 1.5 } });
    const a = h('div', { class: 'sec-text', style: { textAlign: 'center', marginTop: '16px', color: 'var(--primary-dark)', fontSize: '16px' }, hidden: true });
    const showBtn = h('button', { class: 'btn', onClick: () => { shown = true; a.hidden = false; showBtn.hidden = true; nav.hidden = false; } }, icon('visibility'), 'Показати відповідь');
    const nav = h('div', { class: 'dk-row', style: { justifyContent: 'center', marginTop: '16px' }, hidden: true },
      h('button', { class: 'btn text', onClick: () => go(-1) }, icon('arrow_back'), 'Назад'),
      h('button', { class: 'btn', onClick: () => go(1) }, 'Далі', icon('arrow_forward')));
    const go = (d) => { i = (i + d + cards.length) % cards.length; render(); };
    const render = () => {
      shown = false; a.hidden = true; showBtn.hidden = false; nav.hidden = true;
      counter.textContent = `Картка ${i + 1} з ${cards.length}`;
      q.textContent = cards[i].question; a.textContent = cards[i].answer;
    };
    render();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(`Флеш-картки: ${topic.name}`, { back: pop, small: true }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' },
        counter,
        h('div', { style: { background: 'linear-gradient(135deg,#FFF8E7,#E8C87A)', border: '1.5px solid var(--gold)', borderRadius: '16px', padding: '28px 20px', minHeight: '220px', display: 'flex', flexDirection: 'column', justifyContent: 'center' } }, q, a),
        h('div', { style: { textAlign: 'center', marginTop: '16px' } }, showBtn),
        nav,
        h('div', { style: { textAlign: 'center', marginTop: '12px' } }, h('button', { class: 'btn text', onClick: () => { i = 0; cards.sort(() => Math.random() - .5); render(); } }, icon('replay'), 'Повторити')))));
  });
}

// ── Тестування ───────────────────────────────────────────────────────────────
async function testsTab() {
  const card = (ic, title, subtitle, color, content) => h('div', { class: 'tile', style: { flexDirection: 'column', alignItems: 'stretch', gap: '8px' } },
    h('div', { class: 'dk-row' }, h('div', { style: { width: '40px', height: '40px', borderRadius: '10px', background: `${color}1f`, display: 'grid', placeItems: 'center', color } }, icon(ic)),
      h('div', { class: 'grow' }, h('div', { class: 't' }, title), h('div', { class: 's' }, subtitle))),
    content);
  const levelBtn = (d, label, emoji, color) => h('button', { class: 'btn text', style: { justifyContent: 'flex-start', color }, onClick: () => startAudioTest(d) }, `${emoji} ${label}`);
  return h('div', {},
    card('quiz', 'Пробне тестування', 'Перевір знання без збереження результатів', '#2F4F2F',
      h('div', {},
        h('div', { style: { fontWeight: 600, margin: '6px 0' } }, '🎧 Аудіо тест — рівень складності'),
        h('div', { style: { display: 'flex', flexDirection: 'column' } },
          levelBtn('easy', 'Легкий', '🟢', '#2E7D32'), levelBtn('medium', 'Середній', '🟡', '#F57F17'), levelBtn('hard', 'Важкий', '🔴', '#C62828'),
          h('button', { class: 'btn text', style: { justifyContent: 'flex-start' }, onClick: () => startAudioTest(null) }, '🎯 Усі сигнали')),
        h('div', { style: { fontWeight: 600, margin: '10px 0 6px' } }, '📖 Теоретичний тест'),
        h('button', { class: 'btn text', style: { justifyContent: 'flex-start' }, onClick: openTheoryTopics }, icon('menu_book'), 'Обрати тему'))),
    card('school', 'Іспит', 'Введіть код сесії, наданий адміністратором', '#1565C0',
      h('button', { class: 'btn', onClick: async () => {
        const code = await promptDialog('Іспит', { label: 'Код сесії', placeholder: 'XXXXXX', okLabel: 'Почати' });
        if (code) toast('Іспити за кодом будуть доступні у наступній фазі сайту');
      } }, 'Ввести код сесії')));
}

function startAudioTest(difficulty) {
  const withAudio = getSignals().filter((s) => s.audioUrl);
  const pool = difficulty ? withAudio.filter((s) => s.difficulty === difficulty) : withAudio;
  if (!pool.length) { toast('Немає сигналів з аудіо для цього рівня'); return; }
  const shuffle = (a) => a.sort(() => Math.random() - .5);
  const picked = shuffle(pool.slice()).slice(0, 10);
  const names = withAudio.map((s) => s.name);
  const questions = picked.map((s) => {
    const wrongs = shuffle(names.filter((n) => n !== s.name)).slice(0, 3);
    const options = shuffle([s.name, ...wrongs]);
    return { audioUrl: s.audioUrl, options, correct: options.indexOf(s.name), answer: null };
  });
  runQuiz('Аудіо тест', questions, (q) => h('div', { style: { textAlign: 'center', margin: '12px 0' } },
    h('button', { class: 'play-big', style: { margin: '0 auto' }, onClick: () => audio.play(q.audioUrl).catch((e) => toast(`Помилка відтворення: ${e.message}`, 'err')) }, icon('play_arrow')),
    h('div', { class: 's', style: { color: 'var(--grey-600)', marginTop: '8px' } }, 'Прослухайте сигнал і оберіть його назву')));
}

async function openTheoryTopics() {
  const topics = await col('edu_topics');
  pushScreen(({ pop }) => h('div', { class: 'page', style: { background: 'var(--bg)' } },
    appBar('Пробний теоретичний тест', { back: pop, small: true }),
    h('div', { class: 'body' }, h('div', { class: 'body-inner' }, topicList(topics, 'menu_book', 'Теми ще не додані', async (t) => {
      const qs = await col('edu_test_questions', 'topicId', t.id);
      if (!qs.length) { toast('До цієї теми ще не додані питання'); return; }
      runQuiz(t.name, qs.map((q) => ({ text: q.question, options: q.options || [], correct: Number(q.correctIndex) || 0, explanation: q.explanation, answer: null })),
        (q) => h('div', { style: { fontSize: '16px', fontWeight: 600, margin: '12px 0', lineHeight: 1.5 } }, q.text));
    })))));
}

/** Спільний екран тесту: питання → варіанти → результат. */
function runQuiz(title, questions, renderPrompt) {
  pushScreen((ctx) => {
    let i = 0;
    ctx.onPop = () => audio.pause();
    const body = h('div', { class: 'body-inner' });
    const render = () => {
      clear(body);
      if (i >= questions.length) { result(); return; }
      const q = questions[i];
      const opts = q.options.map((o, k) => h('button', { class: 'tile', style: { width: '100%', textAlign: 'left', cursor: 'pointer' }, onClick: () => {
        if (q.answer != null) return;
        q.answer = k;
        opts.forEach((b, j) => { b.style.borderLeft = `4px solid ${j === q.correct ? '#2E7D32' : j === k ? '#C62828' : 'transparent'}`; });
        next.hidden = false;
      } }, h('span', { class: 'grow' }, o)));
      const next = h('button', { class: 'btn block', hidden: true, onClick: () => { audio.pause(); i++; render(); } }, i < questions.length - 1 ? 'Наступне питання' : 'Завершити');
      body.append(
        h('div', { style: { color: 'var(--grey-600)', fontSize: '13px' } }, `Питання ${i + 1} з ${questions.length}`),
        renderPrompt(q), ...opts, q.explanation ? h('div', { class: 's', style: { margin: '8px 0', color: 'var(--grey-600)' }, hidden: true }) : null, next);
    };
    const result = () => {
      const correct = questions.filter((q) => q.answer === q.correct).length;
      const pct = Math.round(correct / questions.length * 100);
      body.append(
        h('div', { style: { textAlign: 'center', padding: '24px 0' } },
          h('div', { style: { fontSize: '56px', fontWeight: 700, color: 'var(--primary)' } }, `${pct}`),
          h('div', { style: { color: 'var(--grey-600)' } }, 'балів зі 100'),
          h('div', { style: { marginTop: '8px', fontWeight: 600 } }, `${correct} правильних з ${questions.length} питань`)),
        h('div', { class: 'sec-title' }, 'Детальні результати'),
        ...questions.map((q, k) => h('div', { class: 'tile', style: { borderLeft: `4px solid ${q.answer === q.correct ? '#2E7D32' : '#C62828'}` } },
          h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, `${k + 1}. ${q.text || 'Сигнал'}`),
            h('div', { class: 's' }, `Ваша відповідь: ${q.answer != null ? q.options[q.answer] : 'Не відповіли'}`),
            h('div', { class: 's', style: { color: '#2E7D32' } }, `Правильно: ${q.options[q.correct]}`)))),
        h('div', { class: 'dk-row', style: { justifyContent: 'center', marginTop: '12px' } },
          h('button', { class: 'btn text', onClick: ctx.pop }, 'Назад'),
          h('button', { class: 'btn', onClick: () => { questions.forEach((q) => { q.answer = null; }); i = 0; render(); } }, icon('replay'), 'Пройти знову')));
    };
    render();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(title, { back: ctx.pop, small: true }),
      h('div', { class: 'body' }, body));
  });
}

// ── Навчальні тренажери ──────────────────────────────────────────────────────
// Внутрішні вкладки; поки одна — «Примітивні ноти»: обираєш сигнал і
// відкривається його екран «Ноти» (той самий, що з деталей сигналу).
const TRAINERS = [
  { id: 'notes', icon: 'music_note', label: 'Примітивні ноти', render: primitiveNotesTrainer },
  { id: 'horn', icon: 'sports_esports', label: 'Чарівна сурма', render: magicHornTrainer },
  { id: 'metronome', icon: 'timer', label: 'Метроном', render: metronomeTrainer },
];

async function trainersTab() {
  let current = TRAINERS[0].id;
  const body = h('div');
  const chips = h('div', { class: 'chips', style: { padding: '0 0 8px', height: 'auto' } },
    TRAINERS.map((t) => h('button', { class: `chip ${t.id === current ? 'selected' : ''}`, 'data-id': t.id, onClick: () => set(t.id) }, icon(t.icon), t.label)));
  const set = (id) => {
    current = id;
    [...chips.children].forEach((b) => b.classList.toggle('selected', b.dataset.id === id));
    clear(body).append(TRAINERS.find((t) => t.id === id).render());
  };
  set(current);
  return h('div', {}, chips, body);
}

const hasNotes = (s) => !!(s.notationUrl || s.notationData.length || s.signalText || s.partitureUrl);

function primitiveNotesTrainer() {
  const signals = getSignals();
  if (!signals.length) return emptyState('music_note', 'Сигнали ще не додані');
  const withNotes = signals.filter(hasNotes), without = signals.filter((s) => !hasNotes(s));
  const row = (s, enabled) => h('div', { class: 'tile', style: { cursor: enabled ? 'pointer' : 'default', opacity: enabled ? 1 : .55 },
    onClick: () => (enabled ? openNotation(s) : toast('Ноти не додані для цього сигналу')) },
    h('img', { src: 'assets/icon.png', style: { width: '40px', height: '40px', borderRadius: '10px' }, alt: '' }),
    h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, s.name), h('div', { class: 's' }, s.category)),
    enabled ? icon('music_note', '') : h('span', { class: 's' }, 'Ноти не додані'));
  return h('div', {},
    h('div', { class: 's', style: { color: 'var(--grey-600)', margin: '4px 0 10px' } }, 'Оберіть сигнал — відкриються його ноти, аудіо до нот і графічне відображення для тренування.'),
    withNotes.map((s) => row(s, true)),
    without.length ? [h('div', { class: 'sec-title', style: { fontSize: '13px', color: 'var(--grey-600)' } }, 'Без нот'), without.map((s) => row(s, false))] : null);
}

/** «Чарівна сурма»: гра доступна для сигналів із графічною нотацією. */
function magicHornTrainer() {
  const signals = getSignals();
  const playable = signals.filter((s) => s.notationData.length), rest = signals.filter((s) => !s.notationData.length);
  if (!signals.length) return emptyState('sports_esports', 'Сигнали ще не додані');
  const row = (s, enabled) => h('div', { class: 'tile', style: { cursor: enabled ? 'pointer' : 'default', opacity: enabled ? 1 : .55 },
    onClick: () => (enabled ? openMagicHorn(s) : toast('Для гри потрібне графічне відображення нот — додайте його в адмін-панелі')) },
    h('div', { style: { width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(212,160,23,.18)', display: 'grid', placeItems: 'center', fontSize: '22px' } }, '📯'),
    h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, s.name),
      h('div', { class: 's' }, enabled ? `${s.notationData.filter((n) => (n.t || 'n') === 'n').length} нот · ${s.notationTempo || 90} BPM` : 'Немає графічних нот')),
    enabled ? icon('play_arrow', '') : null);
  return h('div', {},
    h('div', { class: 's', style: { color: 'var(--grey-600)', margin: '4px 0 10px' } }, 'Гра на кшталт «Piano Tiles»: ноти сигналу падають на доріжки — влучайте в них у ритмі, і сурма заграє мелодію.'),
    playable.length ? playable.map((s) => row(s, true)) : h('div', { class: 's', style: { color: 'var(--grey-600)' } }, 'Поки жоден сигнал не має графічних нот.'),
    rest.length ? [h('div', { class: 'sec-title', style: { fontSize: '13px', color: 'var(--grey-600)' } }, 'Без графічних нот'), rest.map((s) => row(s, false))] : null);
}

/** «Метроном»: картка-запуск; сам метроном — окремий екран. */
function metronomeTrainer() {
  return h('div', {},
    h('div', { class: 's', style: { color: 'var(--grey-600)', margin: '4px 0 10px' } }, 'Метроном зі звуком мисливського рога: темп 30–250 BPM, розміри від 1/4 до 12/8, підрозділи долі, акценти, відстукування темпу.'),
    h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: openMetronome },
      h('div', { style: { width: '44px', height: '44px', borderRadius: '12px', background: 'rgba(212,160,23,.18)', display: 'grid', placeItems: 'center', color: 'var(--gold)' } }, icon('timer')),
      h('div', { class: 'grow' }, h('div', { class: 't' }, 'Відкрити метроном'), h('div', { class: 's' }, 'Сильна доля — СОЛЬ2, слабкі — ДО2, підрозділи — ДО')),
      icon('play_arrow', '')));
}

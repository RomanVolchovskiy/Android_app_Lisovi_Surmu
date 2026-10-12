// Управління навчанням (AdminEducationScreen): теми, навчальні матеріали,
// флеш-картки, питання тестів, план навчання. Той самий екран керує й
// практичними темами (practical_topics / practical_materials, як
// PracticalService у додатку) — див. KINDS. Ті самі колекції й поля, що в
// EducationService / StudyPlanService.
import { h, icon, toast, pushScreen, appBar, confirmDialog, pickFiles, clear, spinner, emptyState, openDialog } from '../ui.js';
import { db, collection, doc, getDocs, setDoc, deleteDoc, query, where, writeBatch } from '../firebase.js';
import { uploadMedia, youTubeId, AUDIO_EXT, IMAGE_EXT, VIDEO_EXT } from '../data.js';
import { invalidateEducationCache } from './education.js';
import { parseCsvLine, parseCsvFile, parseQuestionRow, parseCardRow, importId, bySortOrder } from '../csv-import.js';

const TOPICS = 'edu_topics';
const PLAN = 'study_plan';
const FLASHCARDS = 'edu_flashcards';
const QUESTIONS = 'edu_test_questions';

const MATERIAL_TYPES = [
  ['text', 'Текстовий матеріал'],
  ['video', 'Відео матеріал'],
  ['presentation', 'Презентаційний матеріал'],
  ['infographic', 'Інфографіка'],
  ['image', 'Зображення'],
  ['audio', 'Аудіо'],
];
const UPLOAD_EXT = { video: VIDEO_EXT, audio: AUDIO_EXT, image: IMAGE_EXT, infographic: IMAGE_EXT };

const TAB = {
  topics: { icon: 'topic', label: 'Теми' },
  materials: { icon: 'menu_book', label: 'Матеріали' },
  cards: { icon: 'style', label: 'Флеш-картки' },
  tests: { icon: 'quiz', label: 'Тести' },
  plan: { icon: 'checklist', label: 'План навчання' },
};

// Теоретичний і практичний розділи відрізняються лише колекціями й вкладками
const KINDS = {
  theory: {
    title: 'Управління навчанням', topics: TOPICS, materials: 'edu_learning_materials',
    topicPrefix: 'topic', materialPrefix: 'lm', tabs: ['topics', 'materials', 'cards', 'tests', 'plan'], hiddenFlag: true,
  },
  practical: {
    title: 'Практичні матеріали', topics: 'practical_topics', materials: 'practical_materials',
    topicPrefix: 'pt', materialPrefix: 'pm', tabs: ['topics', 'materials', 'plan'], testLinks: true,
  },
};

// Рівні й типи плану — як StudyPlanEntry у додатку
const LEVELS = [['basic', 'Базовий рівень'], ['standard', 'Стандартний рівень'], ['professional', 'Професійний рівень'], ['expert', 'Експертний рівень']];
const TOPIC_TYPES = { theoretical: 'Теоретична', practical: 'Практична' };

async function load(name, topicId) {
  const q = topicId ? query(collection(db, name), where('topicId', '==', topicId)) : collection(db, name);
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id })).sort(bySortOrder);
}

/** Запис у Firestore з повідомленням про результат; true — успіх. */
async function write(action, okText) {
  try {
    await action();
    invalidateEducationCache();
    if (okText) toast(okText, 'ok');
    return true;
  } catch (e) {
    toast(`Помилка збереження: ${e.message}`, 'err');
    return false;
  }
}

// Розбір рядка CSV (лапки, коми в полях) — csv-import.js; ця назва лишається
// для перевірки якості даних нижче.
const splitCsvLine = parseCsvLine;

const field = (label, input) => h('label', { class: 'field' }, h('span', {}, label), input);
const input = (value = '', placeholder = '', type = 'text') => h('input', { type, placeholder, value });
const textarea = (value = '', placeholder = '') => h('textarea', { placeholder, value });

function formBox(title, fields, onSave, onCancel) {
  const save = h('button', { class: 'btn brown' }, icon('save'), 'Зберегти');
  save.addEventListener('click', async () => {
    save.disabled = true;
    try { await onSave(); } finally { save.disabled = false; }
  });
  return h('div', { class: 'tile', style: { display: 'block', border: '1px solid var(--gold)' } },
    h('div', { class: 't', style: { marginBottom: '12px' } }, title),
    fields,
    h('div', { class: 'row', style: { display: 'flex', gap: '8px', justifyContent: 'flex-end' } },
      h('button', { class: 'btn text', onClick: onCancel }, 'Скасувати'), save));
}

const rowActions = (onEdit, onDelete) => [
  onEdit ? h('button', { class: 'iconbtn dim', title: 'Редагувати', onClick: onEdit }, icon('edit')) : null,
  h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: onDelete }, icon('delete')),
];

/** kind: 'theory' — теми, матеріали, картки, тести; 'practical' — практичні теми й матеріали. */
export function openAdminEducation(kind = 'theory') {
  const cfg = KINDS[kind];
  pushScreen(({ pop }) => {
    let current = 'topics';
    let topics = [];
    let selectedTopicId = null;
    const body = h('div', { class: 'body-inner' });
    const tabs = h('div', { class: 'subtabs scroll' }, cfg.tabs.map((id) => h('button', {
      class: id === current ? 'active' : '', 'data-id': id,
      onClick: () => { current = id; [...tabs.children].forEach((b) => b.classList.toggle('active', b.dataset.id === current)); render(); },
    }, icon(TAB[id].icon), TAB[id].label)));

    const reloadTopics = async () => {
      topics = await load(cfg.topics);
      if (!topics.some((t) => t.id === selectedTopicId)) selectedTopicId = topics[0]?.id ?? null;
    };

    const render = async () => {
      clear(body).append(spinner());
      try {
        if (!topics.length) await reloadTopics();
        const view = { topics: topicsTab, materials: materialsTab, cards: cardsTab, tests: testsTab, plan: planTab }[current];
        clear(body).append(await view());
      } catch (e) { clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); }
    };

    // Вибір теми для матеріалів, карток і тестів
    const topicSelect = (onChange) => {
      const sel = h('select', {}, topics.map((t) => h('option', { value: t.id, selected: t.id === selectedTopicId }, t.name)));
      sel.addEventListener('change', () => { selectedTopicId = sel.value; onChange(); });
      return field('Тема', sel);
    };

    // ── Теми ────────────────────────────────────────────────────────────────
    async function topicsTab() {
      const wrap = h('div');
      const draw = (formFor) => {
        clear(wrap);
        if (formFor === null) wrap.append(topicForm(null));
        else wrap.append(h('button', { class: 'btn brown block', style: { marginBottom: '12px' }, onClick: () => draw(null) }, icon('add'), 'Додати тему'));
        if (!topics.length) wrap.append(emptyState('topic', 'Тем ще немає'));
        topics.forEach((t, i) => {
          if (formFor === t.id) { wrap.append(topicForm(t)); return; }
          wrap.append(h('div', { class: 'tile' },
            h('div', { style: { display: 'flex', flexDirection: 'column' } },
              h('button', { class: 'iconbtn dim', title: 'Вище', disabled: i === 0, onClick: () => move(i, -1) }, icon('arrow_upward')),
              h('button', { class: 'iconbtn dim', title: 'Нижче', disabled: i === topics.length - 1, onClick: () => move(i, 1) }, icon('arrow_downward'))),
            h('div', { class: 'grow' }, h('div', { class: 't' }, t.name,
              t.hidden ? h('span', { class: 's', style: { marginLeft: '8px', color: '#EF6C00', fontWeight: 600 } }, '🔒 прихована') : null),
            t.description ? h('div', { class: 's' }, t.description) : null),
            rowActions(() => draw(t.id), async () => {
              if (!await confirmDialog('Видалити тему?', `Видалити «${t.name}»? Матеріали теми залишаться в базі без теми.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
              if (await write(() => deleteDoc(doc(db, cfg.topics, t.id)), 'Тему видалено')) { await reloadTopics(); draw(); }
            })));
        });
      };
      const move = async (i, dir) => {
        const list = [...topics];
        [list[i], list[i + dir]] = [list[i + dir], list[i]];
        const ok = await write(() => {
          const batch = writeBatch(db);
          list.forEach((t, idx) => batch.update(doc(db, cfg.topics, t.id), { sortOrder: idx }));
          return batch.commit();
        });
        if (ok) { await reloadTopics(); draw(); }
      };
      const topicForm = (t) => {
        const name = input(t?.name, 'Назва теми');
        const desc = textarea(t?.description, 'Короткий опис');
        const image = input(t?.imageUrl ?? '', 'https://…');
        const hidden = h('input', { type: 'checkbox', checked: t?.hidden === true });
        // Практична тема: теоретичні теми, пробні тести яких — «тест дня»
        const tests = new Set(Array.isArray(t?.testTopicIds) ? t.testTopicIds : []);
        const testBoxes = h('div', { class: 's' }, 'Завантаження тем…');
        if (cfg.testLinks) {
          load(TOPICS).then((all) => {
            const visible = all.filter((x) => x.hidden !== true);
            clear(testBoxes).append(...(visible.length ? visible.map((x) => {
              const cb = h('input', { type: 'checkbox', checked: tests.has(x.id) });
              cb.addEventListener('change', () => { if (cb.checked) tests.add(x.id); else tests.delete(x.id); });
              return h('label', { class: 'dk-row', style: { gap: '8px', padding: '3px 0', cursor: 'pointer', fontSize: '14px', color: 'var(--text, inherit)' } }, cb, x.name);
            }) : ['Теоретичних тем ще немає']));
          }).catch((e) => { testBoxes.textContent = `Не вдалося завантажити теми: ${e.message}`; });
        }
        return formBox(t ? 'Редагувати тему' : 'Нова тема', [
          field('Назва *', name), field('Опис', desc), field('Зображення (посилання)', image),
          cfg.hiddenFlag ? [
            h('label', { class: 'dk-row', style: { gap: '8px', fontSize: '14px', marginBottom: '6px', cursor: 'pointer' } }, hidden, 'Прихована (лише для іспитів)'),
            h('div', { class: 's', style: { marginBottom: '12px' } }, 'Прихованої теми не видно в теорії, флеш-картках і пробних тестах сайту; її питання можна брати в іспит.'),
          ] : null,
          cfg.testLinks ? h('div', { style: { marginBottom: '12px' } },
            h('div', { class: 's', style: { marginBottom: '4px' } }, 'Пробний тест дня (кнопка «Пройти тест» у темі)'), testBoxes) : null,
        ], async () => {
          if (!name.value.trim()) { toast('Введіть назву теми', 'err'); return; }
          const data = {
            id: t?.id || `${cfg.topicPrefix}_${Date.now()}`,
            name: name.value.trim(),
            description: desc.value.trim(),
            imageUrl: image.value.trim() || null,
            sortOrder: t?.sortOrder ?? topics.length,
            ...(cfg.hiddenFlag ? { hidden: hidden.checked } : {}),
            ...(cfg.testLinks ? { testTopicIds: [...tests] } : {}),
          };
          // merge: поля, яких форма не знає (зокрема з додатку), не стираються
          if (await write(() => setDoc(doc(db, cfg.topics, data.id), data, { merge: true }), t ? 'Тему оновлено' : 'Тему додано')) { await reloadTopics(); draw(); }
        }, () => draw());
      };
      draw();
      return wrap;
    }

    // ── Матеріали ───────────────────────────────────────────────────────────
    async function materialsTab() {
      if (!topics.length) return emptyState('topic', 'Спершу додайте тему', 'Вкладка «Теми»');
      const wrap = h('div');
      const list = h('div');
      let items = [];
      const refresh = async () => {
        clear(list).append(spinner());
        items = await load(cfg.materials, selectedTopicId);
        draw();
      };
      const draw = (formFor) => {
        clear(list);
        if (formFor === null) list.append(materialForm(null));
        else list.append(h('button', { class: 'btn brown block', style: { marginBottom: '12px' }, onClick: () => draw(null) }, icon('add'), 'Додати матеріал'));
        if (!items.length) list.append(emptyState('folder_open', 'У цій темі ще немає матеріалів'));
        for (const [type, label] of MATERIAL_TYPES) {
          items.filter((m) => m.type === type).forEach((m) => {
            if (formFor === m.id) { list.append(materialForm(m)); return; }
            list.append(h('div', { class: 'tile' },
              h('div', { class: 'grow' }, h('div', { class: 't' }, m.name), h('div', { class: 's' }, label)),
              h('a', { class: 'iconbtn dim', href: m.driveUrl, target: '_blank', rel: 'noopener', title: 'Відкрити' }, icon('open_in_new')),
              rowActions(() => draw(m.id), async () => {
                if (!await confirmDialog('Видалити матеріал?', `Видалити «${m.name}»?`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
                if (await write(() => deleteDoc(doc(db, cfg.materials, m.id)), 'Матеріал видалено')) refresh();
              })));
          });
        }
      };
      const materialForm = (m) => {
        const typeSel = h('select', {}, MATERIAL_TYPES.map(([v, l]) => h('option', { value: v, selected: (m?.type ?? 'text') === v }, l)));
        const name = input(m?.name, 'Назва матеріалу');
        const url = input(m?.driveUrl, 'https://drive.google.com/… або YouTube');
        const thumb = input(m?.thumbnailUrl ?? '', 'Необов’язково — для відео підставиться автоматично');
        const uploadIc = icon('upload_file');
        const uploadBtn = h('button', { class: 'iconbtn', title: 'Завантажити файл у сховище' }, uploadIc);
        const syncUpload = () => { uploadBtn.hidden = !UPLOAD_EXT[typeSel.value]; };
        typeSel.addEventListener('change', syncUpload);
        syncUpload();
        uploadBtn.addEventListener('click', async () => {
          const ext = UPLOAD_EXT[typeSel.value];
          const [file] = await pickFiles({ accept: ext.map((e) => `.${e}`).join(',') });
          if (!file) return;
          uploadIc.textContent = 'hourglass_top'; uploadBtn.disabled = true;
          try { url.value = await uploadMedia('education', file); toast('Файл завантажено у сховище', 'ok'); }
          catch (e) { toast(`Не вдалося завантажити файл: ${e.message}`, 'err'); }
          finally { uploadIc.textContent = 'upload_file'; uploadBtn.disabled = false; }
        });
        return formBox(m ? 'Редагувати матеріал' : 'Новий матеріал', [
          field('Тип', typeSel),
          field('Назва *', name),
          h('label', { class: 'field with-btn' }, h('span', {}, 'Посилання на відео/файл *'), url, uploadBtn),
          field('Мініатюра (посилання)', thumb),
        ], async () => {
          if (!name.value.trim()) { toast('Введіть назву матеріалу', 'err'); return; }
          if (!url.value.trim()) { toast('Вкажіть посилання або завантажте файл', 'err'); return; }
          const type = typeSel.value;
          let thumbnailUrl = thumb.value.trim() || null;
          if (!thumbnailUrl && type === 'video') {
            const yt = youTubeId(url.value.trim());
            const gd = url.value.trim().match(/drive\.google\.com\/file\/d\/([^/?]+)/);
            if (yt) thumbnailUrl = `https://img.youtube.com/vi/${yt}/hqdefault.jpg`;
            else if (gd) thumbnailUrl = `https://drive.google.com/thumbnail?id=${gd[1]}&sz=w480`;
          }
          const data = {
            id: m?.id || `${cfg.materialPrefix}_${Date.now()}`,
            topicId: selectedTopicId,
            type,
            name: name.value.trim(),
            driveUrl: url.value.trim(),
            mediaType: m?.mediaType ?? null,
            thumbnailUrl,
          };
          if (await write(() => setDoc(doc(db, cfg.materials, data.id), data), m ? 'Матеріал оновлено' : 'Матеріал додано')) refresh();
        }, () => draw());
      };
      wrap.append(topicSelect(refresh), list);
      refresh();
      return wrap;
    }

    // ── Флеш-картки ─────────────────────────────────────────────────────────
    async function cardsTab() {
      if (!topics.length) return emptyState('topic', 'Спершу додайте тему', 'Вкладка «Теми»');
      return qaTab({
        colName: FLASHCARDS, idPrefix: 'fc', addLabel: 'Додати картку', empty: 'Карток ще немає',
        csvHint: 'CSV: питання,відповідь (поле з комами — у лапках "…")',
        summary: (c) => [c.question, c.answer],
        form: (c) => {
          const q = textarea(c?.question, 'Питання'); const a = textarea(c?.answer, 'Відповідь');
          return {
            fields: [field('Питання *', q), field('Відповідь *', a)],
            data: () => (q.value.trim() && a.value.trim() ? { question: q.value.trim(), answer: a.value.trim() } : null),
          };
        },
        parseRow: parseCardRow,
      });
    }

    // ── Питання тестів ──────────────────────────────────────────────────────
    async function testsTab() {
      if (!topics.length) return emptyState('topic', 'Спершу додайте тему', 'Вкладка «Теми»');
      return qaTab({
        colName: QUESTIONS, idPrefix: 'tq', addLabel: 'Додати питання', empty: 'Питань ще немає',
        csvHint: 'CSV: питання,варіант1,варіант2,варіант3,варіант4,правильний(0-3),пояснення (поле з комами — у лапках "…")',
        summary: (q) => [q.question, `✔ ${(q.options || [])[q.correctIndex] ?? ''}`],
        form: (q) => {
          const text = textarea(q?.question, 'Питання');
          const opts = [0, 1, 2, 3].map((i) => input(q?.options?.[i] ?? '', `Варіант ${i + 1}`));
          const correct = h('select', {}, [0, 1, 2, 3].map((i) => h('option', { value: i, selected: (q?.correctIndex ?? 0) === i }, `Варіант ${i + 1}`)));
          const expl = textarea(q?.explanation ?? '', 'Необов’язково');
          return {
            fields: [field('Питання *', text), ...opts.map((o, i) => field(`Варіант ${i + 1} *`, o)), field('Правильна відповідь', correct), field('Пояснення', expl)],
            data: () => {
              const options = opts.map((o) => o.value.trim());
              if (!text.value.trim() || options.some((o) => !o)) return null;
              return { question: text.value.trim(), options, correctIndex: +correct.value, explanation: expl.value.trim() || null };
            },
          };
        },
        parseRow: parseQuestionRow,
      });
    }

    // Спільна вкладка для карток і тестів: список, форма, імпорт CSV
    function qaTab({ colName, idPrefix, addLabel, empty, csvHint, summary, form, parseRow }) {
      const wrap = h('div');
      const list = h('div');
      let items = [];
      const refresh = async () => {
        clear(list).append(spinner());
        items = await load(colName, selectedTopicId);
        draw();
      };
      const nextOrder = () => items.reduce((m, x) => Math.max(m, (x.sortOrder ?? -1) + 1), items.length);
      const itemForm = (it) => {
        const f = form(it);
        return formBox(it ? 'Редагувати' : addLabel, f.fields, async () => {
          const d = f.data();
          if (!d) { toast('Заповніть усі обов’язкові поля', 'err'); return; }
          // новий — у кінець списку; під час редагування порядок не змінюється
          const sortOrder = it ? it.sortOrder ?? null : nextOrder();
          const data = { id: it?.id || `${idPrefix}_${Date.now()}`, topicId: selectedTopicId, ...d, ...(sortOrder != null ? { sortOrder } : {}) };
          if (await write(() => setDoc(doc(db, colName, data.id), data, { merge: true }), 'Збережено')) refresh();
        }, () => draw());
      };
      const draw = (formFor) => {
        clear(list);
        if (formFor === null) list.append(itemForm(null));
        else {
          list.append(h('div', { style: { display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '12px' } },
            h('button', { class: 'btn brown', onClick: () => draw(null) }, icon('add'), addLabel),
            h('button', { class: 'btn text', title: csvHint, onClick: importCsv }, icon('upload_file'), 'Імпорт CSV'),
            items.length ? h('button', { class: 'btn text', style: { color: '#C62828' }, onClick: deleteAll }, icon('delete_sweep'), 'Видалити всі') : null));
          list.append(h('div', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px', marginBottom: '8px' } }, `${items.length} шт. · ${csvHint}`));
        }
        if (!items.length) list.append(emptyState('inbox', empty));
        items.forEach((it) => {
          if (formFor === it.id) { list.append(itemForm(it)); return; }
          const [t, s] = summary(it);
          list.append(h('div', { class: 'tile' },
            h('div', { class: 'grow' }, h('div', { class: 't' }, t), h('div', { class: 's' }, s)),
            rowActions(() => draw(it.id), async () => {
              if (await write(() => deleteDoc(doc(db, colName, it.id)), 'Видалено')) refresh();
            })));
        });
      };
      const importCsv = async () => {
        const [file] = await pickFiles({ accept: '.csv,.txt' });
        if (!file) return;
        const { rows, skipped } = parseCsvFile(await file.text(), parseRow);
        const lines = (list) => list.slice(0, 15).map((x) => x.n).join(', ') + (list.length > 15 ? '…' : '');
        if (!rows.length) {
          toast(`Не знайдено жодного правильного рядка (${csvHint})${skipped.length ? `. Пропущено рядки: ${lines(skipped)}` : ''}`, 'err', 6000);
          return;
        }
        const topicName = topics.find((t) => t.id === selectedTopicId)?.name ?? '—';
        const go = await confirmDialog('Імпортувати CSV?',
          `Тема: «${topicName}». Розпізнано рядків: ${rows.length}.`
          + (skipped.length ? ` Буде пропущено: ${skipped.length} (рядки ${lines(skipped)}; перша причина: ${skipped[0].error}).` : '')
          + ` Записи додадуться в кінець списку (зараз ${items.length}).`,
          { okLabel: 'Імпортувати', cancelLabel: 'Скасувати' });
        if (!go) return;
        const ts = Date.now();
        const base = nextOrder();
        const ok = await write(async () => {
          for (let i = 0; i < rows.length; i += 400) { // ліміт Firestore — 500 записів на batch
            const batch = writeBatch(db);
            rows.slice(i, i + 400).forEach((r, j) => {
              const id = importId(idPrefix, ts, i + j);
              batch.set(doc(db, colName, id), { id, topicId: selectedTopicId, ...r, sortOrder: base + i + j });
            });
            await batch.commit();
          }
        });
        if (ok) {
          toast(`Імпортовано ${rows.length}, пропущено ${skipped.length}${skipped.length ? ` (рядки: ${lines(skipped)})` : ''}`, skipped.length ? '' : 'ok', 6000);
          refresh();
        }
      };
      const deleteAll = async () => {
        if (!await confirmDialog('Видалити всі?', `Видалити всі записи (${items.length}) цієї теми?`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
        const ok = await write(async () => {
          for (let i = 0; i < items.length; i += 400) {
            const batch = writeBatch(db);
            items.slice(i, i + 400).forEach((it) => batch.delete(doc(db, colName, it.id)));
            await batch.commit();
          }
        }, 'Видалено');
        if (ok) refresh();
      };
      wrap.append(topicSelect(refresh), list);
      refresh();
      return wrap;
    }

    // ── План навчання (study_plan) ──────────────────────────────────────────
    // Записи: тема (теоретична або практична), рівень, години. Порядок — поле
    // order (його читає додаток) і sortOrder (сайт); пишемо обидва.
    async function planTab() {
      const wrap = h('div');
      let plan = [];
      let theory = [];
      let practical = [];
      const nameOf = (e) => ((e.topicType === 'practical' ? practical : theory).find((x) => x.id === e.topicId)?.name) || '(тему видалено)';
      const refresh = async () => {
        clear(wrap).append(spinner());
        [plan, theory, practical] = await Promise.all([load(PLAN), load(TOPICS), load('practical_topics')]);
        draw();
      };
      const levelOf = (e) => (LEVELS.some(([k]) => k === e.level) ? e.level : '');
      const renumber = (list) => write(() => {
        const batch = writeBatch(db);
        list.forEach((e, i) => batch.update(doc(db, PLAN, e.id), { order: i, sortOrder: i }));
        return batch.commit();
      });
      // Переміщення в межах рівня; загальний порядок — рівні один за одним
      const move = async (e, dir) => {
        const groups = [...LEVELS.map(([k]) => plan.filter((x) => levelOf(x) === k)), plan.filter((x) => !levelOf(x))];
        const g = groups.find((list) => list.includes(e));
        const i = g.indexOf(e);
        [g[i], g[i + dir]] = [g[i + dir], g[i]];
        if (await renumber(groups.flat())) refresh();
      };
      const form = (e) => {
        const topic = h('select', {},
          h('optgroup', { label: 'Теоретичні теми' }, theory.map((x) => h('option', { value: `theoretical:${x.id}`, selected: e?.topicType !== 'practical' && e?.topicId === x.id }, x.name))),
          h('optgroup', { label: 'Практичні теми' }, practical.map((x) => h('option', { value: `practical:${x.id}`, selected: e?.topicType === 'practical' && e?.topicId === x.id }, x.name))));
        const level = h('select', {}, LEVELS.map(([k, l]) => h('option', { value: k, selected: (e?.level || 'basic') === k }, l)));
        const hours = input(e?.hours ?? 2, '', 'number');
        return formBox(e ? 'Редагувати запис плану' : 'Новий запис плану', [
          field('Тема *', topic), field('Рівень', level), field('Години', hours),
        ], async () => {
          if (!topic.value) { toast('Оберіть тему', 'err'); return; }
          const [topicType, ...rest] = topic.value.split(':');
          const n = parseInt(hours.value, 10);
          const order = e ? e.order ?? e.sortOrder ?? 0 : plan.reduce((m, x) => Math.max(m, (x.order ?? x.sortOrder ?? -1) + 1), plan.length);
          const data = {
            id: e?.id || `sp_${Date.now()}`, topicId: rest.join(':'), topicType, level: level.value,
            hours: Number.isNaN(n) || n < 0 ? 0 : n, order, sortOrder: order,
          };
          if (await write(() => setDoc(doc(db, PLAN, data.id), data, { merge: true }), e ? 'Запис оновлено' : 'Запис додано')) refresh();
        }, () => draw());
      };
      const draw = (formFor) => {
        clear(wrap);
        if (!theory.length && !practical.length) { wrap.append(emptyState('topic', 'Спершу додайте теми', 'Теоретичні або практичні')); return; }
        if (formFor === null) wrap.append(form(null));
        else wrap.append(h('button', { class: 'btn brown block', style: { marginBottom: '12px' }, onClick: () => draw(null) }, icon('add'), 'Додати запис плану'));
        const total = plan.reduce((a, e) => a + (Number(e.hours) || 0), 0);
        wrap.append(h('div', { class: 's', style: { marginBottom: '8px' } }, `Записів: ${plan.length} · годин: ${total}. План спільний для теоретичного й практичного розділів.`));
        for (const [k, label] of [...LEVELS, ['', 'Без рівня']]) {
          const list = plan.filter((e) => levelOf(e) === k);
          if (!list.length) continue;
          wrap.append(h('div', { class: 'form-section' }, `${label} · ${list.reduce((a, e) => a + (Number(e.hours) || 0), 0)} год`));
          list.forEach((e, i) => {
            if (formFor === e.id) { wrap.append(form(e)); return; }
            wrap.append(h('div', { class: 'tile' },
              h('div', { style: { display: 'flex', flexDirection: 'column' } },
                h('button', { class: 'iconbtn dim', title: 'Вище', disabled: i === 0, onClick: () => move(e, -1) }, icon('arrow_upward')),
                h('button', { class: 'iconbtn dim', title: 'Нижче', disabled: i === list.length - 1, onClick: () => move(e, 1) }, icon('arrow_downward'))),
              h('div', { class: 'grow' }, h('div', { class: 't' }, nameOf(e)),
                h('div', { class: 's' }, `${TOPIC_TYPES[e.topicType] ?? 'Теоретична'} · ${e.hours || 0} год`)),
              rowActions(() => draw(e.id), async () => {
                if (!await confirmDialog('Видалити запис?', `Прибрати «${nameOf(e)}» з плану? Сама тема лишиться.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
                if (await write(() => deleteDoc(doc(db, PLAN, e.id)), 'Запис видалено')) refresh();
              })));
          });
        }
      };
      refresh();
      return wrap;
    }

    render();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(cfg.title, { back: pop, cls: 'brown', actions: kind === 'theory' ? [
        h('button', { class: 'iconbtn', title: 'Перевірити якість даних', onClick: () => openDataCheck() }, icon('cleaning_services')),
      ] : [] }),
      tabs,
      h('div', { class: 'body' }, body));
  });
}

// ── Перевірка якості даних ──────────────────────────────────────────────────
// Виправляє на місці (від імені адміністратора) відомі дефекти:
//  • розмітку формул із джерела карток: «$150$», «$20\%$», «$40\,000$»;
//  • картки, розірвані старим імпортом CSV по першій комі: питання
//    починається з лапки, а в відповідь потрапив хвіст питання з «","»;
//  • «картки», які насправді є рядками тестів (CSV тестів імпортовано на
//    вкладці «Флеш-картки») — такі видаляються.

/**
 * Відповідь картки — це рядок тесту «варіант1,…,варіант4,номер(0–3)[,пояснення]»?
 * Суворо: рівно чотири непорожні варіанти, п'яте поле — одна цифра 0–3.
 */
export function isTestRowAnswer(answer) {
  const p = splitCsvLine(answer || '');
  return p.length >= 5 && p.slice(0, 4).every((o) => o.trim() && o.trim().length <= 120) && /^[0-3]$/.test(p[4].trim());
}

/** «$150$» → «150», «\%» → «%», «\,» (тонкий пробіл між розрядами) → пробіл. */
export function cleanFormula(text) {
  if (typeof text !== 'string' || !text.includes('$')) return text;
  return text.replace(/\$([^$]{1,40})\$/g, (_, inner) => inner.replace(/\\%/g, '%').replace(/\\,/g, ' ').trim());
}

/** Склеює розірвану картку; null — картка ціла. */
export function repairSplitCard(question, answer) {
  const q = question || '', a = answer || '';
  if (!(q.startsWith('"') || a.trimEnd().endsWith('"') || a.includes('","') || a.includes('?",'))) return null;
  const p = splitCsvLine(`${q},${a}`);
  if (p.length !== 2 || !p[0].trim() || !p[1].trim()) return null;
  return { question: p[0].trim().replace(/,(?=[^\s\d])/g, ', '), answer: p[1].trim() };
}

/** Зміни для однієї картки / питання тесту: { fields, kinds } або null. */
export function planCardFix(card) {
  if (isTestRowAnswer(card.answer)) return { remove: true, kinds: ['testrow'] };
  const kinds = [];
  let { question, answer } = card;
  const rep = repairSplitCard(question, answer);
  if (rep) { ({ question, answer } = rep); kinds.push('split'); }
  const q2 = cleanFormula(question), a2 = cleanFormula(answer);
  if (q2 !== question || a2 !== answer) kinds.push('formula');
  return kinds.length ? { fields: { question: q2, answer: a2 }, kinds } : null;
}
export function planQuestionFix(q) {
  const fields = {};
  const t = cleanFormula(q.question);
  if (t !== q.question) fields.question = t;
  const opts = Array.isArray(q.options) ? q.options.map(cleanFormula) : q.options;
  if (Array.isArray(q.options) && opts.some((o, i) => o !== q.options[i])) fields.options = opts;
  const ex = cleanFormula(q.explanation);
  if (ex !== q.explanation) fields.explanation = ex;
  return Object.keys(fields).length ? { fields, kinds: ['formula'] } : null;
}

function openDataCheck() {
  const box = h('div', {}, spinner());
  const d = openDialog([h('h3', {}, 'Перевірка якості даних'), box]);
  (async () => {
    const [cardsSnap, qSnap] = await Promise.all([getDocs(collection(db, FLASHCARDS)), getDocs(collection(db, QUESTIONS))]);
    const fixes = [];
    cardsSnap.docs.forEach((s) => { const f = planCardFix(s.data()); if (f) fixes.push({ col: FLASHCARDS, id: s.id, before: s.data(), ...f }); });
    qSnap.docs.forEach((s) => { const f = planQuestionFix(s.data()); if (f) fixes.push({ col: QUESTIONS, id: s.id, before: s.data(), ...f }); });
    const n = (col, kind) => fixes.filter((f) => f.col === col && f.kinds.includes(kind)).length;
    clear(box);
    if (!fixes.length) {
      box.append(h('div', { class: 'sec-text' }, `Перевірено ${cardsSnap.size} карток і ${qSnap.size} питань тестів — проблем не знайдено.`),
        h('div', { class: 'row' }, h('button', { class: 'btn', onClick: () => d.close() }, 'Закрити')));
      return;
    }
    const removals = fixes.filter((f) => f.remove);
    const example = fixes.find((f) => f.kinds.includes('split')) || fixes.find((f) => !f.remove);
    const show = (o) => `${(o.question || '').slice(0, 90)} → ${String(o.answer ?? (o.options || []).join(' / ')).slice(0, 70)}`;
    const go = h('button', { class: 'btn', onClick: async () => {
      go.disabled = true; go.textContent = 'Виправлення…';
      try {
        for (let i = 0; i < fixes.length; i += 400) {
          const batch = writeBatch(db);
          fixes.slice(i, i + 400).forEach((f) => (f.remove ? batch.delete(doc(db, f.col, f.id)) : batch.update(doc(db, f.col, f.id), f.fields)));
          await batch.commit();
        }
        invalidateEducationCache();
        d.close();
        toast(`Виправлено: ${fixes.length - removals.length}, видалено: ${removals.length}`, 'ok', 4000);
      } catch (e) { go.disabled = false; go.textContent = 'Спробувати ще раз'; toast(`Помилка: ${e.message}`, 'err'); }
    } }, `Виправити (${fixes.length})`);
    box.append(
      h('div', { class: 'sec-text' }, `Перевірено ${cardsSnap.size} карток і ${qSnap.size} питань тестів. Знайдено:`),
      h('ul', { style: { margin: '8px 0', paddingLeft: '20px', lineHeight: 1.6 } },
        n(FLASHCARDS, 'split') ? h('li', {}, `розірваних карток (частина питання у відповіді): ${n(FLASHCARDS, 'split')}`) : null,
        n(FLASHCARDS, 'formula') ? h('li', {}, `карток із розміткою формул ($…$): ${n(FLASHCARDS, 'formula')}`) : null,
        n(QUESTIONS, 'formula') ? h('li', {}, `питань тестів із розміткою формул ($…$): ${n(QUESTIONS, 'formula')}`) : null,
        removals.length ? h('li', { style: { color: '#C62828' } }, `карток, що насправді є рядками тесту — буде ВИДАЛЕНО: ${removals.length}`) : null),
      example ? [
        h('div', { class: 's', style: { fontWeight: 600 } }, 'Приклад виправлення:'),
        h('div', { class: 's', style: { color: '#C62828' } }, `Було: ${show(example.before)}`),
        h('div', { class: 's', style: { color: '#2E7D32', marginBottom: '8px' } }, `Стане: ${show({ ...example.before, ...example.fields })}`),
      ] : null,
      removals.length ? [
        h('div', { class: 's', style: { fontWeight: 600 } }, 'Буде видалено (картки-рядки тесту):'),
        h('ul', { class: 's', style: { margin: '4px 0 8px', paddingLeft: '20px', maxHeight: '140px', overflowY: 'auto' } },
          removals.map((f) => h('li', {}, `${(f.before.question || '').slice(0, 80)} → ${String(f.before.answer || '').slice(0, 40)}…`))),
      ] : null,
      h('div', { class: 's', style: { marginBottom: '8px' } }, 'Змінюється лише текст виправлених записів; теми, порядок і інші поля лишаються як є.'),
      h('div', { class: 'row' }, h('button', { class: 'btn text', onClick: () => d.close() }, 'Скасувати'), go));
  })().catch((e) => clear(box).append(h('div', { class: 'err' }, `Помилка: ${e.message}`)));
}

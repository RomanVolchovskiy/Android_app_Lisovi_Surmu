// Управління навчанням (AdminEducationScreen): теми, навчальні матеріали,
// флеш-картки, питання тестів. Ті самі колекції й поля, що в EducationService.
import { h, icon, toast, pushScreen, appBar, confirmDialog, pickFiles, clear, spinner, emptyState } from '../ui.js';
import { db, collection, doc, getDocs, setDoc, deleteDoc, query, where, writeBatch } from '../firebase.js';
import { uploadMedia, youTubeId, AUDIO_EXT, IMAGE_EXT, VIDEO_EXT } from '../data.js';
import { invalidateEducationCache } from './education.js';

const TOPICS = 'edu_topics';
const MATERIALS = 'edu_learning_materials';
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

const TABS = [
  { id: 'topics', icon: 'topic', label: 'Теми' },
  { id: 'materials', icon: 'menu_book', label: 'Матеріали' },
  { id: 'cards', icon: 'style', label: 'Флеш-картки' },
  { id: 'tests', icon: 'quiz', label: 'Тести' },
];

async function load(name, topicId) {
  const q = topicId ? query(collection(db, name), where('topicId', '==', topicId)) : collection(db, name);
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id }));
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

export function openAdminEducation() {
  pushScreen(({ pop }) => {
    let current = 'topics';
    let topics = [];
    let selectedTopicId = null;
    const body = h('div', { class: 'body-inner' });
    const tabs = h('div', { class: 'subtabs scroll' }, TABS.map((t) => h('button', {
      class: t.id === current ? 'active' : '', 'data-id': t.id,
      onClick: () => { current = t.id; [...tabs.children].forEach((b) => b.classList.toggle('active', b.dataset.id === current)); render(); },
    }, icon(t.icon), t.label)));

    const reloadTopics = async () => {
      topics = await load(TOPICS);
      topics.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
      if (!topics.some((t) => t.id === selectedTopicId)) selectedTopicId = topics[0]?.id ?? null;
    };

    const render = async () => {
      clear(body).append(spinner());
      try {
        if (!topics.length) await reloadTopics();
        const view = { topics: topicsTab, materials: materialsTab, cards: cardsTab, tests: testsTab }[current];
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
            h('div', { class: 'grow' }, h('div', { class: 't' }, t.name), t.description ? h('div', { class: 's' }, t.description) : null),
            rowActions(() => draw(t.id), async () => {
              if (!await confirmDialog('Видалити тему?', `Видалити «${t.name}»? Матеріали теми залишаться в базі без теми.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
              if (await write(() => deleteDoc(doc(db, TOPICS, t.id)), 'Тему видалено')) { await reloadTopics(); draw(); }
            })));
        });
      };
      const move = async (i, dir) => {
        const list = [...topics];
        [list[i], list[i + dir]] = [list[i + dir], list[i]];
        const ok = await write(() => {
          const batch = writeBatch(db);
          list.forEach((t, idx) => batch.update(doc(db, TOPICS, t.id), { sortOrder: idx }));
          return batch.commit();
        });
        if (ok) { await reloadTopics(); draw(); }
      };
      const topicForm = (t) => {
        const name = input(t?.name, 'Назва теми');
        const desc = textarea(t?.description, 'Короткий опис');
        const image = input(t?.imageUrl ?? '', 'https://…');
        return formBox(t ? 'Редагувати тему' : 'Нова тема', [
          field('Назва *', name), field('Опис', desc), field('Зображення (посилання)', image),
        ], async () => {
          if (!name.value.trim()) { toast('Введіть назву теми', 'err'); return; }
          const data = {
            id: t?.id || `topic_${Date.now()}`,
            name: name.value.trim(),
            description: desc.value.trim(),
            imageUrl: image.value.trim() || null,
            sortOrder: t?.sortOrder ?? topics.length,
          };
          if (await write(() => setDoc(doc(db, TOPICS, data.id), data), t ? 'Тему оновлено' : 'Тему додано')) { await reloadTopics(); draw(); }
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
        items = await load(MATERIALS, selectedTopicId);
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
                if (await write(() => deleteDoc(doc(db, MATERIALS, m.id)), 'Матеріал видалено')) refresh();
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
            id: m?.id || `lm_${Date.now()}`,
            topicId: selectedTopicId,
            type,
            name: name.value.trim(),
            driveUrl: url.value.trim(),
            mediaType: m?.mediaType ?? null,
            thumbnailUrl,
          };
          if (await write(() => setDoc(doc(db, MATERIALS, data.id), data), m ? 'Матеріал оновлено' : 'Матеріал додано')) refresh();
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
        csvHint: 'CSV: питання,відповідь',
        summary: (c) => [c.question, c.answer],
        form: (c) => {
          const q = textarea(c?.question, 'Питання'); const a = textarea(c?.answer, 'Відповідь');
          return {
            fields: [field('Питання *', q), field('Відповідь *', a)],
            data: () => (q.value.trim() && a.value.trim() ? { question: q.value.trim(), answer: a.value.trim() } : null),
          };
        },
        parseCsv: (line) => {
          const i = line.indexOf(',');
          if (i < 1) return null;
          const question = line.slice(0, i).trim(); const answer = line.slice(i + 1).trim();
          return question && answer ? { question, answer } : null;
        },
      });
    }

    // ── Питання тестів ──────────────────────────────────────────────────────
    async function testsTab() {
      if (!topics.length) return emptyState('topic', 'Спершу додайте тему', 'Вкладка «Теми»');
      return qaTab({
        colName: QUESTIONS, idPrefix: 'tq', addLabel: 'Додати питання', empty: 'Питань ще немає',
        csvHint: 'CSV: питання,варіант1,варіант2,варіант3,варіант4,правильний(0-3),пояснення',
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
        parseCsv: (line) => {
          const p = line.split(',');
          if (p.length < 6) return null;
          const question = p[0].trim(); const options = p.slice(1, 5).map((o) => o.trim());
          if (!question || options.some((o) => !o)) return null;
          return { question, options, correctIndex: parseInt(p[5], 10) || 0, explanation: p.length > 6 ? p.slice(6).join(',').trim() || null : null };
        },
      });
    }

    // Спільна вкладка для карток і тестів: список, форма, імпорт CSV
    function qaTab({ colName, idPrefix, addLabel, empty, csvHint, summary, form, parseCsv }) {
      const wrap = h('div');
      const list = h('div');
      let items = [];
      const refresh = async () => {
        clear(list).append(spinner());
        items = await load(colName, selectedTopicId);
        draw();
      };
      const itemForm = (it) => {
        const f = form(it);
        return formBox(it ? 'Редагувати' : addLabel, f.fields, async () => {
          const d = f.data();
          if (!d) { toast('Заповніть усі обов’язкові поля', 'err'); return; }
          const data = { id: it?.id || `${idPrefix}_${Date.now()}`, topicId: selectedTopicId, ...d };
          if (await write(() => setDoc(doc(db, colName, data.id), data), 'Збережено')) refresh();
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
        const rows = (await file.text()).split(/\r?\n/).map((l) => l.trim()).filter(Boolean).map(parseCsv).filter(Boolean);
        if (!rows.length) { toast(`Не знайдено жодного рядка у форматі ${csvHint}`, 'err'); return; }
        const ts = Date.now();
        const ok = await write(async () => {
          for (let i = 0; i < rows.length; i += 400) { // ліміт Firestore — 500 записів на batch
            const batch = writeBatch(db);
            rows.slice(i, i + 400).forEach((r, j) => {
              const id = `${idPrefix}_${ts}_${i + j}`;
              batch.set(doc(db, colName, id), { id, topicId: selectedTopicId, ...r });
            });
            await batch.commit();
          }
        }, `Імпортовано: ${rows.length}`);
        if (ok) refresh();
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

    render();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Управління навчанням', { back: pop, cls: 'brown' }),
      tabs,
      h('div', { class: 'body' }, body));
  });
}

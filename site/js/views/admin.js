// Адміністрування: вхід за паролем (AdminService), панель, додавання /
// редагування / впорядкування сигналів із завантаженням файлів у Storage.
import { h, icon, toast, pushScreen, appBar, confirmDialog, promptDialog, pickFiles, clear, openDialog } from '../ui.js';
import {
  CATEGORIES, getSignals, subscribeSignals, saveSignal, deleteSignal, reorderSignals,
  uploadMedia, AUDIO_EXT, IMAGE_EXT, VIDEO_EXT, mediaUrl,
} from '../data.js';
import { squares } from './notation.js';
import { createEventDialog } from './events.js';
import { db, collection, doc, onSnapshot, deleteDoc } from '../firebase.js';

const ADMIN_PASSWORD = '1488';
const SESSION_KEY = 'admin_session';
let authenticated = sessionStorage.getItem(SESSION_KEY) === '1';

export async function openAdmin() {
  if (!authenticated) {
    const pwd = await promptDialog('Вхід адміністратора', {
      label: 'Пароль', password: true, okLabel: 'Увійти',
      validate: (v) => (v === ADMIN_PASSWORD ? null : 'Невірний пароль'),
    });
    if (pwd == null) return;
    authenticated = true;
    sessionStorage.setItem(SESSION_KEY, '1');
  }
  openAdminPanel();
}

function openAdminPanel() {
  pushScreen(({ pop }) => {
    const tile = (ic, title, subtitle, onClick) => h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick },
      h('div', { style: { width: '44px', height: '44px', borderRadius: '12px', background: 'rgba(47,79,47,.1)', display: 'grid', placeItems: 'center', color: 'var(--primary)' } }, icon(ic)),
      h('div', { class: 'grow' }, h('div', { class: 't' }, title), h('div', { class: 's' }, subtitle)),
      icon('chevron_right', ''));
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Адміністративна панель', { back: pop, actions: [
        h('button', { class: 'iconbtn', title: 'Вийти з адмін панелі', onClick: () => { authenticated = false; sessionStorage.removeItem(SESSION_KEY); pop(); } }, icon('logout')),
      ] }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' },
        tile('add_circle_outline', 'Додати сигнал', 'Новий сигнал з аудіо, відео, нотами', () => openSignalForm(null)),
        tile('edit', 'Редагувати сигнали', 'Змінити, впорядкувати або видалити', () => openEditSignals()),
        tile('school', 'Управління навчанням', 'Теми, матеріали, флеш-картки, тести', () => toast('Розділ буде доступний у наступній фазі')),
        tile('event_note', 'Управління подіями', 'Глобальні мисливські події', () => openAdminEvents()),
        tile('quiz', 'Управління іспитами', 'Сесії іспитів та результати', () => toast('Розділ буде доступний у наступній фазі')))));
  });
}

// ── Список для редагування (EditSignalsScreen) ──────────────────────────────
function openEditSignals() {
  pushScreen((ctx) => {
    const list = h('div', { class: 'body-inner' });
    let dragId = null;
    const render = () => {
      clear(list);
      const items = getSignals();
      if (!items.length) { list.append(h('div', { class: 'empty' }, 'Сигнали відсутні')); return; }
      items.forEach((s) => {
        const row = h('div', { class: 'tile', draggable: true, 'data-id': s.id },
          h('span', { class: 'mi', style: { color: 'var(--grey-500)', cursor: 'grab' } }, 'drag_handle'),
          h('div', { class: 'grow', style: { cursor: 'pointer' }, onClick: () => openSignalForm(s) }, h('div', { class: 't' }, s.name), h('div', { class: 's' }, s.category)),
          h('button', { class: 'iconbtn dim', title: 'Редагувати', onClick: () => openSignalForm(s) }, icon('edit')),
          h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: async () => {
            if (await confirmDialog('Видалити сигнал?', `Видалити "${s.name}"? Цю дію не можна скасувати.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) {
              try { await deleteSignal(s.id); toast('Сигнал видалено', 'ok'); } catch (e) { toast(`Помилка: ${e.message}`, 'err'); }
            }
          } }, icon('delete')));
        row.addEventListener('dragstart', () => { dragId = s.id; row.style.opacity = '.5'; });
        row.addEventListener('dragend', () => { row.style.opacity = ''; });
        row.addEventListener('dragover', (e) => e.preventDefault());
        row.addEventListener('drop', async (e) => {
          e.preventDefault();
          if (!dragId || dragId === s.id) return;
          const ids = getSignals().map((x) => x.id);
          ids.splice(ids.indexOf(dragId), 1);
          ids.splice(ids.indexOf(s.id), 0, dragId);
          try { await reorderSignals(ids); } catch (err) { toast(`Помилка: ${err.message}`, 'err'); }
        });
        list.append(row);
      });
    };
    const off = subscribeSignals(render);
    ctx.onPop = off;
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Редагувати сигнали', { back: ctx.pop, cls: 'brown' }),
      h('div', { class: 'body' }, list));
  });
}

// ── Форма сигналу (AddSignalScreen) ─────────────────────────────────────────
function openSignalForm(existing) {
  pushScreen(({ pop }) => {
    const s = existing || {};
    const f = {};
    const field = (key, label, { hint = '', multiline = false, type = 'text', upload = null } = {}) => {
      const input = multiline
        ? h('textarea', { placeholder: hint, value: s[key] ?? '' })
        : h('input', { type, placeholder: hint, value: s[key] ?? '' });
      if (Array.isArray(s[key])) input.value = s[key].join(key === 'tags' ? ', ' : '\n');
      f[key] = input;
      let btn = null;
      if (upload) {
        const ic = icon('upload_file');
        btn = h('button', { class: 'iconbtn', title: upload.multiple ? 'Завантажити файли у сховище' : 'Завантажити файл у сховище', onClick: async () => {
          const files = await pickFiles({ accept: upload.ext.map((e) => `.${e}`).join(','), multiple: !!upload.multiple });
          if (!files.length) return;
          ic.textContent = 'hourglass_top'; btn.disabled = true;
          try {
            const urls = [];
            for (const file of files) urls.push(await uploadMedia(key, file));
            if (upload.multiple) {
              const cur = input.value.trim();
              input.value = [cur, ...urls].filter(Boolean).join('\n');
            } else input.value = urls[0];
            toast('Файл завантажено у сховище', 'ok');
          } catch (e) { toast(`Не вдалося завантажити файл: ${e.message}`, 'err'); }
          finally { ic.textContent = 'upload_file'; btn.disabled = false; }
        } }, ic);
      }
      return h('label', { class: `field ${btn ? 'with-btn' : ''}` }, h('span', {}, label), input, btn);
    };
    const select = (key, label, options) => {
      const sel = h('select', {}, options.map(([v, l]) => h('option', { value: v, selected: (s[key] ?? '') === v }, l)));
      f[key] = sel;
      return h('label', { class: 'field' }, h('span', {}, label), sel);
    };

    // редактор графічних нот
    let notes = [...(s.notationData || [])];
    const notesView = h('div');
    const renderNotes = () => {
      clear(notesView);
      if (!notes.length) { notesView.append(h('div', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px' } }, 'Нот ще немає — оберіть висоту й тривалість нижче')); return; }
      notesView.append(h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '6px' } }, notes.map((n, i) => h('span', {
        style: { display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '4px 8px', border: '1px solid var(--gold)', borderRadius: '8px', background: '#fff', fontSize: '11px' },
      }, n.t === 'b' ? '│ вдих' : n.t === 'pa' ? '║ пауза' : [`${PITCHES[n.p]} `, squares(n.d)],
        h('button', { class: 'mi', style: { fontSize: '16px', color: '#F44336' }, title: 'Видалити', onClick: () => { notes.splice(i, 1); renderNotes(); } }, 'close')))));
    };
    let pitch = 2;
    const pitchSel = h('select', {}, PITCHES.map((p, i) => h('option', { value: i, selected: i === pitch }, p)));
    pitchSel.addEventListener('change', () => { pitch = +pitchSel.value; });
    const durBtns = DURATIONS.map((l, d) => h('button', { class: 'btn text', style: { padding: '6px 10px', fontSize: '12px' }, onClick: () => { notes.push({ t: 'n', p: pitch, d }); renderNotes(); } }, squares(d), ` ${l}`));
    renderNotes();

    const submit = async () => {
      const v = (k) => f[k].value.trim();
      if (!v('name')) { toast('Введіть назву сигналу', 'err'); return; }
      if (!f.category.value) { toast('Оберіть категорію', 'err'); return; }
      const signal = {
        id: s.id || `${Date.now()}`,
        name: v('name'), description: v('description'), category: f.category.value,
        duration: parseInt(v('duration'), 10) || 0,
        audioUrl: v('audioUrl') || null, videoUrl: v('videoUrl') || null, videoUrl2: v('videoUrl2') || null,
        notationUrl: v('notationUrl') || null, notationAudioUrl: v('notationAudioUrl') || null,
        partitureUrl: v('partitureUrl') || null, imageUrl: v('imageUrl') || null,
        historicalInfo: v('historicalInfo') || null, usageInstructions: v('usageInstructions') || null,
        tags: v('tags') ? v('tags').split(',').map((t) => t.trim()).filter(Boolean) : null,
        galleryImages: v('galleryImages') ? v('galleryImages').split('\n').map((t) => t.trim()).filter(Boolean) : null,
        isFavorite: false,
        difficulty: f.difficulty.value || null,
        signalText: v('signalText') || null,
        notationData: notes.length ? notes : null,
        notationTempo: parseInt(v('notationTempo'), 10) || null,
        sortOrder: s.sortOrder ?? getSignals().length,
      };
      saveBtn.disabled = true;
      try {
        await saveSignal(signal);
        toast(existing ? 'Сигнал успішно оновлено' : 'Сигнал успішно збережено', 'ok');
        pop();
      } catch (e) { toast(`Помилка при збереженні сигналу: ${e.message}`, 'err'); saveBtn.disabled = false; }
    };
    const saveBtn = h('button', { class: 'btn brown block', style: { marginTop: '24px', padding: '14px' }, onClick: submit }, icon('save'), existing ? 'Зберегти зміни' : 'Зберегти сигнал');

    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(existing ? 'Редагувати сигнал' : 'Додати новий сигнал', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' },
        h('div', { class: 'form-section' }, 'Основна інформація'),
        field('name', 'Назва сигналу *', { hint: 'Наприклад: На лови' }),
        field('description', 'Опис *', { hint: 'Короткий опис сигналу', multiline: true }),
        select('category', 'Категорія *', [['', '— оберіть —'], ...CATEGORIES.map((c) => [c.name, c.name])]),
        field('duration', 'Тривалість (секунд)', { hint: '15', type: 'number' }),
        select('difficulty', 'Рівень складності', [['', '— не вказано —'], ['easy', '🟢 Легкий'], ['medium', '🟡 Середній'], ['hard', '🔴 Важкий']]),
        h('div', { class: 'form-section' }, 'Мультимедійні файли'),
        field('audioUrl', 'Аудіо файл', { hint: 'Посилання або файл зі сховища', upload: { ext: AUDIO_EXT } }),
        field('videoUrl', 'Відео 1 (кнопка «Відео»)', { hint: 'YouTube, посилання або файл зі сховища', upload: { ext: VIDEO_EXT } }),
        field('videoUrl2', 'Відео 2 (кнопка «Відео» в деталях)', { hint: 'YouTube, посилання або файл зі сховища', upload: { ext: VIDEO_EXT } }),
        field('notationUrl', 'Файл з нотами (зображення)', { hint: 'Посилання або файл зі сховища', upload: { ext: IMAGE_EXT } }),
        field('notationAudioUrl', 'Аудіо до нот (спів із сигналом)', { hint: 'Посилання або файл зі сховища', upload: { ext: AUDIO_EXT } }),
        field('partitureUrl', 'Партитура (захищене зображення)', { hint: 'Посилання або файл зі сховища', upload: { ext: IMAGE_EXT } }),
        field('signalText', 'Текст сигналу (слова)', { hint: 'Слова до мелодії сигналу, які відображатимуться під нотами', multiline: true }),
        field('imageUrl', 'Зображення (обкладинка)', { hint: 'Посилання або файл зі сховища', upload: { ext: IMAGE_EXT } }),
        field('galleryImages', 'Фотогалерея', { hint: 'Кожне посилання з нового рядка або файли зі сховища', multiline: true, upload: { ext: IMAGE_EXT, multiple: true } }),
        h('div', { class: 'form-section' }, 'Графічне відображення нот'),
        h('div', { style: { background: 'rgba(255,255,255,.9)', border: '1px solid #A1887F', borderRadius: '8px', padding: '12px' } },
          field('notationTempo', 'Темп сигналу (BPM)', { hint: '90', type: 'number' }),
          h('div', { class: 'dk-row', style: { marginBottom: '8px' } }, h('span', { style: { fontSize: '12px', color: 'var(--grey-700)' } }, 'Висота:'), pitchSel),
          h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '4px', marginBottom: '8px' } }, durBtns,
            h('button', { class: 'btn text', style: { padding: '6px 10px', fontSize: '12px' }, onClick: () => { notes.push({ t: 'b' }); renderNotes(); } }, '│ Вдих'),
            h('button', { class: 'btn text', style: { padding: '6px 10px', fontSize: '12px' }, onClick: () => { notes.push({ t: 'pa' }); renderNotes(); } }, '║ Пауза')),
          notesView),
        h('div', { class: 'form-section' }, 'Додаткова інформація'),
        field('historicalInfo', 'Історична довідка', { multiline: true }),
        field('usageInstructions', 'Інструкції з використання', { multiline: true }),
        field('tags', 'Теги', { hint: 'через кому' }),
        saveBtn,
        h('div', { style: { height: '24px' } }))));
  });
}

const PITCHES = ['СОЛЬ2', 'МІ2', 'ДО2', 'СОЛЬ', 'ДО'];
const DURATIONS = ['Ціла', 'Половинна', 'Четвертна', 'Восьма', '1/16'];

// ── Глобальні події (AdminEventsScreen) ─────────────────────────────────────
function openAdminEvents() {
  pushScreen((ctx) => {
    const list = h('div', { class: 'body-inner' });
    let events = [];
    const render = () => {
      clear(list);
      if (!events.length) list.append(h('div', { class: 'empty' }, 'Глобальних подій ще немає'));
      events.forEach((e) => list.append(h('div', { class: 'tile' },
        h('div', { class: 'grow' }, h('div', { class: 't' }, e.title), h('div', { class: 's' }, `${e.type || ''} · ${(e.date || '').slice(0, 10)} · ${e.location || ''}`)),
        h('button', { class: 'iconbtn dim', title: 'Редагувати', onClick: () => createEventDialog(null, { isGlobal: true, existing: e }) }, icon('edit')),
        h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: async () => {
          if (await confirmDialog('Видалити подію?', `Видалити "${e.title}"?`, { okLabel: 'Видалити', danger: true })) {
            try { await deleteDoc(doc(db, 'global_events', String(e.id))); toast('Подію видалено', 'ok'); } catch (err) { toast(`Помилка: ${err.message}`, 'err'); }
          }
        } }, icon('delete')))));
      list.append(h('div', { style: { textAlign: 'center', marginTop: '12px' } },
        h('button', { class: 'btn', onClick: () => createEventDialog(null, { isGlobal: true }) }, icon('add'), 'Створити подію')));
    };
    const unsub = onSnapshot(collection(db, 'global_events'), (snap) => { events = snap.docs.map((d) => d.data()); render(); });
    ctx.onPop = unsub;
    render();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Управління подіями', { back: ctx.pop, cls: 'brown' }),
      h('div', { class: 'body' }, list));
  });
}

// Адмін-панель → «Покіт: розкладка здобичі»: налаштування раунду
// (pokit_trainer/config) і довідник видів (pokit_species) з pokitRank —
// порядком у правильному покоті, який задає викладач.
import { h, icon, toast, pushScreen, appBar, confirmDialog, pickFiles, clear, spinner, emptyState } from '../ui.js';
import { db, doc, setDoc, updateDoc, deleteDoc, serverTimestamp } from '../firebase.js';
import { getSignals, waitForSignals, uploadMedia, IMAGE_EXT } from '../data.js';
import { SPECIES, CONFIG_DOC, DEFAULT_CONFIG, loadSpecies, loadConfig, speciesBadge } from './trainer-pokit.js';

const ICONS = [
  ['pets', 'Звір (лапа)'], ['cruelty_free', 'Заєць'], ['flutter_dash', 'Птах'], ['emoji_nature', 'Комаха/дрібна дичина'],
  ['forest', 'Ліс'], ['set_meal', 'Риба'], ['egg', 'Яйце'], ['spa', 'Листок'],
];
const num = (v, d = 0) => (Number.isFinite(Number(v)) ? Number(v) : d);
const byRank = (a, b) => num(a.pokitRank) - num(b.pokitRank) || (a.name || '').localeCompare(b.name || '', 'uk');
const field = (label, el, hint) => h('label', { class: 'field' }, h('span', {}, label), el, hint ? h('div', { class: 's', style: { marginTop: '4px', color: 'var(--grey-600)' } }, hint) : null);

export function openAdminPokit() {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner', style: { paddingBottom: '96px' } });
    let items = [], cfg = DEFAULT_CONFIG, sortMode = 'rank';

    const reload = async () => {
      clear(body).append(spinner());
      try { [items, cfg] = await Promise.all([loadSpecies(), loadConfig()]); draw(); }
      catch (e) { clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); }
    };

    const configCard = () => {
      const n = (v) => h('input', { type: 'number', min: 1, value: v });
      const minS = n(cfg.minSpecies), maxS = n(cfg.maxSpecies), minC = n(cfg.minCountPerSpecies), maxC = n(cfg.maxCountPerSpecies);
      const grouping = h('input', { type: 'checkbox', checked: cfg.groupingRequired !== false });
      const two = (a, b) => h('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' } }, a, b);
      const save = h('button', { class: 'btn brown', onClick: async () => {
        const v = { minSpecies: num(minS.value), maxSpecies: num(maxS.value), minCountPerSpecies: num(minC.value), maxCountPerSpecies: num(maxC.value) };
        if (Object.values(v).some((x) => !(x >= 1) || !Number.isInteger(x))) { toast('Усі значення — цілі числа від 1', 'err'); return; }
        if (v.maxSpecies < v.minSpecies || v.maxCountPerSpecies < v.minCountPerSpecies) { toast('«Макс» має бути не менше за «мін»', 'err'); return; }
        save.disabled = true;
        try {
          await setDoc(doc(db, ...CONFIG_DOC), { ...v, groupingRequired: grouping.checked, updatedAt: serverTimestamp() }, { merge: true });
          cfg = { ...cfg, ...v, groupingRequired: grouping.checked };
          toast('Налаштування збережено', 'ok');
        } catch (e) { toast(`Помилка: ${e.message}`, 'err'); } finally { save.disabled = false; }
      } }, icon('save'), 'Зберегти');
      return h('details', { class: 'tile', style: { display: 'block' } },
        h('summary', { style: { cursor: 'pointer', fontWeight: 600 } }, `Налаштування раунду: видів ${cfg.minSpecies}–${cfg.maxSpecies}, особин ${cfg.minCountPerSpecies}–${cfg.maxCountPerSpecies}${cfg.groupingRequired !== false ? ', групування обов’язкове' : ''}`),
        h('div', { style: { paddingTop: '12px' } },
          two(field('Видів у раунді: від', minS), field('до', maxS)),
          two(field('Особин одного виду: від', minC), field('до', maxC)),
          h('label', { class: 'dk-row', style: { gap: '6px', marginBottom: '12px', fontSize: '14px' } }, grouping, 'Групування однакових видів обов’язкове'),
          save));
    };

    const draw = () => {
      clear(body).append(configCard());
      const sorted = items.slice().sort(sortMode === 'rank' ? byRank : (a, b) => num(a.sortOrder) - num(b.sortOrder));
      body.append(h('div', { style: { display: 'flex', alignItems: 'center', gap: '8px', margin: '12px 0 8px' } },
        h('div', { class: 'sec-title grow', style: { margin: 0 } }, `Види дичини (${items.length})`),
        h('div', { class: 'chips', style: { height: 'auto', padding: 0 } },
          [['rank', 'За порядком покоту'], ['list', 'За списком']].map(([m, l]) => h('button', { class: `chip ${sortMode === m ? 'selected' : ''}`, onClick: () => { sortMode = m; draw(); } }, l)))));
      if (!items.length) { body.append(emptyState('pets', 'Довідник порожній', 'Додайте щонайменше 4 види кнопкою «+»')); return; }
      sorted.forEach((sp) => {
        const hidden = h('input', { type: 'checkbox', checked: !!sp.hidden, title: 'Прихований' });
        hidden.addEventListener('change', async () => {
          try { await updateDoc(doc(db, SPECIES, sp.id), { hidden: hidden.checked }); sp.hidden = hidden.checked; draw(); }
          catch (e) { hidden.checked = !hidden.checked; toast(`Помилка: ${e.message}`, 'err'); }
        });
        body.append(h('div', { class: 'tile', style: { opacity: sp.hidden ? 0.55 : 1 } },
          h('div', { style: { width: '44px', display: 'grid', placeItems: 'center' } }, speciesBadge(sp, 36)),
          h('div', { class: 'grow' }, h('div', { class: 't' }, sp.name), h('div', { class: 's' }, `Ранг у покоті: ${num(sp.pokitRank)}${sp.hidden ? ' · прихований' : ''}`)),
          h('label', { class: 'dk-row', style: { fontSize: '12px', gap: '4px' } }, hidden, 'прих.'),
          h('button', { class: 'iconbtn dim', title: 'Редагувати', onClick: () => openSpeciesForm(sp, items, reload) }, icon('edit')),
          h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: async () => {
            if (!await confirmDialog('Видалити вид?', `Видалити «${sp.name}»? Старі результати студентів залишаться.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
            try { await deleteDoc(doc(db, SPECIES, sp.id)); toast('Видалено', 'ok'); reload(); } catch (e) { toast(`Помилка: ${e.message}`, 'err'); }
          } }, icon('delete'))));
      });
    };

    reload();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Покіт: розкладка здобичі', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, body),
      h('button', { class: 'fab', title: 'Новий вид', onClick: () => openSpeciesForm(null, items, reload) }, icon('add')));
  });
}

function openSpeciesForm(existing, all, onSaved) {
  pushScreen(({ pop }) => {
    const e = existing || {};
    let imageUrl = e.imageUrl || null;
    const name = h('input', { type: 'text', value: e.name ?? '', placeholder: 'Напр. Кабан' });
    const rank = h('input', { type: 'number', step: 'any', value: e.pokitRank ?? (all.length ? Math.max(...all.map((s) => num(s.pokitRank))) + 10 : 10) });
    const known = ICONS.some(([v]) => v === (e.icon || 'pets'));
    const iconSel = h('select', {}, ICONS.map(([v, l]) => h('option', { value: v, selected: v === (e.icon || 'pets') }, l)), h('option', { value: '__custom', selected: !known }, 'Інша (назва Material-іконки)…'));
    const iconCustom = h('input', { type: 'text', value: known ? '' : e.icon, placeholder: 'напр. pest_control_rodent', hidden: known });
    const signal = h('select', {}, h('option', { value: '' }, '— без сигналу —'));
    const hidden = h('input', { type: 'checkbox', checked: !!e.hidden });
    const preview = h('div');
    const imgBox = h('div');

    const currentIcon = () => (iconSel.value === '__custom' ? iconCustom.value.trim() || 'pets' : iconSel.value);
    const drawImage = () => {
      clear(imgBox).append(h('div', { class: 'dk-row', style: { gap: '10px', marginBottom: '12px' } },
        h('div', { style: { width: '56px', height: '56px', display: 'grid', placeItems: 'center', background: '#fff', borderRadius: '10px', border: '1px solid #ddd' } },
          speciesBadge({ imageUrl, icon: currentIcon() }, 44)),
        h('button', { class: 'btn text', onClick: async () => {
          const [f] = await pickFiles({ accept: IMAGE_EXT.map((x) => `.${x}`).join(',') });
          if (!f) return;
          try { toast('Завантаження…'); imageUrl = await uploadMedia('pokitImage', f); drawImage(); toast('Зображення завантажено', 'ok'); }
          catch (err) { toast(`Помилка завантаження: ${err.message}`, 'err'); }
        } }, icon('image'), imageUrl ? 'Замінити зображення' : 'Завантажити зображення'),
        imageUrl ? h('button', { class: 'btn text', style: { color: '#C62828' }, onClick: () => { imageUrl = null; drawImage(); } }, 'Прибрати') : null));
    };
    // Результуючий порядок покоту з урахуванням ще не збереженого рангу
    const drawPreview = () => {
      const me = { id: e.id || '__new', name: name.value.trim() || '(цей вид)', pokitRank: num(rank.value), hidden: hidden.checked };
      const list = [...all.filter((s) => s.id !== me.id), me].filter((s) => !s.hidden).sort(byRank);
      clear(preview).append(h('div', { class: 's', style: { fontWeight: 600, margin: '4px 0' } }, 'Порядок покоту (видимі види):'),
        h('ol', { style: { margin: '0 0 12px', paddingLeft: '22px' } }, list.map((s) => h('li', { style: { fontWeight: s.id === me.id ? 700 : 400 } }, `${s.name} — ${num(s.pokitRank)}`))));
    };
    iconSel.addEventListener('change', () => { iconCustom.hidden = iconSel.value !== '__custom'; drawImage(); });
    iconCustom.addEventListener('input', drawImage);
    [name, rank].forEach((x) => x.addEventListener('input', drawPreview));
    hidden.addEventListener('change', drawPreview);
    waitForSignals().then(() => {
      getSignals().forEach((s) => signal.append(h('option', { value: s.id, selected: s.id === e.signalId }, s.name)));
    });

    const save = h('button', { class: 'btn block', style: { padding: '14px', marginTop: '8px' }, onClick: async () => {
      if (!name.value.trim()) { toast('Введіть назву виду', 'err'); return; }
      if (!Number.isFinite(Number(rank.value)) || rank.value === '') { toast('Ранг у покоті — число', 'err'); return; }
      const id = e.id || `ps_${Date.now()}`;
      const data = {
        id, name: name.value.trim(), icon: currentIcon(), imageUrl: imageUrl || null,
        pokitRank: num(rank.value), hidden: hidden.checked, signalId: signal.value || null,
        sortOrder: existing ? num(e.sortOrder) : all.length,
      };
      save.disabled = true;
      try { await setDoc(doc(db, SPECIES, id), data, { merge: !!existing }); toast('Вид збережено', 'ok'); pop(); onSaved(); }
      catch (err) { toast(`Помилка збереження: ${err.message}`, 'err'); save.disabled = false; }
    } }, existing ? 'Зберегти зміни' : 'Додати вид');

    drawImage(); drawPreview();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(existing ? 'Редагування виду' : 'Новий вид дичини', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner', style: { maxWidth: '640px' } },
        field('Назва *', name),
        field('Ранг у покоті *', rank, 'Менше число — ближче до початку ряду покоту. Однаковий ранг — види рівнозначні, їхній взаємний порядок не перевіряється.'),
        preview,
        field('Іконка', iconSel), iconCustom,
        imgBox,
        field('Сигнал вшанування (необов’язково)', signal, 'Звучить після правильно викладеного покоту'),
        h('label', { class: 'dk-row', style: { gap: '6px', fontSize: '14px', marginBottom: '8px' } }, hidden, 'Прихований (не з’являється в раундах)'),
        save)));
  });
}

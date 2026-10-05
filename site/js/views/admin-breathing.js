// Дихальні вправи (адмін-панель): список, приховування, форма з редактором
// блоків (cycle — фази з секундами, endurance — цільовий діапазон видиху).
import { h, icon, toast, pushScreen, appBar, confirmDialog, clear, spinner, emptyState } from '../ui.js';
import { db, auth, collection, doc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp } from '../firebase.js';
import { EXERCISES, CATEGORIES, LEVELS, PHASE_TYPES, estimateSeconds, fmtDuration } from './trainer-breathing.js';

const num = (v) => Number(v) || 0;
const clone = (x) => JSON.parse(JSON.stringify(x));
const newCycle = () => ({ label: 'Цикл', kind: 'cycle', repeats: 4, restBetweenReps: 2, phases: [
  { type: 'inhale', seconds: 4, label: 'Вдих носом' }, { type: 'hold', seconds: 2, label: 'Затримка' }, { type: 'exhale', seconds: 8, label: 'Видих' }] });
const newEndurance = () => ({ label: 'Рівномірний видих', kind: 'endurance', repeats: 3, restBetweenReps: 5, phases: [
  { type: 'exhale', targetMinSeconds: 15, targetMaxSeconds: 20, label: 'Рівномірний видих' }] });

async function loadAll() {
  const snap = await getDocs(collection(db, EXERCISES));
  return snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id })).sort((a, b) => num(a.sortOrder) - num(b.sortOrder));
}

export function openAdminBreathing() {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner', style: { paddingBottom: '96px' } });
    let items = [];
    const reload = async () => {
      clear(body).append(spinner());
      try { items = await loadAll(); draw(); } catch (e) { clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); }
    };
    const save = async (ex, isNew) => {
      try {
        await setDoc(doc(db, EXERCISES, ex.id), ex, { merge: !isNew });
        toast('Вправу збережено', 'ok');
        reload();
        return true;
      } catch (e) { toast(`Помилка збереження: ${e.message}`, 'err'); return false; }
    };
    const draw = () => {
      clear(body);
      if (!items.length) { body.append(emptyState('air', 'Вправ ще немає', 'Натисніть «+», щоб створити першу')); return; }
      items.forEach((ex) => {
        const hidden = h('input', { type: 'checkbox', checked: !!ex.hidden });
        hidden.addEventListener('change', async () => {
          try { await updateDoc(doc(db, EXERCISES, ex.id), { hidden: hidden.checked }); ex.hidden = hidden.checked; draw(); }
          catch (e) { hidden.checked = !hidden.checked; toast(`Помилка: ${e.message}`, 'err'); }
        });
        body.append(h('div', { class: 'tile', style: { display: 'block', opacity: ex.hidden ? 0.6 : 1 } },
          h('div', { style: { display: 'flex', alignItems: 'center', gap: '8px' } },
            icon('air'), h('div', { class: 't grow' }, ex.title),
            ex.hidden ? h('span', { class: 'badge', style: { background: '#eee' } }, 'прихована') : null),
          h('div', { class: 's', style: { margin: '6px 0' } },
            [CATEGORIES[ex.category], LEVELS[ex.level], `блоків: ${(ex.blocks || []).length}`, `~${fmtDuration(estimateSeconds(ex))}`].filter(Boolean).join(' · ')),
          h('div', { style: { display: 'flex', alignItems: 'center', gap: '4px', flexWrap: 'wrap' } },
            h('label', { class: 'dk-row', style: { fontSize: '13px', gap: '6px' } }, hidden, 'Прихована'),
            h('div', { class: 'grow' }),
            h('button', { class: 'btn text', onClick: () => openForm(ex, (d) => save(d, false)) }, icon('edit'), 'Редагувати'),
            h('button', { class: 'btn text', style: { color: '#C62828' }, onClick: async () => {
              if (!await confirmDialog('Видалити вправу?', `Видалити «${ex.title}»? Історія виконань студентів залишиться.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
              try { await deleteDoc(doc(db, EXERCISES, ex.id)); toast('Видалено', 'ok'); reload(); } catch (e) { toast(`Помилка: ${e.message}`, 'err'); }
            } }, icon('delete'), 'Видалити'))));
      });
    };
    reload();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Дихальні вправи', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, body),
      h('button', { class: 'fab', title: 'Нова вправа', onClick: () => openForm(null, (d) => save({ ...d, sortOrder: items.length }, true)) }, icon('add')));
  });
}

// ── Форма вправи ────────────────────────────────────────────────────────────
function openForm(existing, onSave) {
  pushScreen(({ pop }) => {
    const e = existing ? clone(existing) : {};
    const blocks = e.blocks?.length ? e.blocks : [newCycle()];
    const field = (label, el) => h('label', { class: 'field' }, h('span', {}, label), el);
    const select = (map, value) => h('select', {}, Object.entries(map).map(([v, l]) => h('option', { value: v, selected: v === value }, l)));
    const title = h('input', { type: 'text', value: e.title ?? '', placeholder: 'Напр. Вправа 1: цикл 4-2-8 і видих на «с-с-с»' });
    const desc = h('textarea', { value: e.description ?? '', placeholder: 'Для чого вправа, як виконувати' });
    const category = select(CATEGORIES, e.category ?? 'diaphragm');
    const level = select(LEVELS, e.level ?? 'beginner');
    const hidden = h('input', { type: 'checkbox', checked: !!e.hidden });
    const estimate = h('div', { class: 's', style: { fontWeight: 600, margin: '8px 0' } });
    const blocksBox = h('div');

    const updateEstimate = () => { estimate.textContent = `Орієнтовна тривалість: ~${fmtDuration(estimateSeconds({ blocks }))}`; };
    // поле, прив'язане до властивості об'єкта; числа — як числа
    const bind = (obj, key, attrs = {}, isNum = false) => {
      const el = h('input', { type: isNum ? 'number' : 'text', min: isNum ? 0 : null, step: isNum ? 'any' : null, value: obj[key] ?? '', ...attrs });
      el.addEventListener('input', () => { obj[key] = isNum ? num(el.value) : el.value; updateEstimate(); });
      return el;
    };
    const two = (...els) => h('div', { style: { display: 'grid', gridTemplateColumns: `repeat(${els.length}, 1fr)`, gap: '8px' } }, els);
    const small = (ic, title, onClick, disabled = false) => h('button', { class: 'iconbtn dim', title, disabled, onClick }, icon(ic));

    const drawBlocks = () => {
      clear(blocksBox);
      blocks.forEach((b, bi) => {
        const kind = select({ cycle: 'Цикл (фази за таймером)', endurance: 'Витривалість видиху (студент засікає сам)' }, b.kind);
        kind.addEventListener('change', () => { blocks[bi] = { ...(kind.value === 'cycle' ? newCycle() : newEndurance()), label: b.label }; drawBlocks(); });
        const phases = h('div');
        if (b.kind === 'endurance') {
          const p = b.phases[0] || (b.phases[0] = { type: 'exhale', targetMinSeconds: 15, targetMaxSeconds: 20 });
          phases.append(two(field('Ціль від, с', bind(p, 'targetMinSeconds', {}, true)), field('до, с', bind(p, 'targetMaxSeconds', {}, true))),
            two(field('Підпис фази', bind(p, 'label')), field('Звук на видиху', bind(p, 'sound', { placeholder: 'напр. с', maxLength: 3 }))));
        } else {
          b.phases.forEach((p, pi) => {
            const type = select(PHASE_TYPES, p.type);
            type.addEventListener('change', () => { p.type = type.value; drawBlocks(); });
            phases.append(h('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(96px, 1fr))', gap: '6px', alignItems: 'end', marginBottom: '6px', paddingBottom: '6px', borderBottom: '1px dashed #ddd' } },
              field('Фаза', type), field('Секунд', bind(p, 'seconds', {}, true)), field('Підпис', bind(p, 'label')),
              field('Звук', bind(p, 'sound', { maxLength: 3, disabled: p.type !== 'exhale' })),
              small('close', 'Видалити фазу', () => { b.phases.splice(pi, 1); drawBlocks(); }, b.phases.length < 2)));
          });
          phases.append(h('button', { class: 'btn text', onClick: () => { b.phases.push({ type: 'exhale', seconds: 4, label: 'Видих' }); drawBlocks(); } }, icon('add'), 'Додати фазу'));
        }
        blocksBox.append(h('div', { class: 'tile', style: { display: 'block', border: '1px solid var(--gold)' } },
          h('div', { style: { display: 'flex', alignItems: 'center', gap: '4px' } },
            h('b', { class: 'grow' }, `Блок ${bi + 1}`),
            small('arrow_upward', 'Вище', () => { [blocks[bi - 1], blocks[bi]] = [blocks[bi], blocks[bi - 1]]; drawBlocks(); }, bi === 0),
            small('arrow_downward', 'Нижче', () => { [blocks[bi + 1], blocks[bi]] = [blocks[bi], blocks[bi + 1]]; drawBlocks(); }, bi === blocks.length - 1),
            small('delete', 'Видалити блок', () => { blocks.splice(bi, 1); drawBlocks(); }, blocks.length < 2)),
          field('Назва блоку', bind(b, 'label')),
          field('Тип', kind),
          two(field('Повторів', bind(b, 'repeats', { min: 1 }, true)), field('Пауза між повторами, с', bind(b, 'restBetweenReps', {}, true))),
          phases));
      });
      updateEstimate();
    };

    const validate = () => {
      if (!title.value.trim()) return 'Введіть назву вправи';
      for (const [i, b] of blocks.entries()) {
        const n = `Блок ${i + 1}: `;
        if (num(b.repeats) < 1) return `${n}кількість повторів — щонайменше 1`;
        if (b.kind === 'endurance') {
          const p = b.phases[0];
          if (!(num(p.targetMinSeconds) > 0) || num(p.targetMaxSeconds) < num(p.targetMinSeconds)) return `${n}ціль має бути додатною, «до» ≥ «від»`;
        } else if (!b.phases.length || b.phases.some((p) => !(num(p.seconds) > 0))) return `${n}кожна фаза має тривати більше 0 с`;
      }
      return null;
    };

    const saveBtn = h('button', { class: 'btn block', style: { padding: '14px', marginTop: '12px' }, onClick: async () => {
      const err = validate();
      if (err) { toast(err, 'err'); return; }
      const clean = blocks.map((b) => ({
        label: (b.label || '').trim(), kind: b.kind, repeats: Math.max(1, Math.round(num(b.repeats))), restBetweenReps: num(b.restBetweenReps),
        phases: b.kind === 'endurance'
          ? [{ type: 'exhale', targetMinSeconds: num(b.phases[0].targetMinSeconds), targetMaxSeconds: num(b.phases[0].targetMaxSeconds), label: (b.phases[0].label || '').trim(), ...(b.phases[0].sound ? { sound: b.phases[0].sound.trim() } : {}) }]
          : b.phases.map((p) => ({ type: p.type, seconds: num(p.seconds), label: (p.label || '').trim(), ...(p.type === 'exhale' && p.sound ? { sound: p.sound.trim() } : {}) })),
      }));
      const data = {
        id: existing?.id ?? `breath_${Date.now()}`,
        title: title.value.trim(), description: desc.value.trim(), category: category.value, level: level.value,
        hidden: hidden.checked, blocks: clean,
        ...(existing ? {} : { createdAt: serverTimestamp(), createdBy: (auth.currentUser?.email || '').toLowerCase() }),
      };
      saveBtn.disabled = true;
      try { if (await onSave(data)) pop(); } finally { saveBtn.disabled = false; }
    } }, existing ? 'Зберегти зміни' : 'Створити вправу');

    drawBlocks();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(existing ? 'Редагування вправи' : 'Нова вправа', { back: pop, cls: 'brown' }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner', style: { maxWidth: '760px' } },
        h('div', { class: 'form-section' }, 'Основне'),
        field('Назва *', title), field('Опис', desc),
        two(field('Категорія', category), field('Рівень', level)),
        h('label', { class: 'dk-row', style: { fontSize: '14px', gap: '6px', marginBottom: '8px' } }, hidden, 'Прихована (студенти не бачать)'),
        h('div', { class: 'form-section' }, 'Блоки'),
        blocksBox,
        h('div', { style: { display: 'flex', gap: '8px', flexWrap: 'wrap' } },
          h('button', { class: 'btn text', onClick: () => { blocks.push(newCycle()); drawBlocks(); } }, icon('add'), 'Блок «Цикл»'),
          h('button', { class: 'btn text', onClick: () => { blocks.push(newEndurance()); drawBlocks(); } }, icon('add'), 'Блок «Витривалість»')),
        estimate,
        saveBtn)));
  });
}

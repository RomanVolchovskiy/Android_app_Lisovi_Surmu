// Адмін: коди доступу та налаштування (домени, пробний період, адміністратори)
// — дзеркало AdminAccessScreen у додатку.
import { h, icon, toast, pushScreen, appBar, confirmDialog, openDialog, clear } from '../ui.js';
import {
  getConfig, loadConfig, saveConfig, currentUser, subscribeCodes, createCode, setCodeActive, deleteCode,
  generateCode, normalizeCode, codeUsable, codeExhausted, codeExpired, fmtDate, AccessError,
} from '../access.js';

const errText = (e) => (e instanceof AccessError ? e.message : `Помилка: ${e?.message || e}`);

export function openAdminAccess() {
  pushScreen((ctx) => {
    let cfg = { ...getConfig() };
    let codes = null;
    let showSettings = false;
    const settingsBox = h('div');
    const summary = h('div');
    const list = h('div');

    // ── Налаштування ──
    const renderSettings = () => {
      clear(settingsBox);
      if (!showSettings) return;
      const me = (currentUser()?.email || '').toLowerCase();
      const chip = (label, onDelete) => h('span', { class: 'chip' }, label,
        onDelete ? h('button', { class: 'mi', style: { fontSize: '16px', marginLeft: '4px' }, title: 'Прибрати', onClick: onDelete }, 'close') : null);
      const domainInput = h('input', { type: 'text', placeholder: 'новий домен, напр. college.edu.ua' });
      const adminInput = h('input', { type: 'email', placeholder: 'пошта адміністратора' });
      const trialInput = h('input', { type: 'number', min: 1, value: cfg.trialDays, style: { width: '120px' } });
      const addDomain = () => {
        let d = domainInput.value.trim().toLowerCase().replace(/^@/, '');
        if (!d.includes('.')) { toast('Введіть домен, напр. forestcollege.ukr.education', 'err'); return; }
        if (!cfg.corporateDomains.includes(d)) cfg.corporateDomains = [...cfg.corporateDomains, d];
        renderSettings();
      };
      const addAdmin = () => {
        const e = adminInput.value.trim().toLowerCase();
        if (!e.includes('@')) { toast('Введіть пошту адміністратора', 'err'); return; }
        if (!cfg.adminEmails.includes(e)) cfg.adminEmails = [...cfg.adminEmails, e];
        renderSettings();
      };
      domainInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') addDomain(); });
      adminInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') addAdmin(); });
      settingsBox.append(h('div', { class: 'tile', style: { display: 'block' } },
        h('div', { class: 'sec-title', style: { marginTop: 0 } }, 'Налаштування доступу'),
        h('div', { class: 't', style: { fontSize: '13px' } }, 'Корпоративні домени (безкоштовно)'),
        h('div', { class: 'chips-inline' }, cfg.corporateDomains.map((d) => chip(`@${d}`,
          cfg.corporateDomains.length > 1 ? () => { cfg.corporateDomains = cfg.corporateDomains.filter((x) => x !== d); renderSettings(); } : null))),
        h('div', { class: 'field with-btn' }, domainInput, h('button', { class: 'iconbtn', onClick: addDomain }, icon('add_circle'))),
        h('div', { class: 't', style: { fontSize: '13px' } }, 'Пробний період, днів'),
        h('div', { class: 'field' }, trialInput),
        h('div', { class: 't', style: { fontSize: '13px' } }, 'Адміністратори (можуть створювати коди)'),
        h('div', { class: 'chips-inline' }, cfg.adminEmails.map((e) => chip(e,
          e === me ? null : () => { cfg.adminEmails = cfg.adminEmails.filter((x) => x !== e); renderSettings(); }))),
        h('div', { class: 'field with-btn' }, adminInput, h('button', { class: 'iconbtn', onClick: addAdmin }, icon('add_circle'))),
        h('div', { class: 'row', style: { display: 'flex', justifyContent: 'flex-end' } },
          h('button', { class: 'btn', onClick: async () => {
            const days = parseInt(trialInput.value, 10);
            if (!(days >= 1)) { toast('Пробний період — ціле число днів (мінімум 1)', 'err'); return; }
            // той, хто зберігає, завжди лишається адміністратором
            const admins = [...new Set([...cfg.adminEmails, me].filter(Boolean))];
            try {
              await saveConfig({ ...cfg, trialDays: days, adminEmails: admins });
              cfg = { ...getConfig() }; renderSettings(); renderSummary();
              toast('Налаштування збережено', 'ok');
            } catch (e) { toast(`Не вдалося зберегти: ${e.message}`, 'err'); }
          } }, icon('save'), 'Зберегти налаштування'))));
    };

    const renderSummary = () => {
      const all = codes || [];
      const active = all.filter(codeUsable).length;
      const used = all.reduce((s, c) => s + c.usedCount, 0);
      summary.replaceChildren(h('div', { class: 'tile', style: { background: '#FFF3E0', color: '#E65100', fontSize: '12.5px', lineHeight: 1.35 } },
        icon('info'),
        h('div', { class: 'grow' },
          `Корпоративні домени: ${cfg.corporateDomains.map((d) => `@${d}`).join(', ')} — безкоштовно. `,
          h('br'), `Пробний період: ${cfg.trialDays} дн. Кодів: ${all.length}, робочих: ${active}, активацій: ${used}.`)));
    };

    // ── Список кодів ──
    const codeTile = (c) => {
      const [label, color] = !c.active ? ['Деактивовано', 'var(--grey-600)']
        : codeExpired(c) ? ['Термін минув', '#C62828']
          : codeExhausted(c) ? ['Використано', '#EF6C00'] : ['Діє', 'var(--primary-light)'];
      const uses = c.maxUses === 0 ? `${c.usedCount}/∞` : `${c.usedCount}/${c.maxUses}`;
      const parts = [
        c.note, `Активацій: ${uses}`, `Доступ ${c.durationDays == null ? 'назавжди' : `на ${c.durationDays} дн.`}`,
        c.expiresAt ? `Дійсний до ${fmtDate(c.expiresAt)}` : null,
        c.usedByEmails.length ? `Використали: ${c.usedByEmails.join(', ')}` : null,
      ].filter(Boolean);
      return h('div', { class: 'tile' },
        h('span', { class: 'mi', style: { color, fontSize: '28px' } }, 'vpn_key'),
        h('div', { class: 'grow' },
          h('div', {}, h('span', { class: 'mono' }, c.code), h('span', { class: 'badge', style: { background: `color-mix(in srgb, ${color} 15%, white)`, color } }, label)),
          h('div', { class: 's' }, parts.join(' · '))),
        h('button', { class: 'iconbtn dim', title: 'Копіювати', onClick: () => { navigator.clipboard?.writeText(c.code); toast(`Скопійовано: ${c.code}`); } }, icon('content_copy')),
        h('button', { class: 'iconbtn dim', title: c.active ? 'Деактивувати' : 'Активувати', onClick: async () => {
          try { await setCodeActive(c.code, !c.active); } catch (e) { toast(errText(e), 'err'); }
        } }, icon(c.active ? 'pause_circle' : 'play_circle')),
        h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: async () => {
          if (await confirmDialog('Видалити код?', `Код ${c.code} буде видалено. Ті, хто вже активував його, доступ не втратять.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) {
            try { await deleteCode(c.code); toast('Код видалено', 'ok'); } catch (e) { toast(errText(e), 'err'); }
          }
        } }, icon('delete')));
    };
    const renderList = () => {
      clear(list);
      if (codes === null) { list.append(h('div', { class: 'center', style: { padding: '32px' } }, h('div', { class: 'spinner' }))); return; }
      if (!codes.length) { list.append(h('div', { class: 'empty' }, icon('vpn_key_off'), h('div', { class: 't' }, 'Кодів ще немає'))); return; }
      list.append(...codes.map(codeTile));
    };

    renderSettings(); renderSummary(); renderList();
    loadConfig(true).then(() => { cfg = { ...getConfig() }; renderSettings(); renderSummary(); });
    const off = subscribeCodes((rows) => { codes = rows; renderSummary(); renderList(); },
      (e) => { clear(list).append(h('div', { class: 'empty' }, `Не вдалося завантажити коди: ${e.message}`)); });
    ctx.onPop = off;

    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Коди доступу', { back: ctx.pop, cls: 'brown', actions: [
        h('button', { class: 'iconbtn', title: 'Налаштування доступу', onClick: () => { showSettings = !showSettings; renderSettings(); } }, icon('settings')),
      ] }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner', style: { paddingBottom: '96px' } }, settingsBox, summary, list)),
      h('button', { class: 'fab', title: 'Створити код', onClick: () => createDialog() }, icon('add')));
  });
}

function createDialog() {
  const code = h('input', { type: 'text', class: 'code-input', value: generateCode(), autocomplete: 'off', spellcheck: false });
  const note = h('input', { type: 'text', placeholder: 'кому / для чого' });
  const maxUses = h('input', { type: 'number', min: 1, value: 1 });
  const unlimited = h('input', { type: 'checkbox' });
  const duration = h('input', { type: 'number', min: 1, placeholder: 'днів', disabled: true });
  const forever = h('input', { type: 'checkbox', checked: true });
  const expires = h('input', { type: 'date', min: new Date().toISOString().slice(0, 10) });
  unlimited.addEventListener('change', () => { maxUses.disabled = unlimited.checked; });
  forever.addEventListener('change', () => { duration.disabled = forever.checked; });
  const err = h('div', { class: 'err', hidden: true });
  const fail = (m) => { err.textContent = m; err.hidden = false; };
  const d = openDialog([
    h('h3', {}, 'Новий код доступу'),
    h('label', { class: 'field with-btn' }, h('span', {}, 'Код'), code,
      h('button', { class: 'iconbtn', title: 'Згенерувати', onClick: () => { code.value = generateCode(); } }, icon('casino'))),
    h('label', { class: 'field' }, h('span', {}, 'Примітка'), note),
    h('label', { class: 'field' }, h('span', {}, 'Кількість активацій'), maxUses),
    h('label', { class: 'dk-row', style: { marginTop: '-8px', marginBottom: '12px', fontSize: '13px' } }, unlimited, ' Без ліміту активацій'),
    h('label', { class: 'field' }, h('span', {}, 'Доступ на … днів'), duration),
    h('label', { class: 'dk-row', style: { marginTop: '-8px', marginBottom: '12px', fontSize: '13px' } }, forever, ' Назавжди'),
    h('label', { class: 'field' }, h('span', {}, 'Активувати можна до (необов’язково)'), expires),
    err,
    h('div', { class: 'row' },
      h('button', { class: 'btn text', onClick: () => d.close() }, 'Скасувати'),
      h('button', { class: 'btn', onClick: async () => {
        const c = normalizeCode(code.value);
        if (c.length < 4) { fail('Код — мінімум 4 символи'); return; }
        const uses = unlimited.checked ? 0 : parseInt(maxUses.value, 10);
        if (!unlimited.checked && !(uses >= 1)) { fail('Кількість активацій — ціле число ≥ 1'); return; }
        let days = null;
        if (!forever.checked) { days = parseInt(duration.value, 10); if (!(days >= 1)) { fail('Тривалість доступу — ціле число днів ≥ 1'); return; } }
        const exp = expires.value ? new Date(`${expires.value}T23:59:59`) : null;
        try {
          await createCode({ code: c, note: note.value.trim(), maxUses: uses, durationDays: days, expiresAt: exp });
          d.close(); toast(`Код ${c} створено`, 'ok');
        } catch (e) { fail(errText(e)); }
      } }, 'Створити')),
  ]);
  setTimeout(() => note.focus(), 50);
}

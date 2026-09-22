// Дрібні помічники для побудови DOM, іконки, тости, діалоги, повноекранні
// «екрани» поверх основного каркаса (аналог Navigator.push).

export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'html') el.innerHTML = v;
    else if (k in el && typeof v !== 'string') el[k] = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat(Infinity)) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

export const icon = (name, cls = '') => h('span', { class: `mi ${cls}`.trim() }, name);

export function clear(el) { while (el.firstChild) el.removeChild(el.firstChild); return el; }

// ── Тост (SnackBar) ──────────────────────────────────────────────────────────
export function toast(text, kind = '', ms = 2500) {
  const root = document.getElementById('toast-root');
  const t = h('div', { class: `toast ${kind}` }, text);
  root.append(t);
  setTimeout(() => t.remove(), ms);
}

// ── Діалоги ──────────────────────────────────────────────────────────────────
export function openDialog(content, { dark = false, dismissible = true } = {}) {
  const root = document.getElementById('overlay-root');
  const box = h('div', { class: `dialog ${dark ? 'dark' : ''}` }, content);
  const ov = h('div', { class: 'overlay' }, box);
  if (dismissible) ov.addEventListener('click', (e) => { if (e.target === ov) ov.remove(); });
  root.append(ov);
  return { close: () => ov.remove(), el: box };
}

export function confirmDialog(title, text, { okLabel = 'Так', cancelLabel = 'Ні', danger = false } = {}) {
  return new Promise((res) => {
    const d = openDialog([
      h('h3', {}, title),
      h('div', { class: 'sec-text' }, text),
      h('div', { class: 'row' },
        h('button', { class: 'btn text', onClick: () => { d.close(); res(false); } }, cancelLabel),
        h('button', { class: `btn ${danger ? 'danger' : ''}`, onClick: () => { d.close(); res(true); } }, okLabel)),
    ]);
  });
}

export function promptDialog(title, { label = '', placeholder = '', value = '', okLabel = 'Зберегти', password = false, validate } = {}) {
  return new Promise((res) => {
    const err = h('div', { class: 'err', hidden: true });
    const input = h('input', { type: password ? 'password' : 'text', placeholder, value });
    const submit = () => {
      const v = input.value.trim();
      const msg = validate ? validate(v) : null;
      if (msg) { err.textContent = msg; err.hidden = false; return; }
      d.close(); res(v);
    };
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
    const d = openDialog([
      h('h3', {}, title),
      h('label', { class: 'field' }, label ? h('span', {}, label) : null, input),
      err,
      h('div', { class: 'row' },
        h('button', { class: 'btn text', onClick: () => { d.close(); res(null); } }, 'Скасувати'),
        h('button', { class: 'btn', onClick: submit }, okLabel)),
    ]);
    setTimeout(() => input.focus(), 50);
  });
}

// ── Повноекранні екрани (стек, як Navigator) ────────────────────────────────
const stack = [];
export function pushScreen(build) {
  const el = h('div', { class: 'screen' });
  const ctx = { el, pop: () => popScreen(el), onPop: null };
  const built = build(ctx);
  if (built instanceof Promise) built.then((n) => el.append(n)); else el.append(built);
  document.body.append(el);
  stack.push({ el, ctx });
  history.pushState({ screen: stack.length }, '');
  return ctx;
}
export function popScreen(el) {
  const i = el ? stack.findIndex((s) => s.el === el) : stack.length - 1;
  if (i < 0) return;
  const [{ el: e, ctx }] = stack.splice(i, 1);
  ctx.onPop?.();
  e.remove();
}
/** Закриває всі повноекранні екрани (вихід з акаунта, втрата доступу). */
export function closeAllScreens() {
  while (stack.length) { const { el: e, ctx } = stack.pop(); ctx.onPop?.(); e.remove(); }
}
window.addEventListener('popstate', () => {
  // кнопка «назад» браузера закриває верхній екран
  if (stack.length) { const { el: e, ctx } = stack.pop(); ctx.onPop?.(); e.remove(); }
});

export function appBar(title, { back = null, actions = [], cls = '', small = false } = {}) {
  return h('div', { class: `appbar ${cls}` },
    back ? h('div', { class: 'lead' }, h('button', { class: 'iconbtn', onClick: back, title: 'Назад' }, icon('arrow_back'))) : null,
    h('div', { class: `title ${small ? 'sm' : ''}` }, title),
    actions.length ? h('div', { class: 'actions' }, actions) : null);
}

export function spinner(light = false) { return h('div', { class: 'center' }, h('div', { class: `spinner ${light ? 'light' : ''}` })); }

export function emptyState(iconName, title, subtitle) {
  return h('div', { class: 'empty' }, icon(iconName), h('div', { class: 't' }, title), subtitle ? h('div', { class: 's' }, subtitle) : null);
}

export function difficultyBadge(d) {
  const map = { easy: '🟢 Легкий', medium: '🟡 Середній', hard: '🔴 Важкий' };
  return d && map[d] ? h('span', { class: `difficulty ${d}` }, map[d]) : null;
}

export function pickFiles({ accept = '', multiple = false } = {}) {
  return new Promise((res) => {
    const input = h('input', { type: 'file', accept, multiple, style: { display: 'none' } });
    input.addEventListener('change', () => { res([...input.files]); input.remove(); });
    document.body.append(input);
    input.click();
  });
}

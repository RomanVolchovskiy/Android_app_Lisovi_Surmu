// Точка входу: вхід і перевірка доступу (AccessGate у додатку), далі каркас
// і перемикання вкладок за хешем (#/signals, …).
import { createShell } from './views/shell.js';
import { renderSignals } from './views/signals.js';
import { renderFavorites } from './views/favorites.js';
import { renderEducation } from './views/education.js';
import { renderEvents } from './views/events.js';
import { renderAuth, renderVerify, renderExpired, renderGateError } from './views/access.js';
import { waitForSignals } from './data.js';
import { onAuthChange, resolve, onStatus, getStatus, allowed, loadConfig, AccessError } from './access.js';
import { h, closeAllScreens } from './ui.js';

const TAB_VIEWS = {
  signals: (c) => renderSignals(c),
  education: (c) => renderEducation(c),
  events: (c) => renderEvents(c),
  favorites: (c) => renderFavorites(c, { onGoToSignals: () => go('signals') }),
};

let cleanup = null;
const shell = createShell({ onTab: go });
const app = document.getElementById('app');

function go(tab) {
  if (location.hash !== `#/${tab}`) { location.hash = `#/${tab}`; return; }
  show(tab);
}

function show(tab) {
  if (!TAB_VIEWS[tab]) tab = 'signals';
  cleanup?.();
  const container = shell.setTab(tab);
  cleanup = TAB_VIEWS[tab](container) || null;
}

window.addEventListener('hashchange', () => { if (inShell) show(location.hash.replace(/^#\//, '')); });

const spinner = (text) => h('div', { class: 'boot' }, h('div', { style: { textAlign: 'center' } },
  h('div', { class: 'spinner', style: { margin: '0 auto 12px' } }), text ? h('div', { style: { color: 'var(--grey-600)' } }, text) : null));

// ── Ворота доступу ───────────────────────────────────────────────────────────
let inShell = false;
let resolvingFor = null; // uid, для якого вже запущено перевірку

function leaveShell() {
  if (inShell) { cleanup?.(); cleanup = null; inShell = false; }
  closeAllScreens();
}

async function enterShell() {
  if (inShell) return;
  inShell = true;
  app.replaceChildren(spinner());
  try {
    await Promise.race([waitForSignals(), new Promise((r) => setTimeout(r, 6000))]);
  } catch (e) { console.error(e); }
  if (!inShell) return; // встигли вийти
  app.replaceChildren(shell.el);
  show(location.hash.replace(/^#\//, '') || 'signals');
}

function checkAccess(user) {
  if (resolvingFor === user.uid && getStatus()) return;
  resolvingFor = user.uid;
  app.replaceChildren(spinner('Перевірка доступу…'));
  resolve().catch((e) => {
    resolvingFor = null;
    app.replaceChildren(renderGateError(e instanceof AccessError ? e.message : `Помилка перевірки доступу: ${e?.message || e}`,
      () => checkAccess(user)));
  });
}

// стан доступу змінився (перевірка, активація коду) — показуємо потрібний екран
onStatus((s) => {
  if (!s) return;
  if (allowed(s)) enterShell();
  else { leaveShell(); app.replaceChildren(renderExpired(s)); }
});

loadConfig();
onAuthChange((user) => {
  if (!user) {
    resolvingFor = null;
    leaveShell();
    app.replaceChildren(renderAuth());
    return;
  }
  if (!user.emailVerified) {
    leaveShell();
    app.replaceChildren(renderVerify(user, () => checkAccess(user)));
    return;
  }
  checkAccess(user);
});

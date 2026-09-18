// Точка входу: будує каркас, перемикає вкладки за хешем (#/signals, …).
import { createShell } from './views/shell.js';
import { renderSignals } from './views/signals.js';
import { renderFavorites } from './views/favorites.js';
import { renderEducation } from './views/education.js';
import { renderEvents } from './views/events.js';
import { waitForSignals } from './data.js';
import { h } from './ui.js';

const TAB_VIEWS = {
  signals: (c) => renderSignals(c),
  education: (c) => renderEducation(c),
  events: (c) => renderEvents(c),
  favorites: (c) => renderFavorites(c, { onGoToSignals: () => go('signals') }),
};

let cleanup = null;
const shell = createShell({ onTab: go });

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

window.addEventListener('hashchange', () => show(location.hash.replace(/^#\//, '')));

async function boot() {
  const app = document.getElementById('app');
  try {
    await Promise.race([waitForSignals(), new Promise((r) => setTimeout(r, 6000))]);
  } catch (e) { console.error(e); }
  app.replaceChildren(shell.el);
  show(location.hash.replace(/^#\//, '') || 'signals');
}
boot().catch((e) => {
  document.getElementById('app').replaceChildren(h('div', { class: 'empty' }, `Помилка запуску: ${e.message}`));
});

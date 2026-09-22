// Каркас (MainNavigation): app bar із заголовком вкладки, банер, вміст,
// нижня навігація з чотирма вкладками.
import { h, icon, clear } from '../ui.js';
import { audio } from '../audio.js';
import { openAdmin } from './admin.js';
import { openAccount, accessBanner } from './access.js';
import { getSignals } from '../data.js';

const TABS = [
  { id: 'signals', title: 'Мисливські Сигнали', label: 'Сигнали', icon: 'surround_sound' },
  { id: 'education', title: 'Навчальні Матеріали', label: 'Навчання', icon: 'school' },
  { id: 'events', title: 'Мисливські події', label: 'Події', icon: 'event' },
  { id: 'favorites', title: 'Обрані Сигнали', label: 'Обране', icon: 'favorite' },
];

export function createShell({ onTab }) {
  const title = h('div', { class: 'title' }, TABS[0].title);
  const content = h('div', { class: 'content' });
  const inner = h('div', { class: 'content-inner' });
  content.append(inner);

  const navButtons = TABS.map((t) => h('button', { onClick: () => onTab(t.id), 'data-tab': t.id }, icon(t.icon), h('span', {}, t.label)));

  // міні-плеєр: показує, що зараз грає, і дає зупинити з будь-якої вкладки
  const npTitle = h('div', { class: 'grow' });
  const npBtn = h('button', { class: 'iconbtn', onClick: () => audio.pause() }, icon('pause'));
  const mini = h('div', { class: 'mini-player', hidden: true },
    icon('graphic_eq'), npTitle, npBtn,
    h('button', { class: 'iconbtn', onClick: () => audio.stop() }, icon('close')));
  audio.subscribe(({ currentId, playing }) => {
    mini.hidden = !playing;
    if (playing) {
      const s = getSignals().find((x) => x.audioUrl === currentId || x.notationAudioUrl === currentId);
      npTitle.textContent = s ? `Відтворення: ${s.name}` : 'Відтворення';
    }
  });

  const root = h('div', { class: 'shell' },
    h('div', { class: 'appbar' },
      title,
      h('div', { class: 'actions' },
        h('button', { class: 'iconbtn', title: 'Мій акаунт', onClick: () => openAccount() }, icon('account_circle')),
        h('button', { class: 'iconbtn', title: 'Адміністратор', onClick: () => openAdmin() }, icon('admin_panel_settings')))),
    h('div', { class: 'banner' },
      h('img', { class: 'bg', src: 'assets/banner.jpg', alt: '' }),
      h('img', { class: 'logo', src: 'assets/icon.png', alt: 'Лісові сурми' })),
    accessBanner(),
    mini,
    content,
    h('nav', { class: 'bottomnav' }, navButtons));

  return {
    el: root,
    setTab(id) {
      const t = TABS.find((x) => x.id === id) || TABS[0];
      title.textContent = t.title;
      navButtons.forEach((b) => b.classList.toggle('active', b.dataset.tab === t.id));
      content.scrollTop = 0;
      return clear(inner);
    },
  };
}

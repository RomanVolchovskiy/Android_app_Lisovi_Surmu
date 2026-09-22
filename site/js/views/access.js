// Екрани доступу: вхід/реєстрація, підтвердження пошти, «пробний період
// завершився», акаунт, діалог коду, смужка-нагадування. Логіка — access.js.
import { h, icon, toast, openDialog, pushScreen, appBar, confirmDialog } from '../ui.js';
import {
  getConfig, loadConfig, currentUser, signIn, register, resendVerification, reloadVerified, resetPassword, logout,
  getStatus, onStatus, resolve, redeemCode, normalizeCode, allowed, daysLeft, fmtDate, AccessError,
} from '../access.js';

const errText = (e) => (e instanceof AccessError ? e.message : `Помилка: ${e?.message || e}`);

function authFrame(...children) {
  return h('div', { class: 'auth-page' },
    h('div', { class: 'auth-card' },
      h('img', { class: 'logo', src: 'assets/icon.png', alt: '' }),
      h('h1', {}, 'Лісові Сурми'),
      h('div', { class: 'sub' }, 'Мисливські сигнали'),
      ...children));
}

function hints() {
  const cfg = getConfig();
  const domains = cfg.corporateDomains.map((d) => `@${d}`).join(', ');
  return h('div', { class: 'auth-hints' },
    h('div', {}, icon('school'), h('span', {}, `Корпоративна пошта коледжу (${domains}) — безкоштовно й без обмежень.`)),
    h('div', {}, icon('timer'), h('span', {}, `Інші користувачі — безкоштовно ${cfg.trialDays} днів після реєстрації.`)),
    h('div', {}, icon('vpn_key'), h('span', {}, 'Код доступу від адміністратора відкриває сайт після пробного періоду.')));
}

// ── Вхід / реєстрація ────────────────────────────────────────────────────────
export function renderAuth() {
  let registerMode = false, busy = false;
  const email = h('input', { type: 'email', placeholder: 'name@example.com', autocomplete: 'email', autocapitalize: 'off' });
  const pwd = h('input', { type: 'password', placeholder: 'Пароль', autocomplete: 'current-password' });
  const eye = h('button', { class: 'iconbtn', type: 'button', title: 'Показати пароль',
    onClick: () => { pwd.type = pwd.type === 'password' ? 'text' : 'password'; eye.firstChild.textContent = pwd.type === 'password' ? 'visibility_off' : 'visibility'; } },
    icon('visibility_off'));
  const err = h('div', { class: 'err', hidden: true });
  const title = h('h3', {}, 'Вхід');
  const submitBtn = h('button', { class: 'btn block', type: 'submit' }, 'Увійти');
  const toggleBtn = h('button', { class: 'btn text block', type: 'button' }, 'Немає акаунта? Зареєструватися');
  const forgotBtn = h('button', { class: 'btn text block', type: 'button' }, 'Забули пароль?');
  const hintsEl = hints();

  const setBusy = (v) => { busy = v; submitBtn.disabled = toggleBtn.disabled = forgotBtn.disabled = v; submitBtn.textContent = v ? '…' : (registerMode ? 'Зареєструватися' : 'Увійти'); };
  const showErr = (m) => { err.textContent = m; err.hidden = !m; };

  toggleBtn.addEventListener('click', () => {
    registerMode = !registerMode; showErr('');
    title.textContent = registerMode ? 'Реєстрація' : 'Вхід';
    submitBtn.textContent = registerMode ? 'Зареєструватися' : 'Увійти';
    toggleBtn.textContent = registerMode ? 'Уже є акаунт? Увійти' : 'Немає акаунта? Зареєструватися';
    forgotBtn.hidden = registerMode;
    pwd.autocomplete = registerMode ? 'new-password' : 'current-password';
  });
  forgotBtn.addEventListener('click', async () => {
    const e = email.value.trim();
    if (!e.includes('@')) { showErr('Введіть пошту, щоб скинути пароль'); return; }
    setBusy(true);
    try { await resetPassword(e); toast(`Лист для зміни пароля надіслано на ${e}`, 'ok'); showErr(''); }
    catch (ex) { showErr(errText(ex)); }
    finally { setBusy(false); }
  });

  const form = h('form', { class: 'auth-box', onSubmit: async (ev) => {
    ev.preventDefault();
    if (busy) return;
    const e = email.value.trim(), p = pwd.value;
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) { showErr('Некоректна адреса пошти'); return; }
    if (!p) { showErr('Введіть пароль'); return; }
    if (registerMode && p.length < 6) { showErr('Пароль — мінімум 6 символів'); return; }
    setBusy(true); showErr('');
    try {
      if (registerMode) await register(e, p); else await signIn(e, p);
      // далі — onAuthChange у app.js
    } catch (ex) { showErr(errText(ex)); setBusy(false); }
  } },
    title,
    h('label', { class: 'field' }, h('span', {}, 'Електронна пошта'), email),
    h('label', { class: 'field with-btn' }, h('span', {}, 'Пароль'), pwd, eye),
    err,
    submitBtn, toggleBtn, forgotBtn);

  // домени/тривалість — з Firestore, підказка оновлюється після завантаження
  loadConfig().then(() => hintsEl.replaceWith(hints())).catch(() => {});
  setTimeout(() => email.focus(), 50);
  const download = h('a', { class: 'auth-download', href: 'downloads/LisoviSurmy_v1.1.0_arm64.apk', download: '' },
    icon('android'), h('span', {}, 'Завантажити додаток для Android'), h('small', {}, 'APK, 31 МБ · версія 1.1.0'));
  return authFrame(form, hintsEl, download);
}

// ── Підтвердження пошти ──────────────────────────────────────────────────────
export function renderVerify(user, onVerified) {
  const msg = h('div', { class: 'err', hidden: true });
  let timer = null, busy = false;
  const check = async (silent) => {
    if (!el.isConnected) { clearInterval(timer); return; } // екран замінили — зупиняємо опитування
    if (busy) return;
    busy = true;
    const ok = await reloadVerified();
    busy = false;
    if (ok) { clearInterval(timer); onVerified(); return; }
    if (!silent) { msg.textContent = 'Пошта ще не підтверджена. Відкрийте лист і натисніть посилання'; msg.hidden = false; }
  };
  timer = setInterval(() => check(true), 5000);
  const box = h('div', { class: 'auth-box', style: { textAlign: 'center' } },
    h('span', { class: 'mi', style: { fontSize: '64px', color: 'var(--primary)' } }, 'mark_email_unread'),
    h('h3', {}, 'Підтвердіть пошту'),
    h('div', { class: 'sec-text', style: { textAlign: 'center' } },
      `Ми надіслали лист на\n${user.email}\n\nВідкрийте його й натисніть посилання. Після цього сайт відкриється автоматично.`),
    h('div', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px', margin: '8px 0 12px' } }, 'Не бачите листа? Перевірте теку «Спам».'),
    msg,
    h('button', { class: 'btn block', onClick: () => check(false) }, icon('check_circle'), 'Я підтвердив(ла) пошту'),
    h('button', { class: 'btn text block', onClick: async () => {
      try { await resendVerification(); toast(`Лист надіслано ще раз на ${user.email}`, 'ok'); }
      catch (e) { toast(errText(e), 'err'); }
    } }, icon('refresh'), 'Надіслати лист ще раз'),
    h('button', { class: 'btn text block', onClick: () => { clearInterval(timer); logout(); } }, 'Увійти з іншою поштою'));
  const el = authFrame(box);
  return el;
}

// ── Доступ завершено ─────────────────────────────────────────────────────────
export function renderExpired(status) {
  const cfg = getConfig();
  const email = currentUser()?.email || '';
  const when = status.until ? ` закінчилися ${fmtDate(status.until)}` : ' вичерпано';
  const box = h('div', { class: 'auth-box', style: { textAlign: 'center' } },
    h('span', { class: 'mi', style: { fontSize: '64px', color: '#EF6C00' } }, 'hourglass_bottom'),
    h('h3', {}, 'Пробний період завершився'),
    h('div', { class: 'sec-text', style: { textAlign: 'center' } },
      `Безкоштовні ${cfg.trialDays} днів для ${email}${when}.\n\nЩоб продовжити, введіть код доступу від адміністратора.`),
    h('div', { style: { height: '12px' } }),
    h('button', { class: 'btn block', onClick: () => openCodeDialog() }, icon('vpn_key'), 'Ввести код доступу'),
    h('button', { class: 'btn text block', onClick: async () => {
      try { await resolve(); } catch (e) { toast(errText(e), 'err'); }
    } }, icon('refresh'), 'Перевірити ще раз'),
    h('button', { class: 'btn text block', onClick: () => logout() }, 'Вийти з акаунта'),
    status.fromCache ? h('div', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px', marginTop: '8px' } }, 'Немає з’єднання — статус узято з кешу.') : null);
  return authFrame(box);
}

export function renderGateError(message, onRetry) {
  return authFrame(h('div', { class: 'auth-box', style: { textAlign: 'center' } },
    h('span', { class: 'mi', style: { fontSize: '56px', color: '#C62828' } }, 'cloud_off'),
    h('div', { class: 'sec-text', style: { textAlign: 'center' } }, message),
    h('div', { style: { height: '12px' } }),
    h('button', { class: 'btn block', onClick: onRetry }, icon('refresh'), 'Спробувати ще раз'),
    h('button', { class: 'btn text block', onClick: () => logout() }, 'Вийти')));
}

// ── Діалог коду ──────────────────────────────────────────────────────────────
export function openCodeDialog() {
  return new Promise((res) => {
    const input = h('input', { type: 'text', class: 'code-input', placeholder: 'ABCD2345', autocapitalize: 'characters', autocomplete: 'off', spellcheck: false });
    const err = h('div', { class: 'err', hidden: true });
    const ok = h('button', { class: 'btn' }, 'Активувати');
    const submit = async () => {
      const code = normalizeCode(input.value);
      if (!code) { err.textContent = 'Введіть код'; err.hidden = false; return; }
      ok.disabled = true; err.hidden = true;
      try {
        const st = await redeemCode(code);
        d.close();
        toast(st.until ? `Код активовано — доступ на ${daysLeft(st)} дн.` : 'Код активовано — доступ без обмежень', 'ok');
        res(true);
      } catch (e) { err.textContent = errText(e); err.hidden = false; ok.disabled = false; }
    };
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
    ok.addEventListener('click', submit);
    const d = openDialog([
      h('h3', {}, icon('vpn_key'), ' Код доступу'),
      h('div', { class: 'sec-text' }, 'Введіть код, який вам надав адміністратор.'),
      h('label', { class: 'field', style: { marginTop: '12px' } }, input),
      err,
      h('div', { class: 'row' }, h('button', { class: 'btn text', onClick: () => { d.close(); res(false); } }, 'Скасувати'), ok),
    ]);
    setTimeout(() => input.focus(), 50);
  });
}

// ── Акаунт ───────────────────────────────────────────────────────────────────
function describe(s) {
  if (!s) return { ic: 'hourglass_empty', color: 'var(--grey-600)', t: 'Перевірка…', s: 'Стан доступу ще не визначено' };
  switch (s.kind) {
    case 'corporate': return { ic: 'verified', color: 'var(--primary-light)', t: 'Корпоративний доступ', s: 'Пошта коледжу — сайт безкоштовний без обмежень' };
    case 'code': return { ic: 'vpn_key', color: '#3949AB', t: 'Доступ за кодом', s: s.until ? `Діє до ${fmtDate(s.until)} (${daysLeft(s)} дн.)` : 'Без обмеження терміну' };
    case 'trial': return { ic: 'timer', color: '#EF6C00', t: 'Пробний період', s: `Залишилось ${daysLeft(s)} дн. — до ${fmtDate(s.until)}. Далі потрібен код доступу` };
    default: return { ic: 'block', color: '#C62828', t: 'Доступ завершено', s: 'Введіть код доступу від адміністратора' };
  }
}

export function openAccount() {
  pushScreen((ctx) => {
    const user = currentUser();
    const card = h('div');
    const render = () => {
      const s = getStatus(); const d = describe(s);
      card.replaceChildren(h('div', { class: 'status-card', style: { background: `color-mix(in srgb, ${d.color} 10%, white)` } },
        h('span', { class: 'mi', style: { color: d.color } }, d.ic),
        h('div', { class: 'grow' }, h('div', { class: 't', style: { color: d.color } }, d.t), h('div', { class: 's' }, d.s),
          s?.fromCache ? h('div', { class: 's', style: { color: 'var(--grey-600)', fontSize: '12px' } }, 'Без мережі — дані з кешу') : null)));
    };
    render();
    const off = onStatus(render);
    ctx.onPop = off;
    const s = getStatus();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Мій акаунт', { back: ctx.pop, small: true }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' },
        h('div', { class: 'tile' },
          h('div', { style: { width: '44px', height: '44px', borderRadius: '50%', background: 'var(--primary)', color: '#fff', display: 'grid', placeItems: 'center' } }, icon('person')),
          h('div', { class: 'grow' }, h('div', { class: 't' }, user?.email || '—'), h('div', { class: 's' }, user?.emailVerified ? 'Пошту підтверджено' : 'Пошту не підтверджено'))),
        card,
        s?.kind !== 'corporate' ? h('button', { class: 'btn block', style: { marginBottom: '8px' }, onClick: () => openCodeDialog() }, icon('vpn_key'), 'Ввести код доступу') : null,
        h('button', { class: 'btn text block', style: { border: '1px solid var(--primary)', marginBottom: '8px' }, onClick: async () => {
          try { await resolve(); toast('Статус оновлено', 'ok'); } catch (e) { toast(errText(e), 'err'); }
        } }, icon('refresh'), 'Оновити статус'),
        h('button', { class: 'btn text block', style: { border: '1px solid var(--primary)', marginBottom: '24px' }, onClick: async () => {
          try { await resetPassword(user.email); toast(`Лист для зміни пароля надіслано на ${user.email}`, 'ok'); } catch (e) { toast(errText(e), 'err'); }
        } }, icon('password'), 'Змінити пароль'),
        h('button', { class: 'btn text block', style: { color: '#C62828' }, onClick: async () => {
          if (await confirmDialog('Вийти з акаунта?', 'Для входу знову знадобляться пошта й пароль.', { okLabel: 'Вийти', cancelLabel: 'Скасувати', danger: true })) {
            ctx.pop(); logout();
          }
        } }, icon('logout'), 'Вийти з акаунта'))));
  });
}

// ── Смужка-нагадування ───────────────────────────────────────────────────────
/** «Пробний період: N дн.» / «код закінчується» — лише коли доступ обмежений у часі. */
export function accessBanner() {
  const el = h('div', { class: 'access-banner', hidden: true, onClick: () => openAccount() });
  const update = (s) => {
    if (!s || !s.until || !allowed(s)) { el.hidden = true; return; }
    const n = daysLeft(s);
    const trial = s.kind === 'trial';
    if (!trial && n > 7) { el.hidden = true; return; }
    el.className = `access-banner ${n <= 3 ? 'danger' : 'warn'}`;
    el.replaceChildren(icon('timer'),
      h('span', {}, trial ? `Пробний період: залишилось ${n} дн.` : `Доступ за кодом закінчується через ${n} дн.`),
      h('u', {}, 'Ввести код'));
    el.hidden = false;
  };
  update(getStatus());
  onStatus(update);
  return el;
}

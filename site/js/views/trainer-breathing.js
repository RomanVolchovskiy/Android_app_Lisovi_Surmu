// Тренажер «Дихальна гімнастика»: вправи з адмін-панелі (breathing_exercises),
// два типи блоків — cycle (фази за таймером) і endurance (студент сам
// засікає видих), запис виконання в breathing_sessions, «Мої результати».
import { h, icon, toast, pushScreen, appBar, confirmDialog, clear, spinner, emptyState } from '../ui.js';
import { db, auth, collection, doc, getDocs, getDoc, setDoc, query, where, writeBatch, serverTimestamp } from '../firebase.js';
import { isAdminUser } from '../access.js';
import { playTone } from '../horn-synth.js';

export const EXERCISES = 'breathing_exercises';
const SESSIONS = 'breathing_sessions';

export const CATEGORIES = { relaxation: 'Розслаблення', diaphragm: 'Діафрагмальне дихання', endurance: 'Витривалість', pre_performance: 'Перед виступом' };
export const LEVELS = { beginner: 'Початковий', intermediate: 'Середній', advanced: 'Просунутий' };
export const PHASE_TYPES = { inhale: 'Вдих', hold: 'Затримка', exhale: 'Видих', pause: 'Пауза' };
const PHASE_TONE = { inhale: 523.25, hold: 392.0, exhale: 261.63, pause: 392.0 };

const MIN_SCALE = 0.45;
const OK = '#2E7D32', WARN = '#EF6C00', BASE = '#1C3A1C';

const num = (v) => Number(v) || 0;

/** Орієнтовна тривалість вправи, с (cycle — сума фаз, endurance — середина цілі). */
export function estimateSeconds(ex) {
  return Math.round((ex.blocks || []).reduce((sum, b) => {
    const reps = Math.max(1, num(b.repeats));
    const rest = num(b.restBetweenReps) * (reps - 1);
    const one = b.kind === 'endurance'
      ? (b.phases || []).reduce((s, p) => s + (num(p.targetMinSeconds) + num(p.targetMaxSeconds)) / 2, 0)
      : (b.phases || []).reduce((s, p) => s + num(p.seconds), 0);
    return sum + one * reps + rest;
  }, 0));
}
export const fmtDuration = (sec) => (sec >= 60 ? `${Math.floor(sec / 60)} хв${sec % 60 ? ` ${sec % 60} с` : ''}` : `${sec} с`);

/** Опис блоку простою мовою: «Цикл 4–2–8 — 4 рази» / «Видих на «с» — 4 рази, 15–20 с». */
export function describeBlock(b) {
  const reps = Math.max(1, num(b.repeats));
  if (b.kind === 'endurance') {
    const p = (b.phases || [])[0] || {};
    return `${b.label || 'Витривалість видиху'} — ${reps} раз(и), ціль ${num(p.targetMinSeconds)}–${num(p.targetMaxSeconds)} с`;
  }
  const pattern = (b.phases || []).map((p) => num(p.seconds)).join('–');
  return `${b.label || 'Цикл'} (${pattern} с) — ${reps} раз(и)`;
}

function feedback(type) {
  try { playTone(PHASE_TONE[type] || 392, 0.35, null, 0.3); } catch { /* аудіо недоступне */ }
  try { navigator.vibrate?.(30); } catch { /* не підтримується */ }
}

async function loadExercises() {
  const snap = await getDocs(collection(db, EXERCISES));
  return snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id }))
    .sort((a, b) => num(a.sortOrder) - num(b.sortOrder));
}

// ── Фішка в «Навчальних тренажерах» ─────────────────────────────────────────
export function breathingTrainer() {
  const list = h('div', {}, spinner());
  loadExercises().then((all) => {
    const visible = all.filter((e) => !e.hidden);
    clear(list);
    if (!visible.length) { list.append(emptyState('air', 'Вправ ще немає', 'Адміністратор додає їх в адмін-панелі → «Дихальні вправи»')); return; }
    visible.forEach((ex) => list.append(h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => openIntro(ex) },
      h('div', { style: { width: '44px', height: '44px', borderRadius: '12px', background: 'rgba(47,79,47,.1)', display: 'grid', placeItems: 'center', color: 'var(--primary)' } }, icon('air')),
      h('div', { class: 'grow' }, h('div', { class: 't' }, ex.title),
        h('div', { class: 's' }, [CATEGORIES[ex.category], LEVELS[ex.level], `~${fmtDuration(estimateSeconds(ex))}`].filter(Boolean).join(' · '))),
      icon('chevron_right', ''))));
  }).catch((e) => clear(list).append(emptyState('error_outline', 'Помилка завантаження', e.message)));
  return h('div', {},
    h('div', { class: 's', style: { color: 'var(--grey-600)', margin: '4px 0 10px' } }, 'Діафрагмальне дихання, рівномірний видих і витривалість — розминка перед грою на ріжку.'),
    list,
    h('div', { class: 'tile', style: { cursor: 'pointer', marginTop: '8px' }, onClick: openMyResults },
      icon('history'), h('div', { class: 'grow' }, h('div', { class: 't' }, 'Мої результати'), h('div', { class: 's' }, 'Останні 50 виконаних вправ')), icon('chevron_right', '')));
}

// ── Екран перед стартом ─────────────────────────────────────────────────────
function openIntro(ex) {
  pushScreen(({ pop }) => h('div', { class: 'page', style: { background: 'var(--bg)' } },
    appBar(ex.title, { back: pop, small: true }),
    h('div', { class: 'body' }, h('div', { class: 'body-inner', style: { maxWidth: '640px' } },
      ex.description ? h('div', { style: { margin: '8px 0 16px', lineHeight: 1.5 } }, ex.description) : null,
      h('div', { class: 's', style: { marginBottom: '8px' } }, [CATEGORIES[ex.category], LEVELS[ex.level], `орієнтовно ${fmtDuration(estimateSeconds(ex))}`].filter(Boolean).join(' · ')),
      h('div', { class: 'sec-title' }, 'Блоки вправи'),
      ...(ex.blocks || []).map((b, i) => h('div', { class: 'tile' }, h('b', {}, `${i + 1})`), h('div', { class: 'grow' }, describeBlock(b)))),
      h('button', { class: 'btn block', style: { padding: '16px', marginTop: '16px', fontSize: '17px' }, onClick: () => { pop(); openRunner(ex); } }, icon('play_arrow'), 'Почати')))));
}

// ── Виконання вправи ────────────────────────────────────────────────────────
function openRunner(ex) {
  pushScreen((ctx) => {
    const blocks = (ex.blocks || []).filter((b) => (b.phases || []).length);
    const startedAt = Date.now();
    const results = []; // enduranceResults
    let completed = 0;
    let finished = false;
    let tick = null, wakeLock = null;
    let paused = false;

    const onUnload = (e) => { if (!finished) { e.preventDefault(); e.returnValue = ''; } };
    window.addEventListener('beforeunload', onUnload);
    try { navigator.wakeLock?.request('screen').then((l) => { wakeLock = l; }).catch(() => {}); } catch { /* немає */ }
    const cleanup = () => { clearInterval(tick); window.removeEventListener('beforeunload', onUnload); try { wakeLock?.release(); } catch { /* ок */ } };
    ctx.onPop = cleanup;

    // Індикатор: коло, масштаб якого показує обсяг повітря
    const circle = h('div', { style: {
      width: 'min(70vw, 46vh)', height: 'min(70vw, 46vh)', borderRadius: '50%', margin: '0 auto',
      background: `radial-gradient(circle at 50% 40%, rgba(212,160,23,.35), ${BASE}22)`, border: `6px solid ${BASE}`,
      display: 'grid', placeItems: 'center', transform: `scale(${MIN_SCALE})`, transition: 'transform .15s linear, border-color .3s',
    } });
    const bigNum = h('div', { style: { fontSize: 'clamp(48px, 14vw, 96px)', fontWeight: 700, color: BASE, lineHeight: 1 } });
    const phaseLbl = h('div', { style: { fontSize: 'clamp(22px, 6vw, 34px)', fontWeight: 700, color: BASE, textAlign: 'center' } });
    const subLbl = h('div', { class: 's', style: { textAlign: 'center', fontSize: '15px', minHeight: '20px' } });
    const blockLbl = h('div', { class: 's', style: { textAlign: 'center', fontSize: '14px' } });
    const controls = h('div', { style: { display: 'flex', gap: '8px', justifyContent: 'center', flexWrap: 'wrap', marginTop: '16px' } });
    const stage = h('div', { style: { position: 'relative', margin: '16px 0' } }, circle,
      h('div', { style: { position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', pointerEvents: 'none' } }, bigNum));
    const body = h('div', { class: 'body-inner', style: { maxWidth: '640px', textAlign: 'center' } });
    const runView = () => clear(body).append(blockLbl, phaseLbl, stage, subLbl, controls);

    const setScale = (s, color) => { circle.style.transform = `scale(${s})`; if (color) circle.style.borderColor = color; };
    const btn = (ic, label, onClick, cls = 'btn text') => h('button', { class: cls, style: { fontSize: '16px' }, onClick }, icon(ic), label);

    // Таймер з кроком 100 мс; час рахується лише без паузи
    const runTimer = (onFrame) => {
      clearInterval(tick);
      let last = performance.now(), elapsed = 0;
      tick = setInterval(() => {
        const now = performance.now();
        if (!paused) elapsed += (now - last) / 1000;
        last = now;
        onFrame(elapsed);
      }, 100);
    };
    const wait = (fn) => new Promise((res) => fn(res));

    const exit = async () => {
      if (finished) { ctx.pop(); return; }
      paused = true;
      if (await confirmDialog('Вийти з вправи?', 'Прогрес цієї вправи не буде збережено.', { okLabel: 'Вийти', cancelLabel: 'Продовжити', danger: true })) { finished = true; ctx.pop(); } else paused = false;
    };

    // Відпочинок між повторами: відлік + «Пропустити паузу»
    const rest = (seconds, nextLabel) => wait((done) => {
      if (seconds <= 0) { done(); return; }
      runView();
      phaseLbl.textContent = 'Відпочинок';
      subLbl.textContent = nextLabel;
      setScale(MIN_SCALE, BASE);
      const finish = () => { clearInterval(tick); done(); };
      clear(controls).append(btn('skip_next', 'Пропустити паузу', finish));
      runTimer((t) => { bigNum.textContent = String(Math.max(0, Math.ceil(seconds - t))); if (t >= seconds) finish(); });
    });

    // cycle: фази йдуть самі; повертає false, якщо блок пропущено
    const runCycle = (b, bi) => wait(async (done) => {
      const reps = Math.max(1, num(b.repeats));
      let skipped = false;
      for (let r = 0; r < reps && !skipped && !finished; r++) {
        for (const p of b.phases) {
          if (skipped || finished) break;
          await wait((next) => {
            runView();
            const dur = Math.max(0.5, num(p.seconds));
            blockLbl.textContent = `Блок ${bi + 1} з ${blocks.length}: ${b.label || 'Цикл'} · Повтор ${r + 1} з ${reps}`;
            phaseLbl.textContent = p.label || PHASE_TYPES[p.type] || '';
            subLbl.textContent = p.type === 'exhale' && p.sound ? `на звук «${p.sound}-${p.sound}-${p.sound}»` : '';
            feedback(p.type);
            const from = parseFloat(circle.style.transform.slice(6)) || MIN_SCALE;
            const to = p.type === 'inhale' ? 1 : p.type === 'exhale' ? MIN_SCALE : from;
            const pauseBtn = btn('pause', 'Пауза', () => {
              paused = !paused;
              pauseBtn.replaceChildren(icon(paused ? 'play_arrow' : 'pause'), paused ? 'Продовжити' : 'Пауза');
            });
            clear(controls).append(pauseBtn,
              btn('skip_next', 'Пропустити блок', () => { skipped = true; clearInterval(tick); next(); }),
              btn('close', 'Вийти', exit));
            runTimer((t) => {
              bigNum.textContent = String(Math.max(0, Math.ceil(dur - t)));
              setScale(from + (to - from) * Math.min(1, t / dur), BASE);
              if (t >= dur || finished) { clearInterval(tick); next(); }
            });
          });
        }
        if (!skipped && r < reps - 1) await rest(num(b.restBetweenReps), `Далі: повтор ${r + 2} з ${reps}`);
      }
      done(!skipped);
    });

    // endurance: студент сам тисне «Почати видих» і «Стоп»
    const runEndurance = (b, bi) => wait(async (done) => {
      const reps = Math.max(1, num(b.repeats));
      const p = b.phases[0];
      const min = num(p.targetMinSeconds), max = Math.max(min, num(p.targetMaxSeconds));
      let skipped = false;
      for (let r = 0; r < reps && !skipped && !finished; r++) {
        await wait((next) => {
          runView();
          blockLbl.textContent = `Блок ${bi + 1} з ${blocks.length}: ${b.label || 'Витривалість видиху'} · Повтор ${r + 1} з ${reps}`;
          phaseLbl.textContent = 'Глибокий вдих — і починайте';
          subLbl.textContent = `Ціль: ${min}–${max} с${p.sound ? ` · на звук «${p.sound}-${p.sound}-${p.sound}»` : ''}`;
          bigNum.textContent = '0';
          setScale(1, BASE);
          const start = btn('play_arrow', 'Почати видих', () => {
            feedback('exhale');
            phaseLbl.textContent = p.label || 'Рівномірний видих';
            let achieved = 0;
            const stop = btn('stop', 'Стоп', () => {
              clearInterval(tick);
              const sec = Math.round(achieved * 10) / 10;
              const inTarget = sec >= min && sec <= max;
              results.push({ blockLabel: b.label || 'Витривалість видиху', repeatIndex: r, achievedSeconds: sec, inTarget });
              feedback('hold');
              phaseLbl.textContent = inTarget ? '✓ У межах цілі' : sec < min ? 'Коротше за ціль' : 'Довше за ціль';
              phaseLbl.style.color = inTarget ? OK : WARN;
              bigNum.textContent = sec.toFixed(1);
              clear(controls).append(btn('arrow_forward', r < reps - 1 ? 'Далі' : 'Завершити блок', () => { phaseLbl.style.color = BASE; next(); }, 'btn'));
            }, 'btn danger');
            stop.style.padding = '18px 40px'; stop.style.fontSize = '20px';
            clear(controls).append(stop);
            runTimer((t) => {
              achieved = t;
              bigNum.textContent = t.toFixed(1);
              const color = t < min ? BASE : t <= max ? OK : WARN;
              setScale(Math.max(MIN_SCALE, 1 - (t / Math.max(max, 1)) * (1 - MIN_SCALE)), color);
            });
          }, 'btn');
          start.style.padding = '18px 32px'; start.style.fontSize = '20px';
          clear(controls).append(start,
            btn('skip_next', 'Пропустити блок', () => { skipped = true; next(); }),
            btn('close', 'Вийти', exit));
        });
        if (!skipped && r < reps - 1 && !finished) await rest(num(b.restBetweenReps), `Далі: повтор ${r + 2} з ${reps}`);
      }
      done(!skipped);
    });

    const separator = (bi) => wait((done) => {
      clearInterval(tick);
      const nextB = blocks[bi + 1];
      clear(body).append(h('div', { style: { padding: '40px 0' } },
        h('span', { class: 'mi', style: { fontSize: '64px', color: OK } }, 'check_circle'),
        h('div', { style: { fontSize: '22px', fontWeight: 700, margin: '8px 0' } }, `Блок ${bi + 1} завершено`),
        h('div', { class: 's', style: { fontSize: '16px' } }, `Наступний: ${nextB.label || describeBlock(nextB)}`),
        h('button', { class: 'btn', style: { marginTop: '20px', padding: '14px 32px', fontSize: '17px' }, onClick: done }, icon('arrow_forward'), 'Продовжити')));
    });

    const run = async () => {
      for (let bi = 0; bi < blocks.length && !finished; bi++) {
        const b = blocks[bi];
        const ok = b.kind === 'endurance' ? await runEndurance(b, bi) : await runCycle(b, bi);
        if (ok) completed++;
        if (bi < blocks.length - 1 && !finished) await separator(bi);
      }
      if (finished) return;
      finished = true;
      cleanup();
      showResult();
    };

    const showResult = () => {
      const total = Math.round((Date.now() - startedAt) / 1000);
      const save = h('button', { class: 'btn', onClick: async () => {
        save.disabled = true;
        await saveSession(ex, { blocksCompleted: completed, blocksTotal: blocks.length, enduranceResults: results, totalDurationSeconds: total });
        ctx.pop();
      } }, icon('save'), 'Зберегти й вийти');
      clear(body).append(
        h('div', { style: { padding: '16px 0' } },
          h('span', { class: 'mi', style: { fontSize: '64px', color: OK } }, 'self_improvement'),
          h('div', { style: { fontSize: '22px', fontWeight: 700 } }, 'Вправу завершено'),
          h('div', { class: 's', style: { fontSize: '15px' } }, `Виконано блоків: ${completed} з ${blocks.length} · ${fmtDuration(total)}`)),
        results.length ? h('div', { style: { textAlign: 'left' } },
          h('div', { class: 'sec-title' }, 'Витривалість видиху'),
          ...results.map((r) => h('div', { class: 'tile', style: { borderLeft: `4px solid ${r.inTarget ? OK : WARN}` } },
            h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, r.blockLabel), h('div', { class: 's' }, `Повтор ${r.repeatIndex + 1}`)),
            h('b', { style: { color: r.inTarget ? OK : WARN, fontSize: '16px' } }, `${r.achievedSeconds.toFixed(1)} с ${r.inTarget ? '✓' : '—'}`)))) : null,
        h('div', { style: { display: 'flex', gap: '8px', justifyContent: 'center', flexWrap: 'wrap', marginTop: '16px' } },
          save,
          h('button', { class: 'btn text', onClick: () => { ctx.pop(); openRunner(ex); } }, icon('replay'), 'Повторити'),
          h('button', { class: 'btn text', onClick: ctx.pop }, icon('home'), 'На головну')));
    };

    runView();
    setTimeout(run, 0);
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(ex.title, { back: exit, small: true }),
      h('div', { class: 'body' }, body));
  });
}

async function saveSession(ex, data) {
  const u = auth.currentUser;
  if (!u) { toast('Увійдіть, щоб зберігати результати', 'err'); return; }
  let profile = {};
  try { profile = (await getDoc(doc(db, 'users', u.uid))).data() || {}; } catch { /* профіль необов'язковий */ }
  try {
    await setDoc(doc(collection(db, SESSIONS)), {
      uid: u.uid, email: (u.email || '').toLowerCase(),
      fullName: profile.fullName ?? null, group: profile.group ?? null,
      exerciseId: ex.id, exerciseTitle: ex.title, ...data, createdAt: serverTimestamp(),
    });
    toast('Результат збережено', 'ok');
  } catch (e) { toast(`Не вдалося зберегти: ${e.message}`, 'err'); }
}

// ── Мої результати ──────────────────────────────────────────────────────────
function openMyResults() {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner' }, spinner());
    const u = auth.currentUser;
    // Видаляти записи дозволено лише адміністратору (правила breathing_sessions)
    const admin = isAdminUser();
    const remove = async (ids, what) => {
      if (!await confirmDialog('Видалити?', `Видалити ${what}? Цю дію не можна скасувати.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
      try {
        for (let i = 0; i < ids.length; i += 400) {
          const batch = writeBatch(db);
          ids.slice(i, i + 400).forEach((id) => batch.delete(doc(db, SESSIONS, id)));
          await batch.commit();
        }
        toast('Видалено', 'ok');
        load();
      } catch (e) { toast(`Не вдалося видалити: ${e.message}`, 'err'); }
    };
    const load = async () => {
      clear(body).append(spinner());
      if (!u) { clear(body).append(emptyState('lock', 'Увійдіть, щоб бачити результати')); return; }
      // лише фільтр за uid — без складеного індексу; сортування на клієнті
      const snap = await getDocs(query(collection(db, SESSIONS), where('uid', '==', u.uid)));
      const all = snap.docs.map((d) => ({ ...d.data(), _id: d.id }));
      const rows = all.sort((a, b) => (b.createdAt?.toMillis?.() ?? 0) - (a.createdAt?.toMillis?.() ?? 0)).slice(0, 50);
      clear(body);
      if (!rows.length) { body.append(emptyState('history', 'Ще немає виконаних вправ')); return; }
      if (admin) body.append(h('button', { class: 'btn text', style: { color: '#C62828', marginBottom: '8px' }, onClick: () => remove(all.map((r) => r._id), `усі свої результати (${all.length})`) }, icon('delete_sweep'), 'Видалити всі мої результати'));
      rows.forEach((r) => {
        const d = r.createdAt?.toDate?.();
        const inT = (r.enduranceResults || []).filter((x) => x.inTarget).length;
        body.append(h('div', { class: 'tile' },
          icon(r.blocksCompleted >= r.blocksTotal ? 'check_circle' : 'timelapse'),
          h('div', { class: 'grow' }, h('div', { class: 't' }, r.exerciseTitle),
            h('div', { class: 's' }, [d ? d.toLocaleString('uk-UA', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '',
              `блоків ${r.blocksCompleted}/${r.blocksTotal}`, (r.enduranceResults || []).length ? `видих у цілі ${inT}/${r.enduranceResults.length}` : ''].filter(Boolean).join(' · '))),
          admin ? h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: () => remove([r._id], 'цей результат') }, icon('delete')) : null));
      });
    };
    load().catch((e) => clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)));
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Мої результати: дихання', { back: pop, small: true }),
      h('div', { class: 'body' }, body));
  });
}

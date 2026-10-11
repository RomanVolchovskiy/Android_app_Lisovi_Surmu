// Анімовані фігурки для 17 вправ дихального тренажера (Canvas 2D, без залежностей).
// Пози задано кутами суглобів і плавно інтерполюються між фазами.
// Полотно — 200×200 умовних одиниць, вісь Y донизу.
// Кути в градусах: 0 = вниз, 90 = вправо, 180 = вгору, −90 = вліво.
//
//   const fig = mountFigure(canvas, 'flow_studies');          // під рушій
//   fig.update({ type: 'inhale', progress: 0.3, variant: 0 }); // на кожен кадр
//   mountFigure(canvas, 'candle', { demo: true });             // зациклене прев'ю
//   fig.stop();
//
// Кольори — з CSS-змінних на canvas: --fig-ink, --fig-bg (фон під фігуркою,
// ним малюються очі), --fig-inhale, --fig-exhale, --fig-prop, --fig-brass, --fig-paper.

const GROUND = 186;
const L = { torso: 42, shoulder: 37, shHalf: 13, hipHalf: 7, neck: 7, headR: 10, upper: 23, fore: 21, thigh: 30, shin: 30 };
const D2R = Math.PI / 180;
const dir = (a) => [Math.sin(a * D2R), Math.cos(a * D2R)];
const perpR = (a) => [-Math.cos(a * D2R), Math.sin(a * D2R)];
const add = (p, v, k = 1) => [p[0] + v[0] * k, p[1] + v[1] * k];
const lerp = (a, b, t) => a + (b - a) * t;
const clamp01 = (t) => Math.max(0, Math.min(1, t));
const frac = (x) => x - Math.floor(x);
const easeInOut = (t) => (t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2);
const easeOut = (t) => 1 - (1 - t) * (1 - t);
/** Імпульс Стрельникової: швидкий рух у позу дії, потім повернення. */
const pulse = (p) => (p < 0.32 ? easeOut(p / 0.32) : 1 - easeInOut((p - 0.32) / 0.68));
const envOf = (p) => Math.min(1, p * 6, (1 - p) * 6);

// ── Пози ────────────────────────────────────────────────────────────────
const KEYS = ['x', 'torso', 'head', 'lu', 'lf', 'ru', 'rf', 'lt', 'ls', 'rt', 'rs', 'fist', 'face'];
const P = (base, o = {}) => ({ ...base, ...o });
const lerpPose = (a, b, t) => Object.fromEntries(KEYS.map((k) => [k, lerp(a[k], b[k], t)]));
const mirror = (p) => ({
  x: 200 - p.x, torso: 360 - p.torso, head: 360 - p.head,
  lu: -p.ru, lf: -p.rf, ru: -p.lu, rf: -p.lf, lt: -p.rt, ls: -p.rs, rt: -p.lt, rs: -p.ls,
  fist: p.fist, face: -p.face,
});

const FRONT_N = { x: 100, torso: 180, head: 180, lu: -8, lf: -4, ru: 8, rf: 4, lt: -5, ls: -2, rt: 5, rs: 2, fist: 0, face: 0 };
const SIDE_N = { x: 100, torso: 180, head: 180, lu: 4, lf: 18, ru: 14, rf: 30, lt: -4, ls: -2, rt: 5, rs: 0, fist: 0, face: 1 };
const PO = {
  stretchUp: P(FRONT_N, { lu: -168, lf: -172, ru: 168, rf: 172, head: 182 }),
  ragBent: P(SIDE_N, { x: 80, torso: 70, head: 22, lu: -2, lf: -6, ru: 4, rf: 0, lt: 12, ls: -8, rt: 16, rs: -6 }),
  lying: P(SIDE_N, { x: 118, torso: -90, head: -96, lu: 95, lf: 88, ru: 100, rf: 92, lt: 122, ls: 20, rt: 120, rs: 22 }),
  palms: P(FRONT_N, { lu: -22, lf: -172, ru: 22, rf: 172, fist: 0 }),
  epaulN: P(FRONT_N, { lu: -28, lf: 42, ru: 28, rf: -42, fist: 1 }),
  epaulA: P(FRONT_N, { lu: -12, lf: -14, ru: 12, rf: 14, fist: 0 }),
  pumpN: P(SIDE_N, { torso: 168, head: 172, lu: 40, lf: 60, ru: 44, rf: 64, fist: 1 }),
  pumpA: P(SIDE_N, { x: 92, torso: 118, head: 105, lu: 15, lf: 12, ru: 18, rf: 14, lt: 8, ls: -4, rt: 10, rs: -3, fist: 1 }),
  catN: P(FRONT_N, { lu: -30, lf: 30, ru: 30, rf: -30, fist: 0.5 }),
  catA: P(FRONT_N, { torso: 174, head: 170, face: 0.8, lu: 30, lf: 75, ru: 75, rf: 85, lt: -50, ls: 12, rt: 50, rs: -12, fist: 1 }),
  hugN: P(FRONT_N, { lu: -92, lf: -96, ru: 92, rf: 96 }),
  hugA: P(FRONT_N, { lu: 12, lf: 132, ru: -12, rf: -132 }),
  pendF: P(SIDE_N, { x: 90, torso: 112, head: 100, lu: 0, lf: 0, ru: 4, rf: 2 }),
  pendB: P(SIDE_N, { x: 106, torso: 197, head: 200, lu: 96, lf: -112, ru: 102, rf: -108, lt: -2, ls: 4, rt: 6, rs: 2 }),
  bellyHand: P(SIDE_N, { lu: -12, lf: 96, ru: -15, rf: 100 }),
  palmFront: P(SIDE_N, { ru: 100, rf: 160 }),
  candle: P(SIDE_N, { x: 70 }),
  paperRest: P(SIDE_N, { x: 128 }),
  paperReach: P(SIDE_N, { x: 128, ru: 106, rf: 110 }),
  bag: P(SIDE_N, { lu: 46, lf: 152, ru: 52, rf: 158 }),
  horn: P(SIDE_N, { lu: 48, lf: 140, ru: 58, rf: 150, fist: 1 }),
};

// ── Вправи: вигляд, тип повітря, демо-цикл ──────────────────────────────
// Крок демо: [фаза, секунди, додаткові поля стану].
const STREL_DEMO = [...Array.from({ length: 8 }, (_, i) => ['inhale', 0.667, { variant: i % 2 }]), ['rest', 2.5]];
const EX = {
  stretch_breath: { view: 'front', flow: 'basic', demo: [['inhale', 4], ['exhale', 4]] },
  rag_doll: { view: 'side', flow: 'basic', demo: [['exhale', 4], ['hold', 2], ['inhale', 6]] },
  book_on_belly: { view: 'side', flow: 'basic', demo: [['inhale', 4], ['exhale', 6]] },
  str_palms: { view: 'front', flow: 'nose', demo: STREL_DEMO },
  str_epaulettes: { view: 'front', flow: 'nose', demo: STREL_DEMO },
  str_pump: { view: 'side', flow: 'nose', demo: STREL_DEMO },
  str_cat: { view: 'front', flow: 'nose', demo: STREL_DEMO },
  str_hug: { view: 'front', flow: 'nose', demo: STREL_DEMO },
  str_pendulum: { view: 'side', flow: 'nose', demo: STREL_DEMO },
  flow_studies: { view: 'side', flow: 'basic', demo: [['inhale', 4], ['exhale', 4], ['inhale', 1], ['exhale', 7]] },
  hiss_exhale: { view: 'side', flow: 'hiss', demo: [['inhale', 3], ['exhale', 10]] },
  panting: { view: 'side', flow: 'pant', demo: [['inhale', 0.4], ['exhale', 0.4]] },
  air_notes: { view: 'side', flow: 'puff', demo: [['inhale', 0.75], ['action', 5.25, { beats: 7, syllable: 'ту' }], ['rest', 1]] },
  candle: { view: 'side', flow: 'candle', demo: [['inhale', 2], ['exhale', 8]] },
  paper_wall: { view: 'side', flow: 'paper', demo: [['inhale', 2.5], ['exhale', 7]] },
  breathing_bag: { view: 'side', flow: 'bag', demo: [['inhale', 3], ['exhale', 4]] },
  long_tones: { view: 'side', flow: 'horn', demo: [['inhale', 1], ['exhale', 8], ['rest', 2], ['inhale', 1], ['exhale', 8, { swell: true }], ['rest', 2]] },
};
const STREL = new Set(['str_palms', 'str_epaulettes', 'str_pump', 'str_cat', 'str_hug', 'str_pendulum']);
export const FIGURE_IDS = Object.keys(EX);

/**
 * Стан кадру:
 *   type      inhale | exhale | hold | action | rest
 *   progress  прогрес фази 0..1
 *   variant   0/1 — сторона в «Кішці», нахил/прогин у «Маятнику» (номер підказки)
 *   beats     долей у фазі (для поштовхів «Повітряних нот»)
 *   swell     crescendo – diminuendo на видиху («Довгі ноти»)
 *   syllable  «ту» / «ху»
 *   time      секунди, для руху повітря й полум'я
 */
function norm(s) {
  return {
    type: s.type || 'rest', p: clamp01(s.progress || 0), variant: s.variant ? 1 : 0, beats: s.beats > 0 ? s.beats : 1,
    swell: !!s.swell, syllable: s.syllable || 'ту', time: s.time || 0,
  };
}

function poseFor(id, s) {
  const { type, p } = s;
  const ei = easeInOut(p);
  const inhale = type === 'inhale';
  switch (id) {
    case 'stretch_breath':
      if (inhale) return lerpPose(FRONT_N, PO.stretchUp, ei);
      if (type === 'exhale') return lerpPose(PO.stretchUp, FRONT_N, ei);
      return type === 'hold' ? PO.stretchUp : FRONT_N;
    case 'rag_doll':
      if (type === 'exhale') return lerpPose(SIDE_N, PO.ragBent, ei);
      if (inhale) return lerpPose(PO.ragBent, SIDE_N, ei);
      if (type === 'hold') {
        const sw = 5 * Math.sin(s.time * 3), b = PO.ragBent;
        return P(b, { lu: b.lu + sw, lf: b.lf + sw * 1.4, ru: b.ru + sw, rf: b.rf + sw * 1.4 });
      }
      return SIDE_N;
    case 'book_on_belly': return PO.lying;
    case 'str_palms': return inhale ? P(PO.palms, { fist: pulse(p) }) : PO.palms;
    case 'str_epaulettes': return inhale ? lerpPose(PO.epaulN, PO.epaulA, pulse(p)) : PO.epaulN;
    case 'str_pump': return inhale ? lerpPose(PO.pumpN, PO.pumpA, pulse(p)) : PO.pumpN;
    case 'str_cat': return inhale ? lerpPose(PO.catN, s.variant ? PO.catA : mirror(PO.catA), pulse(p)) : PO.catN; // 0 — вправо (для глядача — ліворуч)
    case 'str_hug': return inhale ? lerpPose(PO.hugN, PO.hugA, pulse(p)) : PO.hugN;
    case 'str_pendulum': return inhale ? lerpPose(SIDE_N, s.variant ? PO.pendB : PO.pendF, pulse(p)) : SIDE_N;
    case 'hiss_exhale': case 'panting': return PO.bellyHand;
    case 'air_notes': return PO.palmFront;
    case 'candle': return PO.candle;
    case 'paper_wall':
      if (inhale) return lerpPose(PO.paperRest, PO.paperReach, easeOut(clamp01(p / 0.4)));
      if (type === 'exhale') return lerpPose(PO.paperReach, PO.paperRest, easeInOut(clamp01(p / 0.3)));
      return PO.paperRest;
    case 'breathing_bag': return PO.bag;
    case 'long_tones': return PO.horn;
    default: return SIDE_N;
  }
}

/** Наповнення легень / живота 0..1. */
function breathFor(id, s) {
  const { type, p } = s;
  if (STREL.has(id)) {
    if (type !== 'inhale') return 0.2;
    return p < 0.3 ? 0.2 + 0.8 * easeOut(p / 0.3) : 1 - 0.8 * easeInOut((p - 0.3) / 0.7);
  }
  if (id === 'panting') {
    if (type === 'inhale') return lerp(0.45, 0.75, easeInOut(p));
    if (type === 'exhale') return lerp(0.75, 0.45, easeInOut(p));
    return 0.45;
  }
  if (id === 'air_notes' && type === 'action') {
    const q = frac(p * s.beats);
    return 1 - 0.6 * p - 0.08 * Math.sin(Math.PI * clamp01(q / 0.5));
  }
  if (id === 'long_tones' && type === 'rest') return 0.15 + 0.15 * easeInOut(p);
  switch (type) {
    case 'inhale': return 0.15 + 0.85 * easeInOut(p);
    case 'exhale': return 1 - 0.85 * p;
    case 'hold': return id === 'rag_doll' ? 0.15 : 1;
    default: return 0.3;
  }
}

/** Положення суглобів; фігура «стоїть» на підлозі. */
function skeleton(pose, view) {
  const hip0 = [pose.x, 0];
  const td = dir(pose.torso);
  const neck = add(hip0, td, L.torso);
  const head = add(neck, dir(pose.head), L.neck + L.headR);
  const shC = add(hip0, td, L.shoulder);
  let lSh = shC, rSh = shC, lHip = hip0, rHip = hip0;
  if (view === 'front') {
    const pr = perpR(pose.torso);
    lSh = add(shC, pr, -L.shHalf); rSh = add(shC, pr, L.shHalf);
    lHip = add(hip0, pr, -L.hipHalf); rHip = add(hip0, pr, L.hipHalf);
  }
  const lEl = add(lSh, dir(pose.lu), L.upper), lHand = add(lEl, dir(pose.lf), L.fore);
  const rEl = add(rSh, dir(pose.ru), L.upper), rHand = add(rEl, dir(pose.rf), L.fore);
  const lKnee = add(lHip, dir(pose.lt), L.thigh), lFoot = add(lKnee, dir(pose.ls), L.shin);
  const rKnee = add(rHip, dir(pose.rt), L.thigh), rFoot = add(rKnee, dir(pose.rs), L.shin);
  const dy = GROUND - Math.max(lFoot[1], rFoot[1], lKnee[1], rKnee[1], hip0[1], head[1] + L.headR);
  const j = { hip: hip0, neck, head, lSh, rSh, lHip, rHip, lEl, lHand, rEl, rHand, lKnee, lFoot, rKnee, rFoot };
  for (const k in j) j[k] = [j[k][0], j[k][1] + dy];
  if (view === 'side') {
    const f = perpR(pose.head);
    j.mouth = add(add(j.head, f, 8), dir(pose.head), -3);
    j.nose = add(add(j.head, f, 10), dir(pose.head), 1);
    j.flowDir = f;
  } else {
    j.mouth = add(j.head, dir(pose.head), -4);
    j.nose = j.head;
    j.flowDir = [0.8, 0.6];
  }
  return j;
}

/** Опис кадру (для малювання й тестів). */
export function figureFrame(id, state) {
  const ex = EX[id] || EX.flow_studies;
  const s = norm(state);
  const pose = poseFor(id, s);
  return { id, view: ex.view, flow: ex.flow, pose, breath: breathFor(id, s), j: skeleton(pose, ex.view), s };
}

/** Стан демо-циклу в момент t, с. */
export function demoState(id, t) {
  const d = (EX[id] || EX.flow_studies).demo;
  const total = d.reduce((a, x) => a + x[1], 0);
  let r = t - Math.floor(t / total) * total;
  for (let i = 0; i < d.length; i++) {
    if (r < d[i][1] || i === d.length - 1) return { type: d[i][0], progress: clamp01(r / d[i][1]), time: t, ...(d[i][2] || {}) };
    r -= d[i][1];
  }
  return { type: 'rest', progress: 0, time: t };
}

// ── Малювання ──────────────────────────────────────────────────────────
function drawFigure(ctx, F, C) {
  const { j, pose, breath, s, view, flow, id } = F;
  const { type, p, time } = s;
  const env = envOf(p);
  const side = view === 'side';

  const line = (a, b, w, color, alpha = 1) => {
    ctx.globalAlpha = Math.max(0, Math.min(1, alpha)); ctx.strokeStyle = color; ctx.lineWidth = w; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke(); ctx.globalAlpha = 1;
  };
  const dot = (c, r, color, alpha = 1) => {
    ctx.globalAlpha = Math.max(0, Math.min(1, alpha)); ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(c[0], c[1], r, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
  };
  const text = (str, c, size, color, alpha = 1) => {
    ctx.globalAlpha = Math.max(0, Math.min(1, alpha)); ctx.fillStyle = color; ctx.font = `600 ${size}px system-ui, sans-serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(str, c[0], c[1]); ctx.globalAlpha = 1;
  };
  const rect = (x, y, w, h, fill, alpha = 1, stroke = null, sw = 1) => {
    ctx.globalAlpha = alpha;
    if (fill) { ctx.fillStyle = fill; ctx.fillRect(x, y, w, h); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = sw; ctx.strokeRect(x, y, w, h); }
    ctx.globalAlpha = 1;
  };
  const hand = (pos, foreAngle, fist, alpha) => {
    dot(pos, 2.6 + fist * 1.6, C.ink, alpha);
    if (fist < 0.98) for (const k of [-30, 0, 30]) line(pos, add(pos, dir(foreAngle + k), 6 * (1 - fist)), 1.6, C.ink, alpha);
  };
  const arm = (sh, el, ha, fa, alpha) => { line(sh, el, 6, C.ink, alpha); line(el, ha, 5.5, C.ink, alpha); hand(ha, fa, pose.fist, alpha); };
  const leg = (hp, kn, ft, dx, alpha) => { line(hp, kn, 6.5, C.ink, alpha); line(kn, ft, 6, C.ink, alpha); line(ft, [ft[0] + dx, ft[1]], 5, C.ink, alpha); };

  // фон і предмети позаду фігури
  line([8, GROUND + 2], [192, GROUND + 2], 1.5, C.ink, 0.15);
  if (id === 'book_on_belly') rect(34, GROUND - 4, 142, 6, C.prop, 0.28);
  if (id === 'paper_wall') { rect(172, 10, 28, GROUND - 8, C.ink, 0.14); line([172, 10], [172, GROUND + 2], 1.5, C.ink, 0.35); }
  if (id === 'candle') {
    rect(122, GROUND - 82, 46, 4, C.prop);
    line([127, GROUND - 78], [127, GROUND + 1], 3, C.prop); line([163, GROUND - 78], [163, GROUND + 1], 3, C.prop);
    rect(141, GROUND - 104, 8, 22, C.paper, 1, C.ink, 1);
  }

  // фігура: дальні кінцівки й тулуб
  if (side) {
    leg(j.lHip, j.lKnee, j.lFoot, 6, 0.4);
    arm(j.lSh, j.lEl, j.lHand, pose.lf, 0.4);
    line(j.hip, j.neck, 8, C.ink);
  } else {
    leg(j.lHip, j.lKnee, j.lFoot, -5, 1); leg(j.rHip, j.rKnee, j.rFoot, 5, 1);
    line(j.lHip, j.rHip, 7, C.ink); line(j.hip, j.neck, 8, C.ink); line(j.lSh, j.rSh, 6.5, C.ink);
  }
  // живіт: наповнення повітрям
  {
    let c = add(j.hip, dir(pose.torso), 13);
    if (side) c = add(c, perpR(pose.torso), 1.5 + 3 * breath);
    ctx.globalAlpha = 0.18 + 0.42 * breath; ctx.fillStyle = C.inhale;
    ctx.beginPath(); ctx.ellipse(c[0], c[1], side ? 3 + 6 * breath : 5 + 5 * breath, 10, -pose.torso * D2R, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 1;
  }
  // голова
  dot(j.head, L.headR, C.ink);
  if (side) dot(add(add(j.head, perpR(pose.head), 4.5), dir(pose.head), 1.5), 1.4, C.bg);
  else for (const sg of [-1, 1]) dot(add(add(j.head, perpR(pose.head), sg * 3.6 + pose.face * 3), dir(pose.head), 1.5), 1.3, C.bg);

  // предмети між тулубом і ближньою рукою
  if (id === 'breathing_bag') {
    const r = 6 + 12 * (1 - breath);
    const c = add(j.mouth, [4 + r * 0.95, 5 + r * 0.25]);
    line(j.mouth, add(j.mouth, [5, 2]), 3, C.prop);
    ctx.fillStyle = C.prop; ctx.globalAlpha = 0.35; ctx.beginPath(); ctx.arc(c[0], c[1], r, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 1; ctx.strokeStyle = C.prop; ctx.lineWidth = 1.5; ctx.stroke();
  }
  if (id === 'long_tones') {
    const c = add(j.mouth, [18, 8]);
    line(j.mouth, add(c, [-10, -2]), 2.2, C.brass);
    ctx.strokeStyle = C.brass; ctx.lineWidth = 2.2;
    for (const r of [11, 7.5]) { ctx.beginPath(); ctx.arc(c[0], c[1], r, 0, Math.PI * 2); ctx.stroke(); }
    const q = [[8, -7], [33, -22], [39, -7], [11, -1]].map((v) => add(c, v));
    ctx.fillStyle = C.brass; ctx.beginPath(); ctx.moveTo(q[0][0], q[0][1]);
    for (const v of q.slice(1)) ctx.lineTo(v[0], v[1]);
    ctx.closePath(); ctx.fill();
  }
  if (id === 'book_on_belly') {
    const c = add(add(j.hip, dir(pose.torso), 14), perpR(pose.torso), 5 + 7 * breath);
    rect(c[0] - 11, c[1] - 2.5, 22, 5, C.prop);
    line([c[0] - 10, c[1] - 0.2], [c[0] + 10, c[1] - 0.2], 0.8, C.paper);
  }

  // ближні кінцівки
  if (side) { leg(j.rHip, j.rKnee, j.rFoot, 6, 1); arm(j.rSh, j.rEl, j.rHand, pose.rf, 1); }
  else { arm(j.lSh, j.lEl, j.lHand, pose.lf, 1); arm(j.rSh, j.rEl, j.rHand, pose.rf, 1); }

  // повітря
  const fd = j.flowDir, nrm = [-fd[1], fd[0]];
  const inflow = (len, n = 5) => {
    for (let i = 0; i < n; i++) { const u = frac(time * 0.9 + i / n); dot(add(j.mouth, fd, 4 + (1 - u) * len), 1.8, C.inhale, u * 0.85 * env); }
  };
  const outflow = (len, n, glyph) => {
    for (let i = 0; i < n; i++) {
      const u = frac(time * 0.7 + i / n);
      const pos = add(add(j.mouth, fd, 4 + u * len), nrm, Math.sin((u + i) * 7) * 1.2 * u);
      if (glyph) text(glyph, pos, 7 + u * 2, C.exhale, (1 - u) * 0.95 * env);
      else dot(pos, 1.8 + u * 0.8, C.exhale, (1 - u) * 0.85 * env);
    }
  };

  if (flow === 'basic') {
    if (type === 'inhale') inflow(28);
    if (type === 'exhale') outflow(34, 6);
  } else if (flow === 'hiss') {
    if (type === 'inhale') inflow(28);
    if (type === 'exhale') outflow(52, 7, 'с');
  } else if (flow === 'pant') {
    for (let i = 0; i < 3; i++) {
      const off = [nrm[0] * (i - 1) * 2.5, nrm[1] * (i - 1) * 2.5];
      if (type === 'exhale') dot(add(add(j.mouth, fd, 4 + p * 14), off), 1.6, C.exhale, 1 - p);
      if (type === 'inhale') dot(add(add(j.mouth, fd, 4 + (1 - p) * 12), off), 1.6, C.inhale, p);
    }
  } else if (flow === 'puff') {
    if (type === 'inhale') inflow(18);
    if (type === 'action') {
      const q = s.beats > 1 ? frac(p * s.beats) : p;
      const u = clamp01(q / 0.55);
      dot(add(j.mouth, fd, 4 + u * 17), 2.4 + u * 1.6, C.exhale, 1 - u * 0.75);
      text(s.syllable, add(j.mouth, [4, -14 - q * 4]), 9, C.exhale, 1 - q);
    }
  } else if (flow === 'nose') {
    if (type === 'inhale' && p < 0.38) {
      const base = Math.atan2(fd[0], fd[1]) / D2R;
      for (const k of [-28, 0, 28]) {
        const v = dir(base + k);
        line(add(j.nose, v, 15 - 6 * (p / 0.38)), add(j.nose, v, 5), 1.8, C.inhale, 1 - p / 0.38);
      }
    } else if (type === 'inhale') {
      const q = (p - 0.38) / 0.62;
      for (let i = 0; i < 3; i++) dot(add(j.mouth, fd, 4 + q * 12 + i * 4), 1.3, C.exhale, 0.35 * (1 - q));
    }
  } else if (flow === 'candle') {
    const fb = [145, GROUND - 104];
    if (type === 'inhale') inflow(24);
    let st = 0;
    if (type === 'exhale') { st = Math.min(1, p * 5, (1 - p) * 8); outflow(fb[0] - j.mouth[0] - 4, 8); }
    const tilt = st * 50 + Math.sin(time * 13) * 3 + Math.sin(time * 7.3) * 2;
    const h = 14 - st * 3;
    ctx.save(); ctx.translate(fb[0], fb[1]); ctx.rotate(tilt * D2R);
    ctx.globalAlpha = 0.25; ctx.fillStyle = '#FFD166'; ctx.beginPath(); ctx.arc(0, -h * 0.4, 9, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
    ctx.fillStyle = '#F4A261'; ctx.beginPath(); ctx.moveTo(0, -h);
    ctx.bezierCurveTo(4.5, -h * 0.45, 4, 0, 0, 0); ctx.bezierCurveTo(-4, 0, -4.5, -h * 0.45, 0, -h); ctx.fill();
    ctx.fillStyle = '#FFE08A'; ctx.beginPath(); ctx.moveTo(0, -h * 0.6);
    ctx.bezierCurveTo(2, -h * 0.3, 2, 0, 0, 0); ctx.bezierCurveTo(-2, 0, -2, -h * 0.3, 0, -h * 0.6); ctx.fill();
    ctx.restore();
    line([145, GROUND - 104], [145, GROUND - 107], 1, C.ink);
  } else if (flow === 'paper') {
    if (type === 'inhale') inflow(24);
    let alpha = 0, dy = 0, wob = 0;
    if (type === 'inhale') alpha = clamp01(p / 0.4);
    if (type === 'exhale') {
      alpha = 1; wob = Math.sin(time * 9) * 0.7;
      if (p > 0.88) { const k = (p - 0.88) / 0.12; dy = k * k * 40; alpha = 1 - k * 0.7; }
      outflow(172 - j.mouth[0] - 6, 7);
    }
    if (alpha > 0) rect(168.5 + wob * 0.3, j.mouth[1] - 10 + dy, 3.5, 24, C.paper, alpha, C.ink, 0.8);
  } else if (flow === 'horn') {
    if (type === 'inhale') inflow(14, 4);
    if (type === 'exhale') {
      const dyn = s.swell ? Math.sin(Math.PI * p) : 0.75;
      const bm = add(add(j.mouth, [18, 8]), [36, -14.5]);
      const base = Math.atan2(-9, 28);
      ctx.strokeStyle = C.exhale; ctx.lineCap = 'round';
      for (let i = 0; i < 3; i++) {
        const u = frac(time * 0.6 + i / 3);
        ctx.globalAlpha = Math.max(0, Math.min(1, (1 - u) * dyn * env)); ctx.lineWidth = 1.2 + 2.2 * dyn;
        ctx.beginPath(); ctx.arc(bm[0], bm[1], 6 + u * 30, base - 0.6, base + 0.6); ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }
    if (s.swell) {
      line([150, 22], [167, 16], 1.5, C.ink, 0.6); line([150, 22], [167, 28], 1.5, C.ink, 0.6);
      line([167, 16], [184, 22], 1.5, C.ink, 0.6); line([167, 28], [184, 22], 1.5, C.ink, 0.6);
      if (type === 'exhale') dot([150 + 34 * p, 22], 2.2, C.exhale);
    }
  }
}

// ── Кольори ────────────────────────────────────────────────────────────
const LIGHT = { ink: '#263238', bg: '#FAF0E6', inhale: '#1565C0', exhale: '#2E6B30', prop: '#8D6E63', brass: '#B8901C', paper: '#FFFFFF' };
const DARK = { ink: '#E3EBE3', bg: '#121A14', inhale: '#90CAF9', exhale: '#A5D6A7', prop: '#BCAAA4', brass: '#E0B84A', paper: '#ECEFF1' };
function colorsOf(canvas) {
  let dark = false;
  try { dark = matchMedia('(prefers-color-scheme: dark)').matches; } catch { /* немає */ }
  const c = { ...(dark ? DARK : LIGHT) };
  try {
    const cs = getComputedStyle(canvas);
    for (const k of Object.keys(c)) { const v = cs.getPropertyValue(`--fig-${k}`).trim(); if (v) c[k] = v; }
  } catch { /* немає стилів */ }
  return c;
}

/** Намалювати один кадр на контексті, вже масштабованому під 200×200. */
export function paintFigure(ctx, id, state, colors) {
  drawFigure(ctx, figureFrame(id, state), { ...LIGHT, ...(colors || {}) });
}

const reducedMotion = () => { try { return matchMedia('(prefers-reduced-motion: reduce)').matches; } catch { return false; } };

/**
 * Підключає анімацію до canvas. demo: true — зациклене прев'ю;
 * інакше кадр визначає стан з update(). Поза екраном, у прихованій вкладці й поки
 * полотно не на сторінці — не малює. Після закриття екрана викликайте stop().
 */
export function mountFigure(canvas, exerciseId, { demo = false } = {}) {
  const ctx = canvas.getContext('2d');
  let live = { type: 'rest', progress: 0 };
  let raf = 0, running = true, visible = true, colors = null;
  const t0 = performance.now();
  const still = demo && reducedMotion();
  const io = typeof IntersectionObserver !== 'undefined'
    ? new IntersectionObserver((es) => {
      visible = es[es.length - 1].isIntersecting;
      schedule();
    }) : null;
  io?.observe(canvas);
  const onVis = () => schedule();
  document.addEventListener('visibilitychange', onVis);
  let mq = null;
  const onScheme = () => { colors = null; schedule(); };
  try { mq = matchMedia('(prefers-color-scheme: dark)'); mq.addEventListener('change', onScheme); } catch { /* немає */ }

  function render(now) {
    raf = 0;
    if (!running) return;
    // полотно не на сторінці — не малюємо; повернеться — спостерігач його розбудить
    if (!canvas.isConnected) return;
    const t = (now - t0) / 1000;
    // для статичного прев'ю — середина вдиху
    const s = demo ? (still ? { ...demoState(exerciseId, 0), progress: 0.6, time: 1 } : demoState(exerciseId, t)) : { ...live, time: t };
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth, hgt = canvas.clientHeight;
    if (!w || !hgt) { schedule(); return; }
    const W = Math.round(w * dpr), H = Math.round(hgt * dpr);
    if (canvas.width !== W || canvas.height !== H) { canvas.width = W; canvas.height = H; colors = null; }
    colors ||= colorsOf(canvas);
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
    const k = Math.min(W, H) / 200;
    ctx.setTransform(k, 0, 0, k, (W - 200 * k) / 2, (H - 200 * k) / 2);
    drawFigure(ctx, figureFrame(exerciseId, s), colors);
    if (!still) schedule();
  }
  function schedule() {
    if (!raf && running && visible && !document.hidden) raf = requestAnimationFrame(render);
  }
  const api = {
    update(state) { live = { ...state }; schedule(); },
    /** Перечитати кольори (після зміни теми). */
    refreshColors() { colors = null; schedule(); },
    stop() {
      running = false;
      if (raf) cancelAnimationFrame(raf);
      raf = 0; io?.disconnect();
      document.removeEventListener('visibilitychange', onVis);
      try { mq?.removeEventListener('change', onScheme); } catch { /* ок */ }
    },
  };
  schedule();
  return api;
}

/** Номер підказки кроку (0/1) — сторона в «Кішці», нахил/прогин у «Маятнику». */
export function stepVariant(exercise, step) {
  const hints = exercise?.groups?.[0]?.phases?.map((x) => x.hint) || [];
  const i = hints.indexOf(step?.hint);
  return i > 0 ? 1 : 0;
}

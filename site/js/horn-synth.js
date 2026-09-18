// Синтез звуку сурми (Web Audio) — спільний для «Чарівної сурми» та метронома.
// Тембр: пила + трикутник, м'який фільтр, огинаюча, легке вібрато.

export const HORN = [
  { label: 'ДО', freq: 261.63 },
  { label: 'СОЛЬ', freq: 392.00 },
  { label: 'ДО2', freq: 523.25 },
  { label: 'МІ2', freq: 659.25 },
  { label: 'СОЛЬ2', freq: 783.99 },
];

let actx = null;
export function audioCtx() {
  if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
  if (actx.state === 'suspended') actx.resume();
  return actx;
}

/**
 * Грає ноту сурми.
 * @param freq частота, Гц
 * @param seconds тривалість
 * @param when момент старту в часі AudioContext (типово — зараз); дозволяє
 *             планувати удари метронома наперед із точністю до мілісекунд
 * @param gain гучність 0..1
 */
export function playTone(freq, seconds, when = null, gain = 1) {
  const c = audioCtx();
  const t = when ?? c.currentTime;
  const out = c.createGain();
  const peak = Math.max(0.0002, 0.5 * gain);
  out.gain.setValueAtTime(0.0001, t);
  out.gain.exponentialRampToValueAtTime(peak, t + 0.03);
  out.gain.setValueAtTime(peak, t + Math.max(0.05, seconds - 0.12));
  out.gain.exponentialRampToValueAtTime(0.0001, t + seconds + 0.05);
  const lp = c.createBiquadFilter();
  lp.type = 'lowpass'; lp.frequency.value = 1400; lp.Q.value = 0.7;
  const saw = c.createOscillator(); saw.type = 'sawtooth'; saw.frequency.value = freq;
  const tri = c.createOscillator(); tri.type = 'triangle'; tri.frequency.value = freq;
  const vib = c.createOscillator(); vib.frequency.value = 5.5;
  const vibGain = c.createGain(); vibGain.gain.value = freq * 0.004;
  vib.connect(vibGain); vibGain.connect(saw.frequency); vibGain.connect(tri.frequency);
  const sawG = c.createGain(); sawG.gain.value = 0.35;
  const triG = c.createGain(); triG.gain.value = 0.65;
  saw.connect(sawG).connect(lp); tri.connect(triG).connect(lp);
  lp.connect(out).connect(c.destination);
  [saw, tri, vib].forEach((o) => { o.start(t); o.stop(t + seconds + 0.1); });
}

// Адмін: «Практика: роботи й оцінки» — журнал студентів (прогрес, бали,
// роботи на перевірці), сторінка студента з файлами, щоденником і таблицями,
// оцінювання кроків (бали + коментар або «на доопрацювання»), експорт CSV.
import { h, icon, toast, clear, emptyState, pushScreen, appBar, spinner } from '../ui.js';
import { STAGES, ALL_STEPS, stepStatus, totals, MAX_CURRENT, MAX_EXAM } from '../practice-core.js';
import { loadAllPractice, loadStudentPractice, saveGrade } from '../practice-data.js';
import { toCsv } from '../quiz-core.js';
import { statusChip, summaryCard, fileList, diaryView, breathView, signalsView, STATE_STYLE } from './practice.js';

export function openAdminPractice() {
  pushScreen((ctx) => {
    const body = h('div', { class: 'body-inner' }, spinner());
    let students = [];
    let onlyReview = false;
    let group = '';
    const load = async () => {
      clear(body).append(spinner());
      try { students = await loadAllPractice(); draw(); } catch (e) { clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)); }
    };
    const draw = () => {
      const groups = [...new Set(students.map((s) => s.profile.group).filter(Boolean))].sort();
      const rows = students.map((s) => ({ s, t: totals(s.work, s.grades, s.ctx) }))
        .filter(({ s, t }) => (!group || s.profile.group === group) && (!onlyReview || t.review > 0));
      const reviewTotal = students.reduce((a, s) => a + totals(s.work, s.grades, s.ctx).review, 0);
      const groupSel = h('select', { onChange: (e) => { group = e.target.value; draw(); } },
        h('option', { value: '' }, 'Усі групи'), groups.map((g) => h('option', { value: g, selected: g === group }, g)));
      clear(body).append(
        h('div', { class: 'tile', style: { display: 'block' } },
          h('div', { class: 't' }, `Студентів: ${students.length} · робіт на перевірці: ${reviewTotal}`),
          h('div', { class: 's', style: { marginTop: '4px' } }, `Поточна робота — макс. ${MAX_CURRENT} (допуск від 35), залік — макс. ${MAX_EXAM}. Тести й іспит рахуються автоматично.`),
          h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '8px', marginTop: '10px', alignItems: 'center' } },
            groupSel,
            h('label', { class: 'dk-row', style: { gap: '6px' } }, h('input', { type: 'checkbox', checked: onlyReview, onChange: (e) => { onlyReview = e.target.checked; draw(); } }), 'Лише з роботами на перевірці'),
            h('button', { class: 'btn', style: { padding: '6px 14px' }, onClick: () => exportCsv(rows) }, icon('download'), 'CSV'))),
        ...(rows.length ? rows.map(({ s, t }) => h('div', { class: 'tile', style: { cursor: 'pointer', borderLeft: `4px solid ${t.review ? '#1565C0' : t.admitted ? '#2E7D32' : '#BDBDBD'}` }, onClick: () => openStudent(s.uid, load) },
          h('div', { class: 'grow' },
            h('div', { class: 't' }, s.profile.fullName || s.email || s.uid),
            h('div', { class: 's' }, `${s.profile.group || 'група не вказана'} · виконано ${t.done}/${t.count}${t.review ? ` · на перевірці: ${t.review}` : ''}`),
            h('div', { class: 's' }, `Поточна ${t.current}/${MAX_CURRENT}${t.admitted ? ' ✓ допуск' : ''} · залік ${t.exam}/${MAX_EXAM}`)),
          h('div', { style: { textAlign: 'right' } },
            h('div', { style: { fontSize: '20px', fontWeight: 700, color: 'var(--primary-dark)' } }, `${t.total}`),
            h('div', { class: 's' }, t.exam > 0 ? t.grade.ects : '—'))))
          : [emptyState('school', 'Немає студентів', 'Тут з’являться студенти, які заповнили групу в «Мої дані» або почали практику')]));
    };
    load();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Практика: роботи й оцінки', { back: ctx.pop, small: true, actions: [h('button', { class: 'iconbtn', title: 'Оновити', onClick: load }, icon('refresh'))] }),
      h('div', { class: 'body' }, body));
  });
}

function openStudent(uid, onChanged) {
  pushScreen((ctx) => {
    const body = h('div', { class: 'body-inner' }, spinner());
    let data = null;
    const load = async () => {
      try { data = await loadStudentPractice(uid); draw(); } catch (e) { clear(body).append(emptyState('error_outline', 'Помилка', e.message)); }
    };
    const draw = () => {
      const { work, grades, ctx: c, profile, email } = data;
      const nodes = [
        h('div', { class: 'tile', style: { display: 'block' } }, h('div', { class: 't' }, profile.fullName || email), h('div', { class: 's' }, `${profile.group || '—'} · ${email}`)),
        summaryCard(totals(work, grades, c)),
      ];
      let num = 0;
      for (const stage of STAGES) {
        nodes.push(h('div', { class: 'sec-title', style: { marginTop: '18px' } }, `${stage.title} · ${stage.date}`));
        for (const step of stage.steps) {
          num++;
          nodes.push(stepCard(num, step, data, async (grade) => {
            try { await saveGrade(uid, step.id, grade); toast('Збережено', 'ok'); await load(); onChanged?.(); } catch (e) { toast(`Не збережено: ${e.message}`, 'err', 5000); }
          }));
        }
      }
      clear(body).append(...nodes);
    };
    load();
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Робота студента', { back: ctx.pop, small: true }), h('div', { class: 'body' }, body));
  });
}

function stepCard(num, step, data, onGrade) {
  const { work, grades, ctx } = data;
  const st = stepStatus(step, work, grades, ctx);
  const s = work.steps?.[step.id] || {};
  const g = grades[step.id];
  const style = STATE_STYLE[st.state] || STATE_STYLE.todo;
  const parts = [
    h('div', { class: 'dk-row', style: { alignItems: 'flex-start', gap: '10px' } },
      h('div', { style: { width: '28px', height: '28px', borderRadius: '50%', background: style.bg, color: style.color, display: 'grid', placeItems: 'center', fontWeight: 700, fontSize: '12px', flex: 'none' } }, `${num}`),
      h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, step.title), statusChip(st))),
  ];
  const details = [];
  if (s.files?.length) details.push(fileList(s.files));
  if (s.note) details.push(h('div', { style: { marginTop: '6px' } }, h('b', {}, 'Коментар студента: '), s.note));
  if (step.kind === 'diary') details.push(diaryView(work.diary?.[`d${step.day}`]));
  if (step.kind === 'breath') details.push(breathView(work.breath));
  if (step.kind === 'signals') details.push(signalsView(work.signals));
  if (details.length) parts.push(h('details', { open: st.state === 'review', style: { marginTop: '8px' } }, h('summary', { style: { cursor: 'pointer', color: 'var(--primary)' } }, 'Подивитися'), ...details));

  const gradable = ['submit', 'teacher', 'exam'].includes(step.kind);
  if (gradable) {
    const max = step.points || 0;
    const pts = h('input', { type: 'number', min: 0, max, step: 1, value: g && g.status !== 'revise' && g.points != null ? g.points : '', placeholder: step.kind === 'exam' && st.points != null ? `авто: ${st.points}` : '', style: { width: '80px' } });
    const comment = h('input', { type: 'text', value: g?.comment || '', placeholder: 'Коментар студенту', style: { flex: '1 1 160px' } });
    const save = () => {
      if (max) {
        const v = Number(pts.value);
        if (pts.value === '' || !Number.isInteger(v) || v < 0 || v > max) { toast(`Бали — ціле число від 0 до ${max}`, 'err'); return; }
        onGrade({ points: v, comment: comment.value.trim(), status: 'graded' });
      } else onGrade({ points: 0, comment: comment.value.trim(), status: 'graded' });
    };
    parts.push(h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: '8px', alignItems: 'center', marginTop: '10px' } },
      max ? h('label', { class: 'dk-row', style: { gap: '4px' } }, pts, h('span', { class: 's' }, `з ${max}`)) : null,
      comment,
      h('button', { class: 'btn', style: { padding: '6px 14px' }, onClick: save }, icon('check'), max ? 'Оцінити' : 'Прийняти'),
      step.kind === 'submit' ? h('button', { class: 'btn text', style: { padding: '6px 10px', color: '#C62828' }, onClick: () => {
        if (!comment.value.trim()) { toast('Напишіть у коментарі, що доопрацювати', 'err'); return; }
        onGrade({ points: null, comment: comment.value.trim(), status: 'revise' });
      } }, icon('replay'), 'На доопрацювання') : null,
      g ? h('button', { class: 'btn text', style: { padding: '6px 10px' }, title: step.kind === 'exam' ? 'Повернути автоматичні бали іспиту' : 'Скинути оцінку', onClick: () => onGrade({ points: null, comment: '', status: 'none' }) }, icon('backspace'), 'Скинути') : null));
  }
  return h('div', { class: 'tile', style: { display: 'block', borderLeft: `4px solid ${style.color}` } }, ...parts);
}

function exportCsv(rows) {
  const steps = ALL_STEPS.filter((s) => s.group);
  const header = ['ПІБ', 'Група', 'Email', ...steps.map((s) => `${s.title} (${s.points})`), 'Поточна (60)', 'Залік (40)', 'Разом', 'ЄКТС', 'Оцінка', 'Допуск', 'Виконано пунктів', 'На перевірці'];
  const data = rows.map(({ s, t }) => [
    s.profile.fullName || '', s.profile.group || '', s.email || '',
    ...steps.map((step) => { const st = stepStatus(step, s.work, s.grades, s.ctx); return st.points ?? ''; }),
    t.current, t.exam, t.total, t.grade.ects, t.grade.nat, t.admitted ? 'так' : 'ні', `${t.done}/${t.count}`, t.review,
  ]);
  const blob = new Blob([toCsv([header, ...data])], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const a = h('a', { href: url, download: `Практика_оцінки_${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}.csv`, style: { display: 'none' } });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}

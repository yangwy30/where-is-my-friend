// Homepage interactions. Each section is a small live version of an app screen, with example data.
import {startGlobe, TRIPS} from './globe.js?v=20261021h';

const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
const fine = matchMedia('(hover: hover) and (pointer: fine)').matches;
const avatar = (initials, color, cls = 'avatar') => `<span class="${cls}" style="--c:${color}">${initials}</span>`;

// Hero globe and its destination picker.
const picker = $('.picker');
picker.innerHTML = TRIPS.map((t, i) => `<button type="button" aria-pressed="${i === 0}" data-trip="${i}"><img src="assets/emblems/${t.emblem}.png" alt="" width="30" height="30"><span>${t.city}</span></button>`).join('');
startGlobe($('#globe'), {
  caption: $('.globe-caption'),
  onTrip: i => $$('button', picker).forEach(b => b.setAttribute('aria-pressed', String(+b.dataset.trip === i))),
}).then(globe => picker.addEventListener('click', e => { const b = e.target.closest('button'); if (b) globe.go(+b.dataset.trip); })).catch(() => {});

// Friends: pick the city you're in; friends there move up and the "here too" chip follows.
const FRIENDS = [
  {name: 'Mia Chen', short: 'Mia', initials: 'MC', color: '#9E7424', city: 'New York', region: 'New York, NY', emblem: 'new_york', ago: '8m'},
  {name: 'Lin Zhao', short: 'Lin', initials: 'LZ', color: '#2F6F86', city: 'Tokyo', region: 'Tokyo', emblem: 'tokyo', ago: '18m', next: ['Tokyo', 'Oct 21 – 28']},
  {name: 'Chloe Martin', short: 'Chloe', initials: 'CM', color: '#50618F', city: 'Paris', region: 'Paris, Île-de-France', emblem: 'paris', ago: '25m', next: ['Paris', 'Oct 16 – 23']},
  {name: 'David Kim', short: 'David', initials: 'DK', color: '#9E7424', city: 'San Francisco', region: 'San Francisco, CA', emblem: 'san_francisco', ago: '45m', next: ['Kauai', 'Nov 26 – Dec 1']},
  {name: 'Alex Rivera', short: 'Alex', initials: 'AR', color: '#5E7434', city: 'London', region: 'London, England', emblem: 'london', ago: '52m'},
  {name: 'Hana Wang', short: 'Hana', initials: 'HW', color: '#5E7434', city: 'Beijing', region: 'Beijing', emblem: 'beijing', ago: '1h'},
];
const HERE = {'New York': 'New York, NY', Tokyo: 'Tokyo, Japan', Paris: 'Paris, Île-de-France', London: 'London, England'};
const grid = $('[data-friends]'), chip = $('[data-chip]');
let here = 'New York';
function renderFriends(changed) {
  const sorted = [...FRIENDS].sort((a, b) => (b.city === here) - (a.city === here));
  grid.innerHTML = sorted.map(f => {
    const same = f.city === here;
    const back = f.next
      ? `<small>Next stop</small><span class="serif">${f.next[0]}</span><span>${f.next[1]}</span>`
      : `<small>Next stop</small><b>No plans shared yet</b>`;
    return `<button type="button" class="friend${same ? ' same' : ''}${same && changed ? ' moved' : ''}" aria-label="${f.name}, ${f.region}. Show next stop.">
      <span class="friend-inner"><span class="friend-face friend-front"><img src="assets/emblems/${f.emblem}.png" alt="" width="78" height="78"><b>${f.name}</b><span>${f.region}</span><small>${same ? 'Same city · ' : ''}${f.ago}</small></span>
      <span class="friend-face friend-back">${back}</span></span></button>`;
  }).join('');
  const together = FRIENDS.filter(f => f.city === here);
  $('[data-here-line]').textContent = `You’re in ${HERE[here]}`;
  chip.classList.toggle('empty', !together.length);
  if (together.length) { const f = together[0]; $('[data-chip-avatar]').textContent = f.initials; $('[data-chip-avatar]').style.background = f.color; }
  $('[data-chip-text]').textContent = together.length ? `${together.map(f => f.short).join(' and ')} ${together.length > 1 ? 'are' : 'is'} here too` : 'No one else here yet';
  if (changed && !still) { chip.classList.remove('bump'); void chip.offsetWidth; chip.classList.add('bump'); }
}
$('[data-here]').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b || b.dataset.city === here) return;
  here = b.dataset.city;
  $$('[data-here] button').forEach(x => x.setAttribute('aria-checked', String(x === b)));
  renderFriends(true);
});
grid.addEventListener('click', e => { const card = e.target.closest('.friend'); if (card) card.classList.toggle('flipped'); });
renderFriends(false);

// Travel plans: choose a city and drag your dates. A friend's plan counts only in the same city on the same days.
const DAYS = Array.from({length: 14}, (_, i) => new Date(2026, 9, 18 + i));
const PLANS = [
  {who: 'Lin', initials: 'LZ', color: '#2F6F86', city: 'Tokyo', s: 3, e: 10, label: 'Oct 21 – 28'},
  {who: 'Chloe', initials: 'CM', color: '#50618F', city: 'Paris', s: 0, e: 5, label: 'Oct 16 – 23'},
  {who: 'Hana', initials: 'HW', color: '#5E7434', city: 'Paris', s: 8, e: 12, label: 'Oct 26 – 30'},
  {who: 'Mia', initials: 'MC', color: '#9E7424', city: 'London', s: 12, e: 13, label: 'Oct 30 – Nov 2'},
];
const EMBLEM = {Tokyo: 'tokyo', Paris: 'paris', London: 'london'};
const you = {city: 'Tokyo', s: 6, e: 9};
const days = $('[data-days]'), youBar = $('[data-bar="you"]'), plansEl = $('[data-friend-plans]'), together = $('[data-together]');
const fmt = d => d.toLocaleDateString('en-US', {month: 'short', day: 'numeric'});
const span = (s, e) => s === e ? fmt(DAYS[s]) : DAYS[s].getMonth() === DAYS[e].getMonth() ? `${fmt(DAYS[s])} – ${DAYS[e].getDate()}` : `${fmt(DAYS[s])} – ${fmt(DAYS[e])}`;
days.innerHTML = '<span></span>' + DAYS.map(d => `<span class="wd">${'SMTWTFS'[d.getDay()]}</span>`).join('') + '<span></span>' + DAYS.map(d => `<span class="day">${d.getDate()}</span>`).join('');
plansEl.innerHTML = PLANS.map((p, i) => `<div class="cal-track friend-plan" data-plan="${i}"><span class="track-name"><b>${p.who}</b><small>${p.city}</small></span>
  <div class="track"><div class="bar bar-friend" style="--c:${p.color}"><span>${p.label}</span></div></div></div>`).join('');
const cells = $$('.day', days), rows = $$('[data-plan]', plansEl);
function place(bar, s, e) {
  const track = bar.parentElement.getBoundingClientRect().width, gap = parseFloat(getComputedStyle(days).columnGap) || 4;
  const col = (track - gap * 13) / 14;
  bar.style.left = `${s * (col + gap)}px`;
  bar.style.width = `${(e - s + 1) * col + (e - s) * gap}px`;
}
function renderPlans() {
  place(youBar, you.s, you.e);
  const shared = new Set(), friends = [];
  PLANS.forEach((p, i) => {
    place($('.bar', rows[i]), p.s, p.e);
    const here = p.city === you.city, from = Math.max(p.s, you.s), to = Math.min(p.e, you.e);
    rows[i].classList.toggle('other', !here);
    rows[i].classList.toggle('match', here && from <= to);
    if (here && from <= to) { for (let d = from; d <= to; d++) shared.add(d); friends.push({...p, from, to}); }
  });
  cells.forEach((c, i) => {
    c.classList.toggle('y', i >= you.s && i <= you.e);
    c.classList.toggle('l', PLANS.some(p => p.city === you.city && i >= p.s && i <= p.e));
    c.classList.toggle('both', shared.has(i));
  });
  $('[data-plan-dates]').textContent = span(you.s, you.e);
  $('[data-you-city-label]').textContent = you.city;
  $('[data-together-city]').textContent = you.city;
  $('[data-together-emblem]').src = `assets/emblems/${EMBLEM[you.city]}.png`;
  const n = shared.size, names = friends.map(f => f.who), inCity = PLANS.filter(p => p.city === you.city);
  together.classList.toggle('none', !n);
  $('[data-together-text]').textContent = n
    ? `with ${names.join(' and ')} · ${friends.length === 1 ? span(friends[0].from, friends[0].to) + ' · ' : ''}${n} day${n > 1 ? 's' : ''} together`
    : inCity.length ? `No overlap yet. ${inCity.map(p => `${p.who} is there ${p.label}`).join('; ')}.` : 'No friends have shared plans here yet.';
  youBar.setAttribute('aria-valuetext', `${you.city}, ${span(you.s, you.e)}`);
}
$('[data-plan-city]').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b || b.dataset.city === you.city) return;
  you.city = b.dataset.city;
  $$('[data-plan-city] button').forEach(x => x.setAttribute('aria-checked', String(x === b)));
  renderPlans();
  if (!still) { together.classList.remove('bump'); void together.offsetWidth; together.classList.add('bump'); }
});
let dragging = null;
youBar.addEventListener('pointerdown', e => {
  const col = youBar.parentElement.getBoundingClientRect().width / 14;
  dragging = {mode: e.target.dataset.handle || 'move', x: e.clientX, col, s: you.s, e: you.e};
  youBar.setPointerCapture(e.pointerId); youBar.classList.add('dragging');
});
youBar.addEventListener('pointermove', e => {
  if (!dragging) return;
  const d = Math.round((e.clientX - dragging.x) / dragging.col), len = dragging.e - dragging.s;
  if (dragging.mode === 'move') { you.s = Math.max(0, Math.min(13 - len, dragging.s + d)); you.e = you.s + len; }
  if (dragging.mode === 'start') you.s = Math.max(0, Math.max(dragging.e - 9, Math.min(dragging.e, dragging.s + d)));
  if (dragging.mode === 'end') you.e = Math.min(13, Math.min(dragging.s + 9, Math.max(dragging.s, dragging.e + d)));
  renderPlans();
});
const endDrag = () => { dragging = null; youBar.classList.remove('dragging'); };
youBar.addEventListener('pointerup', endDrag); youBar.addEventListener('pointercancel', endDrag);
youBar.addEventListener('keydown', e => {
  const step = {ArrowLeft: -1, ArrowRight: 1}[e.key]; if (!step) return;
  e.preventDefault();
  if (e.shiftKey) you.e = Math.max(you.s, Math.min(13, you.s + 9, you.e + step));
  else { const len = you.e - you.s; you.s = Math.max(0, Math.min(13 - len, you.s + step)); you.e = you.s + len; }
  renderPlans();
});
new ResizeObserver(renderPlans).observe($('[data-cal]'));

// Trips: the arrivals board and boarding pass, as in the app's trip screen.
const TRAVELERS = [
  {id: 'lin', name: 'Lin Zhao', initials: 'LZ', color: '#2F6F86', sub: 'PVG · HA 862', time: '13:30', note: 'Back Dec 1', land: 13.5,
    out: {date: 'Thu, Nov 26', airline: 'HAWAIIAN 862', from: ['PVG', '21:30', 'CST', 'Shanghai'], to: ['LIH', '13:30', 'HST', 'Kauai'], dur: '10h 0m', leaves: 'Shanghai · Terminal 2'},
    back: {date: 'Tue, Dec 1', airline: 'HAWAIIAN 863', from: ['LIH', '15:20', 'HST', 'Kauai'], to: ['PVG', '21:40', 'CST', 'Shanghai', '+1'], dur: '12h 20m', leaves: 'Kauai · Terminal 1'}},
  {id: 'you', name: 'You', initials: 'WY', color: '#B2603F', sub: 'OAK · WN 1289', time: '15:46', note: 'No return yet', warn: true, land: 15.77,
    out: {date: 'Thu, Nov 26', airline: 'SOUTHWEST 1289', from: ['OAK', '12:30', 'PST', 'Oakland'], to: ['LIH', '15:46', 'HST', 'Kauai'], dur: '5h 16m', leaves: 'Oakland · Terminal 2'}},
  {id: 'david', name: 'David Kim', initials: 'DK', color: '#9E7424', sub: 'JFK · UA 1612', time: '20:05', note: 'Back Dec 1', land: 20.08,
    out: {date: 'Thu, Nov 26', airline: 'UNITED 1612', from: ['JFK', '08:15', 'EST', 'New York'], to: ['LIH', '20:05', 'HST', 'Kauai'], dur: '16h 50m', leaves: 'New York · Terminal 7'},
    back: {date: 'Tue, Dec 1', airline: 'UNITED 1611', from: ['LIH', '21:40', 'HST', 'Kauai'], to: ['JFK', '13:55', 'EST', 'New York', '+1'], dur: '11h 15m', leaves: 'Kauai · Terminal 1'}},
  {id: 'mia', name: 'Mia Chen', initials: 'MC', color: '#9E7424', sub: 'No flight yet'},
];
const board = $('[data-board]'), pass = $('[data-pass]'), toast = $('[data-toast]');
let picked = 'david', leg = 'out', reminded = false;
const x = h => `${((h - 6) / 18) * 100}%`;
$('[data-landing]').innerHTML = `<span class="fill"></span>` + TRAVELERS.filter(t => t.land).map((t, i) =>
  `<span class="pin avatar" style="--c:${t.color};left:${x(t.land)};transition-delay:${0.3 + i * 0.35}s">${t.initials}</span>`).join('');
function renderBoard() {
  board.innerHTML = TRAVELERS.map(t => `<div class="row" role="option" tabindex="0" aria-selected="${t.id === picked}" data-who="${t.id}">
    ${avatar(t.initials, t.color)}<div><b>${t.name}</b><span>${t.sub}</span></div>
    <div class="time">${t.out ? `<strong>${t.time}</strong><span class="${t.warn ? 'warn' : ''}">${t.note}</span>` : `<button type="button" class="remind" ${reminded ? 'disabled' : ''}>${reminded ? 'Reminded' : 'Remind'}</button>`}</div></div>`).join('');
  $('.board').classList.add('focus');
}
function ticket(f) {
  return `<div class="ticket-top"><b>${f.airline}</b><span>Scheduled</span></div>
    <div class="route"><span class="code">${f.from[0]}</span><span class="mid"><i></i>${f.dur}</span><span class="code">${f.to[0]}</span></div>
    <div class="times"><div><strong>${f.from[1]}</strong><small>${f.from[2]}</small><span>${f.from[3]}</span></div><div><strong>${f.to[1]}</strong><small>${f.to[4] ? f.to[4] + ' ' : ''}${f.to[2]}</small><span>${f.to[3]}</span></div></div>
    <div class="stub"><small>Leaves from</small><b>${f.leaves}</b></div>`;
}
function renderPass(flip) {
  const t = TRAVELERS.find(t => t.id === picked);
  const flight = t[leg];
  const body = !t.out
    ? `<div class="empty-ticket"><b>No flight yet</b><span>Mia hasn’t added a flight. Send a reminder from the board.</span></div>`
    : flight ? ticket(flight) : `<div class="empty-ticket"><b>No return yet</b><span>Add a flight home whenever it’s booked.</span></div>`;
  const draw = () => {
    pass.innerHTML = `<div class="pass-who">${avatar(t.initials, t.color)}<b>${t.name}</b></div>
      <div class="legs"><button type="button" class="leg" data-leg="out" aria-pressed="${leg === 'out'}" ${t.out ? '' : 'disabled'}><small>Out</small><span>${t.out ? t.out.date : '—'}</span></button>
      <button type="button" class="leg" data-leg="back" aria-pressed="${leg === 'back'}" ${t.out ? '' : 'disabled'}><small>Back</small><span>${t.back ? t.back.date : 'Not added'}</span></button></div>
      <div class="ticket${flip ? ' flip-out' : ''}">${body}</div>${t.out ? '<p class="nights">5 nights in Kauai</p>' : ''}`;
    if (flip) requestAnimationFrame(() => requestAnimationFrame(() => { const el = $('.ticket', pass); el.classList.remove('flip-out'); el.classList.add('flip-in'); }));
  };
  if (flip && !still) { $('.ticket', pass)?.classList.add('flip-out'); setTimeout(draw, 160); } else draw();
}
board.addEventListener('click', e => {
  if (e.target.closest('.remind')) {
    reminded = true; renderBoard();
    toast.textContent = 'Mia will get a nudge to add her flight.'; toast.classList.add('show');
    clearTimeout(toast._t); toast._t = setTimeout(() => toast.classList.remove('show'), 2600);
    return;
  }
  const row = e.target.closest('.row'); if (!row || row.dataset.who === picked) return;
  picked = row.dataset.who; leg = 'out'; renderBoard(); renderPass(true);
});
board.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); e.target.closest('.row')?.click(); } });
pass.addEventListener('click', e => {
  const b = e.target.closest('.leg'); if (!b || b.disabled || b.dataset.leg === leg) return;
  leg = b.dataset.leg; renderPass(true);
});
renderBoard(); renderPass(false);

// Privacy: what Lin sees, and whether you'd be told when Lin lands in your city.
const share = $('[data-share]'), alert = $('[data-alert]'), youCard = $('[data-you-card]'), banner = $('[data-banner]'), note = $('[data-arrive-note]');
const renderShare = () => {
  youCard.classList.toggle('hidden', !share.checked);
  $('[data-you-city]').textContent = share.checked ? 'New York, NY' : 'City not shared';
  $('[data-you-status]').textContent = share.checked ? 'Updated just now' : 'Sharing paused for Lin';
};
share.addEventListener('change', renderShare);
alert.addEventListener('change', () => { note.textContent = ''; });
$('[data-arrive]').addEventListener('click', () => {
  banner.classList.remove('show');
  if (alert.checked) {
    requestAnimationFrame(() => banner.classList.add('show'));
    clearTimeout(banner._t); banner._t = setTimeout(() => banner.classList.remove('show'), 3200);
    note.textContent = 'Lin landed in New York, so you got a same-city alert.';
  } else note.textContent = 'Lin landed in New York. Alerts are off for Lin, so nothing was sent.';
});
renderShare();

// Widgets: light or dark.
$('[data-look]').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  $$('[data-look] button').forEach(x => x.setAttribute('aria-checked', String(x === b)));
  $$('[data-widgets] img').forEach(img => {
    img.classList.add('swap');
    setTimeout(() => { img.src = img.dataset[b.dataset.lookMode]; img.onload = () => img.classList.remove('swap'); }, still ? 0 : 200);
  });
});

// Tilt and spotlight follow the pointer on devices with one.
if (fine && !still) {
  $$('[data-tilt]').forEach(el => {
    el.addEventListener('pointermove', e => {
      const r = el.getBoundingClientRect(), px = (e.clientX - r.left) / r.width - 0.5, py = (e.clientY - r.top) / r.height - 0.5;
      el.style.setProperty('--ry', `${px * 10}deg`); el.style.setProperty('--rx', `${-py * 8}deg`);
    });
    el.addEventListener('pointerleave', () => { el.style.setProperty('--ry', '0deg'); el.style.setProperty('--rx', '0deg'); });
  });
  $$('[data-spotlight]').forEach(el => el.addEventListener('pointermove', e => {
    const r = el.getBoundingClientRect();
    el.style.setProperty('--mx', `${e.clientX - r.left}px`); el.style.setProperty('--my', `${e.clientY - r.top}px`);
  }));
}

// Reveal on scroll; count up the moments total and fill the landing line.
const count = el => {
  const to = +el.dataset.countTo; if (still) return;
  const t0 = performance.now();
  const step = now => { const k = Math.min(1, (now - t0) / 1400); el.textContent = Math.round(to * (1 - Math.pow(1 - k, 3))); if (k < 1) requestAnimationFrame(step); };
  requestAnimationFrame(step);
};
const io = new IntersectionObserver(entries => entries.forEach(({target, isIntersecting}) => {
  if (!isIntersecting) return;
  target.classList.add('in'); io.unobserve(target);
  $$('[data-count-to]', target).forEach(count);
  if (target.classList.contains('trip-stage')) { $('.board').classList.add('in'); $('.landing-line .fill').style.width = x(20.08); }
}), {threshold: 0.2});
$$('.reveal').forEach(el => io.observe(el));

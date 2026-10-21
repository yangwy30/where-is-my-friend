// The hero globe: a web port of the app's trip globe (TripGlobeBoard.swift) in its dark palette.
// Same land dots, projection, arcs and entrance timing. Visitors can spin it, pick a destination,
// and point at a route to light up one friend's flight, as tapping a traveler does in the app.
const C = {
  fresh: '166,230,119', surface: '17,34,23', freshSurface: '25,60,40', sun: '205,247,77',
  border: 'rgba(45,77,57,.76)', text: '#EDF9F1',
};
// WIFPersonPalette dark fills, indexed the way the app hashes each name.
export const PEOPLE = {
  Mia: ['MC', '#B68C3C'], Lin: ['LZ', '#4A8EA6'], Chloe: ['CM', '#6E80AE'],
  David: ['DK', '#B68C3C'], Alex: ['AR', '#7A9150'], Hana: ['HW', '#7A9150'], You: ['WY', '#C77A5A'],
};
const AIRPORTS = {
  HND: [139.78, 35.55, 'Tokyo'], JFK: [-73.78, 40.64, 'New York'], CDG: [2.55, 49.01, 'Paris'], SFO: [-122.38, 37.62, 'San Francisco'],
  PVG: [121.81, 31.14, 'Shanghai'], LHR: [-0.45, 51.47, 'London'], HNL: [-157.92, 21.32, 'Honolulu'], SYD: [151.18, -33.94, 'Sydney'],
  OAK: [-122.22, 37.72, 'Oakland'], SIN: [103.99, 1.36, 'Singapore'], DXB: [55.36, 25.25, 'Dubai'], CPT: [18.6, -33.97, 'Cape Town'],
  GRU: [-46.47, -23.43, 'São Paulo'], AKL: [174.79, -37.0, 'Auckland'],
};
export const TRIPS = [
  {city: 'Tokyo', code: 'HND', emblem: 'tokyo', when: 'Oct 24', flights: [['Lin', 'PVG', '10:30'], ['Hana', 'SIN', '06:40'], ['David', 'SFO', '13:05']]},
  {city: 'Paris', code: 'CDG', emblem: 'paris', when: 'Dec 19', flights: [['Mia', 'JFK', '18:10'], ['Hana', 'DXB', '02:15'], ['Chloe', 'CPT', '19:40']]},
  {city: 'Honolulu', code: 'HNL', emblem: 'honolulu', when: 'Nov 26', flights: [['Lin', 'PVG', '22:10'], ['You', 'OAK', '12:30'], ['David', 'JFK', '08:15']]},
  {city: 'New York', code: 'JFK', emblem: 'new_york', when: 'Jan 2', flights: [['Alex', 'LHR', '08:40'], ['David', 'SFO', '22:05'], ['Chloe', 'GRU', '21:55']]},
  {city: 'Sydney', code: 'SYD', emblem: 'sydney', when: 'Feb 14', flights: [['Mia', 'HND', '21:30'], ['Hana', 'SIN', '20:05'], ['David', 'AKL', '07:15']]},
];
const draw = i => 0.25 + i * 0.55, fly = i => draw(i) + 0.55, land = i => fly(i) + 2.3;
const ease = t => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
const clamp = t => Math.max(0, Math.min(1, t));
const pop = s => { if (s <= 0) return 0; const t = Math.min(1, s / 0.45); return 1 + 0.18 * Math.sin(t * Math.PI) * (1 - t) * 3 - (1 - t) ** 3; };
const HOLD = land(2) + 3.2, TURN = 1.6, IDLE = 14, RAD = Math.PI / 180;
const view = code => ({lon: AIRPORTS[code][0] - 8, lat: Math.max(-45, Math.min(45, AIRPORTS[code][1] * 0.7))});
const lerpAngle = (a, b, t) => a + ((((b - a) % 360) + 540) % 360 - 180) * t;
const names = list => list.length < 2 ? list.join('') : `${list.slice(0, -1).join(', ')} and ${list.at(-1)}`;

export async function startGlobe(canvas, {caption, onTrip} = {}) {
  const ctx = canvas.getContext('2d');
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const dots = (await (await fetch(canvas.dataset.dots)).json()).dots;
  const emblems = Object.fromEntries(TRIPS.map(t => { const img = new Image(); img.src = `${canvas.dataset.emblems}/${t.emblem}.png`; return [t.emblem, img]; }));
  const plane = new Path2D('M9 0Q7 -1.6 2 -1.6L-2 -8L-4.2 -8L-2.2 -1.6L-6.5 -1.6L-8.5 -4.2L-10 -4.2L-9 0L-10 4.2L-8.5 4.2L-6.5 1.6L-2.2 1.6L-4.2 8L-2 8L2 1.6Q7 1.6 9 0Z');
  let w = 0, h = 0, dpr = 1, R = 0, cx = 0, cy = 0, visible = true, clock = 0;
  // Scene: which trip is landing, when it started, and an optional turn toward the next one.
  let index = 0, start = 0, turn = null, lastTouch = -IDLE, hovered = null, selected = null, markers = [];
  // Spin: an offset the visitor adds by dragging, with momentum, that eases home when left alone.
  const spin = {lon: 0, lat: 0, vlon: 0, vlat: 0}, drag = {on: false, x: 0, y: 0, moved: 0};

  function resize() {
    const box = canvas.getBoundingClientRect();
    dpr = Math.min(2, devicePixelRatio || 1); w = box.width; h = box.height;
    canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
    const side = Math.min(w, h / 1.07);
    R = side * 0.44; cx = w / 2; cy = side * 0.5;
  }

  function projector(lon0, lat0) {
    const p0 = lat0 * RAD, sp0 = Math.sin(p0), cp0 = Math.cos(p0);
    return (lon, lat, alt = 0) => {
      const l = (lon - lon0) * RAD, p = lat * RAD, r = R * (1 + alt), cp = Math.cos(p), sp = Math.sin(p), cl = Math.cos(l);
      const depth = sp0 * sp + cp0 * cp * cl;
      return {x: cx + r * cp * Math.sin(l), y: cy - r * (cp0 * sp - sp0 * cp * cl), front: depth > 0, depth};
    };
  }

  function arc(project, a, b, steps = 120) {
    const v = c => [Math.cos(c[1] * RAD) * Math.cos(c[0] * RAD), Math.cos(c[1] * RAD) * Math.sin(c[0] * RAD), Math.sin(c[1] * RAD)];
    const va = v(a), vb = v(b), angle = Math.acos(Math.max(-1, Math.min(1, va[0] * vb[0] + va[1] * vb[1] + va[2] * vb[2])));
    const out = [];
    for (let s = 0; s <= steps; s++) {
      const t = s / steps, ka = Math.sin((1 - t) * angle) / Math.sin(angle), kb = Math.sin(t * angle) / Math.sin(angle);
      const x = va[0] * ka + vb[0] * kb, y = va[1] * ka + vb[1] * kb, z = va[2] * ka + vb[2] * kb;
      const q = project(Math.atan2(y, x) / RAD, Math.asin(Math.max(-1, Math.min(1, z))) / RAD, Math.sin(Math.PI * t) * Math.min(0.3, angle * 0.22));
      out.push([q.x, q.y, q.front || Math.hypot(q.x - cx, q.y - cy) > R]);
    }
    return out;
  }

  function stroke(points, from, to, width, color, dash) {
    const last = points.length - 1;
    ctx.beginPath(); let open = false;
    for (let i = Math.max(0, from); i <= Math.max(0, Math.min(last, to)); i++) {
      const [x, y, seen] = points[i];
      if (!seen) { open = false; continue; }
      open ? ctx.lineTo(x, y) : ctx.moveTo(x, y); open = true;
    }
    ctx.setLineDash(dash || []); ctx.lineWidth = width; ctx.lineCap = 'round'; ctx.strokeStyle = color; ctx.stroke(); ctx.setLineDash([]);
  }

  function currentView() {
    if (!turn) return view(TRIPS[index].code);
    const k = ease(clamp((clock - turn.start) / TURN)), a = turn.from, b = view(TRIPS[turn.to].code);
    return {lon: lerpAngle(a.lon, b.lon, k), lat: a.lat + (b.lat - a.lat) * k};
  }
  function go(next, byVisitor) {
    next = ((next % TRIPS.length) + TRIPS.length) % TRIPS.length;
    if (byVisitor) lastTouch = clock;
    selected = hovered = null;
    turn = {from: currentView(), to: next, start: clock};
    onTrip?.(next);
  }

  function render() {
    if (turn && clock - turn.start >= TURN) { index = turn.to; start = clock; turn = null; }
    if (!turn && !still && clock - start > HOLD && clock - lastTouch > IDLE && !selected) go(index + 1);
    const trip = TRIPS[index], v = currentView();
    const project = projector(v.lon + spin.lon, Math.max(-60, Math.min(60, v.lat + spin.lat)));
    const t = still ? 99 : clock - start, fade = turn ? 1 - clamp((clock - turn.start) / 0.5) : 1;
    const focus = selected || hovered, lit = who => !focus || focus === who;

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
    let g = ctx.createRadialGradient(cx, cy, R * 0.85, cx, cy, R + 40);
    g.addColorStop(0, `rgba(${C.sun},0)`); g.addColorStop(0.45, `rgba(${C.sun},.13)`); g.addColorStop(1, `rgba(${C.sun},0)`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, R + 40, 0, Math.PI * 2); ctx.fill();
    g = ctx.createRadialGradient(cx - R * 0.35, cy - R * 0.4, 0, cx - R * 0.35, cy - R * 0.4, R * 1.4);
    g.addColorStop(0, `rgb(${C.surface})`); g.addColorStop(1, `rgba(${C.freshSurface},.55)`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = C.border; ctx.lineWidth = 1; ctx.stroke();
    // Land, with a slow band of light passing across it.
    const sweep = ((clock / 9) % 1) * 260 - 130 + v.lon + 8;
    for (const [lon, lat] of dots) {
      const p = project(lon, lat);
      if (!p.front) continue;
      const glint = still ? 0 : Math.max(0, 1 - Math.abs(lon - sweep) / 18) * 0.35;
      const alpha = Math.min(1, 0.2 + 0.5 * (0.3 + 0.7 * p.depth) + glint) * 0.8;
      const r = Math.max(0.8, 1.35 * (0.55 + 0.45 * p.depth));
      ctx.fillStyle = `rgba(${C.fresh},${alpha.toFixed(3)})`; ctx.fillRect(p.x - r, p.y - r, r * 2, r * 2);
    }
    const dest = AIRPORTS[trip.code], island = project(dest[0], dest[1]);
    ctx.globalAlpha = Math.max(0, fade);
    markers = [];
    const routes = trip.flights.map(([who, from, time], i) => ({who, from, time, i, points: arc(project, AIRPORTS[from], dest)}));
    for (const {who, from, time, i, points} of routes) {
      const on = lit(who), active = focus === who, last = points.length - 1;
      const drawn = ease(clamp((t - draw(i)) / 0.8)), flown = ease(clamp((t - fly(i)) / 2.3));
      stroke(points, 0, Math.floor(last * drawn), 1.4, `rgba(${C.fresh},${on ? 0.5 : 0.12})`, [1.5, 4.5]);
      const head = Math.floor(last * flown);
      if (flown > 0) stroke(points, flown < 1 ? head - 34 : 0, head, flown < 1 || active ? 2.4 : 1.6, `rgba(${C.fresh},${on ? (flown < 1 ? 1 : 0.8) : 0.16})`);
      if (flown >= 1 && !still) {
        const phase = (((t - land(i)) / (active ? 2.2 : 7) + i * 0.31) % 1) * 1.4;
        if (phase < 1) stroke(points, Math.floor(last * phase) - 10, Math.floor(last * phase), 2.6, `rgba(${C.sun},${on ? 0.9 : 0.25})`);
      }
      if (flown > 0 && flown < 1 && points[head][2]) {
        const p = points[Math.max(0, head - 2)], q = points[Math.min(last, head + 2)];
        ctx.save(); ctx.globalAlpha *= on ? 1 : 0.35; ctx.translate(points[head][0], points[head][1]); ctx.rotate(Math.atan2(q[1] - p[1], q[0] - p[0])); ctx.scale(1.15, 1.15);
        ctx.lineWidth = 1.8; ctx.lineJoin = 'round'; ctx.strokeStyle = `rgb(${C.surface})`; ctx.stroke(plane);
        ctx.fillStyle = PEOPLE[who][1]; ctx.fill(plane); ctx.restore();
        markers.push({who, x: points[head][0], y: points[head][1], r: 22});
      }
      const home = points.find(p => p[2]);
      if (drawn > 0.05 && home) {
        const label = `${from}  ${time}`;
        ctx.font = '600 11px Geist, system-ui, sans-serif';
        const width = ctx.measureText(label).width + 14, x = Math.min(w - width / 2 - 6, Math.max(width / 2 + 6, home[0])), y = home[1] - 12;
        ctx.save(); ctx.globalAlpha *= Math.min(1, drawn * 3) * (on ? 1 : 0.4);
        ctx.fillStyle = active ? `rgb(${C.fresh})` : `rgba(${C.surface},.94)`; ctx.beginPath(); ctx.roundRect(x - width / 2, y - 9, width, 18, 9); ctx.fill();
        ctx.strokeStyle = C.border; ctx.stroke();
        ctx.fillStyle = active ? '#0E1A13' : C.text; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(label, x, y + 0.5); ctx.restore();
        markers.push({who, x, y, r: width / 2 + 8});
      }
    }
    for (const {i} of routes) {
      const since = t - land(i);
      if (since <= 0 || since >= 1.1) continue;
      const q = since / 1.1;
      ctx.strokeStyle = `rgba(${C.fresh},${0.35 * (1 - q)})`; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.ellipse(island.x, island.y + 4, 20 + 46 * q, 7 + 15 * q, 0, 0, Math.PI * 2); ctx.stroke();
    }
    const hop = Math.max(0, ...routes.map(({i}) => { const s = t - land(i); return s > 0 && s < 0.3 ? Math.sin(s / 0.3 * Math.PI) : 0; }));
    const img = emblems[trip.emblem], size = Math.max(64, R * 0.3);
    if (img.complete && img.naturalWidth && island.front) {
      ctx.save(); ctx.shadowColor = 'rgba(0,0,0,.35)'; ctx.shadowBlur = 18; ctx.shadowOffsetY = 10;
      ctx.drawImage(img, island.x - size / 2, island.y - size * 0.82 - hop * 6, size, size); ctx.restore();
    }
    routes.forEach(({who, i}) => {
      const s = pop(t - land(i)); if (s <= 0 || !island.front) return;
      const x = island.x + 6 + (i - (routes.length - 1) / 2) * 20, y = island.y + 22, r = 12 * s * (focus === who ? 1.2 : 1);
      ctx.save(); ctx.globalAlpha *= lit(who) ? 1 : 0.45;
      ctx.fillStyle = PEOPLE[who][1]; ctx.strokeStyle = `rgb(${C.surface})`; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#fff'; ctx.font = `600 ${(9 * r / 12).toFixed(1)}px Geist, system-ui, sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(PEOPLE[who][0], x, y + 0.5); ctx.restore();
      markers.push({who, x, y, r: 14});
    });
    ctx.globalAlpha = 1;
    if (caption) {
      const flight = focus && trip.flights.find(f => f[0] === focus);
      const text = flight
        ? [`${flight[0]} from ${AIRPORTS[flight[1]][2]}`, `${flight[1]} → ${trip.code} · departs ${flight[2]} local time`]
        : [trip.city, `${names(trip.flights.map(f => f[0] === 'You' ? 'you' : f[0]))} land ${trip.when}`];
      const key = text.join('|');
      if (caption.dataset.key !== key) {
        caption.dataset.key = key;
        caption.querySelector('[data-city]').textContent = text[0];
        caption.querySelector('[data-who]').textContent = text[1];
      }
      caption.style.opacity = turn ? String(1 - clamp((clock - turn.start) / 0.4)) : String(still ? 1 : clamp(t / 0.5));
    }
  }

  // Pointer: drag spins with momentum; hover or tap a route, plane or avatar to light up that flight.
  const hit = e => {
    const box = canvas.getBoundingClientRect(), x = e.clientX - box.left, y = e.clientY - box.top;
    let best = null, dist = Infinity;
    for (const m of markers) { const d = Math.hypot(m.x - x, m.y - y); if (d < m.r && d < dist) { best = m.who; dist = d; } }
    return best;
  };
  canvas.addEventListener('pointerdown', e => { drag.on = true; drag.x = e.clientX; drag.y = e.clientY; drag.moved = 0; canvas.setPointerCapture(e.pointerId); lastTouch = clock; });
  canvas.addEventListener('pointermove', e => {
    if (drag.on) {
      const dx = e.clientX - drag.x, dy = e.clientY - drag.y; drag.x = e.clientX; drag.y = e.clientY; drag.moved += Math.abs(dx) + Math.abs(dy);
      spin.vlon = -dx * 0.28; spin.vlat = dy * 0.22; spin.lon += spin.vlon; spin.lat = Math.max(-35, Math.min(35, spin.lat + spin.vlat));
      lastTouch = clock;
      if (still) render();
    } else if (e.pointerType === 'mouse') {
      const next = hit(e);
      if (next !== hovered) { hovered = next; canvas.style.cursor = hovered ? 'pointer' : 'grab'; if (still) render(); }
    }
  });
  canvas.addEventListener('pointerup', e => {
    drag.on = false;
    if (drag.moved < 6) { const who = hit(e); selected = who && who !== selected ? who : null; lastTouch = clock; if (still) render(); }
  });
  canvas.addEventListener('pointercancel', () => { drag.on = false; });
  canvas.addEventListener('pointerleave', () => { hovered = null; if (still) render(); });

  let before = performance.now();
  resize(); new ResizeObserver(() => { resize(); if (still) render(); }).observe(canvas);
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(canvas);
  const tick = now => {
    const dt = Math.max(0, Math.min(0.05, (now - before) / 1000)); before = now;
    if (visible && !document.hidden) {
      clock += dt;
      if (!drag.on) {
        spin.lon += spin.vlon; spin.lat = Math.max(-35, Math.min(35, spin.lat + spin.vlat));
        spin.vlon *= 0.93; spin.vlat *= 0.93;
        if (clock - lastTouch > 2.5) { spin.lon *= 0.97; spin.lat *= 0.97; }
      }
      render();
    }
    requestAnimationFrame(tick);
  };
  onTrip?.(0);
  if (still) render(); else requestAnimationFrame(tick);
  canvas.classList.add('ready');
  return {
    go(i) {
      if (still) { index = ((i % TRIPS.length) + TRIPS.length) % TRIPS.length; selected = hovered = null; onTrip?.(index); render(); }
      else go(i, true);
    },
  };
}

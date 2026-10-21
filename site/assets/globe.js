// The hero globe: a web port of the app's trip globe (TripGlobeBoard.swift) in its dark palette.
// Same land dots, projection, arcs and entrance timing; between trips it turns to the next city.
const C = {
  fresh: '166,230,119', surface: '17,34,23', freshSurface: '25,60,40', sun: '205,247,77',
  border: 'rgba(45,77,57,.76)', text: '#EDF9F1',
};
// WIFPersonPalette dark fills, indexed the way the app hashes each name.
const PEOPLE = {
  Mia: ['MC', '#B68C3C'], Lin: ['LZ', '#4A8EA6'], Chloe: ['CM', '#6E80AE'],
  David: ['DK', '#B68C3C'], Alex: ['AR', '#7A9150'], Hana: ['HW', '#7A9150'], You: ['WY', '#C77A5A'],
};
const AIRPORTS = {
  HND: [139.78, 35.55], JFK: [-73.78, 40.64], CDG: [2.55, 49.01], SFO: [-122.38, 37.62], PVG: [121.81, 31.14],
  LHR: [-0.45, 51.47], HNL: [-157.92, 21.32], SYD: [151.18, -33.94], OAK: [-122.22, 37.72], ICN: [126.44, 37.46],
  PEK: [116.58, 40.08], SIN: [103.99, 1.36], DXB: [55.36, 25.25], CPT: [18.6, -33.97], GRU: [-46.47, -23.43],
  AKL: [174.79, -37.0], HKG: [113.92, 22.31],
};
const TRIPS = [
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
const HOLD = land(2) + 2.6, TURN = 1.8, RAD = Math.PI / 180;
const view = c => ({lon: c[0] - 8, lat: Math.max(-45, Math.min(45, c[1] * 0.7))});
const lerpAngle = (a, b, t) => a + ((((b - a) % 360) + 540) % 360 - 180) * t;

export async function startGlobe(canvas, caption) {
  const ctx = canvas.getContext('2d');
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const dots = (await (await fetch(canvas.dataset.dots)).json()).dots;
  const emblems = Object.fromEntries(TRIPS.map(t => { const img = new Image(); img.src = `${canvas.dataset.emblems}/${t.emblem}.png`; return [t.emblem, img]; }));
  const plane = new Path2D('M9 0Q7 -1.6 2 -1.6L-2 -8L-4.2 -8L-2.2 -1.6L-6.5 -1.6L-8.5 -4.2L-10 -4.2L-9 0L-10 4.2L-8.5 4.2L-6.5 1.6L-2.2 1.6L-4.2 8L-2 8L2 1.6Q7 1.6 9 0Z');
  let w = 0, h = 0, dpr = 1, R = 0, cx = 0, cy = 0, drag = {lon: 0, lat: 0}, pull = null, visible = true, frame = 0;

  function resize() {
    const box = canvas.getBoundingClientRect();
    dpr = Math.min(2, devicePixelRatio || 1); w = box.width; h = box.height;
    canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
    // The stage is taller than wide: the globe sits in the top square, the caption below it.
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

  function render(clock) {
    const cycle = HOLD + TURN, n = Math.floor(clock / cycle), k = clock - n * cycle;
    const at = i => TRIPS[((i % TRIPS.length) + TRIPS.length) % TRIPS.length];
    const trip = at(n), next = at(n + 1);
    const turning = k > HOLD ? ease(clamp((k - HOLD) / TURN)) : 0;
    const a = view(AIRPORTS[trip.code]), b = view(AIRPORTS[next.code]);
    const lon0 = lerpAngle(a.lon, b.lon, turning) + drag.lon, lat0 = a.lat + (b.lat - a.lat) * turning + drag.lat;
    const project = projector(lon0, Math.max(-60, Math.min(60, lat0)));
    const t = still ? 99 : k, fade = 1 - clamp((k - HOLD) / 0.6);

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
    // Glow, body and rim.
    let g = ctx.createRadialGradient(cx, cy, R * 0.85, cx, cy, R + 40);
    g.addColorStop(0, `rgba(${C.sun},0)`); g.addColorStop(0.45, `rgba(${C.sun},.13)`); g.addColorStop(1, `rgba(${C.sun},0)`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, R + 40, 0, Math.PI * 2); ctx.fill();
    g = ctx.createRadialGradient(cx - R * 0.35, cy - R * 0.4, 0, cx - R * 0.35, cy - R * 0.4, R * 1.4);
    g.addColorStop(0, `rgb(${C.surface})`); g.addColorStop(1, `rgba(${C.freshSurface},.55)`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = C.border; ctx.lineWidth = 1; ctx.stroke();
    // Land, with a slow band of light passing across it.
    const sweep = ((clock / 9) % 1) * 260 - 130 + AIRPORTS[trip.code][0];
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
    const routes = trip.flights.map(([who, from, time], i) => ({who, from, time, i, points: arc(project, AIRPORTS[from], dest)}));
    for (const {who, from, time, i, points} of routes) {
      const last = points.length - 1, drawn = ease(clamp((t - draw(i)) / 0.8)), flown = ease(clamp((t - fly(i)) / 2.3));
      stroke(points, 0, Math.floor(last * drawn), 1.4, `rgba(${C.fresh},.5)`, [1.5, 4.5]);
      const head = Math.floor(last * flown);
      if (flown > 0) stroke(points, flown < 1 ? head - 34 : 0, head, flown < 1 ? 2.4 : 1.6, `rgba(${C.fresh},${flown < 1 ? 1 : 0.75})`);
      if (flown >= 1 && !still) {
        const phase = (((t - land(i)) / 7 + i * 0.31) % 1) * 1.4;
        if (phase < 1) stroke(points, Math.floor(last * phase) - 10, Math.floor(last * phase), 2.6, `rgba(${C.sun},.9)`);
      }
      if (flown > 0 && flown < 1 && points[head][2]) {
        const p = points[Math.max(0, head - 2)], q = points[Math.min(last, head + 2)];
        ctx.save(); ctx.translate(points[head][0], points[head][1]); ctx.rotate(Math.atan2(q[1] - p[1], q[0] - p[0])); ctx.scale(1.15, 1.15);
        ctx.lineWidth = 1.8; ctx.lineJoin = 'round'; ctx.strokeStyle = `rgb(${C.surface})`; ctx.stroke(plane);
        ctx.fillStyle = PEOPLE[who][1]; ctx.fill(plane); ctx.restore();
      }
      const home = points.find(p => p[2]);
      if (drawn > 0.05 && home) {
        const label = `${from}  ${time}`;
        ctx.font = '600 11px Geist, system-ui, sans-serif';
        const width = ctx.measureText(label).width + 14, x = Math.min(w - width / 2 - 6, Math.max(width / 2 + 6, home[0])), y = home[1] - 12;
        ctx.save(); ctx.globalAlpha *= Math.min(1, drawn * 3);
        ctx.fillStyle = `rgba(${C.surface},.94)`; ctx.beginPath(); ctx.roundRect(x - width / 2, y - 9, width, 18, 9); ctx.fill();
        ctx.strokeStyle = C.border; ctx.stroke();
        ctx.fillStyle = C.text; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(label, x, y + 0.5); ctx.restore();
      }
    }
    // Ripples as each traveler lands, the emblem's hop, then everyone gathered underneath.
    for (const {i} of routes) {
      const since = t - land(i);
      if (since <= 0 || since >= 1.1) continue;
      const q = since / 1.1;
      ctx.strokeStyle = `rgba(${C.fresh},${0.35 * (1 - q)})`; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.ellipse(island.x, island.y + 4, 20 + 46 * q, 7 + 15 * q, 0, 0, Math.PI * 2); ctx.stroke();
    }
    const hop = Math.max(0, ...routes.map(({i}) => { const s = t - land(i); return s > 0 && s < 0.3 ? Math.sin(s / 0.3 * Math.PI) : 0; }));
    const img = emblems[trip.emblem], size = Math.max(64, R * 0.3);
    if (img.complete && img.naturalWidth) {
      ctx.save(); ctx.shadowColor = 'rgba(0,0,0,.35)'; ctx.shadowBlur = 18; ctx.shadowOffsetY = 10;
      ctx.drawImage(img, island.x - size / 2, island.y - size * 0.82 - hop * 6, size, size); ctx.restore();
    }
    routes.forEach(({who, i}) => {
      const s = pop(t - land(i)); if (s <= 0) return;
      const x = island.x + 6 + (i - (routes.length - 1) / 2) * 20, y = island.y + 22, r = 12 * s;
      ctx.fillStyle = PEOPLE[who][1]; ctx.strokeStyle = `rgb(${C.surface})`; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#fff'; ctx.font = `600 ${9 * s}px Geist, system-ui, sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(PEOPLE[who][0], x, y + 0.5);
    });
    ctx.globalAlpha = 1;
    if (caption && caption.dataset.trip !== String(n)) {
      caption.dataset.trip = String(n);
      const names = trip.flights.map(f => f[0] === 'You' ? 'you' : f[0]);
      caption.querySelector('[data-city]').textContent = trip.city;
      caption.querySelector('[data-who]').textContent = `${names.slice(0, -1).join(', ')} and ${names.at(-1)} land ${trip.when}`;
    }
    if (caption) caption.style.opacity = still ? 1 : String(Math.min(clamp(k / 0.5), fade < 1 ? fade : 1));
  }

  // Drag turns the globe a little; it settles back when let go.
  canvas.addEventListener('pointerdown', e => { pull = {x: e.clientX, y: e.clientY, lon: drag.lon, lat: drag.lat}; canvas.setPointerCapture(e.pointerId); });
  canvas.addEventListener('pointermove', e => { if (pull) drag = {lon: pull.lon - (e.clientX - pull.x) * 0.25, lat: Math.max(-30, Math.min(30, pull.lat + (e.clientY - pull.y) * 0.2))}; });
  const release = () => { pull = null; };
  canvas.addEventListener('pointerup', release); canvas.addEventListener('pointercancel', release);

  resize(); new ResizeObserver(resize).observe(canvas);
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(canvas);
  let clock = 0, before = performance.now();
  const tick = now => {
    const dt = Math.max(0, Math.min(0.05, (now - before) / 1000)); before = now;
    if (visible && !document.hidden) {
      clock += dt;
      if (!pull) { drag.lon *= 0.94; drag.lat *= 0.94; }
      render(clock);
    }
    frame = requestAnimationFrame(tick);
  };
  if (still) { render(0); new ResizeObserver(() => render(0)).observe(canvas); }
  else frame = requestAnimationFrame(tick);
  canvas.classList.add('ready');
  return () => cancelAnimationFrame(frame);
}

// App Store screenshots, 2026-10-20 set. Real 1.0.9 simulator captures in a plain phone frame.
// Rules: one idea per frame, headline + one line, no eyebrow labels, no floating stickers,
// nothing overlaps text, status bar 9:41 in every capture.
//
// Run: NODE_PATH=<dir with sharp>/node_modules node scripts/render_store_20261020.mjs
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const sharp = createRequire(import.meta.url)('sharp');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const set = path.join(root, 'docs/app_store_screenshots/2026-10-20');
const raw = path.join(set, 'raw');
const work = path.join(set, '.work');
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const sizes = [[1320, 2868], [1284, 2778], [1242, 2688], [1206, 2622]];

const theme = {
  lime: {bg: '#A6E677', title: '#0E1A13', sub: 'rgba(14,26,19,.62)', shadow: 'rgba(14,40,10,.45)'},
  mist: {bg: '#F3F4F0', title: '#0E1A13', sub: '#6B7570', shadow: 'rgba(14,26,19,.30)'},
  ink: {bg: '#0E1A13', title: '#FFFFFF', sub: '#8B968F', shadow: 'rgba(0,0,0,.6)'},
};

const frames = [
  {id: '01-friends', theme: 'lime', screen: 'friends',
    en: ['Where are your', 'friends today?', 'Shared cities, never exact locations.'],
    zh: ['朋友们，', '现在都在哪？', '只分享所在城市，不显示精确位置。']},
  {id: '02-together-soon', theme: 'mist', screen: 'together-soon',
    en: ['Same city.', 'Same dates.', 'See the days your plans overlap.'],
    zh: ['行程重叠，', '约上见一面', '提前发现你们在同一座城市的日子。']},
  {id: '03-trip-globe', theme: 'ink', screen: 'trip-globe',
    en: ['Everyone lands', 'together.', 'Every flight on its way to your trip.'],
    zh: ['从各地出发，', '一起落地', '每个人的航班，都飞向同一个目的地。']},
  {id: '04-boarding-pass', theme: 'mist', screen: 'boarding-pass',
    en: ['Every flight,', 'one tap away.', 'Times, terminal and the flight home.'],
    zh: ['每趟航班，', '一点就清楚', '时间、航站楼和回程，一张登机牌看全。']},
  {id: '05-moments', theme: 'lime', screen: 'moments',
    en: ['All the days you', 'shared a city.', 'Your time together, friend by friend.'],
    zh: ['和朋友同城的', '每一天', '按朋友记下你们在同一座城市的日子。']},
  {id: '06-privacy', theme: 'ink', screen: 'friend-detail',
    en: ['City-level only.', 'Your call.', 'Choose who sees your city, friend by friend.'],
    zh: ['只到城市，', '边界由你定', '按好友单独开关共享城市和同城提醒。']},
];

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const fileURL = (p) => 'file://' + p.split('/').map(encodeURIComponent).join('/');

function html(frame, lang, crops) {
  const t = theme[frame.theme];
  const [l1, l2, sub] = frame[lang === 'en' ? 'en' : 'zh'];
  const zh = lang !== 'en';
  const product = frame.widgets
    ? `<div class="widgets"><img src="${fileURL(crops.large)}"><img src="${fileURL(crops.medium)}"></div>`
    : `<div class="phone"><div class="screen"><img src="${fileURL(path.join(raw, `store-${lang}-${frame.screen}.png`))}"><span class="island"></span></div></div>`;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:Geist;src:url("${fileURL(path.join(set, 'assets/Geist-Variable.woff2'))}") format("woff2");font-weight:100 900}
html,body{margin:0}
body{width:1320px;height:var(--h);overflow:hidden;position:relative;background:${t.bg};
  font-family:${zh ? '"PingFang SC",' : ''}Geist,-apple-system,sans-serif;-webkit-font-smoothing:antialiased}
.copy{position:absolute;left:96px;right:96px;top:196px}
h1{margin:0;color:${t.title};font-weight:600;font-size:${zh ? 108 : 116}px;line-height:${zh ? 1.16 : 1};letter-spacing:${zh ? '-0.01em' : '-0.04em'}}
p{margin:${zh ? 34 : 40}px 0 0;color:${t.sub};font-size:50px;line-height:1.3;letter-spacing:${zh ? '0' : '-0.01em'}}
.phone{position:absolute;left:50%;top:720px;width:1080px;margin-left:-540px;background:#0B0F0D;border-radius:166px;padding:24px;
  box-shadow:0 70px 140px -50px ${t.shadow}}
.screen{position:relative;border-radius:142px;overflow:hidden;background:#fff}
.screen img{display:block;width:100%}
.island{position:absolute;top:28px;left:50%;width:322px;height:94px;margin-left:-161px;background:#000;border-radius:47px}
.widgets{position:absolute;left:96px;right:96px;top:820px;display:flex;flex-direction:column;gap:56px}
.widgets img{display:block;width:100%;filter:drop-shadow(0 40px 60px rgba(14,26,19,.16))}
</style></head><body><div class="copy"><h1>${esc(l1)}<br>${esc(l2)}</h1><p>${esc(sub)}</p></div>${product}</body></html>`;
}

fs.mkdirSync(work, {recursive: true});
for (const lang of ['en', 'zh-Hans']) {
  const crops = {};
  for (const frame of frames) {
    const page = path.join(work, `${lang}-${frame.id}.html`);
    for (const [w, h] of sizes) {
      const zoom = w / 1320;
      fs.writeFileSync(page, html(frame, lang, crops).replace('<html>', `<html style="zoom:${zoom};--h:${(h / zoom).toFixed(2)}px">`));
      const dir = path.join(set, lang, `${w}x${h}`);
      fs.mkdirSync(dir, {recursive: true});
      const shot = path.join(work, 'shot.png');
      const r = spawnSync(chrome, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
        '--allow-file-access-from-files', `--user-data-dir=${path.join(work, 'profile')}`, `--window-size=${w},${h}`,
        `--screenshot=${shot}`, fileURL(page)], {stdio: 'ignore'});
      if (r.status !== 0) throw new Error(`Chrome failed for ${lang} ${frame.id} ${w}x${h}`);
      // App Store rejects alpha channels; flatten to opaque RGB at the exact size.
      await sharp(shot).resize(w, h, {fit: 'cover', position: 'top'}).flatten({background: '#ffffff'}).png().toFile(path.join(dir, `${frame.id}.png`));
    }
    console.log(lang, frame.id);
  }
}

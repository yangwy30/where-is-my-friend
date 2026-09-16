// Layout real simulator captures as marketing artwork; source PNGs stay intact.
// Usage: NODE_PATH=/path/to/node_modules node scripts/render_marketing_screenshots.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'docs/app_store_screenshots/2026-09-15');
const specs = [
  { id: '01_friends', raw: 'marketing-01-friends', green: true, title: 'Your friends.\nAround the\nworld.', sub: 'A little closer, city by city.', foot: 'See the latest city your friends choose to share.' },
  { id: '02_here_together', raw: 'marketing-02-same-city', title: 'Same city.\nTime to\nsay hello.', sub: 'Make room for a spontaneous reunion.', foot: 'Based on recent shared cities, with optional alerts.' },
  { id: '03_together_soon', raw: 'upcoming-together-expanded', crop: 180, title: 'Your next\n“See you there.”', sub: 'Find the dates your plans overlap.', foot: 'Future matches appear when you share plans with each other.' },
  { id: '04_shared_trips', raw: 'marketing-04-trips', green: true, title: 'More places.\nMore time\ntogether.', sub: 'Every shared trip, beautifully organized.', foot: 'Create a Trip, choose your dates, and invite your friends.' },
  { id: '05_arrivals', raw: 'marketing-05-arrivals', crop: 300, title: 'Different flights.\nOne reunion.', sub: 'Bring everyone’s arrivals into view.', foot: 'Flight updates are periodic. Confirm details with your airline.' },
  { id: '06_widgets', raw: 'marketing-06-widgets', title: 'A glance\ncloser.', sub: 'Your friends, right on your Home Screen.', foot: 'Choose your friends and your Widget privacy settings.' },
  { id: '07_sharing', raw: 'marketing-07-sharing', crop: 858, height: 1465, top: 880, green: true, title: 'Your city.\nYour choice.', sub: 'Share with the people you choose.', foot: 'Control city sharing. Manage plans and Trips separately.' },
];
fs.mkdirSync(out, { recursive: true });
const escape = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
function poster(s) {
  return `<article class="poster ${s.green ? 'green' : ''}" id="${s.id}">
    <div class="brand">ACROSS US <span>${String(specs.indexOf(s)+1).padStart(2,'0')} / 07</span></div>
    <h1>${escape(s.title).replaceAll('\n','<br>')}</h1><p class="sub">${escape(s.sub)}</p>
    <div class="screen" style="height:${s.height ?? 1810}px;top:${s.top ?? 743}px"><img style="transform:translateY(-${s.crop ?? 130}px)" src="raw/${s.raw}.png" alt="Current Across Us ${s.raw} screen"></div>
    <p class="foot">${escape(s.foot)}</p>
  </article>`;
}
const css = `*{box-sizing:border-box}html,body{margin:0;background:#e8e7df;color:#0a180f;font-family:'Helvetica Neue',Arial,sans-serif}.poster{width:1290px;height:2796px;position:relative;overflow:hidden;background:#ebeae3}.poster.green{background:#00d668}.brand{position:absolute;left:108px;right:108px;top:84px;font-size:24px;font-weight:700;letter-spacing:5px;display:flex;justify-content:space-between}.brand span{font-weight:500;letter-spacing:2px;opacity:.5}h1{position:absolute;top:185px;left:104px;right:90px;margin:0;font-size:126px;line-height:1.04;letter-spacing:-4.8px;font-weight:750}.sub{position:absolute;left:108px;top:609px;margin:0;font-size:34px;line-height:1.4;letter-spacing:-.5px;color:#3e5546}.screen{position:absolute;top:743px;left:105px;width:1080px;height:1810px;border-radius:68px;overflow:hidden;box-shadow:0 28px 65px #142e1825;border:2px solid #ffffff8c;background:#eff5e9}.screen img{display:block;width:100%;height:auto;transform:translateY(-130px)}.foot{position:absolute;left:100px;right:100px;top:2640px;margin:0;text-align:center;font-size:25px;line-height:1.45;color:#627066}.green .foot,.green .sub{color:#074e29}.green .screen{box-shadow:0 24px 60px #064f2020}`;
const html = `<!doctype html><html lang="en"><meta charset="utf-8"><title>Across Us — September 2026</title><style>${css}body{display:grid;grid-template-columns:repeat(7,1290px);gap:40px;padding:40px}</style>${specs.map(poster).join('')}</html>`;
fs.writeFileSync(path.join(out,'gallery.html'),html);
const browser = await chromium.launch({headless:true, channel:process.env.CHROME_CHANNEL || 'chrome'});
try {
  const page = await browser.newPage({viewport:{width:1290,height:2796},deviceScaleFactor:1});
  for (const s of specs) {
    if (!fs.existsSync(path.join(out,'raw',s.raw+'.png'))) throw new Error('Missing capture: '+s.raw);
    const one = `<!doctype html><html><meta charset="utf-8"><base href="${pathToFileURL(out+'/')}"><style>${css}</style>${poster(s)}</html>`;
    const temp = path.join(out,'.render.html'); fs.writeFileSync(temp,one);
    await page.goto(pathToFileURL(temp).href);
    await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode()));});
    for (const [w,h] of [[1290,2796],[1284,2778],[1242,2688]]) {
      const dest = path.join(out,`${w}x${h}`);fs.mkdirSync(dest,{recursive:true});
      await page.setViewportSize({width:w,height:h});
      await page.evaluate(({w,h})=>{const p=document.querySelector('.poster');p.style.transformOrigin='0 0';p.style.transform=`scale(${w/1290},${h/2796})`;}, {w,h});
      await page.screenshot({path:path.join(dest,s.id+'.png'),omitBackground:false});
    }
  }
  fs.rmSync(path.join(out,'.render.html'));
  await page.setViewportSize({width:1890,height:620});
  await page.goto(pathToFileURL(path.join(out,'gallery.html')).href);
  await page.addStyleTag({content:'body{display:block;width:1890px;height:620px;padding:0;overflow:hidden}.poster{position:absolute;top:20px;transform:scale(.2);transform-origin:top left}'});
  await page.evaluate(()=>document.querySelectorAll('.poster').forEach((p,i)=>p.style.left=`${i*267+14}px`));
  await page.screenshot({path:path.join(out,'contact-sheet.png')});
  fs.writeFileSync(path.join(out,'gallery.html'),`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Across Us — New App Screenshots</title><style>*{box-sizing:border-box}body{margin:0;padding:40px;background:#ebeae3;color:#0a180f;font-family:system-ui}h1{font-size:36px;margin:0 0 8px}p{color:#526458}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px;margin-top:32px}a{color:inherit;text-decoration:none}img{width:100%;display:block;border-radius:12px;box-shadow:0 12px 25px #0001}small{display:block;margin:14px 0}footer{margin-top:32px}</style><h1>Across Us</h1><p>新版 App 宣传截图 · September 2026 · 点击查看原尺寸</p><div class="gallery">${specs.map(s=>`<a href="1290x2796/${s.id}.png"><img src="1290x2796/${s.id}.png" alt="${escape(s.title.replaceAll('\n',' '))}"><small>${escape(s.title.replaceAll('\n',' '))}</small></a>`).join('')}</div><footer><a href="../../APP_INTRO_20260915.md">中英文介绍文案</a> · 真实 App 画面，演示数据</footer></html>`);
  console.log(`Rendered ${specs.length} posters in 3 sizes to ${out}`);
} finally {await browser.close();}

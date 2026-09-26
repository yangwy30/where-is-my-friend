// Render typography and untouched app captures as opaque store posters.
// Uses sharp's SVG rasterizer; no browser or network is involved.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const sharp = require('sharp');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'docs/app_store_screenshots/2026-09-25');
const copy = JSON.parse(fs.readFileSync(path.join(out, 'copy.json'), 'utf8'));
const esc = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
const palettes = {cream:['#F8F7EF','#E5F1E5'], mint:['#E7F2E9','#F5F7ED'], blue:['#EDF2F2','#E1EEE8']};
for (const [locale, specs] of Object.entries(copy)) {
  const rendered=[];
  for (const [index, s] of specs.entries()) {
    const raw = path.join(out, 'raw', locale, `${s.id}.png`);
    if (!fs.existsSync(raw) && process.argv.includes('--partial')) continue;
    if (!fs.existsSync(raw)) throw new Error(`Missing real capture: ${raw}`);
    const meta=await sharp(raw).metadata();
    const crop=Math.round(s.crop*meta.width/1320);
    const sourceRect=s.sourceRect ?? {left:0,top:crop,width:meta.width,height:meta.height-crop};
    const capture=await sharp(raw).extract(sourceRect).png().toBuffer();
    const imageHeight=1110*sourceRect.height/sourceRect.width;
    const frameY=s.frameY ?? 650, frameHeight=s.frameHeight ?? 2030;
    const radius=s.sourceRect ? 120 : 62;
    const colors=palettes[s.tone];
    const font=locale==='en'?'Helvetica Neue':'Hiragino Sans GB';
    const fontSize=locale==='en'?124:114;
    const title=s.title.map((line,i)=>`<text x="90" y="${275+i*148}" font-size="${fontSize}" font-weight="700" letter-spacing="${locale==='en'?-4:0}">${esc(line)}</text>`).join('');
    const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1290" height="2796" viewBox="0 0 1290 2796">
      <defs><linearGradient id="bg" x2=".7" y2="1"><stop stop-color="${colors[0]}"/><stop offset="1" stop-color="${colors[1]}"/></linearGradient>
      <clipPath id="screen"><rect x="90" y="${frameY}" width="1110" height="${frameHeight}" rx="${radius}"/></clipPath>
      <filter id="shadow" x="-20%" y="-10%" width="140%" height="130%"><feGaussianBlur stdDeviation="24"/></filter></defs>
      <rect width="1290" height="2796" fill="url(#bg)"/>
      <g font-family="${font}, sans-serif" fill="#123D2D">
      <text x="94" y="100" font-size="25" font-weight="600" letter-spacing="5">ACROSS US</text>
      <text x="1196" y="100" text-anchor="end" font-size="23" fill="#6C8273" letter-spacing="2">${String(index+1).padStart(2,'0')} / 07</text>
      ${title}<text x="94" y="523" font-size="37" fill="#587363">${esc(s.sub)}</text></g>
      <rect x="96" y="${frameY+32}" width="1098" height="${frameHeight-20}" rx="${radius}" fill="#163D29" opacity=".11" filter="url(#shadow)"/>
      <rect x="90" y="${frameY}" width="1110" height="${frameHeight}" rx="${radius}" fill="#F8FAF2"/>
      <image x="90" y="${frameY}" width="1110" height="${imageHeight}" href="data:image/png;base64,${capture.toString('base64')}" clip-path="url(#screen)"/>
      <rect x="90" y="${frameY}" width="1110" height="${frameHeight}" rx="${radius}" fill="none" stroke="#FFFFFF" stroke-opacity=".85" stroke-width="2"/>
    </svg>`;
    const svgDir=path.join(out,'svg',locale);fs.mkdirSync(svgDir,{recursive:true});
    fs.writeFileSync(path.join(svgDir,`${s.id}.svg`),svg);
    const renderedBase=await sharp(Buffer.from(svg)).flatten({background:colors[0]}).png().toBuffer();
    for(const [w,h] of [[1284,2778],[1320,2868]]){
      const dir=path.join(out,locale,`${w}x${h}`);fs.mkdirSync(dir,{recursive:true});
      await sharp(renderedBase).resize(w,h,{fit:'cover'}).removeAlpha().png({compressionLevel:9}).toFile(path.join(dir,`${s.id}.png`));
    }
    rendered.push(await sharp(renderedBase).resize(258,559).png().toBuffer());
  }
  if(rendered.length){
    await sharp({create:{width:rendered.length*280+20,height:599,channels:3,background:'#E9ECE5'}})
      .composite(rendered.map((input,i)=>({input,left:20+i*280,top:20})))
      .png().toFile(path.join(out,`contact-sheet-${locale}.png`));
  }
  console.log(`${locale}: ${rendered.length} posters`);
}
const galleries=Object.entries(copy).map(([locale,specs])=>`<section><h2>${locale==='en'?'English':'简体中文'}</h2><div class="gallery">${specs.map(s=>`<a href="${locale}/1284x2778/${s.id}.png"><img src="${locale}/1284x2778/${s.id}.png" alt="${esc(s.title.join(' '))}"></a>`).join('')}</div></section>`).join('');
fs.writeFileSync(path.join(out,'gallery.html'),`<!doctype html><html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Across Us — screenshots</title><style>body{margin:0;padding:32px;background:#f8f7ef;color:#123d2d;font-family:system-ui}h1{margin:0}h2{margin:32px 0 16px}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:18px}img{width:100%;border-radius:14px;box-shadow:0 8px 24px #163d2914}a{display:block}</style><h1>Across Us</h1>${galleries}</html>`);

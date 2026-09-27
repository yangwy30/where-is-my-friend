// Promotional composition: real widget pixels on the sourced iOS 27 blue wallpaper.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const sharp=createRequire(import.meta.url)('sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'docs/app_store_screenshots/2026-09-26/widget-study');
fs.mkdirSync(out,{recursive:true});
const wallpaper=await sharp(path.join(out,'ios27-blue.png')).resize(1320,2868)
 .extract({left:0,top:880,width:1320,height:1340}).png().toBuffer();
const directory=await sharp(path.join(root,'docs/widget_redesign/2026-09-26/actual-widget-page-2.png'))
 .extract({left:94,top:934,width:1132,height:1182}).png().toBuffer();
const uri=b=>`data:image/png;base64,${b.toString('base64')}`;
const home=await sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="1340">
 <defs><clipPath id="widget"><rect x="94" y="54" width="1132" height="1182" rx="132"/></clipPath></defs>
 <image width="1320" height="1340" href="${uri(wallpaper)}"/>
 <image x="94" y="54" width="1132" height="1182" href="${uri(directory)}" clip-path="url(#widget)"/>
 <text x="660" y="1295" text-anchor="middle" font-family="Helvetica Neue,sans-serif" font-size="42" fill="#FFFFFF">Across Us</text>
 </svg>`)).png().toBuffer();
const together=await sharp(path.join(root,'docs/widget_redesign/2026-09-26/widget-Here-together-Small-Light.png'))
 .extract({left:405,top:738,width:510,height:510}).png().toBuffer();
for(const locale of ['zh-Hans','en']){
 const chinese=locale==='zh-Hans';
 const title=chinese?['把朋友，','放在主屏幕']:['Friends, one','glance away.'];
 const sub=chinese?'在主屏幕上，一眼看到朋友。':'Friends on your Home Screen.';
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1290" height="2796" viewBox="0 0 1290 2796">
 <defs>
  <linearGradient id="paper" x2=".7" y2="1"><stop stop-color="#F8F7EF"/><stop offset="1" stop-color="#E5F1E5"/></linearGradient>
  <clipPath id="home"><rect x="40" y="750" width="1210" height="1228" rx="30"/></clipPath>
  <clipPath id="small"><rect x="820" y="2210" width="370" height="370" rx="62"/></clipPath>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%"><feGaussianBlur stdDeviation="18"/></filter>
 </defs>
 <rect width="1290" height="2796" fill="url(#paper)"/>
 <g font-family="${chinese?'Hiragino Sans GB':'Helvetica Neue'},sans-serif" fill="#123D2D">
 <text x="94" y="100" font-size="25" letter-spacing="5" font-weight="600">ACROSS US</text>
 <text x="1196" y="100" text-anchor="end" font-size="23" fill="#6C8273" letter-spacing="2">02 / 08</text>
 ${title.map((s,i)=>`<text x="90" y="${275+i*148}" font-size="${chinese?114:124}" font-weight="700" letter-spacing="${chinese?0:-4}">${s}</text>`).join('')}
 <text x="94" y="523" font-size="48" fill="#456453">${sub}</text>
 <text x="94" y="2320" font-size="${chinese?51:46}" font-weight="600">${chinese?'朋友在哪，':'Near and far.'}</text>
 <text x="94" y="2395" font-size="${chinese?51:46}" font-weight="600">${chinese?'谁就在身边。':'Sometimes, right here.'}</text>
 <text x="94" y="2470" font-size="32" fill="#587363">${chinese?'朋友名册 · 此刻同城':'Friends directory · Here together'}</text>
 </g>
 <rect x="49" y="774" width="1192" height="1208" rx="30" fill="#153d28" opacity=".1" filter="url(#shadow)"/>
 <image x="40" y="750" width="1210" height="1228.3" href="${uri(home)}" clip-path="url(#home)"/>
 <rect x="825" y="2230" width="360" height="360" rx="62" fill="#153d28" opacity=".14" filter="url(#shadow)"/>
 <image x="820" y="2210" width="370" height="370" href="${uri(together)}" clip-path="url(#small)"/>
 </svg>`;
 fs.writeFileSync(path.join(out,`${locale}-wallpaper-detail.svg`),svg);
 await sharp(Buffer.from(svg)).resize(1284,2778).flatten({background:'#F8F7EF'}).removeAlpha().png().toFile(path.join(out,`${locale}-wallpaper-detail.png`));
}
const before=await sharp(path.join(root,'docs/app_store_screenshots/2026-09-25/zh-Hans/1284x2778/08-widgets.png')).resize(385,833).toBuffer();
const after=await sharp(path.join(out,'zh-Hans-wallpaper-detail.png')).resize(385,833).toBuffer();
await sharp({create:{width:810,height:873,channels:3,background:'#E6EBE2'}}).composite([{input:before,left:10,top:20},{input:after,left:415,top:20}]).png().toFile(path.join(out,'comparison.png'));

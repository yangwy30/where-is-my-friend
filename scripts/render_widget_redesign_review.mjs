// Review images cropped from real shared SwiftUI preview screenshots, not mock UI.
import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url), sharp=require('sharp');
const dir=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../docs/widget_redesign/2026-09-26');
const names=['widget-Friends-Large-Light','widget-Here-together-Large-Light','widget-Friends-Large-Dark','widget-Here-together-Large-Dark'];
const images=[];
for(const name of names){
 const output=path.join(dir,`${name}-crop.png`);
 await sharp(path.join(dir,`${name}.png`)).extract({left:120,top:738,width:1080,height:1128}).png().toFile(output);
 images.push(await sharp(output).resize(344,359).toBuffer());
}
await sharp({create:{width:744,height:778,channels:3,background:'#F8F7EF'}})
 .composite(images.map((input,i)=>({input,left:20+(i%2)*360,top:20+Math.floor(i/2)*379})))
 .png().toFile(path.join(dir,'review-overview.png'));
const tiles=names.map(n=>`<figure><img src="${n}-crop.png" alt="${n}"><figcaption>${n.replace('widget-','').replaceAll('-',' ')}</figcaption></figure>`).join('');
fs.writeFileSync(path.join(dir,'gallery.html'),`<!doctype html><html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Across Us widgets</title><style>body{font-family:system-ui;background:#f8f7ef;color:#20392d;padding:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:24px;max-width:900px}figure{margin:0}img{width:100%;border-radius:24px}figcaption{margin-top:12px;font-size:14px}</style><h1>Across Us widgets</h1><main>${tiles}</main></html>`);

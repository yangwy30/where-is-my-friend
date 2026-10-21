// Website and README images from the 1.0.9 App Store captures. Crops real simulator captures only; never paints app UI.
// Sources: docs/app_store_screenshots/2026-10-20/raw (1206x2622, iPhone 17 Pro, demo data), added on feature/email-google-sign-in.
// Run: NODE_PATH=<dir with sharp>/node_modules node scripts/build_site_images_20261020.mjs
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const sharp=createRequire(import.meta.url)('sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source='docs/app_store_screenshots/2026-10-20/raw';
const output=path.join(root,'site/assets/product');
const shots=[
 ['friends','friends',{left:0,top:200,width:1206,height:1918},760],
 ['together-soon','together-soon',{left:40,top:590,width:1126,height:950},900],
 ['moments','moments',{left:30,top:390,width:1146,height:1150},680],
 ['friend-controls','friend-detail',{left:0,top:1300,width:1206,height:920},900],
 ['boarding-pass','boarding-pass',{left:24,top:540,width:1158,height:1140},960],
];
for(const [name,file,crop,width] of shots)await sharp(path.join(root,source,`store-en-${file}.png`)).extract(crop).resize({width}).webp({quality:86}).toFile(path.join(output,`${name}.webp`));
console.log(`Prepared ${shots.length} product images from the 1.0.9 captures`);

// Website assets from actual simulator captures. Never paints or fabricates app UI.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const sharp=createRequire(import.meta.url)('sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const output=path.join(root,'site/assets/product');fs.mkdirSync(output,{recursive:true});
const source='docs/app_store_screenshots/2026-09-25/raw/en';
const shots=[
 ['friends',`${source}/01-friends.png`,{left:0,top:190,width:1320,height:2100},760],
 ['plans',`${source}/02-friend-plans.png`,{left:35,top:190,width:1250,height:2070},720],
 ['overlap',`${source}/03-together-soon.png`,{left:60,top:225,width:1200,height:1640},720],
 ['same-city',`${source}/04-here-together.png`,{left:60,top:820,width:1200,height:1310},680],
 ['routes',`${source}/06-arrivals.png`,{left:30,top:445,width:1260,height:1830},1000],
 ['flight-details',`${source}/07-flight-details.png`,{left:60,top:1115,width:1200,height:685},960],
];
for(const [name,file,crop,width] of shots)await sharp(path.join(root,file)).extract(crop).resize({width}).webp({quality:86}).toFile(path.join(output,`${name}.webp`));
for(const style of ['Friends','Here-together'])for(const mode of ['Light','Dark']){
 const file=`docs/widget_redesign/2026-09-26/widget-${style}-Large-${mode}-crop.png`;
 await sharp(path.join(root,file)).resize({width:680}).webp({quality:90}).toFile(path.join(output,`${style.toLowerCase()}-${mode.toLowerCase()}.webp`));
}
const hero=fs.readFileSync(path.join(output,'friends.webp')).toString('base64');
const social=`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630"><rect width="1200" height="630" fill="#f7f5ee"/><g fill="#182c22"><text x="60" y="80" font-family="Helvetica Neue,Arial" font-size="32" font-weight="700">across us</text><text x="60" y="275" font-family="Helvetica Neue,Arial" font-size="112" font-weight="650" letter-spacing="-5">See you</text><text x="60" y="395" font-family="Georgia" font-size="108" font-style="italic" letter-spacing="-5">somewhere.</text><text x="65" y="485" font-family="Helvetica Neue,Arial" font-size="28">Friends, cities &amp; travel plans.</text><text x="65" y="565" font-family="Helvetica Neue,Arial" font-size="20">Across Us for iPhone</text></g><rect x="765" width="435" height="630" fill="#dee7df"/><image x="790" y="30" width="385" height="613" href="data:image/webp;base64,${hero}"/></svg>`;
await sharp(Buffer.from(social)).jpeg({quality:88}).toFile(path.join(output,'social-preview.jpg'));
console.log('Prepared 10 real product images and social preview');

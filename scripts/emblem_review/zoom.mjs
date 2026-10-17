import fs from 'node:fs'; import path from 'node:path'; import {createRequire} from 'node:module';
const require=createRequire(import.meta.url); const sharp=require('sharp');
const [dir,out,...names]=process.argv.slice(2); const S=360, comps=[];
for(const [i,n] of names.entries()){const x=(i%4)*(S+8)+8,y=Math.floor(i/4)*(S+30)+8;
 comps.push({input:{create:{width:S,height:S,channels:4,background:'#112217'}},left:x,top:y});
 comps.push({input:await sharp(path.join(dir,`City_${n}.imageset/City_${n}@3x.png`)).extract({left:40,top:200,width:432,height:300}).resize(S,250).png().toBuffer(),left:x,top:y+55});
 comps.push({input:Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="24"><text x="4" y="18" font-family="Helvetica" font-size="18" fill="#222">${n}</text></svg>`),left:x,top:y+S+2});}
const rows=Math.ceil(names.length/4);
await sharp({create:{width:4*(S+8)+8,height:rows*(S+30)+8,channels:3,background:'#fff'}}).composite(comps).png().toFile(out);

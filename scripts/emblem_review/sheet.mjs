import fs from 'node:fs'; import path from 'node:path'; import {createRequire} from 'node:module';
const require=createRequire(import.meta.url); const sharp=require('sharp');
const [dir,outDir]=process.argv.slice(2); fs.mkdirSync(outDir,{recursive:true});
const names=fs.readdirSync(dir).filter(d=>d.endsWith('.imageset')).sort();
const T=180, COLS=6, ROWS=9, LBL=22, PW=T*2+8, PH=T+LBL+6;
for(let s=0;s*COLS*ROWS<names.length;s++){
  const chunk=names.slice(s*COLS*ROWS,(s+1)*COLS*ROWS); const comps=[];
  const W=COLS*PW+10, H=Math.ceil(chunk.length/COLS)*PH+10;
  for(const [i,set] of chunk.entries()){
    const n=set.replace(/^City_|\.imageset$/g,''); const x=10+(i%COLS)*PW, y=10+Math.floor(i/COLS)*PH;
    const img=await sharp(path.join(dir,set,`City_${n}@3x.png`)).resize(T,T).png().toBuffer();
    comps.push({input:{create:{width:T,height:T,channels:4,background:'#FDFBF2'}},left:x,top:y});
    comps.push({input:{create:{width:T,height:T,channels:4,background:'#112217'}},left:x+T,top:y});
    // baseline guide at 90% height
    comps.push({input:Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${2*T}" height="${T}"><line x1="0" x2="${2*T}" y1="${T*0.9}" y2="${T*0.9}" stroke="#e05" stroke-opacity=".35" stroke-dasharray="4 4"/></svg>`),left:x,top:y});
    comps.push({input:img,left:x,top:y}); comps.push({input:img,left:x+T,top:y});
    comps.push({input:Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${2*T}" height="${LBL}"><text x="4" y="16" font-family="Helvetica" font-size="15" fill="#222">${s*COLS*ROWS+i+1}. ${n}</text></svg>`),left:x,top:y+T});
  }
  await sharp({create:{width:W,height:H,channels:3,background:'#ffffff'}}).composite(comps).png().toFile(path.join(outDir,`sheet-${s+1}.png`));
}
console.log(names.length);

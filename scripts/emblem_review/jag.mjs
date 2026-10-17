import fs from 'node:fs'; import path from 'node:path'; import {createRequire} from 'node:module';
const require=createRequire(import.meta.url); const sharp=require('sharp');
const dir=process.argv[2]; const res=[];
const bg=[0x11,0x22,0x17];
for (const set of fs.readdirSync(dir).filter(d=>d.endsWith('.imageset')).sort()){
  const n=set.replace(/^City_|\.imageset$/g,'');
  const {data,info}=await sharp(path.join(dir,set,`City_${n}@3x.png`)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const W=info.width,H=info.height; const bottom=new Array(W).fill(-1);
  for(let x=0;x<W;x++){for(let y=H-1;y>=0;y--){const i=(y*W+x)*4,a=data[i+3]/255;const l=((data[i]+data[i+1]+data[i+2])/3)*a+((bg[0]+bg[1]+bg[2])/3)*(1-a); if(l>90){bottom[x]=y;break}}}
  const xs=bottom.map((y,x)=>[x,y]).filter(([x,y])=>y>=0); if(!xs.length)continue;
  const x0=xs[0][0],x1=xs[xs.length-1][0],w=x1-x0; const inner=bottom.slice(x0+Math.round(w*.1),x1-Math.round(w*.1));
  let jumps=0,tv=0; for(let i=1;i<inner.length;i++){const d=Math.abs(inner[i]-inner[i-1]); tv+=d; if(d>=4)jumps++}
  // smooth baseline: median-filter and compare
  res.push({n,jumps,tv,w});
}
res.sort((a,b)=>b.jumps-a.jumps);
fs.writeFileSync(process.argv[3],JSON.stringify(res));
console.log(res.map(r=>`${r.n}:${r.jumps}`).join(' '));

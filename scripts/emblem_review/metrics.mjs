import fs from 'node:fs'; import path from 'node:path'; import {createRequire} from 'node:module';
const require=createRequire(import.meta.url); const sharp=require('sharp');
const dir=process.argv[2]; const out=[];
for (const set of fs.readdirSync(dir).filter(d=>d.endsWith('.imageset')).sort()){
  const name=set.replace(/^City_|\.imageset$/g,''); const files=fs.readdirSync(path.join(dir,set));
  const contents=JSON.parse(fs.readFileSync(path.join(dir,set,'Contents.json')));
  const f3=files.find(f=>f.endsWith('@3x.png')); if(!f3){out.push({name,error:'no @3x',files});continue}
  const {data,info}=await sharp(path.join(dir,set,f3)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const W=info.width,H=info.height; let minx=W,miny=H,maxx=-1,maxy=-1,opaque=0,semi=0,lightSemi=0,edgeOpaque=0;
  const cornerA=[[0,0],[W-1,0],[0,H-1],[W-1,H-1]].map(([x,y])=>data[(y*W+x)*4+3]);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=(y*W+x)*4,a=data[i+3];if(a>16){if(x<minx)minx=x;if(x>maxx)maxx=x;if(y<miny)miny=y;if(y>maxy)maxy=y}
    if(a>=250)opaque++;else if(a>16){semi++;const l=(data[i]+data[i+1]+data[i+2])/3;if(l>225)lightSemi++}
    if((x<2||y<2||x>=W-2||y>=H-2)&&a>16)edgeOpaque++}
  const sizes=files.filter(f=>f.endsWith('.png')).map(f=>f);
  out.push({name,W,H,bbox:[minx,miny,maxx,maxy],bw:maxx-minx+1,bh:maxy-miny+1,cx:Math.round((minx+maxx)/2-W/2),bottomMargin:H-1-maxy,topMargin:miny,cover:+((maxx-minx+1)*(maxy-miny+1)/(W*H)).toFixed(2),opaque,semi,lightSemi,edgeOpaque,cornerA,nfiles:sizes.length,contentsImages:contents.images?.length});
}
fs.writeFileSync(process.argv[3],JSON.stringify(out,null,0)); console.log(out.length);

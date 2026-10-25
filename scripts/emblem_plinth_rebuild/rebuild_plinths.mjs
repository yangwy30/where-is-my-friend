#!/usr/bin/env node
/**
 * Rebuild and standardize all 211 3D city emblems in
 * WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems from the pre-cleanup
 * @3x masters at commit 728cbe3 (and 3cef555 for the 5 regional archetypes,
 * plus the corrected Fukuoka Tower master in masters/City_fukuoka.png).
 *
 * Usage:
 *   # Run directly from git commits 728cbe3 / 3cef555 across all 211 emblems:
 *   NODE_PATH=/path/to/node_modules node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs
 *
 *   # Or extract 728cbe3 originals to a directory first, then rebuild from that directory:
 *   NODE_PATH=/path/to/node_modules node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs --extract-728cbe3 /tmp/emblem_728cbe3
 *   NODE_PATH=/path/to/node_modules node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs --orig-dir /tmp/emblem_728cbe3
 *
 *   # Rebuild specific cities only:
 *   NODE_PATH=/path/to/node_modules node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs suzhou copenhagen tel_aviv
 */

import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, "../..");
const ASSETS_ROOT = path.join(REPO_ROOT, "WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems");
const FUKUOKA_MASTER = path.join(__dirname, "masters/City_fukuoka.png");

const ARCHETYPE_NAMES = new Set([
  "archetype_central_valley",
  "archetype_desert_adobe",
  "archetype_historic_brick",
  "archetype_pacific_surf",
  "archetype_silicon_valley",
]);

function findRawFile(dir, name) {
  for (const prefix of [`City_${name}`, name]) {
    for (const ext of [".png", ".jpg", ".jpeg", ".webp"]) {
      const p = path.join(dir, `${prefix}${ext}`);
      if (fs.existsSync(p)) return p;
    }
  }
  return null;
}

async function prepareRawOpaqueRender(inputBuf) {
  const { data, info } = await sharp(inputBuf)
    .resize(512, 512, { kernel: sharp.kernel.lanczos3 })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const w = info.width, h = info.height;
  // Check if corners are opaque white studio background
  const cornerIdx = [0, (w - 1) * 4, (h - 1) * w * 4, ((h - 1) * w + (w - 1)) * 4];
  const isOpaqueBg = cornerIdx.every((i) => data[i + 3] > 200 && data[i] > 215 && data[i + 1] > 215 && data[i + 2] > 215);
  if (!isOpaqueBg) return { data, wasOpaqueRaw: false };

  // Border-seeded BFS flood-fill background removal
  const visited = new Uint8Array(w * h);
  const queue = new Int32Array(w * h);
  let qHead = 0, qTail = 0;

  const push = (x, y) => {
    const k = y * w + x;
    if (!visited[k]) {
      visited[k] = 1;
      queue[qTail++] = k;
    }
  };

  for (let x = 0; x < w; x++) { push(x, 0); push(x, h - 1); }
  for (let y = 0; y < h; y++) { push(0, y); push(w - 1, y); }

  while (qHead < qTail) {
    const k = queue[qHead++];
    const cx = k % w, cy = (k - cx) / w;
    const i = k * 4;
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const maxC = Math.max(r, g, b), minC = Math.min(r, g, b), diff = maxC - minC;
    // Studio background:
    // - Left studio floor shadow (cx < 110, cy >= 245): neutral grey-white down to minC >= 216 (diff <= 8)
    // - Right studio floor shadow above plinth (cx > 402, 245 <= cy <= 306): neutral grey-white down to minC >= 236 (diff <= 6)
    // - Bottom studio floor shadow (cy >= 355): minC >= 224 (diff <= 26), except protect bright right plinth rim at cx > 395, 335 <= cy <= 362
    // - Sky / landmark region: minC >= 244 (or 238 when strictly neutral diff <= 4)
    let thresh = 244;
    let maxDiff = 10;
    if (cx < 110 && cy >= 245 && cy < 355) {
      thresh = 216;
      maxDiff = 8;
    } else if (cx > 402 && cy >= 245 && cy <= 306) {
      thresh = 236;
      maxDiff = 6;
    } else if (cy >= 355 && !(cx > 395 && cy <= 362)) {
      thresh = 238;
      maxDiff = 8;
    } else if (diff <= 4) {
      thresh = 238;
      maxDiff = 4;
    }

    if (minC >= thresh && diff <= maxDiff) {
      data[i] = 255; data[i + 1] = 255; data[i + 2] = 255; data[i + 3] = 0;
      if (cx + 1 < w) push(cx + 1, cy);
      if (cx - 1 >= 0) push(cx - 1, cy);
      if (cy + 1 < h) push(cx, cy + 1);
      if (cy - 1 >= 0) push(cx, cy - 1);
    } else if (minC >= thresh - 12 && diff <= maxDiff + 4) {
      const alphaVal = Math.round(255 * (1.0 - (minC - (thresh - 12)) / 12.0));
      data[i + 3] = Math.max(0, Math.min(255, alphaVal));
    }
  }

  // Also clear enclosed pure-#FFFFFF background pockets inside open steel trusses / cables / bridge arches
  // (e.g. Oakland crane, Wichita/Toledo bridge cables, Spokane pavilion lattice, Sioux Falls tower)
  const pocketVisited = new Uint8Array(w * h);
  for (let y0 = 55; y0 < 345; y0++) {
    for (let x0 = 55; x0 < 455; x0++) {
      const k0 = y0 * w + x0;
      if (pocketVisited[k0] || data[k0 * 4 + 3] === 0) continue;
      const r0 = data[k0 * 4], g0 = data[k0 * 4 + 1], b0 = data[k0 * 4 + 2];
      if (Math.min(r0, g0, b0) < 246 || Math.max(r0, g0, b0) - Math.min(r0, g0, b0) > 6) continue;
      const comp = [k0];
      pocketVisited[k0] = 1;
      for (let idx = 0; idx < comp.length; idx++) {
        const k = comp[idx], cx = k % w, cy = (k - cx) / w;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = cx + dx, ny = cy + dy;
          if (nx < 50 || nx >= 462 || ny < 50 || ny >= 350) continue;
          const nk = ny * w + nx;
          if (pocketVisited[nk] || data[nk * 4 + 3] === 0) continue;
          const nr = data[nk * 4], ng = data[nk * 4 + 1], nb = data[nk * 4 + 2];
          if (Math.min(nr, ng, nb) >= 238 && Math.max(nr, ng, nb) - Math.min(nr, ng, nb) <= 8) {
            pocketVisited[nk] = 1;
            comp.push(nk);
          }
        }
      }
      if (comp.length >= 4 && comp.length <= 2500) {
        for (const k of comp) {
          data[k * 4 + 3] = 0;
        }
        // Soft anti-alias 1px rim around cleared truss pockets
        for (const k of comp) {
          const cx = k % w, cy = (k - cx) / w;
          for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            const nx = cx + dx, ny = cy + dy;
            if (nx < 50 || nx >= 462 || ny < 50 || ny >= 350) continue;
            const nk = ny * w + nx, ni = nk * 4;
            if (data[ni + 3] === 0) continue;
            const minC = Math.min(data[ni], data[ni + 1], data[ni + 2]);
            const diff = Math.max(data[ni], data[ni + 1], data[ni + 2]) - minC;
            if (minC >= 224 && diff <= 12) {
              data[ni + 3] = Math.min(data[ni + 3], Math.round(255 * Math.max(0, (238 - minC) / 14.0)));
            }
          }
        }
      }
    }
  }

  // Pre-frame to 88% of 512x512 so the V-curve plinth scanner sees the complete plinth with margin
  let minX = w, minY = h, maxX = -1, maxY = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[(y * w + x) * 4 + 3] > 16) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX <= minX || maxY <= minY) return { data, wasOpaqueRaw: true };

  const bw = maxX - minX + 1, bh = maxY - minY + 1;
  const scale = (512 * 0.88) / Math.max(bw, bh);
  const nw = Math.max(1, Math.round(bw * scale));
  const nh = Math.max(1, Math.round(bh * scale));
  const resized = await sharp(data, { raw: { width: w, height: h, channels: 4 } })
    .extract({ left: minX, top: minY, width: bw, height: bh })
    .resize(nw, nh, { kernel: sharp.kernel.lanczos3 })
    .raw()
    .toBuffer();

  const canvas = Buffer.alloc(w * h * 4, 0);
  const ox = Math.floor((w - nw) / 2);
  const oy = Math.min(Math.floor((h - nh) / 2), 472 - nh);
  for (let y = 0; y < nh; y++) {
    const dy = oy + y;
    if (dy < 0 || dy >= h) continue;
    for (let x = 0; x < nw; x++) {
      const dx = ox + x;
      if (dx < 0 || dx >= w) continue;
      const si = (y * nw + x) * 4, di = (dy * w + dx) * 4;
      canvas[di] = resized[si];
      canvas[di + 1] = resized[si + 1];
      canvas[di + 2] = resized[si + 2];
      canvas[di + 3] = resized[si + 3];
    }
  }
  return { data: canvas, wasOpaqueRaw: true };
}

function loadRawMasterBuffer(name, origDir) {
  if (origDir) {
    const found = findRawFile(origDir, name);
    if (found) return fs.readFileSync(found);
  }
  const bundledMaster = findRawFile(path.join(__dirname, "masters"), name);
  if (bundledMaster) {
    return fs.readFileSync(bundledMaster);
  }
  if (name === "fukuoka" && fs.existsSync(FUKUOKA_MASTER)) {
    return fs.readFileSync(FUKUOKA_MASTER);
  }
  if (ARCHETYPE_NAMES.has(name)) {
    return execSync(
      `git show 3cef555:WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems/City_${name}.imageset/City_${name}@3x.png`,
      { cwd: REPO_ROOT, maxBuffer: 20 * 1024 * 1024 }
    );
  }
  return execSync(
    `git show 728cbe3:WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems/City_${name}.imageset/City_${name}@3x.png`,
    { cwd: REPO_ROOT, maxBuffer: 20 * 1024 * 1024 }
  );
}

async function writeImagesetScales(setPath, name, finalBuf) {
  fs.mkdirSync(setPath, { recursive: true });
  const contentsPath = path.join(setPath, "Contents.json");
  if (!fs.existsSync(contentsPath)) {
    const defaultContents = {
      images: [
        { idiom: "universal", scale: "1x", filename: `City_${name}.png` },
        { idiom: "universal", scale: "2x", filename: `City_${name}@2x.png` },
        { idiom: "universal", scale: "3x", filename: `City_${name}@3x.png` },
      ],
      info: { author: "xcode", version: 1 },
    };
    fs.writeFileSync(contentsPath, JSON.stringify(defaultContents, null, 2) + "\n");
  }
  const contents = JSON.parse(fs.readFileSync(contentsPath, "utf8"));
  for (const img of contents.images || []) {
    if (!img.filename) continue;
    const targetPath = path.join(setPath, img.filename);
    if (img.scale === "3x") {
      await sharp(finalBuf, { raw: { width: 512, height: 512, channels: 4 } }).png().toFile(targetPath);
    } else if (img.scale === "2x") {
      await sharp(finalBuf, { raw: { width: 512, height: 512, channels: 4 } })
        .resize(341, 341, { kernel: sharp.kernel.lanczos3 })
        .png()
        .toFile(targetPath);
    } else if (img.scale === "1x") {
      await sharp(finalBuf, { raw: { width: 512, height: 512, channels: 4 } })
        .resize(170, 170, { kernel: sharp.kernel.lanczos3 })
        .png()
        .toFile(targetPath);
    }
  }
}

async function cleanArchetypeCity(name, origDir) {
  const setPath = path.join(ASSETS_ROOT, `City_${name}.imageset`);
  const rawPng = loadRawMasterBuffer(name, origDir);
  const { data: orig } = await sharp(rawPng)
    .resize(512, 512, { kernel: sharp.kernel.lanczos3 })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const w = 512, h = 512;
  let minX = w, minY = h, maxX = -1, maxY = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (orig[(y * w + x) * 4 + 3] > 24) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  const bwClean = maxX - minX + 1, bhClean = maxY - minY + 1;
  const s = Math.min(368.0 / bwClean, 446.0 / bhClean);
  const newW = Math.round(bwClean * s), newH = Math.round(bhClean * s);
  const cropped = await sharp(orig, { raw: { width: w, height: h, channels: 4 } })
    .extract({ left: minX, top: minY, width: bwClean, height: bhClean })
    .resize(newW, newH, { kernel: sharp.kernel.lanczos3 })
    .raw()
    .toBuffer();

  let rMinX = newW, rMinY = newH, rMaxX = -1, rMaxY = -1;
  for (let y = 0; y < newH; y++) {
    for (let x = 0; x < newW; x++) {
      if (cropped[(y * newW + x) * 4 + 3] > 16) {
        if (x < rMinX) rMinX = x;
        if (x > rMaxX) rMaxX = x;
        if (y < rMinY) rMinY = y;
        if (y > rMaxY) rMaxY = y;
      }
    }
  }

  const placeLeft = Math.round(256 - (rMinX + rMaxX) / 2);
  const placeTop = Math.round(475 - rMaxY);
  const finalBuf = Buffer.alloc(w * h * 4, 0);
  for (let y = 0; y < newH; y++) {
    const dy = placeTop + y;
    if (dy < 2 || dy >= h - 2) continue;
    for (let x = 0; x < newW; x++) {
      const dx = placeLeft + x;
      if (dx < 2 || dx >= w - 2) continue;
      const srcIdx = (y * newW + x) * 4, dstIdx = (dy * w + dx) * 4;
      finalBuf[dstIdx]     = cropped[srcIdx];
      finalBuf[dstIdx + 1] = cropped[srcIdx + 1];
      finalBuf[dstIdx + 2] = cropped[srcIdx + 2];
      finalBuf[dstIdx + 3] = cropped[srcIdx + 3];
    }
  }

  await writeImagesetScales(setPath, name, finalBuf);
}

async function cleanCity(name, origDir) {
  if (ARCHETYPE_NAMES.has(name)) {
    return cleanArchetypeCity(name, origDir);
  }

  const setPath = path.join(ASSETS_ROOT, `City_${name}.imageset`);
  const rawPng = loadRawMasterBuffer(name, origDir);
  const { data: orig, wasOpaqueRaw } = await prepareRawOpaqueRender(rawPng);
  const w = 512, h = 512, n = w * h, W0 = 250.0;
  const L = new Float32Array(n), C = new Float32Array(n), A = new Float32Array(n);

  for (let k = 0; k < n; k++) {
    const al = orig[k * 4 + 3] / 255.0;
    const r = orig[k * 4] * al + W0 * (1 - al);
    const g = orig[k * 4 + 1] * al + W0 * (1 - al);
    const b = orig[k * 4 + 2] * al + W0 * (1 - al);
    L[k] = 0.299 * r + 0.587 * g + 0.114 * b;
    C[k] = Math.max(r, g, b) - Math.min(r, g, b);
    A[k] = orig[k * 4 + 3];
  }

  // 1. Identify small disconnected alpha speckles (< 120 px)
  const visited = new Uint8Array(n);
  const isSpeckle = new Uint8Array(n);
  for (let k0 = 0; k0 < n; k0++) {
    if (visited[k0] || A[k0] < 8) continue;
    const comp = [k0];
    visited[k0] = 1;
    for (let idx = 0; idx < comp.length; idx++) {
      const k = comp[idx], cx = k % w, cy = (k - cx) / w;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (dx === 0 && dy === 0) continue;
          const nx = cx + dx, ny = cy + dy;
          if (nx >= 0 && nx < w && ny >= 0 && ny < h && !visited[ny * w + nx] && A[ny * w + nx] >= 8) {
            visited[ny * w + nx] = 1;
            comp.push(ny * w + nx);
          }
        }
      }
    }
    if (comp.length < 120) {
      for (const k of comp) isSpeckle[k] = 1;
    }
  }

  // 2. Bottom-up studio floor & contact-crevice scanner per column x
  const yStop = new Int32Array(w).fill(-1);
  const floor = new Uint8Array(n);
  const protectFlat = ["kyoto", "lucerne", "santiago", "taipei"].includes(name);

  for (let x = 0; x < w; x++) {
    let y = h - 1;
    while (y >= 0 && (A[y * w + x] < 8 || isSpeckle[y * w + x])) {
      if (isSpeckle[y * w + x]) floor[y * w + x] = 1;
      y--;
    }
    if (y < 0) continue;

    let prev = -1, opaque = 0, lastL = -1, lastA = 0, run = [];
    while (y >= 0) {
      const k = y * w + x;
      if (A[k] < 8 || isSpeckle[k]) {
        if (isSpeckle[k]) floor[k] = 1;
        let ny = y - 1;
        while (ny >= 350 && (A[ny * w + x] < 8 || isSpeckle[ny * w + x])) ny--;
        if (ny >= 350 && L[ny * w + x] >= 210 && C[ny * w + x] <= 46) {
          prev = -1;
          lastA = 0;
          y = ny;
          continue;
        }
        break;
      }
      if (C[k] > 46 || L[k] < 150) break;
      if (A[k] < 250) {
        floor[k] = 1;
        run.push(k);
        prev = -1;
        lastL = L[k];
        lastA = A[k];
        y--;
        continue;
      }
      if (prev < 0) {
        if (lastA >= 150 && Math.abs(L[k] - lastL) <= 9) opaque = 3;
        else if (L[k] < 212) break;
        else opaque = 0;
      } else if (opaque < 3) {
        if (L[k] < 208) break;
      } else if (Math.abs(L[k] - prev) > 9) {
        break;
      }
      floor[k] = 1;
      run.push(k);
      prev = L[k];
      opaque++;
      y--;

      if (protectFlat && opaque >= 10) {
        let lo = 999, hi = -1, solid = true;
        for (let i = run.length - 10; i < run.length; i++) {
          const r = run[i];
          if (A[r] < 250) { solid = false; break; }
          if (L[r] < lo) lo = L[r];
          if (L[r] > hi) hi = L[r];
        }
        if (solid && hi < 232 && (hi - lo) <= 3.5) {
          for (let i = run.length - 10; i < run.length; i++) floor[run[i]] = 0;
          y += 10;
          break;
        }
      }
    }

    // Crevice-climb post-step: climb through dark contact shadow crevices / rubber base gaskets
    if (y > 300 && A[y * w + x] >= 180 && L[y * w + x] < 228) {
      let yy = y, curL = L[yy * w + x], minL = curL, minY = yy;
      let climbing = false;
      for (let step = 0; step < 36 && yy > 280; step++, yy--) {
        const lk = L[yy * w + x], ck = C[yy * w + x];
        if (ck > 58 || A[yy * w + x] < 180) break;
        if (!climbing) {
          if (lk <= curL + 2.5 || lk < 68) {
            if (lk < minL) { minL = lk; minY = yy; }
            curL = lk;
          } else if (minL < 168) {
            climbing = true;
            curL = lk;
          } else {
            break;
          }
        }
        if (climbing) {
          if (lk >= Math.max(136, minL + 20.0)) {
            for (let fillY = y; fillY > yy; fillY--) floor[fillY * w + x] = 1;
            y = yy;
            break;
          }
          if (lk < curL - 4.0 || yy < minY - 12) break;
          curL = lk;
        }
      }
    }
    yStop[x] = y;
  }

  // 3. Robust isometric V-curve fitting: y_V(x) = yTip + cA - sqrt((slope * |x - xC|)^2 + cA^2)
  function fitV(xMin, xMax) {
    let bestScore = -1e9, bestParams = null;
    for (let xC = 252; xC <= 260; xC += 2) {
      for (let slope = 0.48; slope <= 0.59; slope += 0.012) {
        for (let cA = 8; cA <= 24; cA += 4) {
          const impliedTips = [];
          for (let x = xMin; x <= xMax; x += 2) {
            if (yStop[x] <= 260) continue;
            const dx = Math.abs(x - xC);
            impliedTips.push(yStop[x] - (cA - Math.sqrt(dx * dx * slope * slope + cA * cA)));
          }
          if (impliedTips.length < 20) continue;
          impliedTips.sort((a, b) => a - b);
          let modeTip = impliedTips[Math.floor(impliedTips.length * 0.6)], maxInliers = -1;
          for (let i = 0; i < impliedTips.length; i += 2) {
            const cand = impliedTips[i];
            let inliers = 0;
            for (let j = 0; j < impliedTips.length; j++) {
              const d = Math.abs(impliedTips[j] - cand);
              if (d <= 2.5) inliers += (3.0 - d);
            }
            if (inliers > maxInliers) { maxInliers = inliers; modeTip = cand; }
          }
          let score = maxInliers * 2.0;
          for (let x = xMin; x <= xMax; x += 2) {
            if (yStop[x] <= 260) continue;
            const dx = Math.abs(x - xC);
            const err = yStop[x] - (modeTip + cA - Math.sqrt(dx * dx * slope * slope + cA * cA));
            if (Math.abs(err) <= 2.5) score += 3.0 - Math.abs(err);
            else if (err < -2.5) score -= 0.1;
            else score -= 0.4;
          }
          if (score > bestScore) {
            bestScore = score;
            bestParams = { xC, yTip: modeTip, slope, cA };
          }
        }
      }
    }
    return bestParams;
  }

  const p1 = fitV(125, 387);
  const yV1 = (x) => p1.yTip + p1.cA - Math.sqrt(Math.pow((x - p1.xC) * p1.slope, 2) + p1.cA * p1.cA);
  let xL = 70, xR = 442;
  for (let x = 35; x < 200; x++) {
    const yBase = Math.round(yV1(x));
    let cnt = 0;
    for (let y = yBase - 65; y <= yBase - 14; y++) {
      if (y >= 0 && y < h && A[y * w + x] >= 220 && !floor[y * w + x]) cnt++;
    }
    if (cnt >= 12) { xL = x; break; }
  }
  for (let x = w - 35; x > 310; x--) {
    const yBase = Math.round(yV1(x));
    let cnt = 0;
    for (let y = yBase - 65; y <= yBase - 14; y++) {
      if (y >= 0 && y < h && A[y * w + x] >= 220 && !floor[y * w + x]) cnt++;
    }
    if (cnt >= 12) { xR = x; break; }
  }
  const dL = p1.xC - xL, dR = xR - p1.xC;
  const halfW = Math.min(dL, dR) + (Math.abs(dL - dR) <= 4 ? Math.round(Math.abs(dL - dR) / 2) : 0);
  xL = Math.round(p1.xC - halfW);
  xR = Math.round(p1.xC + halfW);

  const wSpan = xR - xL;
  const p = fitV(xL + Math.round(wSpan * 0.07), xR - Math.round(wSpan * 0.07)) || p1;
  const xMid = 0.5 * (xL + xR);
  const yBound = new Float32Array(w);
  for (let x = 0; x < w; x++) {
    const dx = Math.abs(x - p.xC);
    const uSide = Math.max(0, (Math.abs(x - xMid) - (halfW - 16)) / 16.0);
    yBound[x] = p.yTip + p.cA - Math.sqrt(dx * dx * p.slope * p.slope + p.cA * p.cA) - 8.0 * uSide * uSide;
  }

  const topPlinthY = new Int32Array(w);
  for (let x = xL; x <= xR; x++) {
    const yb = Math.round(yBound[x]);
    if (wasOpaqueRaw) {
      let y = yb - 2;
      while (y >= Math.max(220, yb - 28) && A[y * w + x] >= 180) y--;
      topPlinthY[x] = y + 1;
    } else {
      let highY = yb - 28;
      for (let y = Math.max(220, yb - 52); y <= yb - 2; y++) {
        if (A[y * w + x] >= 180) { highY = y; break; }
      }
      topPlinthY[x] = highY;
    }
  }

  // 4. Reconstruct frosted-acrylic / light plinth walls and remove shadow-ink streaks (e.g. tel_aviv)
  const out = Buffer.from(orig);
  const S = [62, 58, 54];
  const W_PLINTH = 246.0;

  const wallRGB = Buffer.from(orig);
  const isRepaired = new Uint8Array(n);

  for (let x = xL; x <= xR; x++) {
    const yb = yBound[x];
    const yTop = topPlinthY[x];
    const yBot = Math.min(h - 1, Math.ceil(yb) + 1);
    for (let y = yTop; y <= yBot; y++) {
      const k = y * w + x, i = k * 4;
      const al = A[k] / 255.0;
      if (A[k] < 250) {
        const rawL = 0.299 * orig[i] + 0.587 * orig[i + 1] + 0.114 * orig[i + 2];
        if (name === "tel_aviv" && rawL < 200) {
          // In tel_aviv, semi-transparent hole pixels inside the warm-cream right plinth wall
          // had their RGB overwritten with dark shadow ink (~27,31,36) in 728cbe3.
          wallRGB[i]     = 244;
          wallRGB[i + 1] = 237;
          wallRGB[i + 2] = 226;
          isRepaired[k] = 1;
        } else {
          wallRGB[i]     = Math.round(orig[i]     * al + W_PLINTH * (1.0 - al));
          wallRGB[i + 1] = Math.round(orig[i + 1] * al + W_PLINTH * (1.0 - al));
          wallRGB[i + 2] = Math.round(orig[i + 2] * al + W_PLINTH * (1.0 - al));
          if (name === "tel_aviv") isRepaired[k] = 1;
        }
      }
    }
  }

  if (name === "tel_aviv") {
    const wallSmooth = Buffer.from(wallRGB);
    for (let pass = 0; pass < 3; pass++) {
      const src = pass % 2 === 0 ? wallSmooth : wallRGB;
      const dst = pass % 2 === 0 ? wallRGB : wallSmooth;
      if (pass > 0) dst.set(src);
      for (let x = xL + 1; x <= xR - 1; x++) {
        const yTop = topPlinthY[x];
        const yBot = Math.min(h - 1, Math.ceil(yBound[x]) + 1);
        for (let y = yTop; y <= yBot; y++) {
          const k = y * w + x;
          let nearRepaired = isRepaired[k];
          if (!nearRepaired && y > yTop + 2) {
            if (
              isRepaired[(y - 1) * w + x] ||
              isRepaired[(y + 1) * w + x] ||
              isRepaired[y * w + x - 1] ||
              isRepaired[y * w + x + 1]
            ) {
              nearRepaired = 1;
            }
          }
          if (!nearRepaired) continue;
          let rSum = 0, gSum = 0, bSum = 0, cnt = 0;
          for (let dy = -2; dy <= 2; dy++) {
            const ny = y + dy;
            if (ny < yTop || ny > yBot) continue;
            for (let dx = -3; dx <= 3; dx++) {
              const nx = x + dx;
              if (nx < xL + 1 || nx > xR - 1) continue;
              if (ny < topPlinthY[nx] || ny > Math.ceil(yBound[nx]) + 1) continue;
              const ni = (ny * w + nx) * 4;
              rSum += src[ni];
              gSum += src[ni + 1];
              bSum += src[ni + 2];
              cnt++;
            }
          }
          if (cnt > 0) {
            const i = k * 4;
            dst[i]     = Math.round(rSum / cnt);
            dst[i + 1] = Math.round(gSum / cnt);
            dst[i + 2] = Math.round(bSum / cnt);
          }
        }
      }
    }
  }

  for (let x = 0; x < w; x++) {
    const yb = yBound[x];
    const inPlinthX = x >= xL && x <= xR;

    for (let y = 0; y < h; y++) {
      const k = y * w + x, i = k * 4;
      if (!inPlinthX) {
        const yCorner = yBound[x < xL ? xL : xR];
        if (isSpeckle[k] || y >= yCorner - 120 || floor[k]) {
          out[i] = 0; out[i + 1] = 0; out[i + 2] = 0; out[i + 3] = 0;
        }
        continue;
      }

      if (y <= yb - 1.0) {
        const sideDist = Math.min(x - xL, xR - x);
        if (y >= topPlinthY[x] && sideDist >= 1) {
          out[i]     = wallRGB[i];
          out[i + 1] = wallRGB[i + 1];
          out[i + 2] = wallRGB[i + 2];
          out[i + 3] = 255;
        } else if (isSpeckle[k]) {
          out[i] = 0; out[i + 1] = 0; out[i + 2] = 0; out[i + 3] = 0;
        }
      } else if (y <= yb + 0.5) {
        const t = (y - (yb - 1.0)) / 1.5;
        const pR = wallRGB[i], pG = wallRGB[i + 1], pB = wallRGB[i + 2];
        const shA = 96.0, aOut = Math.round((1 - t) * 255 + t * shA), wPlinth = ((1 - t) * 255) / Math.max(1, aOut);
        out[i]     = Math.round(wPlinth * pR + (1 - wPlinth) * S[0]);
        out[i + 1] = Math.round(wPlinth * pG + (1 - wPlinth) * S[1]);
        out[i + 2] = Math.round(wPlinth * pB + (1 - wPlinth) * S[2]);
        out[i + 3] = aOut;
      } else if (y <= yb + 9.0) {
        const d = y - yb, sideDist = Math.min(x - xL, xR - x), taper = Math.max(0, Math.min(1, (sideDist - 2) / 14.0));
        out[i]     = S[0];
        out[i + 1] = S[1];
        out[i + 2] = S[2];
        out[i + 3] = Math.round(96.0 * Math.pow(Math.max(0, 1.0 - d / 9.0), 1.5) * taper);
      } else {
        out[i] = 0; out[i + 1] = 0; out[i + 2] = 0; out[i + 3] = 0;
      }
    }
    if (x === xL || x === xR) {
      for (let y = Math.round(yb - 50); y <= Math.round(yb); y++) {
        if (y >= 0 && y < h) out[(y * w + x) * 4 + 3] = Math.min(out[(y * w + x) * 4 + 3], 170);
      }
    }
  }

  // 5. Scale and center to standardized plinth width (~368 px), horizontal center (256), and bottom baseline (y = 475 -> bottomMargin = 36 px)
  let minX = w, minY = h, maxX = -1, maxY = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (out[(y * w + x) * 4 + 3] > 16) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  const bwClean = maxX - minX + 1, bhClean = maxY - minY + 1, wPlinth = xR - xL;
  let s = 368.0 / wPlinth;
  if (s * bhClean < 310) s = Math.min(390.0 / bwClean, Math.max(s, 315.0 / bhClean));
  s = Math.max(0.84, Math.min(1.28, Math.min(s, 394.0 / bwClean, 446.0 / bhClean)));
  const newW = Math.round(bwClean * s), newH = Math.round(bhClean * s);
  const cropped = await sharp(out, { raw: { width: w, height: h, channels: 4 } })
    .extract({ left: minX, top: minY, width: bwClean, height: bhClean })
    .resize(newW, newH, { kernel: sharp.kernel.lanczos3 })
    .raw()
    .toBuffer();

  let rMinX = newW, rMinY = newH, rMaxX = -1, rMaxY = -1;
  for (let y = 0; y < newH; y++) {
    for (let x = 0; x < newW; x++) {
      if (cropped[(y * newW + x) * 4 + 3] > 16) {
        if (x < rMinX) rMinX = x;
        if (x > rMaxX) rMaxX = x;
        if (y < rMinY) rMinY = y;
        if (y > rMaxY) rMaxY = y;
      }
    }
  }
  const placeLeft = Math.round(256 - (rMinX + rMaxX) / 2);
  const placeTop = Math.round(475 - rMaxY);
  const finalBuf = Buffer.alloc(w * h * 4, 0);
  for (let y = 0; y < newH; y++) {
    const dy = placeTop + y;
    if (dy < 2 || dy >= h - 2) continue;
    for (let x = 0; x < newW; x++) {
      const dx = placeLeft + x;
      if (dx < 2 || dx >= w - 2) continue;
      const srcIdx = (y * newW + x) * 4, dstIdx = (dy * w + dx) * 4;
      finalBuf[dstIdx]     = cropped[srcIdx];
      finalBuf[dstIdx + 1] = cropped[srcIdx + 1];
      finalBuf[dstIdx + 2] = cropped[srcIdx + 2];
      finalBuf[dstIdx + 3] = cropped[srcIdx + 3];
    }
  }

  await writeImagesetScales(setPath, name, finalBuf);
}

async function main() {
  const args = process.argv.slice(2);
  let origDir = null;
  let extractDir = null;
  const targets = [];

  for (let i = 0; i < args.length; i++) {
    if ((args[i] === "--orig-dir" || args[i] === "--raw-dir") && args[i + 1]) {
      origDir = path.resolve(args[++i]);
    } else if (args[i] === "--extract-728cbe3" && args[i + 1]) {
      extractDir = path.resolve(args[++i]);
    } else {
      targets.push(args[i]);
    }
  }

  const allSets = fs
    .readdirSync(ASSETS_ROOT)
    .filter((d) => d.endsWith(".imageset"))
    .sort()
    .map((d) => d.replace(/^City_/, "").replace(/\.imageset$/, ""));

  if (extractDir) {
    fs.mkdirSync(extractDir, { recursive: true });
    for (const name of allSets) {
      const buf = loadRawMasterBuffer(name, null);
      fs.writeFileSync(path.join(extractDir, `City_${name}.png`), buf);
    }
    console.log(`Extracted ${allSets.length} raw @3x masters to ${extractDir}`);
    if (!origDir && targets.length === 0) return;
  }

  const list = targets.length > 0 ? targets : allSets;
  let done = 0;
  for (let i = 0; i < list.length; i += 12) {
    const slice = list.slice(i, i + 12);
    await Promise.all(
      slice.map(async (name) => {
        await cleanCity(name, origDir);
        done++;
      })
    );
    if (done % 48 === 0 || done === list.length) {
      console.log(`Processed ${done}/${list.length}`);
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

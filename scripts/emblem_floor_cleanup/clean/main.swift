import Foundation
// Converts the light studio-floor glare / reflection left under each city emblem's plinth into a
// dark, semi-transparent shadow, so emblems read correctly on dark backgrounds.
//
// usage: clean in.png out.png [mask-viz.png]
//
// Floor is found by scanning each column upward from below the emblem: the run starts at a light
// pixel (or a soft matte edge) and continues while colour stays low-saturation and luminance changes
// smoothly, stopping at the plinth's bottom edge. Floor pixels are then re-expressed as a dark shadow
// whose alpha reproduces their appearance over a white floor, so light-mode rendering is unchanged.
// Set PROTECT_FLAT_FACES=1 for emblems whose frosted lower tier blends into the floor without an edge.
let env = ProcessInfo.processInfo.environment
func ev(_ k: String, _ d: Float) -> Float { env[k].flatMap(Float.init) ?? d }
let TSTART = ev("TSTART", 228) // first floor pixel (seen over white) must be at least this light
let TMIN = ev("TMIN", 150)     // floor run continues only while this light
let SAT = ev("SAT", 46)        // max chroma for floor
let STEP = ev("STEP", 9)        // max luminance step between consecutive floor pixels
let GRACE = Int(ev("GRACE", 3)) // matte-edge pixels exempt from the step check
let TGRACE = ev("TGRACE", 208)  // ...but they must still be this light
let FLATN = env["PROTECT_FLAT_FACES"] == "1" ? Int(ev("FLATN", 10)) : Int.max  // a run of this many opaque pixels...
let FLATR = ev("FLATR", 3.5)        // ...within this luminance range...
let FLATHI = ev("FLATHI", 232)      // ...and darker than this is a plinth face, not floor
let W0: Float = 250            // assumed studio floor white
let a = CommandLine.arguments
var p = loadPix(a[1])
let w = p.w, h = p.h, n = w * h
// Colour as seen over a white floor
var L = [Float](repeating: 0, count: n), C = [Float](repeating: 0, count: n), A = [Float](repeating: 0, count: n)
for k in 0..<n {
    let al = Float(p.d[k*4+3]) / 255
    let r = Float(p.d[k*4]) * al + W0 * (1 - al), g = Float(p.d[k*4+1]) * al + W0 * (1 - al), b = Float(p.d[k*4+2]) * al + W0 * (1 - al)
    L[k] = 0.299*r + 0.587*g + 0.114*b; C[k] = max(r,g,b) - min(r,g,b); A[k] = Float(p.d[k*4+3])
}
var floor = [Bool](repeating: false, count: n)
for x in 0..<w {
    var y = h - 1
    // skip exterior: transparent or already-faint pixels
    while y >= 0 && (A[y*w+x] < 8) { y -= 1 }
    if y < 0 { continue }
    var prev: Float = -1
    var run = [Int]()
    var opaque = 0
    var lastL: Float = -1, lastA: Float = 0
    while y >= 0 {
        let k = y*w+x
        if A[k] < 8 {
            if run.count < 8 { run.removeAll(); prev = -1; lastA = 0; y -= 1; continue }   // speckle below the band: keep, rescan
            break                                     // gap above a real floor band: stop
        }
        if C[k] > SAT || L[k] < TMIN { break }
        if A[k] < 250 {                               // existing soft shadow / matte fringe
            floor[k] = true; run.append(k); prev = -1; lastL = L[k]; lastA = A[k]; y -= 1; continue
        }
        if prev < 0 {
            if lastA >= 150 && abs(L[k] - lastL) <= STEP { opaque = GRACE }  // soft matte flowing into a shading gradient
            else if L[k] < TSTART { break }
            else { opaque = 0 }
        }
        else if opaque < GRACE { if L[k] < TGRACE { break } }
        else if abs(L[k] - prev) > STEP { break }
        floor[k] = true; run.append(k); prev = L[k]; opaque += 1; y -= 1
        // Floor is bright glare or a shading gradient; a flat mid-grey stretch is a plinth face.
        if opaque >= FLATN {
            var lo: Float = 999, hi: Float = -1, solid = true
            for r in run.suffix(FLATN) { if A[r] < 250 { solid = false }; lo = min(lo, L[r]); hi = max(hi, L[r]) }
            if solid && hi < FLATHI && hi - lo <= FLATR {
                for r in run.suffix(FLATN) { floor[r] = false }
                break
            }
        }
    }
}
// Close narrow (<= GAP px) horizontal slivers bounded by floor on both sides.
let GAP = Int(ev("GAP", 24))
let GAPTOL = ev("GAPTOL", 14)  // filled pixels must match the floor on both sides
for _ in 0..<2 {
    var add = [Int]()
    for y in 0..<h { var x = 0
        while x < w {
            let k = y*w+x
            if floor[k] || A[k] < 8 { x += 1; continue }
            var e = x; while e < w && !floor[y*w+e] && A[y*w+e] >= 8 && e - x <= GAP { e += 1 }
            if x > 0 && floor[k-1] && e < w && floor[y*w+e] && e - x <= GAP {
                var ok = true
                let l0 = L[k-1], l1 = L[y*w+e]
                for xx in x..<e {
                    let m = y*w+xx, t = Float(xx - x + 1) / Float(e - x + 1)
                    if C[m] > SAT || L[m] < TMIN || abs(L[m] - (l0 + (l1 - l0) * t)) > GAPTOL { ok = false }
                }
                if ok { for xx in x..<e { add.append(y*w+xx) } }
            }
            x = max(e, x + 1)
        }
    }
    for k in add { floor[k] = true }
}
// Speckles: small light islands left by the jagged matte that touch the floor.
let SPECK = Int(ev("SPECK", 80))
var comp = [Int32](repeating: -1, count: n)
var comps = [[Int]]()
for k0 in 0..<n where comp[k0] < 0 && A[k0] >= 8 && !floor[k0] {
    let id = Int32(comps.count); var members = [k0]; comp[k0] = id; var i = 0
    while i < members.count {
        let k = members[i]; i += 1; let x = k % w, y = k / w
        for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
            let nx = x+dx, ny = y+dy
            if nx < 0 || ny < 0 || nx >= w || ny >= h { continue }
            let m = ny*w+nx
            if comp[m] < 0 && A[m] >= 8 && !floor[m] { comp[m] = id; members.append(m) }
        } }
    }
    comps.append(members)
}
for members in comps where members.count <= SPECK {
    var touches = false, light = true
    for k in members {
        if C[k] > SAT || L[k] < 180 { light = false; break }
        let x = k % w, y = k / w
        for (dx, dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
            let nx = x+dx, ny = y+dy
            if nx >= 0 && ny >= 0 && nx < w && ny < h && floor[ny*w+nx] { touches = true }
        }
    }
    if light && touches { for k in members { floor[k] = true } }
}
// Floor white estimate (95th percentile of floor luminance)
var fl = [Float](); for k in 0..<n where floor[k] && A[k] > 200 { fl.append(L[k]) }
fl.sort()
let W: Float = fl.isEmpty ? W0 : min(254, max(244, fl[Int(Float(fl.count - 1) * 0.95)]))
let S: (Float, Float, Float) = (62, 58, 54)
let Ls = 0.299*S.0 + 0.587*S.1 + 0.114*S.2
var viz = p
var changed = 0
for k in 0..<n where floor[k] {
    let na = 255 * max(0, min(1, (W - L[k]) / (W - Ls)))
    p.d[k*4] = UInt8(S.0); p.d[k*4+1] = UInt8(S.1); p.d[k*4+2] = UInt8(S.2); p.d[k*4+3] = UInt8(na.rounded())
    viz.d[k*4] = 255; viz.d[k*4+1] = 0; viz.d[k*4+2] = 255; viz.d[k*4+3] = 255
    changed += 1
}
savePix(p, a[2])
if a.count > 3 { savePix(viz, a[3]) }
print(String(format: "%@ floor=%d W=%.1f", (a[1] as NSString).lastPathComponent, changed, W))

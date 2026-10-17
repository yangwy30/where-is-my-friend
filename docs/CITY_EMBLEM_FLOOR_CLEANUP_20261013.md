# City emblem floor-glare cleanup (2026-10-13)

## Problem
The original studio renders kept an opaque, light warm-white floor reflection under each plinth
(for example `City_tokyo@3x.png` pixel (112,375) = RGBA 255,250,240,255). Over the light canvas
(#FDFBF2) it reads as soft floor light. Over the dark canvas (#112217) it shows up as a glowing
white smudge.

## Fix
`scripts/emblem_floor_cleanup/run.sh` (Swift + CoreGraphics; no PIL needed) rebuilds every
imageset from the pre-cleanup @3x masters at commit `728cbe3`:

1. **Floor detection.** Each column is scanned upward from below the emblem. A floor run starts at a
   light pixel or at a soft matte edge. It continues while the colour stays low-saturation and the
   luminance changes smoothly, and it stops at the plinth's bottom edge, where luminance jumps.
   Gaps of 24 px or less between floor runs are bridged only when they match the floor on both
   sides. Light specks of 80 px or less that touch the floor are absorbed.
2. **Conversion.** Floor pixels become a dark shadow (RGB 62,58,54). Their alpha is chosen so that,
   composited over white, they keep their original appearance. Light mode therefore looks the same,
   and dark mode gets a soft dark shadow instead of a white smudge.
3. **Flat-face guard.** For 9 emblems the frosted lower tier meets the floor with no visible edge.
   For these, a run of 10 or more opaque, flat (≤3.5 luminance range), non-glare pixels counts as
   plinth and is kept: raleigh, jeju, stockholm, zurich, hamburg, phoenix, copenhagen, reykjavik,
   rome.
4. @2x (341 px) and @1x (170 px) are downscaled from the cleaned @3x with premultiplied
   resampling. Filenames and `Contents.json` are unchanged.

To re-run and write review sheets:

    scripts/emblem_floor_cleanup/run.sh 728cbe3 /path/to/review-dir

## Emblems changed
All 211 imagesets changed (the 212th entry in `CityEmblems/` is the folder's own
`Contents.json`). Pixels converted per @3x master, smallest to largest:

| floor px | emblems |
|---|---|
| < 1.5k (minimal: rome, zurich, archetypes, generic/unknown) | rome, zurich, archetype_historic_brick, archetype_central_valley, archetype_pacific_surf, unknown_location, generic_block, archetype_desert_adobe |
| 1.5k – 8k | archetype_silicon_valley, kobe, kyoto, atlanta, istanbul, taipei, rio_de_janeiro, barcelona, macau, milan, bangkok, shenzhen, helsinki, seoul, athens, sydney, riyadh, sapporo, sao_paulo, wuhan, new_haven, xi_an, charlottesville, brisbane, guangzhou, venice, indianapolis, madison |
| 8k – 16k | reykjavik, cape_town, charleston, nice, durham, hangzhou, cincinnati, abu_dhabi, princeton, madrid, brussels, detroit, porto, sacramento, marseille, phuket, memphis, anchorage, portland, lyon, oklahoma_city, austin, quebec_city, melbourne, dublin, frankfurt, las_vegas, fukuoka, salt_lake_city, raleigh, dallas, utrecht, charlotte, doha, ottawa, baltimore, oslo, ithaca, perth, st_louis, bordeaux, cleveland, boston, tokyo, split, bogota, honolulu, bristol, victoria, christchurch, shanghai, san_antonio, florence, asheville, hsinchu, montreal, budapest, new_york, beijing, basel, manchester, columbus, calgary, nashville, krakow, xiamen, liverpool, heidelberg, auckland, chapel_hill, mountain_view, prague, lima, dubai, ann_arbor, new_orleans, berkeley, orlando, taichung, san_juan, kuala_lumpur, boulder, cancun, okinawa, toronto, manila, gold_coast, mexico_city, yokohama, bruges, sunnyvale, cambridge, chengdu, nanjing, kansas_city, queenstown, stockholm, houston, tainan, seville, amsterdam, glasgow, minneapolis |
| ≥ 16k (heaviest glare) | albuquerque, cologne, paris, washington, halifax, seattle, osaka, chongqing, guadalajara, santorini, milwaukee, pittsburgh, edinburgh, warsaw, miami, san_jose, hong_kong, antwerp, santa_barbara, lisbon, san_diego, buenos_aires, medellin, rotterdam, tucson, cupertino, chicago, providence, jakarta, tel_aviv, savannah, phoenix, palo_alto, boise, geneva, louisville, vienna, tampa, dubrovnik, san_francisco, penang, busan, incheon, munich, vancouver, singapore, irvine, denver, cusco, edmonton, suzhou, cairo, waterloo, kaohsiung, los_angeles, valencia, berlin, bali, hamburg, copenhagen, birmingham, wellington, el_paso, monterrey, lucerne, london, santiago, philadelphia, adelaide, oxford, chiang_mai, jeju |

## Known limitations
- A few emblems keep tiny, faint light specks at the far ends of the shadow band (for example
  santiago and seattle). They are only visible when zoomed in.
- The cleanup was checked on contact sheets over both canvases and on the Friends grid in the app.
- The interim dark-mode `CityEmblemView.floorGlow` mitigation was removed after an in-app
  comparison: it washed out the new dark shadows. Cleaned assets were checked in the app (dark mode).

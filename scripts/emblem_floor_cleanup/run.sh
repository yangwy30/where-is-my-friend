#!/bin/zsh
# Rebuild the City emblem imagesets with the floor glare converted to shadow.
#
#   scripts/emblem_floor_cleanup/run.sh [source-rev] [review-dir]
#
# Reads the original @3x masters from git (default: 728cbe3, the last commit before cleanup) so the
# run is reproducible and never re-processes already-cleaned files. Writes @3x and the downscaled
# @2x/@1x back into WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems; Contents.json is untouched.
# If review-dir is given, before/after contact sheets over the light and dark canvases land there.
set -euo pipefail
HERE=${0:a:h}; ROOT=${HERE:h:h}
REV=${1:-728cbe3}
REVIEW=${2:-}
SETS=$ROOT/WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems
WORK=$(mktemp -d)   # scratch (under $TMPDIR)
mkdir -p $WORK/bin $WORK/orig $WORK/out

# Emblems whose frosted lower tier meets the floor without a visible edge; keep flat faces intact.
PROTECT_FLAT=(raleigh jeju stockholm zurich hamburg phoenix copenhagen reykjavik rome)

for tool in clean resize; do swiftc -O $HERE/PixIO.swift $HERE/$tool/main.swift -o $WORK/bin/$tool; done
swiftc -O $HERE/sheet/main.swift -o $WORK/bin/sheet

for set in $SETS/City_*.imageset; do
  name=${set:t:r}; city=${name#City_}
  git -C $ROOT show "${REV}:WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems/$name.imageset/${name}@3x.png" > $WORK/orig/$name.png
  protect=0; (( ${PROTECT_FLAT[(Ie)$city]} )) && protect=1
  PROTECT_FLAT_FACES=$protect $WORK/bin/clean $WORK/orig/$name.png $WORK/out/$name.png
  cp $WORK/out/$name.png $set/$name@3x.png
  $WORK/bin/resize $WORK/out/$name.png $set/$name@2x.png 341
  $WORK/bin/resize $WORK/out/$name.png $set/$name.png 170
done

if [[ -n $REVIEW ]]; then
  mkdir -p $REVIEW
  names=($(ls $WORK/orig))
  for bg in 112217:dark FDFBF2:light; do
    hex=${bg%%:*}; label=${bg##*:}; i=0; page=1
    while (( i < ${#names} )); do
      files=(); for n in ${names[@]:$i:24}; do files+=($WORK/orig/$n $WORK/out/$n); done
      $WORK/bin/sheet $REVIEW/${label}_before_after_$page.png 8 200 $hex $files
      i=$((i+24)); page=$((page+1))
    done
  done
fi

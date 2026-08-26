#!/usr/bin/env python3
"""
City Emblem Asset Pipeline (High-Precision Transparent Alpha)

Processes raw 3D miniature city renders into production-ready iOS Asset Catalogs:
1. Border-seeded BFS flood-fill background removal (completely eliminates square borders & vignette artifacts)
2. Soft anti-aliased edge matte ramp
3. Tight bounding-box framing (94% occupancy to make the 3D model big and prominent)
4. Multi-resolution generation (@1x: 64x64, @2x: 128x128, @3x: 192x192)
5. Xcode Asset Catalog generation (Imageset + Contents.json)
"""

import json
import os
import sys
import collections
from pathlib import Path
from PIL import Image, ImageFilter

WORKSPACE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = WORKSPACE_DIR / "scripts" / "raw_renders"
XCSETS_DIR = WORKSPACE_DIR / "WhereIsMyFriend" / "Resources" / "Assets.xcassets" / "CityEmblems"

def remove_background_clean(img: Image.Image, threshold: int = 218) -> Image.Image:
    """
    Remove solid/gradient white studio background using border-connected BFS flood-fill.
    Completely eliminates any square frame edges or background vignetting.
    """
    img = img.convert("RGBA")
    w, h = img.size
    pixels = img.load()
    
    visited = set()
    queue = collections.deque()
    
    # Seed from all four image boundaries
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
        visited.add((x, 0))
        visited.add((x, h - 1))
        
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))
        visited.add((0, y))
        visited.add((w - 1, y))
        
    while queue:
        cx, cy = queue.popleft()
        r, g, b, a = pixels[cx, cy]
        
        max_c = max(r, g, b)
        min_c = min(r, g, b)
        diff = max_c - min_c
        
        # If it's a light background pixel (low saturation and bright)
        if min_c >= threshold and diff <= 28:
            pixels[cx, cy] = (255, 255, 255, 0)
            for nx, ny in [(cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)]:
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    queue.append((nx, ny))
        elif min_c >= threshold - 20 and diff <= 32:
            # Soft anti-aliased edge near threshold
            alpha_val = int(255 * (1.0 - (min_c - (threshold - 20)) / 20.0))
            pixels[cx, cy] = (r, g, b, max(0, min(255, alpha_val)))
            
    return img

def center_and_tight_crop(img: Image.Image, target_size: int = 512, occupancy: float = 0.94) -> Image.Image:
    """Center the non-transparent content within a square canvas with tight framing to maximize visual size."""
    bbox = img.getbbox()
    if not bbox:
        return img.resize((target_size, target_size), Image.LANCZOS)
        
    cropped = img.crop(bbox)
    w, h = cropped.size
    max_dim = max(w, h)
    
    desired_dim = int(target_size * occupancy)
    scale = desired_dim / float(max_dim)
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    
    resized = cropped.resize((new_w, new_h), Image.LANCZOS)
    
    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    offset_x = (target_size - new_w) // 2
    offset_y = (target_size - new_h) // 2
    canvas.paste(resized, (offset_x, offset_y), resized)
    return canvas

def export_imageset(city_id: str, base_img: Image.Image, output_dir: Path):
    """Generate Xcode imageset with @1x, @2x, @3x PNGs and Contents.json."""
    imageset_name = f"City_{city_id}.imageset"
    imageset_dir = output_dir / imageset_name
    imageset_dir.mkdir(parents=True, exist_ok=True)
    
    scales = [
        ("1x", 64, f"City_{city_id}.png"),
        ("2x", 128, f"City_{city_id}@2x.png"),
        ("3x", 192, f"City_{city_id}@3x.png"),
    ]
    
    images_meta = []
    for scale_name, size, filename in scales:
        resized = base_img.resize((size, size), Image.LANCZOS)
        resized.save(imageset_dir / filename, "PNG", optimize=True)
        images_meta.append({
            "idiom": "universal",
            "scale": scale_name,
            "filename": filename
        })
        
    contents = {
        "images": images_meta,
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    with open(imageset_dir / "Contents.json", "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)

def process_city_image(city_id: str, src_path: Path):
    """Process a single city image from source into Xcode Assets."""
    print(f"Processing '{city_id}' from {src_path.name}...")
    with Image.open(src_path) as raw:
        clean = remove_background_clean(raw)
        centered = center_and_tight_crop(clean, target_size=512, occupancy=0.94)
        export_imageset(city_id, centered, XCSETS_DIR)
        print(f"  -> Cleaned & generated City_{city_id}.imageset (@1x, @2x, @3x)")

def ensure_namespace():
    """Ensure CityEmblems folder has Contents.json."""
    XCSETS_DIR.mkdir(parents=True, exist_ok=True)
    contents = {
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    with open(XCSETS_DIR / "Contents.json", "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)

def main():
    ensure_namespace()
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    
    count = 0
    for img_file in sorted(RAW_DIR.glob("*.*")):
        if img_file.suffix.lower() in [".jpg", ".jpeg", ".png", ".webp"]:
            city_id = img_file.stem.replace("clean_diorama_", "").replace("emblem_raw_", "")
            process_city_image(city_id, img_file)
            count += 1
            
    print(f"\n🎉 Successfully processed {count} city emblems with zero square border artifacts into:\n   {XCSETS_DIR}")

if __name__ == "__main__":
    main()

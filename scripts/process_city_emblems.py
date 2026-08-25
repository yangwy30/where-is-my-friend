#!/usr/bin/env python3
"""
City Emblem Asset Pipeline

Processes raw 3D miniature city renders into production-ready iOS Asset Catalogs:
1. Alpha transparency extraction (clean edge matte from studio white background)
2. Auto-centering and golden ratio padding (object occupies ~82% of bounding box)
3. Multi-resolution generation (@1x: 64x64, @2x: 128x128, @3x: 192x192)
4. Xcode Asset Catalog generation (Imageset + Contents.json)
"""

import json
import os
import sys
from pathlib import Path
from PIL import Image, ImageFilter

WORKSPACE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = WORKSPACE_DIR / "scripts" / "raw_renders"
XCSETS_DIR = WORKSPACE_DIR / "WhereIsMyFriend" / "Resources" / "Assets.xcassets" / "CityEmblems"

def remove_white_background(img: Image.Image, threshold: int = 248) -> Image.Image:
    """Extract alpha channel from studio white background with soft anti-aliasing."""
    img = img.convert("RGBA")
    data = img.getdata()
    
    new_data = []
    ramp_width = 16
    min_thresh = threshold - ramp_width
    
    for r, g, b, a in data:
        min_c = min(r, g, b)
        if r >= threshold and g >= threshold and b >= threshold:
            new_data.append((255, 255, 255, 0))
        elif r >= min_thresh and g >= min_thresh and b >= min_thresh:
            # Smooth anti-aliased transition
            alpha_ratio = 1.0 - (min_c - min_thresh) / float(ramp_width)
            alpha_val = max(0, min(255, int(255 * alpha_ratio)))
            new_data.append((r, g, b, alpha_val))
        else:
            new_data.append((r, g, b, 255))
            
    img.putdata(new_data)
    return img

def center_and_crop(img: Image.Image, target_size: int = 512, occupancy: float = 0.82) -> Image.Image:
    """Center the non-transparent content within a square canvas, occupying specified percentage."""
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
        clean = remove_white_background(raw)
        centered = center_and_crop(clean, target_size=512, occupancy=0.84)
        export_imageset(city_id, centered, XCSETS_DIR)
        print(f"  -> Successfully generated City_{city_id}.imageset (@1x, @2x, @3x)")

def ensure_namespace():
    """Ensure CityEmblems folder has a namespaced Contents.json."""
    XCSETS_DIR.mkdir(parents=True, exist_ok=True)
    contents = {
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "provides-namespace": True
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
            
    print(f"\n🎉 Successfully processed {count} city emblems into Xcode Assets Catalog:\n   {XCSETS_DIR}")

if __name__ == "__main__":
    main()

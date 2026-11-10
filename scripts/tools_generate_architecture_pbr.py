from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "materials" / "architecture"
SOURCE_IMAGES = {
    "wet_old_wood": Path(r"C:\Users\23279\.codex\generated_images\019f1de2-8af9-7923-86e3-a659bc5cc03e\exec-90aba597-f80d-4196-a7c1-b7e0350a684e.png"),
    "peeling_plaster": Path(r"C:\Users\23279\.codex\generated_images\019f1de2-8af9-7923-86e3-a659bc5cc03e\exec-d9717d6b-f2c1-493f-9d20-9e22be0214f5.png"),
    "wet_gray_roof_tile": Path(r"C:\Users\23279\.codex\generated_images\019f1de2-8af9-7923-86e3-a659bc5cc03e\exec-4ae09ee2-c3b3-47be-acb2-b9dab3435ed3.png"),
}


def seamless_4k(source: Path) -> Image.Image:
    base = Image.open(source).convert("RGB").resize((2048, 2048), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (4096, 4096))
    canvas.paste(base, (0, 0))
    canvas.paste(ImageOps.mirror(base), (2048, 0))
    canvas.paste(ImageOps.flip(base), (0, 2048))
    canvas.paste(ImageOps.flip(ImageOps.mirror(base)), (2048, 2048))
    return canvas


def normalize(values: np.ndarray) -> np.ndarray:
    low, high = np.percentile(values, (1.0, 99.0))
    if high <= low:
        return np.zeros_like(values, dtype=np.float32)
    return np.clip((values - low) / (high - low), 0.0, 1.0).astype(np.float32)


def save_gray(path: Path, values: np.ndarray) -> None:
    Image.fromarray(np.uint8(np.clip(values, 0.0, 1.0) * 255.0), "L").save(path, optimize=True)


def generate_normal(height: np.ndarray, strength: float) -> Image.Image:
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=-1)
    normal = np.uint8((normal * 0.5 + 0.5) * 255.0)
    return Image.fromarray(normal, "RGB")


def build_material(name: str, source: Path) -> None:
    image = seamless_4k(source)
    rgb = np.asarray(image, dtype=np.float32) / 255.0
    luminance = rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722

    smooth = np.asarray(
        Image.fromarray(np.uint8(luminance * 255.0), "L").filter(ImageFilter.GaussianBlur(5.0)),
        dtype=np.float32,
    ) / 255.0
    broad = np.asarray(
        Image.fromarray(np.uint8(luminance * 255.0), "L").filter(ImageFilter.GaussianBlur(28.0)),
        dtype=np.float32,
    ) / 255.0

    height = normalize(smooth * 0.72 + luminance * 0.28)
    crevice = np.clip(1.0 - height, 0.0, 1.0)
    saturation_green = np.clip(rgb[..., 1] - (rgb[..., 0] + rgb[..., 2]) * 0.5, 0.0, 1.0)

    if name == "wet_old_wood":
        base_roughness, normal_strength = 0.76, 8.5
        wetness = normalize((1.0 - broad) * 0.72 + crevice * 0.28)
        moss_dirt = normalize(saturation_green * 5.2 + crevice * 0.36)
    elif name == "peeling_plaster":
        base_roughness, normal_strength = 0.84, 7.0
        wetness = normalize((1.0 - broad) * 0.78 + crevice * 0.22)
        moss_dirt = normalize(saturation_green * 4.5 + crevice * 0.44)
    else:
        base_roughness, normal_strength = 0.68, 9.0
        wetness = normalize((1.0 - broad) * 0.58 + crevice * 0.42)
        moss_dirt = normalize(saturation_green * 5.5 + crevice * 0.34)

    wetness = np.clip((wetness - 0.2) / 0.8, 0.0, 1.0)
    moss_dirt = np.clip((moss_dirt - 0.34) / 0.66, 0.0, 1.0)
    roughness = np.clip(base_roughness - wetness * 0.34 + (1.0 - height) * 0.08, 0.18, 0.93)
    ao = np.clip(0.48 + height * 0.52, 0.0, 1.0)

    image.save(OUTPUT_DIR / f"{name}_base_color_4k.png", optimize=True)
    generate_normal(height, normal_strength).save(OUTPUT_DIR / f"{name}_normal_gl_4k.png", optimize=True)
    save_gray(OUTPUT_DIR / f"{name}_roughness_4k.png", roughness)
    save_gray(OUTPUT_DIR / f"{name}_ao_4k.png", ao)
    save_gray(OUTPUT_DIR / f"{name}_height_4k.png", height)
    save_gray(OUTPUT_DIR / f"{name}_wetness_4k.png", wetness)
    save_gray(OUTPUT_DIR / f"{name}_moss_dirt_4k.png", moss_dirt)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, source in SOURCE_IMAGES.items():
        if not source.exists():
            raise FileNotFoundError(source)
        build_material(name, source)
        print(f"Generated {name} PBR set")


if __name__ == "__main__":
    main()

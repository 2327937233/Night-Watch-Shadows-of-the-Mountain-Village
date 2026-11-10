"""Continuous whole-body deformation for the authored front/back sprites.

Run from the project root. Only axial walk/start/stop and their moving-turn
dependencies are rebuilt; original exports are backed up once before writing.
"""
from pathlib import Path
import math
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def smooth(a, b, value):
    t = max(0.0, min(1.0, (value - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def continuous_walk(source, index, strength=1.0):
    """One inverse mesh, with shared vertices: no cutouts or pasted limbs."""
    phase = index * math.tau / 8.0
    width, height = source.size

    def source_point(x, y):
        leg = smooth(475.0, 695.0, y)
        # Both legs share exactly the same pelvis transform. Opposite swing
        # begins below the hip and grows smoothly toward the shoes.
        side = 2.0 * smooth(235.0, 270.0, x) - 1.0
        foot_phase = phase + (math.pi if side > 0 else 0.0)
        swing = math.sin(phase)
        dx = 1.1 * swing * (1.0 - leg) + 7.0 * side * swing * leg
        lift = max(0.0, math.sin(foot_phase)) * 7.0
        dy = 1.5 * (1.0 - math.cos(2.0 * phase)) * (1.0 - leg) - lift * leg
        return (x - dx * strength, y - dy * strength)

    mesh = []
    step = 5
    for y in range(0, height, step):
        for x in range(0, width, step):
            right, bottom = min(width, x + step), min(height, y + step)
            quad = source_point(x, y) + source_point(x, bottom) + source_point(right, bottom) + source_point(right, y)
            mesh.append(((x, y, right, bottom), quad))
    # Premultiplied sampling avoids dark RGB seams along the alpha silhouette.
    return source.convert('RGBa').transform(source.size, Image.Transform.MESH, mesh, Image.Resampling.BICUBIC).convert('RGBA')


def rebuild():
    changed = []
    for folder in ['animations', 'animations_dehalo']:
        directory = ROOT / 'assets/characters' / folder
        backup = ROOT / 'tmp/axial_walk_originals' / folder
        backup.mkdir(parents=True, exist_ok=True)
        outputs = {}
        for direction in ['front', 'back']:
            source = Image.open(directory / f'chen_mo_{direction}_idle_00.png').convert('RGBA')
            for i in range(8):
                outputs[f'chen_mo_{direction}_walk_{i:02d}.png'] = continuous_walk(source, i)
            for i in range(3):
                outputs[f'chen_mo_start_walk_{direction}_{i:02d}.png'] = continuous_walk(source, i, i / 2.0)
                outputs[f'chen_mo_stop_walk_{direction}_{i:02d}.png'] = continuous_walk(source, i + 5, 1.0 - i / 2.0)
        # Moving turns embed regular walk poses. Replace the axial half too,
        # otherwise the old detached thigh would survive in these transitions.
        for a, b in [('front','left'), ('front','right'), ('back','left'), ('back','right'), ('left','front'), ('right','front'), ('left','back'), ('right','back')]:
            for i in range(4):
                direction, frame = (a, (i + 5) % 8) if i < 2 else (b, i - 2)
                if direction in ['front', 'back']:
                    outputs[f'chen_mo_walk_{a}_to_{b}_{i:02d}.png'] = outputs[f'chen_mo_{direction}_walk_{frame:02d}.png']
        for name, frame in outputs.items():
            target = directory / name
            if target.exists() and not (backup / name).exists():
                shutil.copy2(target, backup / name)
            frame.save(target)
            changed.append(str(target.relative_to(ROOT)))
    (ROOT / 'tmp/axial_walk_rebuilt.txt').write_text('\n'.join(changed), encoding='utf-8')
    print(f'Rebuilt {len(changed)} dependent frames; originals retained in tmp/axial_walk_originals.')


if __name__ == '__main__':
    rebuild()

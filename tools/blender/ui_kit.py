"""UI elements (gold rims + PBR textured metal faces) rendered to PNG with Blender.

Run (from the repo root):
    blender -b --factory-startup -P tools/blender/ui_kit.py -- --out mockup/blender_test

1 Blender unit = 100 px. Every element is rendered top-down with an orthographic
camera on a transparent background, with a drop shadow (added in post from the alpha).
States: normal (rendered in Blender), active and disabled (post-processed from the
normal render with numpy). There is no pressed state: in game, a press is shown by
scaling the button down (like the play button of the game selection screen).
"""
import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np

PX = 100.0  # pixels per Blender unit
PAD = 24  # transparent margin (px) around each element, for shadow and glow
HDRI = Path(bpy.app.binary_path).parent / f"{bpy.app.version[0]}.{bpy.app.version[1]}" / "datafiles/studiolights/world/studio.exr"
GOLD_GLOW = (1.0, 0.78, 0.25)
FONT = "C:/Windows/Fonts/segoeuib.ttf"
# Player accent colors (medallions), up to 8 players.
PLAYER_COLORS = [
    (0.80, 0.04, 0.04),  # red
    (0.04, 0.55, 0.14),  # green
    (0.04, 0.22, 0.85),  # blue
    (0.95, 0.38, 0.02),  # orange
    (0.45, 0.10, 0.75),  # purple
    (0.00, 0.62, 0.72),  # cyan
    (0.90, 0.18, 0.52),  # pink
    (0.85, 0.85, 0.88),  # white
]


# --------------------------------------------------------------------------- scene

def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    _enable_gpu(scene)

    world = bpy.data.worlds.new("World")
    scene.world = world
    nodes, links = world.node_tree.nodes, world.node_tree.links
    env = nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(str(HDRI))
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(135))
    coords = nodes.new("ShaderNodeTexCoord")
    links.new(coords.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], env.inputs["Vector"])
    bg = nodes["Background"]
    bg.inputs["Strength"].default_value = 1.6
    links.new(env.outputs["Color"], bg.inputs["Color"])

    # Key light from the top-left: highlights on the rims and a shadow to the bottom-right.
    light = bpy.data.lights.new("Key", "AREA")
    light.energy = 700
    light.size = 3.0
    key = bpy.data.objects.new("Key", light)
    key.location = (-3.0, 3.0, 5.0)
    _look_at(key, (0, 0, 0))
    scene.collection.objects.link(key)


def _enable_gpu(scene) -> None:
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for backend in ("OPTIX", "CUDA", "HIP", "ONEAPI"):
            try:
                prefs.compute_device_type = backend
            except TypeError:
                continue
            prefs.get_devices()
            gpus = [d for d in prefs.devices if d.type != "CPU"]
            if gpus:
                for d in prefs.devices:
                    d.use = d.type != "CPU"
                scene.cycles.device = "GPU"
                print(f"[ui_kit] Cycles on GPU ({backend})")
                return
    except Exception as e:  # noqa: BLE001
        print(f"[ui_kit] GPU setup failed: {e}")
    print("[ui_kit] Cycles on CPU")


def _look_at(obj, target) -> None:
    from mathutils import Vector
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_camera(width_px: int, height_px: int) -> None:
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(width_px, height_px) / PX
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, 0, 10)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = width_px
    scene.render.resolution_y = height_px
    scene.render.resolution_percentage = 100


# ------------------------------------------------------------------------ materials

def _principled(name: str, color, metallic: float, roughness: float):
    mat = bpy.data.materials.new(name)
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat, bsdf


def mat_gold():
    mat, _ = _principled("Gold", (1.0, 0.66, 0.10), 1.0, 0.24)
    return mat


# PBR texture sets (1024 px, see textures/): a folder with albedo and normal-ogl
# PNGs, plus optional metal(lic), rough(ness), ao, named "<name>_<map>.png" or
# "<name>-<map>.png". Tile = Blender units (x100 px) covered by one texture tile.
TEXTURES = Path(__file__).resolve().parent / "textures"
FACE_TEXTURES, FACE_TILE = TEXTURES / "used-stainless-steel2", 8.0  # button faces
BAR_TEXTURES, BAR_TILE = TEXTURES / "knights-armor", 18.0  # bottom button bar


def mat_textured(folder: Path, tile: float, rotation: float = 0.0):
    """Principled material from a PBR texture set, projected top-down (object XY),
    repeated every `tile` units and turned by `rotation` degrees (hides the
    repetition on tall plates)."""
    mat, bsdf = _principled("Textured", (1, 1, 1), 1.0, 0.5)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coords = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / tile,) * 3
    mapping.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(rotation))
    links.new(coords.outputs["Object"], mapping.inputs["Vector"])

    def find(*suffixes: str) -> Path | None:
        for suffix in suffixes:
            for sep in ("_", "-"):
                match = next(folder.glob(f"*{sep}{suffix}.png"), None)
                if match:
                    return match
        return None

    def image(path: Path, color: bool):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(path))
        node.image.colorspace_settings.name = "sRGB" if color else "Non-Color"
        links.new(mapping.outputs["Vector"], node.inputs["Vector"])
        return node

    albedo = image(find("albedo"), True)
    ao_path = find("ao")
    if ao_path:
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        links.new(albedo.outputs["Color"], mix.inputs["A"])
        links.new(image(ao_path, False).outputs["Color"], mix.inputs["B"])
        links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    else:
        links.new(albedo.outputs["Color"], bsdf.inputs["Base Color"])
    # Metal and roughness maps are optional: the Principled defaults (1.0 / 0.5) apply.
    for suffixes, socket in ((("metallic", "metal"), "Metallic"), (("roughness", "rough"), "Roughness")):
        path = find(*suffixes)
        if path:
            links.new(image(path, False).outputs["Color"], bsdf.inputs[socket])
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(image(find("normal-ogl"), False).outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def mat_face():
    """Metal of the button faces (used stainless steel)."""
    return mat_textured(FACE_TEXTURES, FACE_TILE)


def mat_dark_flat(value: float, alpha: float = 1.0):
    """Uniform dark satin face (no brushing, weak reflections) for faces stretched by
    9-slice. alpha < 1 makes the face see-through (the background shows behind it)."""
    mat, bsdf = _principled("DarkFlat", (value, value, value * 1.08), 0.0, 0.45)
    bsdf.inputs["Specular IOR Level"].default_value = 0.15
    bsdf.inputs["Alpha"].default_value = alpha
    return mat


def mat_red():
    """Glossy red plastic, like the existing Start button."""
    mat, bsdf = _principled("Red", (0.75, 0.01, 0.01), 0.0, 0.18)
    bsdf.inputs["Coat Weight"].default_value = 0.6
    return mat


def mat_amber():
    """Lit gold track of an active toggle."""
    mat, bsdf = _principled("Amber", (1.0, 0.62, 0.08), 0.6, 0.3)
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.55, 0.05, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.6
    return mat


def mat_enamel(color):
    mat, bsdf = _principled("Enamel", color, 0.0, 0.2)
    bsdf.inputs["Coat Weight"].default_value = 0.8
    return mat


def mat_metal(color, roughness: float):
    mat, _ = _principled("Metal", color, 1.0, roughness)
    return mat


def mat_satin(value: float, roughness: float = 0.4):
    """Neutral lacquer (white or black) with a light clear coat."""
    mat, bsdf = _principled("Satin", (value, value, value), 0.0, roughness)
    bsdf.inputs["Coat Weight"].default_value = 0.5
    return mat


# Look of the controls (buttons, option arrows, row plates, toggles). Gold stays
# reserved for the frames (panels, title plaque, button bar, medallions).
CONTROL_STYLES = {
    "gold": dict(rim=mat_gold, glyph=mat_gold, track_on=mat_amber, glow=GOLD_GLOW),
    # Polished steel rim, white lacquered symbols, red track (like Start).
    "steel_white": dict(rim=lambda: mat_metal((0.62, 0.63, 0.65), 0.2),
                        glyph=lambda: mat_satin(0.85, 0.3),
                        track_on=mat_red, glow=(0.85, 0.9, 1.0)),
    # Satin black rim, white symbols: the most discreet.
    "black_white": dict(rim=lambda: mat_satin(0.02, 0.35),
                        glyph=lambda: mat_satin(0.85, 0.3),
                        track_on=mat_red, glow=(0.9, 0.92, 1.0)),
    # All steel: steel rim, dark engraved-looking symbols.
    "steel_engraved": dict(rim=lambda: mat_metal((0.62, 0.63, 0.65), 0.2),
                           glyph=lambda: mat_satin(0.015, 0.5),
                           track_on=mat_red, glow=(0.85, 0.9, 1.0)),
}
# Rimless variants: a single solid body whose edge profile catches the light.
for _shape in ("dome", "chamfer", "pillow"):
    CONTROL_STYLES[_shape] = dict(CONTROL_STYLES["steel_white"], shape=_shape)
# Retained look: rimless "pillow" buttons (bar pills, round buttons), polished
# steel frames for the option widgets (spinner, toggle, value field, rows),
# white symbols, warm light halo behind the selected pill.
CONTROL_STYLES["sober"] = dict(CONTROL_STYLES["steel_white"], shape="pillow", glow=(1.0, 0.62, 0.15))
STYLE = CONTROL_STYLES["gold"]


# ------------------------------------------------------------------------- geometry

def rounded_rect(w: float, h: float, r: float, seg: int = 16) -> list[tuple[float, float]]:
    """Counter-clockwise outline of a rounded rectangle centered on the origin."""
    r = min(r, w / 2, h / 2)
    cx, cy = w / 2 - r, h / 2 - r
    pts = []
    for corner, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
        a0 = corner * math.pi / 2
        for i in range(seg + 1):
            a = a0 + (math.pi / 2) * i / seg
            pt = (sx * cx + r * math.cos(a), sy * cy + r * math.sin(a))
            if not pts or math.dist(pt, pts[-1]) > 1e-6:
                pts.append(pt)
    if math.dist(pts[0], pts[-1]) < 1e-6:
        pts.pop()
    return pts


def _new_object(name: str, bm, mat, bevel_width: float, bevel_segments: int = 5):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel_width > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel_width
        mod.segments = bevel_segments
        mod.limit_method = "ANGLE"
        mod.harden_normals = False
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def prism(name: str, pts, z0: float, z1: float, mat, bevel: float):
    """Flat slab with the given outline."""
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    return _new_object(name, bm, mat, bevel)


def ring(name: str, outer, inner, z0: float, z1: float, mat, bevel: float):
    """Frame between two outlines with the same vertex count."""
    bm = bmesh.new()
    ob = [bm.verts.new((x, y, z0)) for x, y in outer]
    ot = [bm.verts.new((x, y, z1)) for x, y in outer]
    ib = [bm.verts.new((x, y, z0)) for x, y in inner]
    it = [bm.verts.new((x, y, z1)) for x, y in inner]
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ot[i], ot[j], it[j], it[i]))  # top
        bm.faces.new((ob[j], ob[i], ib[i], ib[j]))  # bottom
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))  # outer wall
        bm.faces.new((ib[j], ib[i], it[i], it[j]))  # inner wall
    return _new_object(name, bm, mat, bevel)


def framed_plate(w: float, h: float, r: float, rim: float, lift: float, face_mat,
                 rim_height: float = 0.12, face_height: float = 0.07, rim_mat=None):
    """Rim (gold by default) around a recessed face. Returns the created objects."""
    outer = rounded_rect(w, h, r)
    inner = rounded_rect(w - 2 * rim, h - 2 * rim, max(r - rim, 0.01))
    face_pts = rounded_rect(w - rim, h - rim, max(r - rim / 2, 0.01))
    return [
        ring("Rim", outer, inner, lift, lift + rim_height, rim_mat or mat_gold(), min(rim * 0.45, rim_height * 0.45)),
        prism("Face", face_pts, lift, lift + face_height, face_mat, min(0.015, face_height * 0.4)),
    ]


def control_plate(w: float, h: float, r: float, rim: float, lift: float, face_mat,
                  rim_height: float = 0.12, face_height: float = 0.07, framed: bool = False):
    """Body of a control in the current style: a framed plate (rim) or, for the
    rimless shapes, one solid whose edge profile gives the volume:
    dome (fully rounded), chamfer (machined 45 degree edge), pillow (soft edge).
    Returns (objects, z of the top face)."""
    shape = "framed" if framed else STYLE.get("shape", "framed")
    if shape == "framed":
        objs = framed_plate(w, h, r, rim, lift, face_mat, rim_height, face_height, rim_mat=STYLE["rim"]())
        return objs, lift + face_height
    m = min(w, h)
    height, bevel, segments = {
        "dome": (0.05 + 0.24 * m, None, 10),
        "chamfer": (0.04 + 0.12 * m, None, 1),
        "pillow": (0.04 + 0.12 * m, None, 6),
    }[shape]
    bevel = {"dome": 0.9, "chamfer": 0.75, "pillow": 0.45}[shape] * min(height, r if r > 0.01 else height)
    obj = prism("Body", rounded_rect(w, h, r), lift, lift + height, face_mat, 0.0)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = False
    return [obj], lift + height


def _rotate(pts, angle: float):
    c, s = math.cos(angle), math.sin(angle)
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


def gold_glyph(kind: str, size: float, z: float):
    """Symbol (in the control style) lying on a face: minus, plus, left, right, up,
    down, question, pencil."""
    gold = STYLE["glyph"]()
    if kind in ("minus", "plus"):
        t = size * 0.22
        bars = [(size, t)] + ([(t, size)] if kind == "plus" else [])
        return [prism(f"Glyph{i}", rounded_rect(bw, bh, t / 2, 8), z, z + 0.06, gold, 0.02)
                for i, (bw, bh) in enumerate(bars)]
    if kind in ("left", "right", "up", "down"):
        s = size / 2
        tri = [(s * 0.85, 0.0), (-s * 0.6, s * 0.9), (-s * 0.6, -s * 0.9)]  # pointing right
        angle = {"right": 0.0, "up": 90.0, "left": 180.0, "down": 270.0}[kind]
        return [prism("Glyph", _rotate(tri, math.radians(angle)), z, z + 0.06, gold, 0.03)]
    if kind == "pencil":
        L, t = size, size * 0.32
        body = [(L / 2 - t * 0.9, t / 2), (-L / 2, t / 2), (-L / 2, -t / 2), (L / 2 - t * 0.9, -t / 2), (L / 2, 0.0)]
        return [prism("Glyph", _rotate(body, math.radians(45)), z, z + 0.06, gold, 0.015)]
    if kind == "question":
        curve = bpy.data.curves.new("Glyph", "FONT")
        curve.body = "?"
        curve.font = bpy.data.fonts.load(FONT)
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.size = size * 2.0
        curve.extrude = 0.03
        curve.bevel_depth = 0.012
        curve.bevel_resolution = 3
        obj = bpy.data.objects.new("Glyph", curve)
        obj.location.z = z + 0.03
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(gold)
        return [obj]
    raise ValueError(kind)


# ---------------------------------------------------------------------- post-process

def _load(path: Path) -> np.ndarray:
    img = bpy.data.images.load(str(path))
    w, h = img.size
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    return arr


def _save(arr: np.ndarray, path: Path) -> None:
    h, w = arr.shape[:2]
    img = bpy.data.images.new(path.stem, w, h, alpha=True)
    img.pixels.foreach_set(np.clip(arr, 0, 1).ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def _blur(a: np.ndarray, radius: int) -> np.ndarray:
    """Approximate gaussian blur (3 box passes) of a 2D array."""
    for _ in range(3):
        for axis in (0, 1):
            pad = [(0, 0), (0, 0)]
            pad[axis] = (radius + 1, radius)
            c = np.cumsum(np.pad(a, pad), axis=axis)
            if axis == 0:
                a = (c[2 * radius + 1:] - c[:-2 * radius - 1]) / (2 * radius + 1)
            else:
                a = (c[:, 2 * radius + 1:] - c[:, :-2 * radius - 1]) / (2 * radius + 1)
    return a


def _over(top: np.ndarray, bottom: np.ndarray) -> np.ndarray:
    ta, ba = top[..., 3:4], bottom[..., 3:4]
    out_a = ta + ba * (1 - ta)
    rgb = (top[..., :3] * ta + bottom[..., :3] * ba * (1 - ta)) / np.maximum(out_a, 1e-6)
    return np.concatenate([rgb, out_a], axis=-1)


def add_drop_shadow(path: Path, offset: int, blur: int, opacity: float) -> None:
    img = _load(path)
    a = np.roll(np.roll(img[..., 3], -offset, axis=0), offset, axis=1)  # down-right (rows go bottom-up)
    shadow = np.zeros_like(img)
    # Only outside the element: a see-through face must not show its own shadow.
    outside = 1 - np.clip(img[..., 3] * 4, 0, 1)
    shadow[..., 3] = np.clip(_blur(a, blur) * opacity, 0, 1) * outside
    _save(_over(img, shadow), path)


def make_active(src: Path, dst: Path) -> None:
    img = _load(src)
    # Glow from the element silhouette (alpha), ignoring the faint shadow.
    mask = np.clip((img[..., 3] - 0.8) / 0.2, 0, 1)
    glow_a = np.clip(_blur(mask, 9) * 2.6, 0, 1)
    glow = np.zeros_like(img)
    glow[..., :3] = STYLE["glow"]
    glow[..., 3] = glow_a
    lit = img.copy()
    lit[..., :3] = np.clip(lit[..., :3] * 1.12 + 0.02, 0, 1)
    _save(_over(lit, glow), dst)


def make_disabled(src: Path, dst: Path) -> None:
    img = _load(src)
    grey = img[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    img[..., :3] = (grey[..., None] * 0.55)
    img[..., 3] *= 0.75
    _save(img, dst)


# -------------------------------------------------------------------------- elements

def render(path: Path, shadow_offset: int = 6) -> None:
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    add_drop_shadow(path, shadow_offset, max(shadow_offset, 2), 0.65)
    print(f"[ui_kit] {path}")


def _states(out: Path, name: str, active: bool = True, disabled: bool = True) -> None:
    if active:
        make_active(out / f"{name}_normal.png", out / f"{name}_active.png")
    if disabled:
        make_disabled(out / f"{name}_normal.png", out / f"{name}_disabled.png")


def _scene(w_px: int, h_px: int) -> None:
    reset_scene()
    setup_camera(w_px + 2 * PAD, h_px + 2 * PAD)


def round_button(out: Path, glyph: str, size_px: int = 80) -> None:
    """Small square button (rounded corners, steel frame like the option spinner)
    with a symbol (+, -, arrows, ?). Kept the "round_button" file names."""
    name = f"round_button_{glyph}"
    d = size_px / PX
    _scene(size_px, size_px)
    _, top = control_plate(d, d, 0.14, rim=0.05, lift=0.0, face_mat=mat_face(),
                           rim_height=0.10, face_height=0.09, framed=True)
    gold_glyph(glyph, d * 0.36, top - 0.02)
    render(out / f"{name}_normal.png", shadow_offset=3)
    _states(out, name)


def pill_button(out: Path, red: bool, w_px: int = 400, h_px: int = 120) -> None:
    """Blank pill button for the bottom bar (label drawn by Godot).
    9-slice: stretch only the middle columns (margins = h_px / 2 + PAD)."""
    name = "pill_button_red" if red else "pill_button"
    w, h = w_px / PX, h_px / PX
    _scene(w_px, h_px)
    control_plate(w, h, h / 2, rim=0.09, lift=0.0, face_mat=mat_red() if red else mat_face())
    render(out / f"{name}_normal.png")
    _states(out, name, active=not red)


def title_plaque(out: Path, w_px: int = 640, h_px: int = 120) -> None:
    """Blank title plaque, shared by the setup panels (the title is a Godot Label)."""
    w, h = w_px / PX, h_px / PX
    _scene(w_px, h_px)
    framed_plate(w, h, h * 0.28, rim=0.13, lift=0.10, face_mat=mat_face())
    render(out / "title_plaque.png")


def button_bar(out: Path, w_px: int = 1760, h_px: int = 168, name: str = "button_bar",
               tile: float = BAR_TILE, rotation: float = 0.0) -> None:
    """Knights armor plate with a gold rim: bottom button bars and the game screen
    side panel. Rendered at its real on-screen size so the texture is never
    stretched."""
    w, h = w_px / PX, h_px / PX
    _scene(w_px, h_px)
    framed_plate(w, h, 0.4, rim=0.10, lift=0.0, face_mat=mat_textured(BAR_TEXTURES, tile, rotation))
    render(out / f"{name}.png", shadow_offset=6)


def panel(out: Path, name: str = "panel", alpha: float = 0.85, size_px: int = 256, radius_px: int = 40) -> None:
    """9-slice source for the big panels: gold rim (as thick as the title
    plaque's), uniform dark face, slightly see-through by default (opaque
    variant for dialogs drawn over other content).
    Patch margins: radius_px + rim + PAD on every side."""
    s = size_px / PX
    _scene(size_px, size_px)
    framed_plate(s, s, radius_px / PX, rim=0.13, lift=0.0, face_mat=mat_dark_flat(0.006, alpha=alpha))
    render(out / f"{name}.png", shadow_offset=8)


def row_plate(out: Path, w_px: int = 256, h_px: int = 90, active: bool = False) -> None:
    """9-slice source for list rows (players, options, score tables): thin frame
    in the control style, dark face; active = face lit by a warm light (current
    player of the score tables)."""
    w, h = w_px / PX, h_px / PX
    _scene(w_px, h_px)
    face = mat_dark_flat(0.012)
    if active:
        face, bsdf = _principled("WarmFace", (0.05, 0.028, 0.006), 0.0, 0.4)
        bsdf.inputs["Emission Color"].default_value = (1.0, 0.55, 0.12, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 0.09
    control_plate(w, h, 0.18, rim=0.04, lift=0.0, face_mat=face,
                  rim_height=0.06, face_height=0.04, framed=True)
    render(out / f"row_plate_{'active' if active else 'normal'}.png", shadow_offset=4)


def value_display(out: Path, w_px: int = 240, h_px: int = 80) -> None:
    """Recessed dark display for option values (value drawn by Godot)."""
    w, h = w_px / PX, h_px / PX
    _scene(w_px, h_px)
    control_plate(w, h, 0.14, rim=0.05, lift=0.0, face_mat=mat_dark_flat(0.002),
                  rim_height=0.10, face_height=0.02, framed=True)
    render(out / "value_display.png", shadow_offset=3)


def toggle(out: Path, w_px: int = 150, h_px: int = 72) -> None:
    """Switch for boolean options (CheckButton icons): off = dark track, knob left;
    on = gold track, knob right."""
    w, h = w_px / PX, h_px / PX
    knob = h * 0.78
    for state, on in (("off", False), ("on", True)):
        _scene(w_px, h_px)
        _, top = control_plate(w, h, h / 2, rim=0.06, lift=0.0,
                               face_mat=STYLE["track_on"]() if on else mat_dark_flat(0.004),
                               rim_height=0.08, face_height=0.03, framed=True)
        x = (w / 2 - h / 2) * (1 if on else -1)
        objs, _ = control_plate(knob, knob, knob / 2, rim=knob * 0.14, lift=max(top, 0.08), face_mat=mat_face(),
                                framed=True)
        for obj in objs:
            obj.location.x = x
        render(out / f"toggle_{state}.png", shadow_offset=3)
        make_disabled(out / f"toggle_{state}.png", out / f"toggle_{state}_disabled.png")


SPIN_CAP, SPIN_MID, SPIN_H = 88, 200, 80  # px: arrow caps, middle (stretched), height


def spinner(out: Path) -> None:
    """Option value selector in one piece: steel frame, dark value window in the
    middle, the left/right arrow buttons forming the two ends of the frame.
    Rendered whole (normal, each cap pressed, disabled), then cut into
    spinner_left_*, spinner_mid (9-slice horizontally) and spinner_right_*, so
    the joins are seamless in Godot."""
    w_px = 2 * SPIN_CAP + SPIN_MID
    w, h = w_px / PX, SPIN_H / PX
    r, rim, rim_h = 0.14, 0.05, 0.10
    wi, hi = w - 2 * rim, h - 2 * rim
    xd = w / 2 - SPIN_CAP / PX  # divider x (right side, mirrored on the left)
    div = 0.05

    def cap_outline(side: int):
        inner = rounded_rect(wi, hi, r - rim)
        # Counter-clockwise outline: its left arcs run from the top edge down to the bottom one.
        left = [pt for pt in inner if pt[0] < -xd]
        poly = left + [(-xd + div / 2, -hi / 2), (-xd + div / 2, hi / 2)]
        if side > 0:
            poly = [(-x, y) for x, y in reversed(poly)]
        return poly

    def build(pressed: int):
        _scene(w_px, SPIN_H)
        steel = STYLE["rim"]
        ring("Rim", rounded_rect(w, h, r), rounded_rect(wi, hi, r - rim), 0.0, rim_h, steel(), rim * 0.45)
        for side in (-1, 1):
            divider = prism(f"Divider{side}", rounded_rect(div, hi + 0.01, 0.005, 2), 0.0, rim_h, steel(), 0.015)
            divider.location.x = side * xd
            top = 0.09 if pressed != side else 0.05
            cap = prism(f"Cap{side}", cap_outline(side), 0.0, top, mat_face(), 0.025)
            if pressed == side:
                cap.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
            for g in gold_glyph("right" if side > 0 else "left", SPIN_H / PX * 0.34, top - 0.02):
                g.location.x += side * (w / 2 - SPIN_CAP / PX / 2)
        prism("Window", rounded_rect(2 * xd - div, hi, 0.01, 2), 0.0, 0.02, mat_dark_flat(0.002), 0.005)

    states = (("normal", 0), ("left_pressed", -1), ("right_pressed", 1))
    for name, pressed in states:
        build(pressed)
        render(out / f"_spinner_{name}.png", shadow_offset=3)
    make_disabled(out / "_spinner_normal.png", out / "_spinner_disabled.png")

    x_left = PAD + SPIN_CAP  # first column of the middle piece
    x_right = PAD + SPIN_CAP + SPIN_MID
    normal = _load(out / "_spinner_normal.png")
    _save(normal[:, x_left:x_right].copy(), out / "spinner_mid.png")
    for state in ("normal", "disabled"):
        img = _load(out / f"_spinner_{state}.png")
        _save(img[:, :x_left].copy(), out / f"spinner_left_{state}.png")
        _save(img[:, x_right:].copy(), out / f"spinner_right_{state}.png")
    _save(_load(out / "_spinner_left_pressed.png")[:, :x_left].copy(), out / "spinner_left_pressed.png")
    _save(_load(out / "_spinner_right_pressed.png")[:, x_right:].copy(), out / "spinner_right_pressed.png")


def medallion(out: Path, index: int, color, size_px: int = 80) -> None:
    """Player badge: gold rim, colored enamel ring, dark center (number drawn by Godot)."""
    d = size_px / PX
    _scene(size_px, size_px)
    gold_r, color_r = d / 2, d / 2 * 0.84
    face_r = d / 2 * 0.64
    ring("Rim", rounded_rect(d, d, gold_r), rounded_rect(2 * color_r, 2 * color_r, color_r),
         0.0, 0.12, mat_gold(), 0.04)
    ring("Enamel", rounded_rect(2 * color_r, 2 * color_r, color_r), rounded_rect(2 * face_r, 2 * face_r, face_r),
         0.0, 0.09, mat_enamel(color), 0.02)
    prism("Face", rounded_rect(2 * face_r, 2 * face_r, face_r), 0.0, 0.07, mat_face(), 0.01)
    render(out / f"medallion_{index}.png", shadow_offset=4)


def icon(out: Path, glyph: str, size_px: int = 56) -> None:
    """Standalone gold icon (no button), e.g. the edit pencil of the player rows."""
    _scene(size_px, size_px)
    gold_glyph(glyph, size_px / PX * 0.95, 0.0)
    render(out / f"icon_{glyph}.png", shadow_offset=2)


def gold_rule(out: Path, w_px: int = 600, h_px: int = 6) -> None:
    """Thin gold divider under option group titles."""
    _scene(w_px, h_px)
    prism("Rule", rounded_rect(w_px / PX, h_px / PX, h_px / PX / 2, 6), 0.0, 0.03, mat_gold(), 0.01)
    render(out / "gold_rule.png", shadow_offset=2)


def contact_sheet(out: Path, files: list[Path], cols: int, name: str) -> None:
    imgs = [_load(f) for f in files]
    cell_w = max(i.shape[1] for i in imgs) + 20
    cell_h = max(i.shape[0] for i in imgs) + 20
    rows = math.ceil(len(imgs) / cols)
    sheet = np.zeros((rows * cell_h, cols * cell_w, 4), dtype=np.float32)
    sheet[..., :3] = (0.36, 0.20, 0.06)  # warm amber, like the dartboard background
    sheet[..., 3] = 1.0
    for k, img in enumerate(imgs):
        # Blender image rows go bottom-up: row 0 of the sheet array is the bottom.
        r, c = rows - 1 - k // cols, k % cols
        y = r * cell_h + (cell_h - img.shape[0]) // 2
        x = c * cell_w + (cell_w - img.shape[1]) // 2
        region = sheet[y:y + img.shape[0], x:x + img.shape[1]]
        sheet[y:y + img.shape[0], x:x + img.shape[1]] = _over(img, region)
    _save(sheet, out / f"_preview_{name}.png")


# Elements that can be rendered alone with --elements.
SINGLE_ELEMENTS = {
    "button_bar": button_bar,
    "game_bar": lambda out: button_bar(out, 1552, 168, "game_bar"),
    "game_side_panel": lambda out: button_bar(out, 320, 1048, "game_side_panel", tile=12.0, rotation=17.0),
    "row_plate_active": lambda out: row_plate(out, active=True),
    "title_plaque": title_plaque,
    "spinner": spinner,
}


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--controls", choices=CONTROL_STYLES, default="sober",
                   help="look of the buttons, option arrows, row plates and toggles")
    p.add_argument("--only-controls", action="store_true",
                   help="render only the elements affected by --controls")
    p.add_argument("--elements", nargs="+", choices=sorted(SINGLE_ELEMENTS),
                   help="render only these elements")
    args = p.parse_args(argv)
    global STYLE
    STYLE = CONTROL_STYLES[args.controls]
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if args.elements:
        for element in args.elements:
            SINGLE_ELEMENTS[element](out)
        return

    glyphs = ("minus", "plus", "left", "right", "up", "down", "question")
    states = ("normal", "active", "disabled")
    for glyph in glyphs:
        round_button(out, glyph)
    pill_button(out, red=False)
    pill_button(out, red=True)
    row_plate(out)
    row_plate(out, active=True)
    value_display(out)
    spinner(out)
    toggle(out)
    icon(out, "pencil")
    if args.only_controls:
        contact_sheet(out, [out / f"round_button_{g}_normal.png" for g in glyphs]
                      + [out / "pill_button_normal.png", out / "pill_button_active.png",
                         out / "pill_button_red_normal.png", out / "toggle_off.png", out / "toggle_on.png",
                         out / "value_display.png", out / "icon_pencil.png", out / "_spinner_normal.png",
                         out / "_spinner_left_pressed.png", out / "_spinner_disabled.png"],
                      len(glyphs), "controls_" + args.controls)
        return
    title_plaque(out)
    button_bar(out)
    SINGLE_ELEMENTS["game_bar"](out)
    SINGLE_ELEMENTS["game_side_panel"](out)
    panel(out)
    panel(out, "dialog_panel", alpha=1.0)
    for i, color in enumerate(PLAYER_COLORS, 1):
        medallion(out, i, color)
    gold_rule(out)

    contact_sheet(out, [out / f"round_button_{g}_{s}.png" for s in states for g in glyphs], len(glyphs), "round_buttons")
    contact_sheet(out, [out / f"pill_button_{s}.png" for s in states]
                  + [out / "pill_button_red_normal.png", out / "pill_button_red_disabled.png", out / "title_plaque.png"],
                  3, "pills")
    contact_sheet(out, [out / f"medallion_{i}.png" for i in range(1, len(PLAYER_COLORS) + 1)]
                  + [out / "icon_pencil.png"], 9, "medallions")
    contact_sheet(out, [out / f"toggle_{s}.png" for s in ("off", "on", "off_disabled", "on_disabled")]
                  + [out / "value_display.png", out / "gold_rule.png"], 3, "controls")
    contact_sheet(out, [out / "panel.png", out / "row_plate_normal.png", out / "row_plate_active.png"], 3, "plates")
    contact_sheet(out, [out / "button_bar.png"], 1, "bar")


main()

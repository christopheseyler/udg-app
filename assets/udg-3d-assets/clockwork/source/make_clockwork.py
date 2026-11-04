"""Clockwork parts for the Around the Clock logo: three brass wheels and two
black lacquered hands, one GLB each in the parent folder.

Each part is a flat outline extruded from z = 0 (back) to its thickness (front,
facing Godot +Z; Blender -Y), its origin on its axis of rotation.

- Wheel<N>.glb: a clock wheel of N teeth (WHEELS), all of module MODULE (pitch
  radius MODULE * N / 2) so that any two of them mesh at a centre distance of
  MODULE * (N1 + N2) / 2. The teeth have radial flanks under the pitch circle
  and a rounded (ogival) tip above it, 0.46 of the pitch thick at the pitch
  circle, with room to spare in the gaps of the other wheel. The rim is held
  to the hub by straight spokes, and the hub has an axle hole.
- MinuteHand.glb, HourHand.glb: hands pointing to +Y, with a boss around the
  axis, a spade near the tip and a round counterweight on the tail.

The walls are smooth shaded, with sharp edges at their corners and around the
flat front and back faces.

    blender --background --factory-startup --python make_clockwork.py -- [--preview]

Output: the GLBs (+ source/clockwork_preview.png with --preview).
"""
import math
import os
import sys

import bpy  # before bmesh
import bmesh
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)

MODULE = 0.005
WHEEL_THICKNESS = 0.006
# name: (teeth, spokes, hub radius)
WHEELS = {"Wheel52": (52, 6, 0.022), "Wheel20": (20, 4, 0.011), "Wheel18": (18, 5, 0.010)}
AXLE = 0.0025                 # radius of the axle hole
HAND_THICKNESS = 0.0025
ARC_STEP = math.radians(3)    # arcs sampled at least that finely
SHARP = math.radians(35)      # wall edges sharper than that stay sharp

# part frame (x, y, z toward the viewer) -> Blender, facing -Y
TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


# ---------------------------------------------------------------- outlines
def polar(r, a):
    return Vector((r * math.cos(a), r * math.sin(a)))


def arc(r, a0, a1, centre=Vector((0, 0)), first=True):
    """Points of the arc of radius r from angle a0 to a1 (either way)."""
    n = max(1, math.ceil(abs(a1 - a0) / ARC_STEP))
    return [centre + polar(r, a0 + (a1 - a0) * i / n) for i in range(0 if first else 1, n + 1)]


def area(pts):
    return sum(a.cross(b) for a, b in zip(pts, pts[1:] + pts[:1])) / 2


def wheel_outline(n):
    """Toothed outline of a wheel of n teeth, counter-clockwise."""
    r = MODULE * n / 2
    ra, rf = r + 0.9 * MODULE, r - 1.15 * MODULE
    p = 2 * math.pi / n
    tp = 0.23 * p                          # half tooth, as an angle at the pitch circle
    k_tip = 6
    pts = []
    for k in range(n):
        c = k * p
        pts += arc(rf, c - p + tp, c - tp, first=False)     # gap, from the previous tooth
        for i in range(k_tip + 1):                           # flank and tip, up ...
            u = math.pi / 2 * i / k_tip
            pts.append(polar(r + (ra - r) * math.sin(u), c - tp * math.cos(u)))
        for i in range(k_tip - 1, -1, -1):                   # ... and down
            u = math.pi / 2 * i / k_tip
            pts.append(polar(r + (ra - r) * math.sin(u), c + tp * math.cos(u)))
        pts.append(polar(rf, c + tp))
    return pts


def wheel_holes(n, spokes, hub):
    """Openings between the spokes, and the axle hole."""
    r = MODULE * n / 2
    rim = r - 1.15 * MODULE - max(0.006, 0.08 * r)        # inner radius of the rim
    w = max(0.0022, 0.035 * r)                             # half width of a spoke
    holes = []
    for j in range(spokes):
        a0, a1 = 2 * math.pi * j / spokes, 2 * math.pi * (j + 1) / spokes
        outer, inner = math.asin(w / rim), math.asin(w / hub)
        holes.append(arc(rim, a0 + outer, a1 - outer) + arc(hub, a1 - inner, a0 + inner))
    holes.append(arc(AXLE, 0, 2 * math.pi)[:-1])
    return holes


def hand_outline(tail, tail_width, boss, profile):
    """Hand pointing to +Y: a round counterweight (centre y, radius) on a tail
    of half width tail_width, a boss of radius boss around the axis, then
    `profile`, the right edge of the hand from the boss to its tip (x = 0).
    Counter-clockwise: up the right edge, down the mirrored left one."""
    ty, tr = tail
    top = math.atan2(math.sqrt(tr * tr - tail_width ** 2), tail_width)
    below = math.atan2(-math.sqrt(boss * boss - tail_width ** 2), tail_width)
    x0 = profile[0][0]
    above = math.atan2(math.sqrt(boss * boss - x0 * x0), x0)
    right = (arc(tr, -math.pi / 2, top, Vector((0, ty)))
             + arc(boss, below, above)
             + [Vector(p) for p in profile[1:]])
    left = [Vector((-p.x, p.y)) for p in reversed(right[1:-1])]
    return right + left


HANDS = {
    "MinuteHand": hand_outline((-0.04, 0.011), 0.004, 0.013, [
        (0.0055, 0.0), (0.0035, 0.148), (0.0110, 0.162), (0.0020, 0.186), (0.0, 0.205)]),
    "HourHand": hand_outline((-0.03, 0.010), 0.0045, 0.014, [
        (0.0070, 0.0), (0.0048, 0.082), (0.0130, 0.088), (0.0185, 0.097), (0.0190, 0.106),
        (0.0160, 0.115), (0.0085, 0.126), (0.0, 0.142)]),
}


# ---------------------------------------------------------------- mesh
def extruded(loops, thickness):
    """Solid bmesh of the outline loops[0] with the holes loops[1:], from z = 0
    to thickness."""
    loops = [l if (area(l) > 0) == (k == 0) else l[::-1] for k, l in enumerate(loops)]
    bm = bmesh.new()
    flat = [p for l in loops for p in l]
    back = [bm.verts.new((p.x, p.y, 0.0)) for p in flat]
    front = [bm.verts.new((p.x, p.y, thickness)) for p in flat]
    caps = set()
    for a, b, c in tessellate_polygon([[p.to_3d() for p in l] for l in loops]):
        if (flat[b] - flat[a]).cross(flat[c] - flat[a]) < 0:
            a, b = b, a
        caps.add(bm.faces.new((front[a], front[b], front[c])))
        caps.add(bm.faces.new((back[a], back[c], back[b])))
    start = 0
    for l in loops:
        n = len(l)
        for i in range(n):
            a, b = start + i, start + (i + 1) % n
            bm.faces.new((back[a], back[b], front[b], front[a]))
        start += n
    bm.normal_update()
    for f in bm.faces:
        f.smooth = f not in caps
    for e in bm.edges:
        fs = e.link_faces
        e.smooth = (len(fs) == 2 and not (fs[0] in caps or fs[1] in caps)
                    and fs[0].normal.angle(fs[1].normal) < SHARP)
    return bm


def material(name, colour, roughness, metallic=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*colour, 1.0)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = roughness
    return m


def part(name, bm, mat):
    bmesh.ops.transform(bm, matrix=TO_BLENDER, verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True)
    print("[clockwork] %s: %d triangles" % (name, tris))
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    brass = material("Brass", (0.85, 0.6, 0.27), 0.3)
    # Not metal: a metal only reflects the warm, dim surroundings of the
    # carousel, and the hands then blend into the brass.
    lacquer = material("BlackLacquer", (0.02, 0.02, 0.025), 0.2, metallic=0.0)
    obs = []
    for name, (n, spokes, hub) in WHEELS.items():
        obs.append(part(name, extruded([wheel_outline(n)] + wheel_holes(n, spokes, hub),
                                       WHEEL_THICKNESS), brass))
    for name, outline in HANDS.items():
        obs.append(part(name, extruded([outline], HAND_THICKNESS), lacquer))
    if "--preview" in ARGS:
        render_preview(os.path.join(HERE, "clockwork_preview.png"), obs)


def render_preview(path, obs):
    x = 0.0
    for ob in obs:
        w = ob.dimensions.x
        ob.location.x = x + w / 2
        x += w + 0.02
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1800, 700
    world = bpy.data.worlds.new("Preview")
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.06, 1)
    # Metal needs surroundings to reflect: Blender's interior studio light,
    # behind the plain background the camera sees.
    env = nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(
        bpy.utils.system_resource("DATAFILES", path="studiolights/world"), "interior.exr"))
    lit = nodes.new("ShaderNodeBackground")
    links.new(env.outputs["Color"], lit.inputs["Color"])
    mix = nodes.new("ShaderNodeMixShader")
    links.new(nodes.new("ShaderNodeLightPath").outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(lit.outputs["Background"], mix.inputs[1])
    links.new(nodes["Background"].outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], nodes["World Output"].inputs["Surface"])
    scene.world = world
    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = x * 1.02
    scene.collection.objects.link(cam)
    view = Vector((0.15, -1.0, 0.35)).normalized()
    cam.location = Vector((x / 2, 0, 0)) + view * x
    cam.rotation_euler = (-view).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for name, rot, energy in (("Key", (math.radians(50), 0, math.radians(-35)), 3.0),
                              ("Rim", (math.radians(110), 0, math.radians(150)), 1.5)):
        sun = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        sun.data.energy = energy
        sun.rotation_euler = rot
        scene.collection.objects.link(sun)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


main()

"""Parts of the Cricket mark (games/cricket/cricket_mark_3d.tscn), one GLB each in
the parent folder:

- CricketRing.glb: the front half of a torus, cut in its plane: flat back at
  z = 0, rounded front. Outer radius RING_RADIUS + RING_TUBE = 0.5: the mark is
  1 unit wide.
- CricketBar.glb: the front half of a capsule along X (a cylinder with rounded
  ends), cut the same way, BAR_LENGTH long end to end. The mark crosses two of
  them at 45 degrees over the ring, and their ends stick out of it.

Both face Godot +Z (Blender -Y), centred on their origin. The rounded faces are
smooth shaded, the flat back is flat, with sharp edges around it. Their
material is a placeholder: CricketMark3D gives each part its own.

    blender --background --factory-startup --python make_cricket_mark.py -- [--preview]

Output: the GLBs (+ source/cricket_mark_preview.png with --preview).
"""
import math
import os
import sys

import bpy  # before bmesh
import bmesh
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)

RING_RADIUS = 0.435           # centre line of the tube
RING_TUBE = 0.065             # radius of the tube
BAR_RADIUS = 0.06
BAR_LENGTH = 1.12             # end to end
AROUND = 96                   # segments around the ring
ACROSS = 12                   # segments across a rounded half section
CAP = 8                       # segments along a rounded end

# part frame (x, y, z toward the viewer) -> Blender, facing -Y
TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


def finish(bm, back):
    """Outward normals, smooth rounded faces, flat back with sharp edges."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = f not in back
    for e in bm.edges:
        fs = e.link_faces
        e.smooth = len(fs) == 2 and (fs[0] in back) == (fs[1] in back)
    return bm


def ring():
    bm = bmesh.new()
    grid = [[bm.verts.new(((RING_RADIUS + RING_TUBE * math.cos(a)) * math.cos(t),
                           (RING_RADIUS + RING_TUBE * math.cos(a)) * math.sin(t),
                           RING_TUBE * math.sin(a)))
             for a in (math.pi * j / ACROSS for j in range(ACROSS + 1))]
            for t in (2 * math.pi * i / AROUND for i in range(AROUND))]
    back = set()
    for i in range(AROUND):
        u, v = grid[i], grid[(i + 1) % AROUND]
        for j in range(ACROSS):
            bm.faces.new((u[j], v[j], v[j + 1], u[j + 1]))
        back.add(bm.faces.new((u[ACROSS], v[ACROSS], v[0], u[0])))   # inner to outer edge
    return finish(bm, back)


def bar():
    """Rings of the half capsule from one tip to the other, each from its +Y edge
    over the top to its -Y edge (a tip is a single vertex)."""
    half = BAR_LENGTH / 2 - BAR_RADIUS
    stations = [(-half - BAR_RADIUS * math.cos(p), BAR_RADIUS * math.sin(p))
                for p in (math.pi / 2 * k / CAP for k in range(CAP + 1))]
    stations += [(-x, r) for x, r in reversed(stations)]
    bm = bmesh.new()
    rings = []
    for x, r in stations:
        if r < 1e-9:
            rings.append([bm.verts.new((x, 0, 0))] * (ACROSS + 1))
        else:
            rings.append([bm.verts.new((x, r * math.cos(a), r * math.sin(a)))
                          for a in (math.pi * j / ACROSS for j in range(ACROSS + 1))])
    back = set()
    for u, v in zip(rings, rings[1:]):
        for j in range(ACROSS):
            quad = list(dict.fromkeys((u[j], v[j], v[j + 1], u[j + 1])))
            bm.faces.new(quad)
        side = list(dict.fromkeys((u[ACROSS], v[ACROSS], v[0], u[0])))
        back.add(bm.faces.new(side))
    return finish(bm, back)


def material():
    m = bpy.data.materials.new("CricketMark")
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.04, 0.04, 0.05, 1.0)
    p.inputs["Roughness"].default_value = 0.08
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
    print("[cricket_mark] %s: %d triangles" % (name, tris))
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = material()
    obs = [part("CricketRing", ring(), mat), part("CricketBar", bar(), mat)]
    if "--preview" in ARGS:
        render_preview(os.path.join(HERE, "cricket_mark_preview.png"), obs)


def render_preview(path, obs):
    """The ring and two bars crossed over it, as the mark lays them out."""
    ring_ob, bar_ob = obs
    second = bar_ob.copy()
    bpy.context.scene.collection.objects.link(second)
    bar_ob.rotation_euler.y = math.radians(45)      # Blender Y is the depth axis
    second.rotation_euler.y = math.radians(-45)
    bar_ob.location.y = second.location.y = -0.02
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 800
    world = bpy.data.worlds.new("Preview")
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes["Background"].inputs["Color"].default_value = (0.35, 0.35, 0.38, 1)
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
    cam.data.ortho_scale = 1.4
    scene.collection.objects.link(cam)
    view = Vector((0.25, -1.0, 0.35)).normalized()
    cam.location = view * 3
    cam.rotation_euler = (-view).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


main()

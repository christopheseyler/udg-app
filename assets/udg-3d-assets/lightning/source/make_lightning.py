"""Lightning bolt: the "3" of the Lightning Bolt font (Woodcutter Manero), extruded,
with a wide flat bevel on its front face only (flat back, straight walls).

The glyph outline is first straightened: its long edges are kept (consecutive ones
nearly in line merged into one), the short ones rounding its corners dropped, and
each corner is the intersection of its two edges. The bevel is then an inset of
that outline (each edge moved inward by the same distance, each corner along its
bisector): exact as long as the inset outline does not cross itself, so the widest
bevel is that limit, found by bisection. --bevel is the bevel width as a fraction
of it; at the bolt's sharp tips the bevel faces meet on a ridge.

Facing Godot +Z (Blender -Y), back face at z = 0, centred on the origin in x and y.

    blender --background --factory-startup --python make_lightning.py -- <out_dir>
            [--height 0.4] [--depth 0.045] [--bevel 0.85] [--slope 45]
            [--font <ttf>] [--preview]

--height is the bolt's height and --depth its thickness, in metres. --slope is the
angle of the bevel faces to the front face, in degrees: the bevel is as deep as it
is wide at 45. Output: Lightning.glb (+ Lightning_preview.png with --preview).
"""
import math
import os
import sys

import bpy  # before bmesh
import bmesh
from mathutils import Matrix, Vector
from mathutils.geometry import intersect_line_line_2d, tessellate_polygon

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def arg(name, default):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


OUT = os.path.abspath(ARGS[0] if ARGS and not ARGS[0].startswith("--") else "out")
# Installed for the current user (LOCALAPPDATA), else for all users.
FONT = arg("--font", next((p for p in (
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft/Windows/Fonts/Lightning Bolt.ttf"),
    "C:/Windows/Fonts/Lightning Bolt.ttf") if os.path.isfile(p)), "Lightning Bolt.ttf"))
CHAR = "3"
HEIGHT = float(arg("--height", 0.4))
DEPTH = float(arg("--depth", 0.045))
BEVEL = float(arg("--bevel", 0.85))
SLOPE = math.radians(float(arg("--slope", 45)))
NAME = "Lightning"
LONG_EDGE = 0.03      # outline edges kept, as a fraction of the glyph height
IN_LINE = math.radians(8)   # consecutive kept edges closer than that are merged
os.makedirs(OUT, exist_ok=True)

# bolt frame (x, y, z toward the viewer) -> Blender, facing -Y
TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


def glyph_outline():
    """Outline of the glyph as Blender fills it, counter-clockwise, at text size 1."""
    cu = bpy.data.curves.new("t", "FONT")
    cu.body = CHAR
    cu.font = bpy.data.fonts.load(FONT)
    cu.size = 1.0
    cu.resolution_u = 12
    ob = bpy.data.objects.new("t", cu)
    bpy.context.scene.collection.objects.link(ob)
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    font = cu.font
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bpy.data.fonts.remove(font)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts, edges=bm.edges)
    if len(bm.faces) != 1:
        raise RuntimeError("expected the glyph as a single face, got %d" % len(bm.faces))
    pts = [v.co.xy.copy() for v in bm.faces[:][0].verts]
    bm.free()
    if area(pts) < 0:
        pts.reverse()
    return pts


def area(pts):
    return sum(a.cross(b) for a, b in zip(pts, pts[1:] + pts[:1])) / 2


def straightened(pts):
    """The outline as its long edges only (see the module docstring). An edge of the
    font can come as a chain of short, nearly aligned segments (a slightly curved
    stroke): segments within IN_LINE of the first one of their chain are merged."""
    n = len(pts)
    height = max(p.y for p in pts) - min(p.y for p in pts)
    dirs = [(pts[(i + 1) % n] - pts[i]) for i in range(n)]

    def turn(u, v):
        return abs(u.angle_signed(v))
    # Start on a segment not in line with its predecessor.
    start = next(i for i in range(n) if turn(dirs[i - 1], dirs[i]) > IN_LINE)
    chains = []                           # [first segment, last segment] of each chain
    for k in range(n):
        i = (start + k) % n
        if chains and turn(dirs[chains[-1][0]], dirs[i]) <= IN_LINE:
            chains[-1][1] = i
        else:
            chains.append([i, i])
    lines = [(pts[a], pts[(b + 1) % n]) for a, b in chains
             if (pts[(b + 1) % n] - pts[a]).length > LONG_EDGE * height]
    corners = []
    for (a0, a1), (b0, b1) in zip(lines[-1:] + lines[:-1], lines):
        da, db = (a1 - a0).normalized(), (b1 - b0).normalized()
        # intersection of the two (infinite) lines
        t = (b0 - a0).cross(db) / da.cross(db)
        p = a0 + da * t
        if (p - (a1 + b0) / 2).length > 0.05 * height:
            raise RuntimeError("corner far from the glyph at (%.4f, %.4f)" % tuple(p))
        corners.append(p)
    return corners


def inset(pts, d):
    """Each edge moved inward by d, each corner along its bisector."""
    n = len(pts)
    normals = [Vector((-(b - a).y, (b - a).x)).normalized() for a, b in zip(pts, pts[1:] + pts[:1])]
    out = []
    for i in range(n):
        n1, n2 = normals[i - 1], normals[i]
        out.append(pts[i] + (n1 + n2) * (d / (1 + n1.dot(n2))))
    return out


def is_simple(pts, ref):
    """The inset `pts` keeps every edge of `ref` pointing the same way and does not
    cross itself."""
    n = len(pts)
    for i in range(n):
        if (pts[(i + 1) % n] - pts[i]).dot(ref[(i + 1) % n] - ref[i]) <= 0:
            return False
    for i in range(n):
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            if intersect_line_line_2d(pts[i], pts[(i + 1) % n], pts[j], pts[(j + 1) % n]):
                return False
    return True


def widest_inset(pts):
    lo, hi = 0.0, max(p.x for p in pts) - min(p.x for p in pts)
    for _ in range(40):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if is_simple(inset(pts, mid), pts) else (lo, mid)
    return lo


def material():
    m = bpy.data.materials.new(NAME)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (1.0, 0.62, 0.04, 1.0)
    p.inputs["Metallic"].default_value = 1.0
    p.inputs["Roughness"].default_value = 0.3
    return m


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    outline = straightened(glyph_outline())
    lo = Vector((min(p.x for p in outline), min(p.y for p in outline)))
    hi = Vector((max(p.x for p in outline), max(p.y for p in outline)))
    scale = HEIGHT / (hi.y - lo.y)
    outline = [(p - (lo + hi) / 2) * scale for p in outline]
    limit = widest_inset(outline)
    width = BEVEL * limit
    drop = width * math.tan(SLOPE)
    if drop >= DEPTH:
        raise RuntimeError("the bevel (%.4f m deep) does not fit in --depth %.4f" % (drop, DEPTH))
    front = inset(outline, width)

    bm = bmesh.new()
    back = [bm.verts.new((p.x, p.y, 0.0)) for p in outline]
    rim = [bm.verts.new((p.x, p.y, DEPTH - drop)) for p in outline]
    top = [bm.verts.new((p.x, p.y, DEPTH)) for p in front]
    n = len(outline)
    # Front and back triangulated here: bmesh.ops.triangulate turned a triangle of
    # the (concave, narrow necked) front face over.
    for a, b, c in tessellate_polygon([[p.to_3d() for p in front]]):
        if (front[b] - front[a]).cross(front[c] - front[a]) < 0:
            a, b = b, a
        bm.faces.new((top[a], top[b], top[c]))
    for a, b, c in tessellate_polygon([[p.to_3d() for p in outline]]):
        if (outline[b] - outline[a]).cross(outline[c] - outline[a]) > 0:
            a, b = b, a
        bm.faces.new((back[a], back[b], back[c]))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], rim[j], rim[i]))
        bm.faces.new((rim[i], rim[j], top[j], top[i]))
    for f in bm.faces:
        f.smooth = False
    bm.normal_update()
    bmesh.ops.transform(bm, matrix=TO_BLENDER, verts=bm.verts)
    me = bpy.data.meshes.new(NAME)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material())
    ob = bpy.data.objects.new(NAME, me)
    bpy.context.scene.collection.objects.link(ob)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True)
    size = (hi - lo) * scale
    print("[lightning] %d corners, %.3f x %.3f x %.3f m, bevel %.4f m wide (limit %.4f), "
          "%.4f m deep, %d triangles" % (n, size.x, size.y, DEPTH, width, limit, drop,
                                         sum(len(p.vertices) - 2 for p in me.polygons)))
    if "--preview" in ARGS:
        render_preview(os.path.join(OUT, NAME + "_preview.png"), ob)


def render_preview(path, ob):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    world = bpy.data.worlds.new("Preview")
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.06, 1)
    # Metal needs surroundings to reflect: Blender's interior studio light, behind
    # the plain background the camera sees.
    nodes, links = world.node_tree.nodes, world.node_tree.links
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
    cam.data.ortho_scale = HEIGHT * 1.2
    scene.collection.objects.link(cam)
    view = Vector((0.45, -1.0, 0.3)).normalized()           # from the front, right, above
    cam.location = Vector((0, 0, 0)) + view * HEIGHT * 3
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

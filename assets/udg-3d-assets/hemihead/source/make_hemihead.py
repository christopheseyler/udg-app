"""HemiHead Bold Italic characters A-Z, a-z and 0-9, each its own object (Char_A,
Char_a, Char_0...): slightly extruded, with a rounded bevel on the front face only
(flat back). Facing Blender -Y (= Godot +Z), back face at y = 0.

With --chamfer the front bevel is a flat chamfer instead. With --outline each
character also gets a backing plate behind it: the same glyph dilated by that
amount (mitred corners), a quarter of the character's depth thick, in a second
material (HemiHead_Outline). With --textures <dir> (the PBR sets of
tools/blender/textures) the letter is brushed metal and the backing scuffed gold,
box-mapped; otherwise both are plain greys.

Each mesh has its origin on the baseline at the glyph's pen position, and carries
its advance width in metres as the "advance" custom property (glTF extras), so
words can be laid out by adding advances. In the file the characters are laid out
in three rows (upper case, lower case, digits) under the "HemiHead" root.

    blender --background --factory-startup --python make_hemihead.py -- <out_dir>
            [--size 0.1] [--depth 0.1] [--bevel 0.02] [--chamfer] [--outline 0.03]
            [--textures <dir>] [--chars ABC] [--name HemiHead] [--font <otf>] [--preview]

--size is the text size in metres as Blender defines it: the height of the font's
bounding box (1255 units of its 1000-unit em for HemiHead). --depth (extrusion),
--bevel (front bevel width) and --outline (dilation of the backing) are fractions
of that size. --chars limits the characters. Output: <name>.glb + <name>.blend
(+ <name>_preview.png with --preview).
"""
import glob
import math
import os
import struct
import sys
from collections import Counter

import bpy  # before bmesh
import bmesh
import numpy
from mathutils import Matrix, Vector
from mathutils.geometry import delaunay_2d_cdt

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def arg(name, default):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


OUT = os.path.abspath(ARGS[0] if ARGS and not ARGS[0].startswith("--") else "out")
# Installed for the current user (LOCALAPPDATA), else for all users.
FONT = arg("--font", next((p for p in (
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft/Windows/Fonts/HemiHead-BoldItalic.otf"),
    "C:/Windows/Fonts/HemiHead-BoldItalic.otf") if os.path.isfile(p)), "HemiHead-BoldItalic.otf"))
SIZE = float(arg("--size", 0.1))
DEPTH = float(arg("--depth", 0.1))
BEVEL = float(arg("--bevel", 0.02))
BEVEL_SEG = 1 if "--chamfer" in ARGS else 3
OUTLINE = float(arg("--outline", 0))  # dilation of the backing plate, 0 = none
BACKING = DEPTH / 4                   # thickness of the backing plate
MITER_LIMIT = 2.0                     # backing corners: mitred up to 2x the dilation
TEXTURES = arg("--textures", None)    # folder of the PBR sets, None = plain greys
LETTER_TEX, BACK_TEX = "brushed-metal-bl", "gold-scuffed-bl"
TEX_TILE = 1.0                        # one texture repeat per text size
NAME = arg("--name", "HemiHead")
RESOLUTION = 5                        # curve segments between font control points
CHARS = arg("--chars", None)
ROWS = tuple(r for r in ("".join(c for c in row if CHARS is None or c in CHARS) for row in (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", "0123456789")) if r)
LETTER_GAP, ROW_GAP = 0.06, 1.0       # layout of the rows in the file (text size)
SHARP = math.radians(35)
os.makedirs(OUT, exist_ok=True)

# glyph (x, y, z_out) -> Blender, facing -Y
TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


# ---------------------------------------------------------------- font metrics
def advances(path, chars):
    """Advance width of each character in Blender text size units (font units over
    the height of the font's bounding box), from the cmap/hmtx/head tables."""
    data = open(path, "rb").read()
    u16 = lambda off: struct.unpack_from(">H", data, off)[0]
    tables = {}
    for i in range(u16(4)):
        tag, _, off, _ = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        tables[tag.decode("latin-1")] = off
    _, y_min, _, y_max = struct.unpack_from(">hhhh", data, tables["head"] + 36)
    n_metrics = u16(tables["hhea"] + 34)

    cmap = tables["cmap"]
    for i in range(u16(cmap + 2)):
        pid, eid, off = struct.unpack_from(">HHI", data, cmap + 4 + 8 * i)
        if (pid, eid) in ((3, 1), (0, 3)) and u16(cmap + off) == 4:
            sub = cmap + off
            break
    else:
        raise RuntimeError("no Unicode BMP (format 4) cmap in " + path)
    segs = u16(sub + 6) // 2
    ends = sub + 14
    starts = ends + 2 * segs + 2
    deltas = starts + 2 * segs
    ranges = deltas + 2 * segs

    def glyph(code):
        for s in range(segs):
            if code > u16(ends + 2 * s):
                continue
            start = u16(starts + 2 * s)
            if code < start:
                return 0
            delta = struct.unpack_from(">h", data, deltas + 2 * s)[0]
            ro = u16(ranges + 2 * s)
            if ro == 0:
                return (code + delta) & 0xFFFF
            g = u16(ranges + 2 * s + ro + 2 * (code - start))
            return (g + delta) & 0xFFFF if g else 0
        return 0

    def advance(gid):
        return u16(tables["hmtx"] + 4 * min(gid, n_metrics - 1)) / (y_max - y_min)

    return {c: advance(glyph(ord(c))) for c in chars}


# ---------------------------------------------------------------- mesh helpers
def glyph_bm(char, font):
    """Glyph extruded from z = 0 (back) to DEPTH (front) in text size units, front
    edges bevelled. In a narrow notch (middle of the B) the full bevel folds back on
    itself: it is then narrowed for that glyph until no front face points backwards."""
    for width in (BEVEL, BEVEL * 0.75, BEVEL * 0.5, BEVEL * 0.3):
        bm, bevel = bevelled_glyph(char, font, width)
        folds = [f for f in bm.faces if f.normal.z < -0.05
                 and f.calc_center_median().z > DEPTH - width - 1e-6]
        if not folds:
            break
        bm.free()
    else:
        raise RuntimeError("front bevel of %r folds even at %.3f of the size" % (char, width))
    if width != BEVEL:
        print("[hemihead] %r: bevel narrowed to %.3f of the size" % (char, width))

    # Smooth shading inside the bevel and along curved walls, but the flat front
    # and back faces stay flat: sharp edges between front / bevel / walls / back.
    # A one-segment chamfer is faceted like the walls.
    def part(f):
        if f in bevel:
            return 1
        if f.normal.z > 0.999:
            return 0
        if f.normal.z < -0.999:
            return 3
        return 2
    faceted = (2,) if BEVEL_SEG > 1 else (1, 2)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        fs = e.link_faces
        if len(fs) != 2:
            continue
        a, b = part(fs[0]), part(fs[1])
        e.smooth = a == b and (a not in faceted or fs[0].normal.angle(fs[1].normal) < SHARP)

    if OUTLINE:
        # The backing plate goes under the back face, which is then hidden, and the
        # whole character moves up so that the back of the plate is at z = 0.
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if part(f) == 3], context="FACES")
        me = bpy.data.meshes.new("t")
        back = backing_bm(char, font)
        back.to_mesh(me)
        back.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        bmesh.ops.translate(bm, vec=(0, 0, BACKING), verts=bm.verts)
    return bm


def font_bm(char, font, extrude):
    """The glyph as Blender fills it, at text size 1 with its pen at the origin,
    extruded by +-extrude around z = 0 (flat at z = 0 for 0)."""
    cu = bpy.data.curves.new("t", "FONT")
    cu.body = char
    cu.font = font
    cu.size = 1.0
    cu.align_x = "LEFT"
    cu.align_y = "TOP_BASELINE"
    cu.extrude = extrude
    cu.resolution_u = RESOLUTION
    ob = bpy.data.objects.new("t", cu)
    bpy.context.scene.collection.objects.link(ob)
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for layer in list(bm.loops.layers.uv.values()):
        bm.loops.layers.uv.remove(layer)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return bm


def backing_bm(char, font):
    """Backing plate (material 1): the glyph dilated by OUTLINE, with mitred corners
    clipped beyond MITER_LIMIT, extruded from z = -BACKING to 0. The dilated shape
    is the union of the glyph, a band OUTLINE wide outside each outline edge and a
    mitre at each convex corner: the triangles of their constrained Delaunay
    triangulation that lie in at least one of them."""
    bm = font_bm(char, font, 0)
    index = {v: i for i, v in enumerate(bm.verts)}
    pts = [v.co.xy for v in bm.verts]
    faces = []
    for f in bm.faces:
        vs = [index[v] for v in f.verts]
        faces.append(vs if f.normal.z > 0 else vs[::-1])       # CCW
    bm.free()
    uses = Counter(frozenset(e) for f in faces for e in zip(f, f[1:] + f[:1]))
    nxt, prv = {}, {}             # outline edges a -> b, with the glyph on their left
    for f in faces:
        for a, b in zip(f, f[1:] + f[:1]):
            if uses[frozenset((a, b))] == 1:
                nxt.setdefault(a, []).append(b)
                prv.setdefault(b, []).append(a)

    def add(*ps):
        faces.append(list(range(len(pts), len(pts) + len(ps))))
        pts.extend(ps)

    d = OUTLINE
    for a, bs in nxt.items():
        for b in bs:
            t = (pts[b] - pts[a]).normalized()
            n = Vector((t.y, -t.x)) * d
            add(pts[a], pts[a] + n, pts[b] + n, pts[b])
    for v, ws in nxt.items():
        p = pts[v]
        if len(ws) != 1 or len(prv[v]) != 1:       # outlines touching: a disc
            r = d / math.cos(math.pi / 16)
            add(*(p + Vector((math.cos(i * math.pi / 8), math.sin(i * math.pi / 8))) * r
                  for i in range(16)))
            continue
        t1 = (p - pts[prv[v][0]]).normalized()
        t2 = (pts[ws[0]] - p).normalized()
        if t1.cross(t2) <= 0:                      # concave: the bands overlap
            continue
        n1, n2 = Vector((t1.y, -t1.x)), Vector((t2.y, -t2.x))
        bis = (n1 + n2).normalized()
        cos_half = n1.dot(bis)
        if cos_half * MITER_LIMIT >= 1:
            add(p, p + n1 * d, p + bis * (d / cos_half), p + n2 * d)
        else:
            s = (MITER_LIMIT - cos_half) * d / t1.dot(bis)
            add(p, p + n1 * d, p + n1 * d + t1 * s, p + n2 * d - t2 * s, p + n2 * d)

    out, _, tris, _, _, orig = delaunay_2d_cdt(pts, [], faces, 0, 1e-7)
    bm = bmesh.new()
    vs = [bm.verts.new((p.x, p.y, 0)) for p in out]
    for f, o in zip(tris, orig):
        if o:
            bm.faces.new([vs[i] for i in f])
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    # slivers between outline vertices left in a straight line
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3],
                          quad_method="BEAUTY", ngon_method="BEAUTY")

    rim = [(l.vert, l.link_loop_next.vert) for f in bm.faces for l in f.loops
           if l.edge.is_boundary]
    low = {v: bm.verts.new(v.co - Vector((0, 0, BACKING))) for v in list(bm.verts)}
    for f in list(bm.faces):
        bm.faces.new([low[v] for v in reversed(f.verts)])
    for a, b in rim:
        bm.faces.new((a, low[a], low[b], b))
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
        f.material_index = 1
    for e in bm.edges:
        fs = e.link_faces
        e.smooth = len(fs) == 2 and fs[0].normal.angle(fs[1].normal) < SHARP
    return bm


def bevelled_glyph(char, font, width):
    """(bmesh, set of bevel faces) of the glyph with a front bevel `width` wide."""
    bm = font_bm(char, font, DEPTH / 2)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts, edges=bm.edges)
    bmesh.ops.translate(bm, vec=(0, 0, DEPTH / 2), verts=bm.verts)
    bm.normal_update()

    def is_front(f):
        return f.normal.z > 0.999 and abs(f.calc_center_median().z - DEPTH) < 1e-5

    front = {f for f in bm.faces if is_front(f)}
    rim = [e for e in bm.edges if sum(f in front for f in e.link_faces) == 1]
    bevel = set(bmesh.ops.bevel(bm, geom=rim, offset=width, offset_type="OFFSET",
                                segments=BEVEL_SEG, profile=0.5, affect="EDGES",
                                clamp_overlap=True)["faces"])
    tris = bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    for a, b in tris["face_map"].items():          # triangles <-> split face
        if a in bevel or b in bevel:
            bevel.update((a, b))
    bm.normal_update()
    return bm, {f for f in bevel if f.is_valid}


def box_uv(bm):
    """UVs in text size units over TEX_TILE, each face projected along the axis it
    faces most: front and back faces from the front, walls from the side."""
    uv = bm.loops.layers.uv.new("UVMap")
    bm.normal_update()
    for f in bm.faces:
        axis = max(range(3), key=lambda i: abs(f.normal[i]))
        for l in f.loops:
            co = l.vert.co
            u, v = (co.z, co.y) if axis == 0 else (co.x, co.z) if axis == 1 else (co.x, co.y)
            l[uv].uv = (u / TEX_TILE, v / TEX_TILE)


# map file suffix (<set>_<suffix>.png) -> Principled BSDF input, or glTF occlusion
MAP_INPUTS = {"albedo": "Base Color", "basecolor": "Base Color", "metallic": "Metallic",
              "roughness": "Roughness", "normal": "Normal", "normal-ogl": "Normal",
              "ao": "Occlusion"}


def material(name, grey, tex_set):
    m = bpy.data.materials.new(name)
    if m.node_tree is None:           # Blender < 5 creates materials without nodes
        m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (grey, grey, grey, 1)
    p.inputs["Roughness"].default_value = 0.35
    if TEXTURES:
        pbr_maps(m, p, tex_set)
    return m


def pbr_maps(m, p, tex_set):
    """Feed the Principled BSDF `p` of `m` from the maps of the PBR set `tex_set`.
    A map that is uniform to within 4/255 (both normal maps, both metallic maps,
    the gold's colour) becomes a plain value."""
    nodes, links = m.node_tree.nodes, m.node_tree.links
    files = sorted(glob.glob(os.path.join(TEXTURES, tex_set, "**", "*.png"), recursive=True))
    if not files:
        raise RuntimeError("no PBR maps for %s in %s" % (tex_set, TEXTURES))
    for f in files:
        target = MAP_INPUTS.get(os.path.splitext(os.path.basename(f))[0].rsplit("_", 1)[-1].lower())
        if target is None:
            continue
        im = bpy.data.images.load(f, check_existing=True)
        im.colorspace_settings.name = "sRGB" if target == "Base Color" else "Non-Color"
        px = numpy.empty(len(im.pixels), numpy.float32)
        im.pixels.foreach_get(px)
        px = px.reshape(-1, im.channels)[:, :3]
        lo, hi = px.min(0), px.max(0)
        if (hi - lo).max() <= 4 / 255:
            v = (lo + hi) / 2                 # file values, sRGB for the colour
            if target == "Base Color":
                p.inputs[target].default_value = [
                    *(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in v), 1]
            elif target in ("Metallic", "Roughness"):
                p.inputs[target].default_value = float(v[0])
            bpy.data.images.remove(im)        # flat normal map, even occlusion: nothing
            continue
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = im
        if target == "Normal":
            nm = nodes.new("ShaderNodeNormalMap")
            links.new(tex.outputs["Color"], nm.inputs["Color"])
            links.new(nm.outputs["Normal"], p.inputs["Normal"])
        elif target == "Occlusion":
            out = nodes.new("ShaderNodeGroup")
            out.node_tree = gltf_output()
            links.new(tex.outputs["Color"], out.inputs["Occlusion"])
        else:
            links.new(tex.outputs["Color"], p.inputs[target])


def gltf_output():
    """The node group the glTF exporter reads the occlusion map from."""
    g = bpy.data.node_groups.get("glTF Material Output")
    if g is None:
        g = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    return g


# ---------------------------------------------------------------- preview
def render_preview(path, chars):
    # Cycles: EEVEE's shadows streak on objects this small.
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 2000, 520
    world = bpy.data.worlds.new("Preview")
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.06, 1)
    if TEXTURES:
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

    xs = [o.matrix_world.translation.x for o in chars]
    zs = [o.matrix_world.translation.z for o in chars]
    width = max(xs) - min(xs) + SIZE
    centre = Vector(((max(xs) + min(xs)) / 2, 0, (max(zs) + min(zs)) / 2 + 0.25 * SIZE))

    cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = width * 1.04
    scene.collection.objects.link(cam)
    view = Vector((0.2, -1.0, 0.25)).normalized()          # from the front, left, above
    cam.location = centre + view * width
    cam.rotation_euler = (-view).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    for name, rot, energy in (("Key", (math.radians(50), 0, math.radians(-35)), 4.0),
                              ("Rim", (math.radians(110), 0, math.radians(150)), 2.0)):
        sun = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        sun.data.energy = energy
        sun.rotation_euler = rot
        scene.collection.objects.link(sun)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- build
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    font = bpy.data.fonts.load(FONT)
    adv = advances(FONT, "".join(ROWS))
    mats = [material("HemiHead", 0.86, LETTER_TEX)]
    if OUTLINE:
        mats.append(material("HemiHead_Outline", 0.06, BACK_TEX))
    root = bpy.data.objects.new("HemiHead", None)
    bpy.context.scene.collection.objects.link(root)

    chars = []
    for row, line in enumerate(ROWS):
        x = 0.0
        for c in line:
            bm = glyph_bm(c, font)
            if TEXTURES:
                box_uv(bm)
            bmesh.ops.transform(bm, matrix=TO_BLENDER @ Matrix.Scale(SIZE, 4), verts=bm.verts)
            me = bpy.data.meshes.new("Char_" + c)
            bm.to_mesh(me)
            bm.free()
            for m in mats:
                me.materials.append(m)
            ob = bpy.data.objects.new("Char_" + c, me)
            ob["advance"] = round(adv[c] * SIZE, 6)
            ob.location = TO_BLENDER @ Vector((x * SIZE, -row * ROW_GAP * SIZE, 0))
            ob.parent = root
            bpy.context.scene.collection.objects.link(ob)
            chars.append(ob)
            x += adv[c] + LETTER_GAP
    bpy.data.fonts.remove(font)       # the meshes no longer need it

    bpy.ops.object.select_all(action="SELECT")
    glb = os.path.join(OUT, NAME + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_yup=True,
                              use_selection=True, export_extras=True)
    bpy.context.preferences.filepaths.save_version = 0     # no .blend1 backup
    # Texture paths stay as given: the textures are not next to the output.
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + ".blend"), compress=True,
                                relative_remap=False)
    tris = sum(len(p.vertices) - 2 for o in chars for p in o.data.polygons)
    print("[hemihead]", len(chars), "characters,", tris, "triangles")
    if "--preview" in ARGS:
        render_preview(os.path.join(OUT, NAME + "_preview.png"), chars)


main()

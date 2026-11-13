"""Builds the gold crown of the Do Better If You Can logo (issue #1) and
exports it as glTF binary.

Modelled on the reference picture of the issue: four pointed plates (the back one hidden behind the front one) with a
central crease, each tipped with a gold ball, the front one the tallest,
flaring out above a thick rounded band (a big bottom ring, a groove, a face
and a thin lip).

Run (from the repo root):
    blender -b --factory-startup --python tools/blender/crown.py -- games/do_better/crown.glb

Units are metres, origin at the centre of the base. The front point looks
towards Blender -Y, which is +Z (towards the logo camera) in Godot.
"""
import math
import sys

import bmesh
import bpy

# Band (lathe profile) and wall dimensions.
R = 0.058            # band inner reference radius
BAND_TOP = 0.030     # top of the band lip
WALL_BOTTOM = 0.016  # wall starts inside the band
WALL_THICKNESS = 0.0028
POINTS = 4
SEGMENTS_PER_POINT = 24
FRONT_PEAK = 0.080   # tip of the front point
SIDE_PEAK = 0.066    # tip of the other points
VALLEY = 0.046       # bottom of the V between two points
RIDGE = 0.006        # outward push of the crease at the middle of a point
BALL_RADIUS = 0.0102

GOLD = (1.0, 0.74, 0.18, 1.0)
EMISSION = (0.13, 0.08, 0.012, 1.0)


def wall_radius(z: float) -> float:
    """Wall radius at height z: flares outwards towards the tips."""
    return 0.0595 + (z - WALL_BOTTOM) * 0.3


def peak_height(i: int) -> float:
    return FRONT_PEAK if i == 0 else SIDE_PEAK


def angle_dir(a: float) -> tuple[float, float]:
    """Angle 0 faces -Y (front)."""
    return math.sin(a), -math.cos(a)


def top_height(s: int, segments: int) -> tuple[float, float]:
    """Height of the top edge at segment column s, and the tent factor
    (1 at the middle of a point, 0 in a valley)."""
    per = SEGMENTS_PER_POINT
    i = (s + per // 2) // per % POINTS          # point index
    f = ((s + per // 2) % per) / per            # 0..1 across the point, 0.5 at its tip
    tent = 1.0 - abs(f * 2.0 - 1.0)
    return VALLEY + (peak_height(i) - VALLEY) * tent, tent


def make_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("CrownGold")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = GOLD
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.26
    # The logo scene is dark: a faint gold glow keeps the crown as bright as
    # the reference picture (exported as the glTF emissive factor).
    bsdf.inputs["Emission Color"].default_value = EMISSION
    bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat


def link(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def build_wall(mat) -> bpy.types.Object:
    segments = POINTS * SEGMENTS_PER_POINT
    rows = 16
    bm = bmesh.new()
    grid = []
    for s in range(segments):
        a = math.tau * s / segments
        dx, dy = angle_dir(a)
        top, tent = top_height(s, segments)
        col = []
        for r in range(rows + 1):
            v = r / rows
            z = WALL_BOTTOM + (top - WALL_BOTTOM) * v
            rad = wall_radius(z) + RIDGE * tent * v
            col.append(bm.verts.new((dx * rad, dy * rad, z)))
        grid.append(col)
    for s in range(segments):
        c0, c1 = grid[s], grid[(s + 1) % segments]
        for r in range(rows):
            # Counter-clockwise seen from outside: normals point out.
            bm.faces.new((c0[r], c1[r], c1[r + 1], c0[r + 1]))
    bm.normal_update()
    # Sharp creases along the middle of each point and at each valley.
    per = SEGMENTS_PER_POINT
    sharp_cols = set()
    for i in range(POINTS):
        sharp_cols.add((i * per) % segments)               # tip column
        sharp_cols.add((i * per + per // 2) % segments)    # valley column
    bm.verts.index_update()
    sharp_keys = set()
    for s in sharp_cols:
        col = grid[s]
        for r in range(rows):
            sharp_keys.add(tuple(sorted((col[r].index, col[r + 1].index))))
    obj = link("CrownWall", bm, mat)
    for e in obj.data.edges:
        if tuple(sorted(e.vertices)) in sharp_keys:
            e.use_edge_sharp = True
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = WALL_THICKNESS
    solid.offset = -1.0
    solid.use_even_offset = True
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = 0.0007
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(60)
    bevel.harden_normals = False
    return obj


def band_profile() -> list[tuple[float, float]]:
    """Closed (radius, z) outline of the band, outer side bottom to top then
    inner side top to bottom."""
    pts = []

    def bump(z0, z1, base, amp, steps):
        for k in range(steps):
            t = k / steps
            pts.append((R + base + amp * math.sin(math.pi * t), z0 + (z1 - z0) * t))

    pts.append((R - 0.0005, 0.0))
    bump(0.0, 0.013, 0.0025, 0.0048, 12)    # big bottom ring
    bump(0.013, 0.025, 0.0025, 0.0018, 9)   # band face
    bump(0.025, BAND_TOP, 0.0018, 0.0020, 6)  # thin lip
    pts.append((R + 0.0012, BAND_TOP))
    pts.append((R - 0.0025, BAND_TOP))      # inner side
    pts.append((R - 0.0025, 0.0))
    return pts


def build_band(mat) -> bpy.types.Object:
    steps = 120
    prof = band_profile()
    bm = bmesh.new()
    rings = []
    for s in range(steps):
        a = math.tau * s / steps
        dx, dy = angle_dir(a)
        rings.append([bm.verts.new((dx * r, dy * r, z)) for r, z in prof])
    n = len(prof)
    for s in range(steps):
        p0, p1 = rings[s], rings[(s + 1) % steps]
        for k in range(n):
            k1 = (k + 1) % n
            bm.faces.new((p0[k], p1[k], p1[k1], p0[k1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link("CrownBand", bm, mat)
    # Grooves and the flat inner/top faces stay crisp.
    groove_rows = {0, 1, 13, 22, n - 4, n - 3, n - 2, n - 1}
    mesh = obj.data
    for e in mesh.edges:
        a, b = e.vertices
        ka, kb = a % n, b % n
        if ka == kb and ka in groove_rows:
            e.use_edge_sharp = True
    return obj


def build_balls(mat) -> list[bpy.types.Object]:
    objs = []
    for i in range(POINTS):
        a = math.tau * i / POINTS
        dx, dy = angle_dir(a)
        top = peak_height(i)
        rad = wall_radius(top) + RIDGE - WALL_THICKNESS * 0.5
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=BALL_RADIUS)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(dx * rad, dy * rad, top + BALL_RADIUS * 0.75))
        objs.append(link("CrownBall%d" % i, bm, mat))
    return objs


def smooth(obj, keep_sharp=True):
    for p in obj.data.polygons:
        p.use_smooth = True
    # Blender 4.1+: sharp edges split the normals without auto smooth.


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = make_material()
    objs = [build_wall(mat), build_band(mat)] + build_balls(mat)
    for o in objs:
        smooth(o)
    # Apply modifiers and join into one mesh named Crown.
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    crown = bpy.context.view_layer.objects.active
    crown.name = "Crown"
    crown.data.name = "Crown"
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in crown.data.polygons)
    print("CROWN_OK triangles=%d" % tris)


if __name__ == "__main__":
    main()

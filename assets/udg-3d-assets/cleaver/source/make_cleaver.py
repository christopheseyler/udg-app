"""Game version of the butcher's cleaver (Hachoir_Boucher.glb, 330 mm, see
Lisez-moi.txt): ../Cleaver.glb, light enough for the carousel logos.

- The seven parts are joined into one mesh with a single material: they share
  one UV atlas and the same textures, so one material is one draw call.
- The 4K textures (base colour, ORM, OpenGL normal) are scaled down to
  TEXTURE_SIZE: the cleaver is about 300 px wide on screen.

The model keeps its origin and axes: in Godot the blade is toward -X, the
handle toward +X, the cutting edge at y = 0 and the spine at y = 0.115, the
flat of the blade facing +Z.

The original model (Hachoir_Boucher.blend, Hachoir_Boucher.glb and the 4K
textures, about 240 MB) is not in git (see .gitignore): put it back here to
run this script.

    blender --background --factory-startup --python make_cleaver.py
"""
import os
import tempfile

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "Hachoir_Boucher.glb")
OUT = os.path.join(os.path.dirname(HERE), "Cleaver.glb")
TEXTURE_SIZE = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
material = meshes[0].data.materials[0]
material.name = "Cleaver"
for o in meshes:
    o.data.materials.clear()
    o.data.materials.append(material)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.join()
cleaver = bpy.context.view_layer.objects.active
cleaver.name = cleaver.data.name = "Cleaver"
for o in [o for o in bpy.data.objects if o.type == "EMPTY"]:
    bpy.data.objects.remove(o)

# The imported images are packed (a reload would bring the 4K back): each one
# is scaled, copied to a new 8-bit image saved on disk, and the nodes point to
# that copy. The pixels are copied as stored, without colour conversion.
tmp = tempfile.mkdtemp()
small = {}
for node in material.node_tree.nodes:
    im = node.image if node.type == "TEX_IMAGE" else None
    if im is None:
        continue
    if im.name not in small:
        colorspace = im.colorspace_settings.name
        im.scale(TEXTURE_SIZE, TEXTURE_SIZE)
        px = [0.0] * (TEXTURE_SIZE * TEXTURE_SIZE * 4)
        im.pixels.foreach_get(px)
        name = im.name.split("-")[0].replace("_AO_4K", "_ORM").replace("_4K", "")
        copy = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
        copy.colorspace_settings.name = colorspace
        copy.pixels.foreach_set(px)
        copy.filepath_raw = os.path.join(tmp, name + ".png")
        copy.file_format = "PNG"
        copy.save()
        bpy.data.images.remove(copy)
        loaded = bpy.data.images.load(os.path.join(tmp, name + ".png"))
        loaded.colorspace_settings.name = colorspace
        small[im.name] = loaded
    node.image = small[im.name]
for im in [im for im in bpy.data.images if im not in small.values()]:
    bpy.data.images.remove(im)

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False,
                          export_image_format="AUTO", export_apply=True)
print("[cleaver] %s: %d triangles, textures %s" % (
    OUT, sum(len(p.vertices) - 2 for p in cleaver.data.polygons),
    [(i.name, tuple(i.size)) for i in bpy.data.images]))

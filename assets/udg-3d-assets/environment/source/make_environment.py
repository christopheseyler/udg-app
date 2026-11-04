"""Reflection environment of the 3D scenes: Blender's bundled "interior" studio
light (Poly Haven's hotel_room, CC0) as Radiance HDR files Godot can import (it
does not read the DWAB compression of the original EXR).

hotel_room.hdr keeps the linear values. hotel_room_compat.hdr has them passed
through the sRGB encoding curve (extended above 1): the Compatibility renderer of
the board decodes a sky panorama as sRGB, which darkened and saturated the
reflections, and decodes this copy back to the linear values.

    blender --background --factory-startup --python make_environment.py -- <out_dir>
"""
import os
import sys

import bpy
import numpy

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
SRC = os.path.join(bpy.utils.system_resource("DATAFILES", path="studiolights/world"), "interior.exr")


def save(im, name):
    im.file_format = "HDR"
    im.filepath_raw = os.path.join(OUT, name)
    im.save()


im = bpy.data.images.load(SRC)
px = numpy.empty(len(im.pixels), numpy.float32)      # (reading loads the image)
im.pixels.foreach_get(px)
save(im, "hotel_room.hdr")
rgb = px.reshape(-1, 4)[:, :3]
c = numpy.clip(rgb, 0.0, None)
rgb[:] = numpy.where(c <= 0.0031308, c * 12.92, 1.055 * numpy.power(c, 1 / 2.4) - 0.055)
im.pixels.foreach_set(px)
save(im, "hotel_room_compat.hdr")
print("[environment] %s: max %.1f, sRGB copy max %.1f" % (SRC, c.max(), rgb.max()))

SUMMARY = "Ultimate Darts Game - exported Godot binary + PCK"
LICENSE = "CLOSED"

# This recipe packages an ALREADY-EXPORTED Godot Linux/arm64 build; it does
# not build the Godot engine or export the project itself (Yocto has no
# Godot editor/export-template recipe, and cross-exporting a Godot project
# is not a bitbake task). See ../../README.md "Exporting the game" for the
# one-time host-side step that produces the tarball below.
#
# Expected tarball contents (paths relative to the tar root):
#   udg              - the exported Linux/arm64 binary (self-contained,
#                       embedded .pck), executable
SRC_URI = "file://udg-linux-arm64.tar.gz"

# Real export (Godot 4.7.2.stable, "Linux" preset, arm64, embed_pck=true).
# Re-export and update this whenever the game changes - see "Exporting the
# game" in ../../README.md.
SRC_URI[sha256sum] = "49fcc59356317bd358f955505f056e20f680141f99693b5d35d4f9aeded6aec7"

S = "${WORKDIR}"

# Deliberately not `inherit allarch`: this packages a real arm64 ELF
# binary, so it must build as a normal machine-specific package.

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/udg ${D}${bindir}/udg-game
}

FILES:${PN} = "${bindir}/udg-game"

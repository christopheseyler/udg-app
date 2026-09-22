SUMMARY = "Packages needed on the ROCK 5C dart board"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit packagegroup

PACKAGE_ARCH = "${MACHINE_ARCH}"

RDEPENDS:${PN} = " \
    weston \
    udg-game-session \
    rauc \
    u-boot-fw-utils \
    kernel-modules \
    alsa-utils \
"

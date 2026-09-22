# RAUC A/B boot glue for the ROCK 5C, scoped to this one machine so it can
# never accidentally apply to another board's defconfig (see
# files/boot.cmd and files/rauc.cfg for why this is a from-scratch
# reimplementation rather than a reuse of meta-rauc-rockchip's own
# u-boot_%.bbappend, which hardcodes the rock-pi-4b/rk3399 defconfig).

FILESEXTRAPATHS:prepend:rock-5c := "${THISDIR}/files:"

SRC_URI:append:rock-5c = " \
    file://boot.cmd \
    file://rauc.cfg \
    file://rock-5c-fdt.cfg \
"

# Mandatory for poky/meta/recipes-bsp/u-boot/u-boot.inc to compile
# boot.cmd -> boot.scr via uboot-mkimage and deploy/install it.
UBOOT_ENV:rock-5c = "boot"
UBOOT_ENV_SUFFIX:rock-5c = "scr"

FILES:${PN}-extlinux:append:rock-5c = " /boot/${UBOOT_ENV_BINARY}"

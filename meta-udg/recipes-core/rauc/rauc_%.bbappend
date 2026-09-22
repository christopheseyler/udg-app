FILESEXTRAPATHS:prepend:rock-5c := "${THISDIR}/files:"
SRC_URI:append:rock-5c = " \
    file://rauc-grow-data-partition.service \
    file://grow-data-partition.sh \
"

# u-boot-fw-utils/u-boot-env: RAUC talks to the bootloader (marking a slot
# good/bad, reading BOOT_ORDER) through the U-Boot environment via
# fw_setenv/fw_printenv, matching CONFIG_ENV_IS_IN_MMC in
# recipes-bsp/u-boot/files/rauc.cfg.
RDEPENDS:${PN}:append:rock-5c = " u-boot-fw-utils u-boot-env"

inherit systemd

SYSTEMD_PACKAGES:append:rock-5c = " ${PN}-grow-data-part"
SYSTEMD_SERVICE:${PN}-grow-data-part = "rauc-grow-data-partition.service"

PACKAGES:append:rock-5c = " ${PN}-grow-data-part"

RDEPENDS:${PN}-grow-data-part += "parted e2fsprogs-resize2fs gptfdisk"

do_install:append:rock-5c() {
    install -d ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/rauc-grow-data-partition.service ${D}${systemd_unitdir}/system/

    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/grow-data-partition.sh ${D}${bindir}
}

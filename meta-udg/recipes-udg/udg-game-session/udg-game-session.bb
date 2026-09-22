SUMMARY = "Weston kiosk session that autostarts the darts game fullscreen"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://weston.ini \
    file://udg-weston.service \
    file://udg-game.service \
    file://udg-mark-good.service \
"

# Godot itself is not built by this layer (see ../udg-game/udg-game_1.0.bb);
# this recipe only wires up the display/session side.
RDEPENDS:${PN} = "weston udg-game rauc"

inherit systemd allarch

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "udg-weston.service udg-game.service udg-mark-good.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${sysconfdir}/xdg/weston
    install -m 0644 ${WORKDIR}/weston.ini ${D}${sysconfdir}/xdg/weston/weston.ini

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/udg-weston.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/udg-game.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/udg-mark-good.service ${D}${systemd_unitdir}/system/
}

FILES:${PN} = " \
    ${sysconfdir}/xdg/weston/weston.ini \
    ${systemd_unitdir}/system/udg-weston.service \
    ${systemd_unitdir}/system/udg-game.service \
    ${systemd_unitdir}/system/udg-mark-good.service \
"

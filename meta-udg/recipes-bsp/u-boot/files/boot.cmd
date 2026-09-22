# RAUC A/B slot selection + boot script for the ROCK 5C.
#
# Copied, unmodified in logic, from meta-rauc-community's
# meta-rauc-rockchip/recipes-bsp/u-boot/files/boot.cmd (rauc/meta-rauc-community,
# scarthgap branch) - see ../../../README.md. This logic is generic across
# Rockchip boards; it only assumes the partition layout in
# ../../../wic/rock5c-rauc.wks.in (eMMC = mmc device 1, /boot = p9,
# rootfs A/B = p10/p11).
#
# Compiled to boot.scr by the u-boot-mkimage step wired up in
# ../u-boot_%.bbappend (UBOOT_ENV / UBOOT_ENV_SUFFIX), and loaded by
# CONFIG_BOOTCOMMAND (see ../files/rauc.cfg).

test -n "${BOOT_ORDER}" || env set BOOT_ORDER "A B"
test -n "${BOOT_A_LEFT}" || env set BOOT_A_LEFT 3
test -n "${BOOT_B_LEFT}" || env set BOOT_B_LEFT 3

env set bootpart
env set bootdev
env set raucslot

for BOOT_SLOT in "${BOOT_ORDER}"; do
    if test "x${bootpart}" != "x"; then
        # stop checking after selecting a slot

    elif test "x${BOOT_SLOT}" = "xA"; then
        if itest ${BOOT_A_LEFT} -gt 0; then
            setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
            echo "Booting RAUC slot A"

            setenv bootpart "rootfsA"
            setenv raucslot "A"
            setenv bootdev "mmc 1:10"
        fi

    elif test "x${BOOT_SLOT}" = "xB"; then
        if itest ${BOOT_B_LEFT} -gt 0; then
            setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
            echo "Booting RAUC slot B"

            setenv bootpart "rootfsB"
            setenv raucslot "B"
            setenv bootdev "mmc 1:11"
        fi
    fi
done

if test -n "${bootpart}"; then
    saveenv
else
    echo "No valid RAUC slot found. Resetting attempts to 3"
    setenv BOOT_A_LEFT 3
    setenv BOOT_B_LEFT 3
    saveenv
    reset
fi

if mmc dev 1; then
    setenv bootfile /extlinux/extlinux.conf
    sysboot mmc 1:9 any
    boot
else
    echo "Could not find mmc 1"
    reset
fi

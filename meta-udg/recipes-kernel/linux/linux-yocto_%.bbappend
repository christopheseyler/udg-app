# The ROCK 5C isn't in meta-rockchip's own list of COMPATIBLE_MACHINE
# overrides yet (recipes-kernel/linux/linux-yocto_%.bbappend there lists
# rock-5a/rock-5b/... but stops short of rock-5c, confirmed by running
# `bitbake -n udg-image` against the real scarthgap meta-rockchip - see
# ../../README.md item 1). Same single-line pattern as every other board
# in that file; nothing else (SRC_URI, KMACHINE, ...) needs touching since
# rock-5a/rock-5b need nothing beyond this line either - the actual kernel
# config/DT selection is handled generically via
# conf/machine/include/rk3588s.inc + KERNEL_DEVICETREE
# (conf/machine/rock-5c.conf), not per-board here.
COMPATIBLE_MACHINE:rock-5c = "rock-5c"

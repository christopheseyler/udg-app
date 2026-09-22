FILESEXTRAPATHS:prepend:rock-5c := "${THISDIR}/files:"

SRC_URI:append:rock-5c = " file://fstab"

dirs755:append:rock-5c = " /data"

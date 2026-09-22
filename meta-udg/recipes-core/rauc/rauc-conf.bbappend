FILESEXTRAPATHS:prepend:rock-5c := "${THISDIR}/files:"
SRC_URI:append:rock-5c = " file://system.conf file://ca.cert.pem"

# Written explicitly rather than relying on rauc-conf.bb (meta-rauc) to
# pick up ca.cert.pem from SRC_URI on its own, since that recipe's own
# do_install was not available to check against while writing this layer.
do_install:append:rock-5c() {
    install -d ${D}${sysconfdir}/rauc
    install -m 0644 ${WORKDIR}/ca.cert.pem ${D}${sysconfdir}/rauc/ca.cert.pem
}

FILES:${PN}:append:rock-5c = " ${sysconfdir}/rauc/ca.cert.pem"

DESCRIPTION = "RAUC update bundle for the ROCK 5C dart board"

inherit bundle

RAUC_BUNDLE_COMPATIBLE = "rock-5c"
RAUC_BUNDLE_VERSION = "${DISTRO_VERSION}"
RAUC_BUNDLE_DESCRIPTION = "Ultimate Darts Game system update"

RAUC_BUNDLE_FORMAT = "verity"

RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "udg-image"
RAUC_SLOT_rootfs[fstype] = "ext4"

# Real signing key/certificate, generated locally and NOT committed to the
# repo - see ../../README.md "Generating RAUC keys". Keeping them under
# secrets/ (sibling of this layer, already gitignore'd in this repo) rather
# than inside meta-udg keeps a real deployment key out of git history.
RAUC_KEY_FILE ?= "${LAYERDIR}/../secrets/rauc/dev-1.key.pem"
RAUC_CERT_FILE ?= "${LAYERDIR}/../secrets/rauc/dev-1.cert.pem"

SUMMARY = "Ultimate Darts Game system image (ROCK 5C, RAUC-updatable)"

require recipes-core/images/core-image-base.bb

IMAGE_FSTYPES:append = " ext4"

IMAGE_INSTALL:append = " packagegroup-udg-image"

# core-image-base already pulls in a getty on the serial console for
# debugging (see machine SERIAL_CONSOLES); tty1 is reserved for Weston
# (Conflicts=getty@tty1.service in udg-weston.service).

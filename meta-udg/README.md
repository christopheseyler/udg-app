# meta-udg

Yocto/OpenEmbedded layer that turns the Godot game in this repo into a
RAUC-updatable Linux image for the Radxa ROCK 5C (RK3588S, eMMC boot).

**Status: validated by a full dry-run, not yet actually compiled or run on
hardware.** `bitbake -n udg-image` (parses + resolves + simulates every
task without compiling) completes clean against the real upstream layers:
6491 tasks, all the way through `do_image_wic`, **0 errors**. That caught
and fixed two real bugs: `rock-5c` missing from the kernel's
`COMPATIBLE_MACHINE` list (checklist item 1, now resolved) and `weston`
needing `pam` in `DISTRO_FEATURES` (now in `local.conf.sample`). What a
dry-run *can't* catch - actual compiles, the U-Boot Kconfig fragment, the
`rk-u-boot-env` wic plugin, real GPU driver packaging, anything that only
shows up on real hardware - is still open; see the remaining checklist
items.

## Why a from-scratch layer instead of reusing existing ones

- **BSP**: [`meta-rockchip`](https://git.yoctoproject.org/meta-rockchip/)
  (the community/OE layer at git.yoctoproject.org, *not*
  [`radxa/meta-rockchip`](https://github.com/radxa/meta-rockchip) - that's
  Radxa's own vendor-kernel/libmali SDK layer, a different codebase with a
  different machine list). The community layer uses `linux-yocto`
  (mainline kernel) and mainline U-Boot, so the Mali G610 GPU is driven by
  the in-tree **Panthor** kernel driver + Mesa's **panfrost** Gallium
  driver (OpenGL ES 3.1, conformant - no Vulkan).
- **RAUC integration**: reimplemented here rather than pulling in
  [`rauc/meta-rauc-community`](https://github.com/rauc/meta-rauc-community)'s
  `meta-rauc-rockchip`, because that layer's `u-boot_%.bbappend`
  unconditionally patches `rock-pi-4-rk3399_defconfig` (a different SoC's
  defconfig) - adding that layer alongside `MACHINE = "rock-5c"` would
  break the U-Boot build. The A/B boot script and partition layout are
  SoC-agnostic and are reused here almost verbatim (credited in each file),
  just re-scoped to the `rock-5c` machine and a Kconfig fragment instead of
  a defconfig patch.

## Layers and branches

All on the **scarthgap** (Yocto 5.0 LTS) series, which is what
`meta-rauc`/`meta-rauc-community` and the community `meta-rockchip` are
documented against:

| Layer | URL | Branch |
|---|---|---|
| poky (bitbake + oe-core) | `https://git.yoctoproject.org/poky` | `scarthgap` |
| meta-openembedded | `https://github.com/openembedded/meta-openembedded` | `scarthgap` |
| meta-arm | `https://git.yoctoproject.org/meta-arm` | `scarthgap` |
| meta-rockchip | `https://git.yoctoproject.org/meta-rockchip` | `scarthgap` |
| meta-rauc | `https://github.com/rauc/meta-rauc` | `scarthgap` |
| meta-udg (this layer) | this repo, `meta-udg/` | - |

```bash
mkdir ~/udg-yocto && cd ~/udg-yocto
git clone -b scarthgap https://git.yoctoproject.org/poky
git clone -b scarthgap https://github.com/openembedded/meta-openembedded
git clone -b scarthgap https://git.yoctoproject.org/meta-arm
git clone -b scarthgap https://git.yoctoproject.org/meta-rockchip
git clone -b scarthgap https://github.com/rauc/meta-rauc
git clone <this repo's URL> udg-test   # the repo this README lives in

source poky/oe-init-build-env build
bitbake-layers add-layer ../meta-openembedded/meta-oe
# meta-arm is a super-repo of several sub-layers; only these two are
# needed here (meta-arm-bsp/meta-arm-systemready are for other boards).
# Order matters the first time: meta-arm needs arm-toolchain present.
bitbake-layers add-layer ../meta-arm/meta-arm-toolchain
bitbake-layers add-layer ../meta-arm/meta-arm
bitbake-layers add-layer ../meta-rockchip
bitbake-layers add-layer ../meta-rauc
bitbake-layers add-layer ../udg-test/meta-udg

cat ../udg-test/meta-udg/conf/local.conf.sample >> conf/local.conf
```

`bitbake-layers show-layers` should then list 9 layers: `core`, `yocto`,
`yoctobsp`, `openembedded-layer`, `arm-toolchain`, `meta-arm`, `rockchip`,
`rauc`, `udg`.

Then edit `conf/local.conf`: `RAUC_KEY_FILE`/`RAUC_CERT_FILE` in
[`recipes-core/bundles/udg-update-bundle.bb`](recipes-core/bundles/udg-update-bundle.bb)
default to `../secrets/rauc/dev-1.{key,cert}.pem` relative to this layer -
see "Generating RAUC keys" below before you need to build the bundle.

## Exporting the game

Yocto doesn't build the Godot engine or export the project - that happens
once, on any machine with the Godot 4.7 editor and Linux export templates
installed, and the result is committed as an opaque input to the
`udg-game` recipe:

```bash
godot4 --headless --export-release "Linux" export/linux/udg
tar -C export/linux -czf meta-udg/recipes-udg/udg-game/files/udg-linux-arm64.tar.gz udg
sha256sum meta-udg/recipes-udg/udg-game/files/udg-linux-arm64.tar.gz
```

Paste that checksum into `SRC_URI[sha256sum]` in
[`recipes-udg/udg-game/udg-game_1.0.bb`](recipes-udg/udg-game/udg-game_1.0.bb)
(it currently has a placeholder of all zeros so the recipe parses before
you've exported anything - `bitbake udg-game` will refuse to fetch until
you fix it).

The `Linux` export preset (`export_presets.cfg` in the repo root) targets
`arm64` with `binary_format/embed_pck=true`, producing one self-contained
`udg` binary - that's what `udg-game_1.0.bb` expects to find in the
tarball. The Mali G610 only has GLES 3.1 (Panthor/panfrost, no Vulkan), so
the game must run with Godot's Compatibility renderer; `udg-game.service`
(installed by `udg-game-session`) launches it with
`--rendering-driver opengl3`.

## Building

```bash
bitbake udg-image
```

Output: `tmp/deploy/images/rock-5c/udg-image-rock-5c.rootfs.wic`.

## Flashing (first install, eMMC module)

Per [Radxa's ROCK 5C docs](https://docs.radxa.com/en/rock5/rock5c/other-os/yocto/install-system/system-to-emmc):
put the eMMC module in a Radxa eMMC/UFS module reader, plug it into a
host PC, and flash the `.wic` with [balenaEtcher](https://etcher.balena.io/)
(or `bmaptool copy udg-image-rock-5c.rootfs.wic /dev/sdX` /
`dd` on Linux). The `.wic` already contains the bootloader (idbloader +
U-Boot + ATF), so this one step is enough to get to a first boot.

## Updating in the field (RAUC)

```bash
bitbake udg-update-bundle
```

Output: `tmp/deploy/images/rock-5c/udg-update-bundle-rock-5c.raucb`. Copy it
to the board (scp/USB stick) and:

```bash
rauc install /path/to/udg-update-bundle-rock-5c.raucb
reboot
```

RAUC installs into the currently-inactive slot; `boot.cmd` (see
`recipes-bsp/u-boot/files/boot.cmd`) picks it up on the next boot, and
`udg-mark-good.service` calls `rauc status mark-good` 30s after
`udg-game.service` starts (see `recipes-udg/udg-game-session/files/`) so a
slot that boots the game successfully doesn't keep decrementing its
`BOOT_A_LEFT`/`BOOT_B_LEFT` attempt counter forever. That 30s "it must be
fine by now" delay is a placeholder - swap it for a real readiness signal
(the game touching a status file/socket once its title screen is up) once
you know how long a real boot takes.

## Generating RAUC keys

Not part of this layer - generate your own and keep them out of git
(matches this repo's existing `secrets/` convention):

```bash
mkdir -p secrets/rauc
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -keyout secrets/rauc/dev-1.key.pem -out secrets/rauc/dev-1.cert.pem \
  -subj "/O=UDG/CN=udg-rock-5c-dev"
cp secrets/rauc/dev-1.cert.pem meta-udg/recipes-core/rauc/files/ca.cert.pem
```

`rauc-conf.bbappend` already installs `files/ca.cert.pem` as
`/etc/rauc/ca.cert.pem` (matching `[keyring] path=` in `system.conf`) -
just make sure that file is the certificate from the keypair you actually
sign bundles with before building `udg-image`. For real production
hardware, keep the private key on a build/signing server only, never on
the boards or in this repo.

## First build checklist

Things flagged inline as unverified, gathered in one place:

1. ~~`conf/machine/rock-5c.conf`: `require conf/machine/include/rk3588s.inc`
   not confirmed against the actual file~~ **Resolved/confirmed**: a full
   `bitbake -n udg-image` against the real scarthgap `meta-rockchip`
   parses `rock-5c.conf` cleanly, so `rk3588s.inc` and the
   `KERNEL_DEVICETREE`/`UBOOT_MACHINE` values are at least
   syntactically/structurally correct. One real gap the dry-run *did*
   catch: `meta-rockchip`'s own
   `recipes-kernel/linux/linux-yocto_%.bbappend` lists
   `COMPATIBLE_MACHINE` overrides for every RK3588(S) board up through
   `rock-5b`, but not `rock-5c` yet - fixed by adding the same one-line
   override, scoped to `rock-5c`, in
   [`recipes-kernel/linux/linux-yocto_%.bbappend`](recipes-kernel/linux/linux-yocto_%.bbappend)
   in this layer. `bitbake -n` still can't confirm the DTB filename or
   `UBOOT_MACHINE` defconfig actually *build*, just that they're wired up
   consistently - that needs a real `bitbake udg-image`.
2. **`MACHINE_FEATURES:append = " rk-u-boot-env"`** and the
   `${RK_UBOOT_ENV}` wic param in `wic/rock5c-rauc.wks.in`: copied from
   meta-rauc-community's example; confirm meta-rockchip on this branch
   actually implements this machine feature/wic-plugin, or replace that
   wic line with an explicit `--source rawcopy` of a generated env blob.
3. ~~`recipes-bsp/u-boot/files/rauc.cfg`: assumes `rk3588_defconfig`
   doesn't set conflicting values~~ **Worse than that, and fixed**: a real
   `bitbake udg-image` failed U-Boot's `do_configure` outright -
   `configs/rk3588_defconfig` doesn't exist at all in U-Boot 2024.01
   (that name came from Radxa's *vendor* SDK, a different U-Boot fork from
   the one this layer uses). rock-5c has no board-specific defconfig
   upstream either (only `rock5a-rk3588s_defconfig` and
   `rock5b-rk3588_defconfig` do). Switched `UBOOT_MACHINE` to
   `rock5a-rk3588s_defconfig` (closest match: same RK3588S SoC variant)
   with its default devicetree overridden to rock-5c's own via
   [`recipes-bsp/u-boot/files/rock-5c-fdt.cfg`](recipes-bsp/u-boot/files/rock-5c-fdt.cfg).
   This got U-Boot compiling; it's still rock-5a's board file (pinmux,
   regulators, ...) underneath, not a real rock-5c port - the DTB and
   kernel are unaffected (they come from mainline Linux, which does have a
   real `rk3588s-rock-5c.dtb`), but boot may need further U-Boot-level
   fixes once tried on real hardware.
4. **`rauc status mark-good`**: not called anywhere yet (see "Updating in
   the field" above) - required before this is safe for unattended updates.
5. **GPU driver packaging**: `MESA_GPU_DRIVERS = "panfrost"` in the machine
   conf assumes meta-rockchip's `mesa` recipe/bbappend on this branch
   already exposes that `PACKAGECONFIG`; if `eglinfo`/`glxinfo` on target
   shows a software (llvmpipe) renderer, check `PACKAGECONFIG:pn-mesa` and
   `DISTRO_FEATURES` (`opengl` is set in `conf/local.conf.sample`).
6. **Weston kiosk startup race**: `udg-game.service` retries on failure
   (`RestartSec=2`) to cover Weston's Wayland socket not existing yet
   immediately after `udg-weston.service` starts; if that's flaky in
   practice, switch to a `PathExists=/run/weston/wayland-0` gate instead.

#!/data/data/com.termux/files/usr/bin/sh
##
##    Termux RootFS installer
##

if [[ $(busybox uname -m) != aarch64 ]]; then
    echo ""
    echo "Sorry, only AArch64 CPU architecture is supported."
    echo ""
    exit 1
fi

###############################################################################
##
##    Setting up environment
##
###############################################################################

## use command busybox's version of command 'echo'
alias echo='busybox echo'

SCRIPT_PATH=$(realpath "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

if [ ! -f "${SCRIPT_DIR}/VERSION_INFO" ]; then
    echo "[!] Cannot obtain version info."
    exit 1
fi

## VERSION_INFO contains the following variables:
##   LATEST_VERSION, ARCHIVE_SHA256, ENABLE_INC_UPDATES, UPDATES_SCHEME
. "${SCRIPT_DIR}"/VERSION_INFO

BASEDIR="/data/data/com.termux/files"

ARCHIVE_NAME="termux-rootfs-v${LATEST_VERSION}.tar.bz2"
ARCHIVE_PATH="${BASEDIR}/${ARCHIVE_NAME}"
ARCHIVE_URL="https://github.com/xeffyr/termux-rootfs/releases/download/v${LATEST_VERSION}/${ARCHIVE_NAME}"

ROOTFS_DIR="termux-rootfs-v${LATEST_VERSION}"

###############################################################################
##
##    Common functions
##
###############################################################################

is_binary_installed()
{
    if [ -x "${PREFIX}/bin/${1}" ]; then
        return 0
    else
        return 1
    fi
}

###############################################################################
##
##    Make sure that Termux-RootFS is not installed
##
###############################################################################

if [ -f "${PREFIX}/etc/os-release" ]; then
    if ! (
        . "${PREFIX}"/etc/os-release

        if [ "${ID}" = "termux-rootfs" ]; then
            exit 1
        fi
    ); then
        echo "[!] An existing installation of Termux RootFS"
        echo "    was found."
        echo "    If you want to upgrade your installation,"
        echo "    run command 'termux-upgrade-rootfs'."
        exit 1
    fi
fi

###############################################################################
##
##    Check packages needed for installation
##
###############################################################################

NEEDED_PACKAGES=""

for bin in bash bzip2 coreutils tar wget; do
    if ! is_binary_installed "${bin}"; then
        NEEDED_PACKAGES="${NEEDED_PACKAGES} ${bin}"
    fi
done

if [ ! -z "${NEEDED_PACKAGES}" ]; then
    if is_binary_installed apt; then
        echo "[*] Installing packages..."
        apt install ${NEEDED_PACKAGES}

        for bin in bash bzip2 coreutils tar wget; do
            if ! is_binary_installed ${bin}; then
                echo "[!] Cannot find binary '${bin}'"
                exit 1
            fi
        done
    else
        echo "[!] The following packages is not available:"
        echo
        for bin in ${NEEDED_PACKAGES}; do
            echo "    + ${bin}"
        done
        echo
    fi
fi

###############################################################################
##
##    Installation
##
###############################################################################

if [ ! -e "${ARCHIVE_PATH}" ]; then
    echo "[*] Downloading archive (v${LATEST_VERSION})..."
    if ! wget -O "${ARCHIVE_PATH}" "${ARCHIVE_URL}"; then
        echo "[!] Failed to download archive"
        exit 1
    fi
fi

echo -n "[*] Checking SHA-256... "
if [ "$(sha256sum ${ARCHIVE_PATH} | awk '{ print $1 }')" != "${ARCHIVE_SHA256}" ]; then
    echo "FAIL"
    rm -f "${ARCHIVE_PATH}"
    exit 1
else
    echo "OK"
fi

if [ ! -e "${BASEDIR}/${ROOTFS_DIR}" ]; then
    echo -n "[*] Extracting data (may take several minutes)... "
    if ! tar xf "${ARCHIVE_PATH}" -C "${BASEDIR}" > /dev/null 2>&1; then
        echo "FAIL"
        exit 1
    else
        echo "OK"
    fi
else
    echo "[!] Remove '${BASEDIR}/${ROOTFS_DIR}'"
    exit 1
fi

if [ ! -e "${BASEDIR}/usr.old" ]; then
    echo -n "[*] Replacing rootfs... "
    if /system/bin/mv "${BASEDIR}"/usr "${BASEDIR}"/usr.old; then
        if /system/bin/mv "${BASEDIR}/${ROOTFS_DIR}" "${BASEDIR}"/usr; then
            echo "OK"
        else
            echo "FAIL"
            exit 1
        fi
    else
        echo "FAIL"
        exit 1
    fi
else
    echo "[!] Remove '${BASEDIR}/usr.old'"
    exit 1
fi

rm -f "${ARCHIVE_PATH}"

## Remove lock file '.termux-rootfs_configured' if it exists before
## running 'termux-setup-rootfs'
rm -f "${HOME}/.termux-rootfs_configured"

exec "${PREFIX}"/bin/bash "${PREFIX}"/bin/termux-setup-rootfs

#!/bin/sh

set -eu

simulator="${1:?Usage: build.sh <simulator>}"
simh_repository='https://github.com/open-simh/simh'
simh_revision="${SIMH_REVISION:-master}"

operating_system() {
  case "$(uname -s)" in
    Darwin) echo 'macos' ;;
    Linux) echo 'linux' ;;
    *)
      echo "Unsupported operating system: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

architecture() {
  case "$(uname -m)" in
    x86_64) echo 'x86-64' ;;
    arm64 | aarch64) echo 'arm64' ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

make_flags() {
  case "$(operating_system)" in
    # Statically link everything, including the C standard library. This
    # requires a musl based system, i.e. Alpine Linux. musl does not identify
    # itself with a predefined macro, so simh falls back to format strings
    # that trigger -Werror=format (hence WARNINGS=ALLOWED) and musl has
    # removed the legacy LFS64 interfaces, i.e. fopen64 (hence
    # DONT_DO_LARGEFILE; off_t is always 64 bit on musl).
    linux) echo 'LDFLAGS_O=-static WARNINGS=ALLOWED CFLAGS_I=-DDONT_DO_LARGEFILE' ;;
    # Video support is not useful for a headless simulator and would pull in
    # a dynamically linked SDL2 from Homebrew.
    macos) echo 'NOVIDEO=1' ;;
  esac
}

number_of_cpus() {
  getconf _NPROCESSORS_ONLN 2> /dev/null || nproc
}

# The oldest macOS version the binary will run on. macOS 13 is the floor for
# the system provided libpcre2-8.dylib the binary links against.
if [ "$(operating_system)" = 'macos' ]; then
  export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
fi

if [ ! -d simh ]; then
  git clone --depth 1 --branch "$simh_revision" "$simh_repository" simh
fi

make -C simh -j "$(number_of_cpus)" $(make_flags) "$simulator"

# The binary needs to be named in lowercase.
binary=$(echo "$simulator" | tr '[:upper:]' '[:lower:]')

mkdir -p output
staging_directory=$(mktemp -d)
trap 'rm -rf "$staging_directory"' EXIT

cp "simh/BIN/$simulator" "$staging_directory/$binary"
tar -C "$staging_directory" -cf \
  "output/$binary-$(operating_system)-$(architecture).tar" "$binary"

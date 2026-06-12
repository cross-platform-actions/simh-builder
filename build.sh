#!/bin/sh

set -eu

simulator="${1:?Usage: build.sh <simulator>}"
simh_repository='https://github.com/open-simh/simh'

# The Open SIMH revision to build. Open SIMH does not publish releases or tags,
# so this is pinned to a specific commit for reproducible builds. Bump it
# deliberately and record the change in the changelog. It can be overridden,
# with a commit, branch or tag, by setting the SIMH_REVISION environment
# variable.
simh_revision="${SIMH_REVISION:-0dc9decac98fc99c8db9722cd5d941b9e73ac67b}"

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

number_of_cpus() {
  getconf _NPROCESSORS_ONLN 2> /dev/null || nproc
}

# The oldest macOS version the binary will run on. macOS 13 is the floor for
# the system provided libpcre2-8.dylib the binary links against.
if [ "$(operating_system)" = 'macos' ]; then
  export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
fi

# A shallow fetch of the exact revision. Unlike "git clone --branch", this
# accepts a commit, not just a branch or tag.
if [ ! -d simh ]; then
  git init -q simh
  git -C simh remote add origin "$simh_repository"
  git -C simh fetch --depth 1 origin "$simh_revision"
  git -C simh checkout -q FETCH_HEAD
fi

# Build the make argument list in the positional parameters. This preserves
# argument boundaries, which matters because the linux CFLAGS_I below contains
# spaces and must reach make as a single argument. The simulator name was
# saved as $simulator above, so overwriting the positional parameters is safe.
set -- -C simh -j "$(number_of_cpus)"
case "$(operating_system)" in
  # Statically link everything, including the C standard library. This
  # requires a musl based system, i.e. Alpine Linux. musl does not identify
  # itself with a predefined macro, so simh falls back to format strings that
  # trigger -Werror=format (hence WARNINGS=ALLOWED).
  #
  # musl has removed the legacy LFS64 interfaces (fopen64, fseeko64, ftello64,
  # off64_t) that sim_fio.c calls by name. Do NOT define DONT_DO_LARGEFILE to
  # work around this: that compiles out simh's tested large-file I/O path and
  # breaks the ISO 9660 CDROM attach, so booting an install CD fails with
  # "?4D DEVOFFLINE" under VMB. off_t is always 64 bit on musl, so instead
  # alias the *64 names to the native functions and keep the path intact.
  linux)
    set -- "$@" LDFLAGS_O=-static WARNINGS=ALLOWED \
      CFLAGS_I='-Dfopen64=fopen -Dfseeko64=fseeko -Dftello64=ftello -Doff64_t=off_t'
    ;;
  # Video support is not useful for a headless simulator and would pull in a
  # dynamically linked SDL2 from Homebrew.
  macos) set -- "$@" NOVIDEO=1 ;;
esac

make "$@" "$simulator"

# The binary needs to be named in lowercase.
binary=$(echo "$simulator" | tr '[:upper:]' '[:lower:]')

mkdir -p output
staging_directory=$(mktemp -d)
trap 'rm -rf "$staging_directory"' EXIT

cp "simh/BIN/$simulator" "$staging_directory/$binary"
tar -C "$staging_directory" -cf \
  "output/$binary-$(operating_system)-$(architecture).tar" "$binary"

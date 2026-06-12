# SIMH Builder

This project builds simulators from [Open SIMH](https://github.com/open-simh/simh)
and publishes the resulting binaries as GitHub releases. Each release contains
one archive per simulator and platform, with the binary named after the
simulator (in lowercase) at the root of the archive.

## Simulators

The following simulators are built:

| Simulator | Description           |
|-----------|-----------------------|
| `vax`     | MicroVAX 3900         |

To add a new simulator, add it to the `simulator` list in the matrix in
[`.github/workflows/build.yml`](.github/workflows/build.yml) and to the above
table. The simulator name needs to match a target in the simh makefile.

## Operating Systems and Architectures

The following operating systems and architectures are supported:

| Operating System | Architecture | Artifact                       |
|------------------|--------------|--------------------------------|
| Linux            | x86-64       | `<simulator>-linux-x86-64.tar` |
| Linux            | arm64        | `<simulator>-linux-arm64.tar`  |
| macOS            | arm64        | `<simulator>-macos-arm64.tar`  |

## Linking

The released binaries are self contained:

* **Linux** - The binary is fully statically linked, including the C standard
  library (musl). It runs on any Linux distribution, regardless of the libc.
  This is achieved by building in an Alpine Linux container.

* **macOS** - The binary only links dynamically against system libraries,
  which are present on every macOS machine. The simh makefile links any
  Homebrew library it detects, so the CI build removes the dynamic libraries
  of the Homebrew packages it installs, forcing the linker to fall back to
  the static archives. Video support is disabled (`NOVIDEO=1`) to avoid a
  dependency on SDL2. The binary targets macOS 13.0 or later
  (`MACOSX_DEPLOYMENT_TARGET=13.0`), which is the floor for the system
  provided `libpcre2-8.dylib` it links against.

## Building Locally

### Prerequisite

* [Git](https://git-scm.com)
* GNU Make
* A C compiler (GCC or Clang)
* **Linux** - A musl based distribution, i.e. Alpine Linux, with the
  `linux-headers` package installed, to produce a fully statically linked
  binary
* **macOS** - The Xcode Command Line Tools

### Building

1. Clone the repository:

    ```
    git clone https://github.com/cross-platform-actions/simh-builder
    cd simh-builder
    ```

2. Run `build.sh` to build a simulator:

    ```
    ./build.sh vax
    ```

    By default the `master` branch of Open SIMH is built. To build a different
    branch or tag, set the `SIMH_REVISION` environment variable:

    ```
    SIMH_REVISION=v4.0-devel ./build.sh vax
    ```

The above command will build the `vax` simulator and the resulting archive will
be at the path: `output/<simulator>-<operating_system>-<architecture>.tar`,
i.e. `output/vax-macos-arm64.tar`.

Note: a local macOS build links dynamically against any Homebrew libraries the
simh makefile detects. Only the CI build, which removes the Homebrew dynamic
libraries before building, produces a binary free of Homebrew dependencies.

## Contributing

### Updating the Changelog

The changelog is maintained in the [changelog.md](changelog.md) file, following
the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. The
changelog is updated incrementally. That is, for every new feature or bugfix,
add an entry to the changelog under the `[Unreleased]` section using an
appropriate sub header (`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`,
or `Security`).

For example, when adding a new feature:

```markdown
## [Unreleased]
### Added
- Short description of the new feature
```

Entries under these sub headers determine the semantic version bump when the
next release is cut with [relog](https://github.com/jacob-carlborg/relog).

### Creating a New Release

Releases are cut with [relog](https://github.com/jacob-carlborg/relog), driven
by the `[Unreleased]` section of `changelog.md`. relog derives the next
version from the sub headers under `[Unreleased]`:

* `### Fixed` only -> patch bump
* `### Added`, `### Changed`, `### Deprecated` -> minor bump
* `### Removed` (or "Breaking" anywhere in the section) -> major bump

To cut a release, from a clean `master` working tree, run:

```
relog
```

To preview the changes without modifying anything:

```
relog --dry-run
```

To override the auto-detected version:

```
relog X.Y.Z
```

relog rewrites the changelog, commits the result, creates an annotated `vX.Y.Z`
tag, and prompts before pushing. Pushing the `vX.Y.Z` tag triggers the GitHub
Actions workflow defined in
[`.github/workflows/build.yml`](.github/workflows/build.yml), which builds the
binaries and, in the "Create Release" step, creates a draft GitHub release
using the newly added changelog section as the release notes. Review the draft
release on GitHub and publish it.

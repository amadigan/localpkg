> **NOTE** These instructions are for installing localpkg from source. For other information, please see the [README](README.md).

# Installing localpkg

localpkg requires:
- zsh
- bsdtar
- curl
- jq
- openssl

localpkg also uses `gh` if installed, but it is not required.

Building localpkg requires:
- zsh
- bsdtar (for the compressed version)
- openssl (for the sha256sums.txt file)

If you do not have these tools on your host system, you may use the docker build script (`build-docker.sh`) to build
localpkg as a docker image.

## Installation

To localpkg from source on your system, in ~/.local/bin, run `./localpkg.zsh add localpkg`, to install the compressed
version, use `./localpkg.zsh add -z localpkg`.

## Release Files

A release of localpkg in GitHub contains:

- `localpkg` - the compressed build of localpkg
- `localpkg.zsh` - the uncompressed build of localpkg
- `sha256sums.txt` - the sha256sums of the compressed and uncompressed builds

A correct build of localpkg depends on some environment variables:
- GITHUB_REPOSITORY - the name of the repository that hosts localpkg
- RELEASE_TAG - then tag of the GitHub release this build is for

These environment variables ensure that when localpkg installs itself, it is able to update itself properly. Otherwise,
they have no effect.

To run the release build on a host with the required tools, run `./build-release.zsh` in the desired output directory.
Alternately, you may pass the desired output directory as an argument to `./build-release.zsh`.

To run the release build in docker, run `./build-docker-release.sh` in the desired output directory. Alternately, you
may pass the desired output directory as an argument to `./build-docker-release.sh`.

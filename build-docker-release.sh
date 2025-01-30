#!/usr/bin/env bash
# This script should work on bash 3+ (for macOS and GitHub Actions)
set -e
declare outdir="."
declare push=0

while [[ $# -gt 0 ]]; do
	case "${1}" in
		-h|--help)
			echo "Build a release to the specified directory (default: .)"
			echo "Usage: ${0} [options] [outdir]"
			echo ""
			echo "Options:"
			echo "  -h, --help  Show this help message"
			exit 0
			;;
		-p|--push)
			push=1
			shift
			;;
		*)
			outdir="${1}"
			shift
			;;
	esac
done

declare -a docker_args=()

if [[ -n "${GITHUB_REPOSITORY}" ]]; then
	docker_args+=("--build-arg" "GITHUB_REPOSITORY=${GITHUB_REPOSITORY}")
fi

if [[ -n "${RELEASE_TAG}" ]]; then
	docker_args+=("--build-arg" "RELEASE_TAG=${RELEASE_TAG}")
fi

realpath "$(dirname "${BASH_SOURCE[0]}")"
declare srcdir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

mkdir -p "${outdir}" || exit 1

if [[ "${srcdir}" == "$(realpath "${outdir}")" ]]; then
	echo Refusing to build in the source directory
	exit 1
fi

set -x

cd "${outdir}" || exit 1
docker buildx build "${docker_args[@]}" --target release --output type=local,dest=. "${srcdir}"

if [[ -n "${push}" ]]; then
	docker buildx build --platform linux/arm64,linux/amd64 "${docker_args[@]}" --target localpkg --tag "ghcr.io/${GITHUB_REPOSITORY}/localpkg:${RELEASE_TAG}" --push "${srcdir}"
fi

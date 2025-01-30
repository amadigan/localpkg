#!/usr/bin/env bash
# This script should work on bash 3+
set -e
declare docker_tag="localpkg"

while [[ $# -gt 0 ]]; do
	case "${1}" in
		-h|--help)
			echo "Build the docker image with a specified tag (default: localpkg)"
			echo "Usage: ${0} [options] [outdir]"
			echo ""
			echo "Options:"
			echo "  -h, --help  Show this help message"
			exit 0
			;;
		*)
			docker_tag="${1}"
			shift
			;;
	esac
done


declare -a docker_args=("--target" "localpkg" "--tag" "${docker_tag}" "--load")

if [[ -n "${GITHUB_REPOSITORY}" ]]; then
	docker_args+=("--build-arg" "GITHUB_REPOSITORY=${GITHUB_REPOSITORY}")
fi

if [[ -n "${RELEASE_TAG}" ]]; then
	docker_args+=("--build-arg" "RELEASE_TAG=${RELEASE_TAG}")
fi

realpath "$(dirname "${BASH_SOURCE[0]}")"
declare srcdir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

set -x

docker buildx build "${docker_args[@]}" "${srcdir}"

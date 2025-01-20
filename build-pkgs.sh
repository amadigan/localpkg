#!/bin/bash
project_root="$(realpath "${BASH_SOURCE%/*}")"

mkdir -p "${project_root}/dist"

for pkg in $(ls -d "${project_root}"/pkg/*.zsh); do
	pkg_name=$(basename "${pkg}")
	pkg_name="${pkg_name%.*}"

	echo "${pkg} -> ${project_root}/dist/${pkg_name}"
	"${project_root}/mkinstall.zsh" -o "${project_root}/dist/${pkg_name}" "${pkg}"
done

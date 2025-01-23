# core functions for libinstall
LOCALPKG_PREFIX="${LOCALPKG_PREFIX:-${HOME}/.local}"

zmodload -m -F zsh/files b:zf_\*
zmodload zsh/system

typeset -t lp_pkg_name
typeset -t lp_pkg_url
typeset -m lp_pkg_file
typeset -t lp_update_url
typeset -t lp_gh_repo
typeset -t lp_release
typeset -a lp_tar_args=("--strip-components" "1" "--safe-writes" "--exclude" '*LICENSE*' "--exclude" '*README*' "--exclude" '*CHANGELOG*' "--exclude" '*COPYING*')

lp_debug() {
	if [[ -n "${LOCALPKG_DEBUG}" ]]; then
		echo -E "$(print -P "%D{"%Y-%m-%dT%H:%M:%SZ"}")"'	debug	'"${@}" >&2
	fi
}

lp_log() {
	echo -E "$(print -P "%D{"%Y-%m-%dT%H:%M:%SZ"}")"'	localpkg	'"${@}" >&2
}

lp_fatal() {
	lp_log "${@}"
	exit 1
}

trap lp_cleanup EXIT

lp_reset_pkg_vars() {
	lp_pkg_name=""
	lp_pkg_url=""
	lp_pkg_file=""
	lp_update_url=""
	lp_gh_repo=""
	lp_release=""
}

lp_main() {
	set -e
	lp_init
	[[ -z "${lp_pkg_name}" ]] && lp_fatal "Package name not set"
	[[ -z "${lp_pkg_url}" ]] && lp_fatal "No package URL found for ${lp_pkg_name}"

	lp_skeleton
	lp_install_pkg
	lp_postinstall "${LOCALPKG_PREFIX}" "${lp_pkg_name}"
	lp_create_uninstall
	lp_log "Installed ${lp_pkg_name} ${lp_release} to ${LOCALPKG_PREFIX}, to uninstall run \"${LOCALPKG_PREFIX}/pkg/${lp_pkg_name} remove\""
}

lp_mktemp() {
	local random="${RANDOM}"
	local dir="$(printf 'localpkg-%x%04x' $(print -P "%D{"%s"}") ${random})"
	dir="${TMPDIR:-/tmp}/${dir}"
	dir="${dir:A}"

	if zf_mkdir "${dir}"; then
		lpr_tmp_dir="${dir}"
		lpr_tmp_dirs+=("${dir}")
	else
		lp_fatal "Failed to create temporary directory"
	fi
}

lp_cleanup() {
	for dir in "${lpr_tmp_dirs[@]}"; do
		zf_rm -rf "${dir}"
	done
}

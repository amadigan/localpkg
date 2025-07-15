# core functions for libinstall
typeset -tAg lp_pkg=(
	[name]="" # package name, usually the name of the program
	[repo]="" # GitHub repository, in the form "user/repo"
	[release]="" # release tag to install, defaults to "latest"
	[latest_package_url]="" # URL to fetch the latest package
	[package_url]="" # versioned package URL
	[latest_package]="" # static package name across releases
	[package]="" # versioned package name
	[package_pattern]="" # pattern to match package files
	[installer_url]="" # full installer URL (always latest)
	[installer]="" # installer name (always latest)
	[installer_pattern]="" # pattern to match installer files
	[hashalg]="" # hash algorithm to use for checksums
	[package_hash]="" # hash of the package file
	# metadata for the fetched file, present in the manager script
	[content_type]=""
	[effective_url]=""
	[etag]=""
	[last_modified]=""
	[filename]=""
	[download_hash]="" # hash of the downloaded file
)

typeset -tg lp_debug_current_cmd=""
typeset -tg lp_log_timestamp='%D{%Y-%m-%dT%H:%M:%SZ}'

lp_debug() {
	[[ -n "${LOCALPKG_DEBUG}" ]] && printf '%s %s\n' "${(%)lp_log_timestamp}" "${*}" >&2
	return 0
}

lp_log() {
	printf '%s %s\n' "${(%)lp_log_timestamp}" "${*}" >&2
	return 0
}

lp_error() {
	printf '%s ERROR %s\n' "${(%)lp_log_timestamp}" "${*}" >&2
	return 1
}


lp_err_trap() {
	[[ "${funcstack[2]}" != "lp_error" ]] && lp_error "${1}" failed
}

lp_boot() {
	# this is called by main
	if [[ -v __SFX_ID && -n "${__SFX_FD}" ]]; then
		if [[ -r "/dev/fd/${__SFX_FD}" ]]; then
			lp_log "Redirecting fd ${__SFX_FD} to stdin"
			exec <&${__SFX_FD}
			exec {__SFX_FD}<&-
		else
			lp_log "Failed to open /dev/fd/${__SFX_FD}"
		fi
		
		unset __SFX_FD
	fi

	setopt err_exit typeset_silent unset

	[[ -z "${LOCALPKG_PREFIX}" ]] && typeset -gx LOCALPKG_PREFIX="${HOME}/.local"

	# TODO this should probably be debug-only
	#trap 'lp_debug_current_cmd="${ZSH_DEBUG_CMD}"' DEBUG
	#trap 'lp_err_trap "${lp_debug_current_cmd}"' ERR

	typeset -f lp_cleanup &>/dev/null && trap lp_cleanup EXIT
	typeset -g lp_os="${OSTYPE%%[^[:alpha:]]*}" # e.g. "darwin" "linux"
	typeset -g lp_arch="${CPUTYPE}"

	case "${lp_arch}" in
		(amd64|x86_64)
			lp_arch="amd64"
			;;
		(aarch64|arm64)
			lp_arch="arm64"
			;;
	esac

	zmodload zsh/system zsh/zutil zsh/files zsh/stat
}

lp_mktempdir() {
	private i

	[[ -v lp_mktemp_dir ]] || return 1
	builtin mkdir -p "${TMPDIR:-/tmp}" || return 1

	for i in {1..2}; do
		lp_mktemp_dir="${TMPDIR:-/tmp}/localpkg-$(command -p openssl rand -hex 8)"
		if builtin mkdir "${lp_mktemp_dir}"; then
			lp_tmp_dirs+=("${lp_mktemp_dir}")
			return 0
		fi
	done

	lp_error "Failed to create temporary directory"
	return 1
}

lp_mktempfile() {
	private i

	[[ -v lp_mktemp_file ]] || return 1
	builtin mkdir -p "${TMPDIR:-/tmp}" || return 1

	for i in {1..2}; do
		lp_mktemp_file="${TMPDIR:-/tmp}/localpkg-$(command -p openssl rand -hex 8)"
		if [[ ! -e "${lp_mktemp_file}" ]]; then
			printf '' > "${lp_mktemp_file}"
			lp_tmp_dirs+=("${lp_mktemp_file}")
			return 0
		fi
	done

	lp_error "Failed to create temporary file"
	return 1
}

lp_cleanup() {
	[[ ! -v lp_tmp_dirs ]] && return 0
	for dir in "${lp_tmp_dirs[@]}"; do
		builtin rm -rf "${dir}"
	done
}

lp_hash_file() {
	private hashalg="${1}"
	private file="${2}"

	private hash="$(command -p openssl dgst -r "-${hashalg}" "${file}")"
	hash="${hash%% *}"
	printf "%s" "${hash}"
}

lp_unset() {
	local var
	for var in "${@}"; do
		[[ -v "${var}" ]] && unset "${var}"
	done
}

lp_cmd() {
	private prefix="${1}"
	shift

	private cmd

	if [[ "${#@}" -gt 0 && "${1}" != -* ]]; then
		cmd="${1}"
		shift
	fi

	private cmdfunc="${prefix}_${cmd}"

	[[ -z "${cmd}" ]] && cmdfunc="${prefix}"

	if [[ "${cmd}" == "-h" || "${cmd}" == "--help" ]]; then
		"${prefix}_help"
		return 0
	fi

	if typeset -f "${cmdfunc}" &>/dev/null; then
		"${cmdfunc}" "${@}"
		return
	else
		[[ -n "${cmd}" ]] && echo "Unknown command: ${cmd}"
		"${prefix}_help"
		return 1
	fi
}

lp_cmd_help() {
	private prefix="${1}"
	private -a cmds
	private cmd
	private -a lines

	for func in ${(k)functions}; do
		if [[ "${func}" == "${prefix}_"* && "${func}" != "${prefix}_help" ]]; then
			cmds+=("${func##${prefix}_}")
		fi
	done

	cmds=(${(o)cmds})

	[[ ${#cmds} -eq 0 ]] && return 1

	for cmd in ${(@)cmds}; do
		lines=(${(f)"$("${prefix}_${cmd}" --help)"})
		printf "\t%s\t%s\n" "${cmd}" "${lines[1]}"
	done

	return 0
}

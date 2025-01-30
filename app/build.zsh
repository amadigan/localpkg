typeset -tagU xlpcli_vars xlpcli_funcs

lpcli_load_script() {
	# load a script, recording the resulting variables and functions for transclusion
	# results are added to lp_script_vars and lp_script_funcs
	lpcli_script_vars=()
	lpcli_script_funcs=()
	lpcli_script_mods=()

	private -U old_mods=($(zmodload -LF))
	private -U old_funcs=(${(k)functions})
	private -U old_vars=(${(k)parameters})

	eval "${1}"

	for lp_var in ${(k)parameters}; do
		[[ "${parameters[${lp_var}]}" == *-tag* ]] && lpcli_script_vars+=("${lp_var}")
	done

	lpcli_script_vars=(${lpcli_script_vars:|old_vars})
	lpcli_script_vars=(${lpcli_script_vars:#?*})
	lpcli_script_vars=(${(o)lpcli_script_vars})

	lpcli_script_funcs=(${(k)functions})
	lpcli_script_funcs=(${lpcli_script_funcs:|old_funcs})
	lpcli_script_funcs=(${lpcli_script_funcs:#?*})
	lpcli_script_funcs=(${(o)lpcli_script_funcs})

	lpcli_script_mods=($(zmodload -LF))
	lpcli_script_mods=(${lpcli_script_mods:|old_mods})
	lpcli_script_mods=(${lpcli_script_mods:#?*})
	lpcli_script_mods=(${(o)lpcli_script_mods})
}

lpcli_cmd_build() {
	# build subcommand
	private -A opts=()

	zparseopts -D -E -A opts h -help z -compress

	if [[ -v opts[-h] || -v opts[--help] ]]; then
		lpcli_build_help
		return 0
	fi

	private src="${1}"
	private dest="${2}"
	private gen=""

	[[ "${src}" == "-" ]] && src=""
	[[ "${dest}" == "-" ]] && dest=""

	private fd=0
	private line

	if [[ "${src}" != "@" ]]; then
		if [[ -n "${src}" ]] && ! sysopen -r -u fd "${src}"; then
			lp_error "Failed to open ${src}"
			return 1
		fi

		src=""
		while sysread -i ${fd} -t 0 line; do src+="${line}"; done
		exec {fd}<&-
	fi

	if ! gen="$(lpcli_build_installer "${src}")"; then
		lp_error "Failed to build installer"
		return 1
	fi

	[[ -n "${dest}" ]] && builtin rm -f "${dest}"

	private outfmt="%s\n"

	if [[ -v opts[-z] || -v opts[--compress] ]]; then
		outfmt="%s"
		private outfile="${dest}"

		if [[ -z "${dest}" ]]; then
			local lp_mktemp_file
			lp_mktempfile
			outfile="${lp_mktemp_file}"
			unset lp_mktemp_file
		fi

		printf "%s" "${gen}" > "${outfile}"
		private pkgname="$(lpcli_build_get_pkg_name "${src}")"
		if ! gen="$(lp_compress_script "${pkgname}" "${outfile}")"; then
			lp_error "Failed to compress installer"
			return 1
		fi
		builtin rm -f "${outfile}"
	fi

	if [[ -n "${dest}" ]]; then
		printf "${outfmt}" "${gen}" > "${dest}"
		builtin chmod 755 "${dest}"
	else
		printf "${outfmt}" "${gen}"
	fi

	return 0
}

lpcli_build_help() {
	echo "Build an installer script"
	echo "Usage: ${ZSH_ARGZERO} build [options...] [infile] [outfile]"
	echo ""
	echo "Options:"
	echo "  -h, --help  Show this help message"
	echo "  -z, --compress Generate a compressed installer"
	echo ""
	echo "To build from stdin, use '-' as the infile"
}

lpcli_build_installer() {
	private srcpath="${1}"

	local -a lpcli_script_vars lpsc_script_funcs lpsc_script_mods

	[[ "${1}" != "@" ]] && lpcli_load_script "${srcpath}"

	printf "#!/bin/zsh\n"
	xlp_transclude

	if [[ "${1}" == "@" ]]; then
		typeset -p "${xlpcli_vars[@]}"
		typeset -f "${xlpcli_funcs[@]}"
		printf "lpcli_main \"\${@}\"\nexit\n"
	else
		[[ ${#lpcli_script_mods[@]} -gt 0 ]] && print -l "${lpcli_script_mods[@]}"
		[[ ${#lpcli_script_vars[@]} -gt 0 ]] && typeset -p "${lpcli_script_vars[@]}"
		[[ ${#lpcli_script_funcs[@]} -gt 0 ]] && typeset -f "${lpcli_script_funcs[@]}"
		printf "lp_installer_main \"\${@}\"\nexit\n"
	fi
}

lpcli_build_get_pkg_name() {
	if [[ "${1}" == "@" ]]; then
		printf "localpkg"
	else
		local -A lp_pkg=()
		eval "${1}" || return 1
		printf "${lp_pkg[name]}"
	fi
}

lpcli_cmd_test() {
	private -A opts=()
	zparseopts -D -E -A opts h -help

	if [[ -v opts[-h] || -v opts[--help] ]]; then
		lpcli_test_help
		return 0
	fi

	if [[ -z "${1}" ]]; then
		lpcli_test_help

		return 1
	fi

	(lpcli_build_installer "${1}") | exec -a "${1}" zsh -s
}

lpcli_test_help() {
	echo "Test an installer script"
	echo "Usage: ${ZSH_ARGZERO} test [options...] infile"
	echo ""
	echo "Options:"
	echo "  -h, --help  Show this help message"
	echo ""
}

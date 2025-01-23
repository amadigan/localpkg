lpcli_load_script() {
	# load a script, recording the resulting variables and functions for transclusion
	# results are added to lp_script_vars and lp_script_funcs
	lp_script_vars=()
	lp_script_funcs=()

	if [[ -z "$1" || ! -f "$1" ]]; then
		lp_fatal "Error: Script to be sourced (${1}) is not provided or does not exist."
	fi

	local -U lp_exclude_vars=("LOCALPKG_PREFIX" "zle_bracketed_paste" "WATCHFMT" "LOGCHECK")

	local -U lp_pre_funcs=(${(k)functions})
	local -A lp_pre_vars
	local lp_var

	for lp_var in ${(k)parameters}; do
	  if [[ " ${lp_exclude_vars[@]} " != *" ${lp_var} "* ]]; then
	    lp_pre_vars[${lp_var}]="${parameters[${lp_var}]}"
	  fi
	done

	source "$1"

	for lp_var in ${(k)parameters}; do
		if [[ " ${lp_exclude_vars[@]} " != *" ${lp_var} "* &&
			 (${lp_pre_vars[${lp_var}]} != "${parameters[${lp_var}]}" || -z "${lp_pre_vars[${lp_var}]}" ) ]]; then
			lp_script_vars+=("${lp_var}")
		fi
	done

	local -U lp_post_funcs=(${(k)functions})
	lp_script_funcs=(${lp_post_funcs:|lp_pre_funcs})
	lp_script_vars=(${lp_script_vars:#?*})
}

lpcli_build() {
	# build subcommand

	if [[ -z "${1}" ]]; then
		echo "Usage: ${ZSH_ARGZERO} build infile [outfile]"
		exit 1
	fi

	local infile="${1}"
	shift

	if [[ -n "${1}" ]]; then
		local outfile="${1}"
		zf_rm -f "${outfile}"
		shift
	fi

	if [[ "${infile}" == "@" ]]; then
		if [[ -n "${outfile}" ]]; then
			lpcli_build_self > "${outfile}"
			zf_chmod 755 "${outfile}"
		else
			lpcli_build_self
		fi
	elif [[ -n "${outfile}" ]]; then
		lpcli_build_installer "${infile}" "${@}" > "${outfile}"
		zf_chmod 755 "${outfile}"
	else
		lpcli_build_installer "${infile}" "${@}"
	fi
}

lpcli_build_installer() {
	local srcpath="${1}"
	shift

	local -U lp_script_vars lp_script_funcs

	lpcli_load_script "${srcpath}"

	local override

	for override in "${@}"; do
		[[ -n "${override}" ]] && eval "${override}"
	done

	echo "#!/bin/zsh"
	echo "LOCALPKG_PREFIX=\"\${LOCALPKG_PREFIX:=\${HOME}/.local}\""
	
	xlp_transclude

	[[ ${#lp_script_vars[@]} -gt 0 ]] && typeset -p "${lp_script_vars[@]}"
	[[ ${#lp_script_funcs[@]} -gt 0 ]] && typeset -f "${lp_script_funcs[@]}"
	echo "lp_main \"\${@}\""
}

lpcli_build_self() {
	echo "#!/bin/zsh"
	echo "LOCALPKG_PREFIX=\"\${LOCALPKG_PREFIX:=\${HOME}/.local}\""
	xlp_transclude
	typeset -p "${xlpcli_vars[@]}"
	typeset -f "${xlpcli_funcs[@]}"
	echo "lpcli_main \"\${@}\""
}

lpcli_test() {
	[[ -z "${1}" ]] && lp_fatal "Usage: ${ZSH_ARGZERO} test <script> [overrides...]"
	lpcli_build_installer "${@}" | zsh -s
}

lp_skeleton() {
	zf_mkdir -p "${LOCALPKG_PREFIX}/etc"

	local prefix="${LOCALPKG_PREFIX/#$HOME/\${HOME\}}"

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/bashrc" ]]; then
		{
			typeset -f lp_skeleton_bashrc
			echo -E "lp_skeleton_bashrc ${(q)prefix}"
			echo -E "unset -f lp_skeleton_bashrc"
		} > "${LOCALPKG_PREFIX}/etc/bashrc"
	fi

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/zshenv" ]]; then
		lp_write_anon_func lp_skeleton_zshenv "${prefix}" > "${LOCALPKG_PREFIX}/etc/zshenv"
	fi

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/zshrc" ]]; then
		lp_write_anon_func lp_skeleton_zshrc "${prefix}" > "${LOCALPKG_PREFIX}/etc/zshrc"
	fi

	lp_ensure_file_line "${HOME}/.zshenv" "[[ -r \"${prefix}/etc/zshenv\" ]] && source \"${prefix}/etc/zshenv\" # localpkg DO NOT EDIT"
	lp_ensure_file_line "${HOME}/.zshrc" "[[ -r \"${prefix}/etc/zshrc\" ]] && source \"${prefix}/etc/zshrc\" # localpkg DO NOT EDIT"
	lp_ensure_file_line "${HOME}/.bash_profile" "[[ -r \"${prefix}/etc/profile\" ]] && source \"${prefix}/etc/profile\" # localpkg DO NOT EDIT"
	lp_ensure_file_line "${HOME}/.bashrc" "[[ -r \"${prefix}/etc/profile\" ]] && source \"${prefix}/etc/profile\" # localpkg DO NOT EDIT"
}

lp_write_anon_func() {
	local func_name="${1}"
	shift
	local src=$(typeset -f "${func_name}")
	echo -E "${src#${func_name} }" "${(q)@}"
}

lp_skeleton_bashrc() {
	# this function is written to ~/.local/etc/bashrc, followed by an invocation (with LOCALPKG_PREFIX as a parameter), followed unsetting the function
	
	# protect against double-loading, because this script is referenced in ~/.bashrc and ~/.bash_profile
	[[ -n "${_LOCALPKG_BASHRC_LOADED}" ]] && return
	_LOCALPKG_BASHRC_LOADED=1
	local prefix="${1}"
	local file

	export PATH="${prefix}/bin:${PATH}"
	export MANPATH="${prefix}/share/man:${MANPATH}"
	if [[ -d "${prefix}/etc/bashrc.d" ]]; then
		for file in "${prefix}/etc/bashrc.d"/*.sh; do
			[[ -r "${file}" ]] && . "${file}"
		done
	fi
}

lp_skeleton_zshenv() {
	# this is written as an anonymous function to ~/.local/etc/zshenv, with LOCALPKG_PREFIX as a parameter
	local prefix="${1}"
	export PATH="${prefix}/bin:${PATH}"
	if [[ -d "${prefix}/etc/zshenv.d" ]]; then
		for file in "${prefix}/etc/zshenv.d"/*.zsh; do
			[[ -r "${file}" ]] && . "${file}"
		done
	fi
}

lp_skeleton_zshrc() {
	# this is written as an anonymous function to ~/.local/etc/zshrc, with LOCALPKG_PREFIX as a parameter
	local prefix="${1}"
	export MANPATH="${prefix}/share/man:${MANPATH}"
	if [[ -d "${prefix}/etc/zshrc.d" ]]; then
		for file in "${prefix}/etc/zshrc.d"/*.zsh; do
			[[ -r "${file}" ]] && . "${file}"
		done
	fi
}

lp_ensure_file_line() {
	local file="${1}"
	local line="${2}"
	local fline

	if [[ ! -f "${file}" ]]; then
		lp_log Creating "${file}"
		echo "${line}" > "${file}"
		return 0
	fi

	while read -r fline; do
		if [[ "${fline}" == "${line}" ]]; then
			return 0
		fi
	done < "${file}"

	lp_log Appending "${line}" to "${file}"
	echo "${line}" >> "${file}"
}

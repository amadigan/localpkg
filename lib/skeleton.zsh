lp_skeleton() {
	builtin mkdir -p "${LOCALPKG_PREFIX}/etc"

	private prefix="${LOCALPKG_PREFIX/#$HOME/\${HOME\}}"

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/bashrc" ]]; then
		{
			typeset -f lp_skeleton_bashrc
			printf 'lp_skeleton_bashrc "%s"\n' "${prefix}"
			printf "unset -f lp_skeleton_bashrc\n"
		} > "${LOCALPKG_PREFIX}/etc/bashrc"
	fi

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/zshrc" ]]; then
		{
			echo "#!/bin/zsh"
			echo "# localpkg DO NOT EDIT"
			lp_write_anon_func lp_skeleton_zshrc "\"${prefix}\""
		} > "${LOCALPKG_PREFIX}/etc/zshrc"
	fi

	local -A lp_skeleton_lines
	lp_skeleton_mklines

	private efile eline

	for efile eline in "${(@kv)lp_skeleton_lines}"; do
		lp_ensure_file_line "${efile}" "${eline}"
	done
}

lp_skeleton_mklines() {
	private prefix="${LOCALPKG_PREFIX/#$HOME/\${HOME\}}"
	lp_skeleton_lines[${HOME}/.zshrc]="[[ -r \"${prefix}/etc/zshrc\" ]] && source \"${prefix}/etc/zshrc\" # localpkg DO NOT EDIT"
	lp_skeleton_lines[${HOME}/.bash_profile]="[[ -r \"${prefix}/etc/bashrc\" ]] && source \"${prefix}/etc/bashrc\" # localpkg DO NOT EDIT"
	lp_skeleton_lines[${HOME}/.bashrc]="[[ -r \"${prefix}/etc/bashrc\" ]] && source \"${prefix}/etc/bashrc\" # localpkg DO NOT EDIT"
}

lp_write_anon_func() {
	private func_name="${1}"
	shift
	printf "%s %s\n" "${$(typeset -f "${func_name}")#${func_name} }" "${*}"
}

lp_skeleton_bashrc() {
	# this function is written to ~/.local/etc/bashrc, followed by an invocation (with LOCALPKG_PREFIX as a parameter), followed unsetting the function
	
	# protect against double-loading, because this script is referenced in ~/.bashrc and ~/.bash_profile
	[[ -n "${_LOCALPKG_BASHRC_LOADED}" ]] && return
	_LOCALPKG_BASHRC_LOADED=1
	local bashrcfile
	
	export LOCALPKG_PREFIX="${1}"

	[[ ":${PATH}:" != *":${1}/bin:"* ]] && export PATH="${1}/bin:${PATH:+:${PATH}}"
	[[ ":${MANPATH}:" != *":${1}/share/man:"* ]] && export MANPATH="${1}/share/man${MANPATH:+:${MANPATH}}"
	if [[ -d "${1}/etc/profile.d" ]]; then
		for bashrcfile in "${1}/etc/profile.d"/*.sh; do
			[[ -r "${bashrcfile}" ]] && source "${bashrcfile}"
		done
	fi
	if [[ -d "${1}/etc/bashrc.d" ]]; then
		for bashrcfile in "${1}/etc/bashrc.d"/*.sh; do
			[[ -r "${bashrcfile}" ]] && source "${bashrcfile}"
		done
	fi
}

lp_skeleton_zshrc() {
	# this is written as an anonymous function to ~/.local/etc/zshrc, with LOCALPKG_PREFIX as a parameter
	[[ ":${PATH}:" != *":${1}/bin:"* ]] && path=("${1}/bin" "${(@)path}") 
	[[ ":${MANPATH}:" != *":${1}/share/man:"* ]] && manpath=("${1}/share/man" "${(@)manpath}")
	local -a __localpkg_zshrc_files
	{
		setopt localoptions null_glob
		__localpkg_zshrc_files=("${1}/etc/profile.d/*.sh"(N))
	}
	local __localpkg_zshrc
	for __localpkg_zshrc in "${(@)__localpkg_zshrc_files}"
	do
		[[ -r "${__localpkg_zshrc}" ]] && emulate sh -c "source '${__localpkg_zshrc}'"
	done
	{
		setopt localoptions null_glob
		__localpkg_zshrc_files=("${1}/etc/zshrc.d/*.zsh"(N))
	}
	for __localpkg_zshrc in "${(@)__localpkg_zshrc_files}"
	do
		[[ -r "${__localpkg_zshrc}" ]] && source "${__localpkg_zshrc}"
	done
}

lp_ensure_file_line() {
	private file="${1}"
	private line="${2}"
	private fline

	if [[ ! -f "${file}" ]]; then
		lp_log Creating "${file}"
		printf "%s\n" "${line}" > "${file}"

		return 0
	fi

	while read -r fline; do
		[[ "${fline}" == "${line}" ]] && return 0
	done < "${file}"

	lp_log Appending "${line}" to "${file}"
	printf "\n%s\n" "${line}" >> "${file}"
}

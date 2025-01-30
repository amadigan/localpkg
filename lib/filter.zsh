# functions related to filtering the list of release files
typeset -tag lp_package_patterns=(
	'*.tar.gz' '*.tgz' '*.tar.xz' '*.txz' '*.tar.bz2' '*.tbz2' '*.tar' '*.zip'
)

typeset -tag lp_exclude_package_patterns=(
	'*.asc' '*.sum' '*.sig' '*.sha256' '*.sha512' '*.sha1' '*.md5' '*.sha' '*.sha256sum' '*.sha512sum' '*.md5sum' '*.sums'
	'*.shasum' '*.gpg' '*.txt' '*.md'
)

typeset -tag lp_package_seps=('-' '_' '.' ' ')

typeset -tag lp_installer_names=(
	"localpkg-install" "localpkg-install.sh" "localpkg-install.zsh"
	"install-localpkg" "install-localpkg.sh" "install-localpkg.zsh"
	"localpkg" "localpkg.sh" "localpkg.zsh"
)

lp_filter_release() {
	private -aU os_names arch_names files filtered refiltered choices
	private os_name arch_name sep

	files=("${@}")
	lp_debug "Filtering ${#files} release files: ${files[@]}"
	if [[ -n "${lp_pkg[package_pattern]}" ]]; then
		files=(${(fQ)"$(lp_filter_pattern "${lp_pkg[package_pattern]}" ${(@)files})"})
	fi
	[[ "${#files}" -lt 2 ]] && printf "%q" "${(@)files}" && return
	files=(${(fQ)"$(lp_filter_exclude_patterns ${(@)files})"})
	lp_debug "After excluding patterns: ${files[@]}"
	[[ "${#files}" -lt 2 ]] && printf "%q" "${(@)files}" && return

	os_names=("${OSTYPE}")
	case "${OSTYPE}" in
		linux*)
			os_names+=("${OSTYPE}" "linux")
			;;
		darwin*)
			os_names+=("${OSTYPE}" "macos" "darwin")
			;;
	esac

	for os_name in "${(@)os_names}"; do
		filtered=(${(fQ)"$(lp_filter_name "${os_name}" "${(@)files}")"})

		if [[ "${#filtered}" -ne 0 ]]; then
			files=("${(@)filtered}")
			break
		fi
	done

	[[ "${#files}" -lt 2 ]] && printf "%q" "${(@)files}" && return
	
	arch_names=("${CPUTYPE}")
	case "${CPUTYPE}" in
		(amd64|x86_64)
			arch_names+=("amd64" "x86_64")
			;;
		(aarch64|arm64)
			arch_names+=("arm64" "aarch64")
			;;
	esac

	for arch_name in "${(@)arch_names}"; do
		filtered=(${(fQ)"$(lp_filter_name "${arch_name}" "${(@)files}")"})

		if [[ "${#filtered}" -ne 0 ]]; then
			files=("${(@)filtered}")
			break
		fi
	done

	[[ "${#files}" -lt 2 ]] && printf "%q" "${(@)files}" && return

	choices=()
	for pattern in "${(@)lp_package_patterns}"; do
		filtered=(${(fQ)"$(lp_filter_pattern "${pattern}" "${(@)files}")"})
		lp_debug filter results for pattern "${pattern}": "${filtered[@]}"

		if [[ "${#filtered}" -gt 1 ]]; then
			for sep in "${(@)lp_package_seps}"; do
				refiltered=(${(fQ)"$(lp_filter_nameprefix "${sep}" "${(@)filtered}")"})
				[[ "${#refiltered}" -ne 0 ]] && filtered=("${(@)refiltered}") && break
			done
		fi

		if [[ "${#filtered}" -eq 1 ]]; then
			printf "%q" "${(@)filtered}"
			return 0
		else
			choices+=("${(@)filtered}")
		fi
	done

	[[ "${#choices}" -gt 0 ]] && files=("${(@)choices}")
	lp_debug "Multiple choices: ${(q@)files}"
	printf "%q\n" "${(@)files}"
}

lp_filter_name() {
  private regex="(^|[^[:alnum:]])${1}([^[:alnum:]]|$)"
	private fname
	private -a match
	shift

	for fname in "${@}"; do
		[[ "${(L)fname}" =~ ${regex} ]] && printf "%q\n" "${fname}"
	done

	return 0
}

lp_filter_pattern() {
	private -m pattern="${1}"
	private fname
	shift

	for fname in "${@}"; do
		[[ ${fname} == ${~pattern} ]] && printf "%q\n" "${fname}"
	done

	return 0
}

lp_filter_nameprefix() {
	private prefix="${lp_pkg[package]:-${lp_pkg[name]}}${1}"
	shift

	lp_debug "Filtering for prefix: ${prefix}"

	for fname in "${@}"; do
		[[ "${fname}" == "${prefix}"* ]] && printf "%q\n" "${fname}"
	done

	return 0
}

lp_filter_exclude_patterns() {
	private -m pattern
	private fname matches

	for fname in "${@}"; do
		matches=0
		for pattern in "${(@)lp_exclude_package_patterns}"; do
			[[ "${fname}" == ${~pattern} ]] && matches=1 && break
		done

		(( matches == 0 )) && printf "%q\n" "${fname}"
	done

	return 0
}

lp_filter_findinstaller() {
	private fname iname

	for fname in "${@}"; do
		[[ "${fname}" == "${lp_pkg[package]}.localpkg" ]] && printf "%q" "${fname}" && return
	done

	for fname in "${@}"; do
		[[ "${fname}" == "${lp_pkg[name]}.localpkg" ]] && printf "%q" "${fname}" && return
	done

	for fname in "${@}"; do
		for iname in "${(@)lp_installer_names}"; do
			[[ "${fname}" == "${iname}" ]] && printf "%q" "${fname}" && return
		done
	done

	private -a pkgscripts

	for fname in "${@}"; do
		[[ "${fname}" == *.localpkg ]] && pkgscripts+=("${fname}")
	done

	[[ "${#pkgscripts}" -eq 1 ]] && printf "%q" "${pkgscripts[1]}"

	return 0
}

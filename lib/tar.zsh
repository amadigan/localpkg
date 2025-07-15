typeset -tAg lp_tar_paramargs=(
	[--strip-components]="--strip-components"
	[-C]=-C
	[--cd]=-C
	[--directory]=-C
	[--gid]=--gid
	[--gname]=--gname
	[--passphrase]=--passphrase
)

typeset -tUg lp_tar_exclude
typeset -tUg lp_tar_include
typeset -tUg lp_tar_options
typeset -tUg lp_tar_patterns
typeset -tag lp_tar_args

lp_install_reset() {
	lp_tar_exclude=("*LICENSE*" "*README*" "*CHANGELOG*" "*COPYING*")
	lp_tar_include=()
	lp_tar_options=()
	lp_tar_patterns=()
	lp_tar_args=("--strip-components" "1" "--safe-writes")
}

lp_install_reset

lp_prepare_tar_args() {
	private -A map_opts=()
	private arg arg2 argparam
	private optlist=""
	private root="${1}"
	shift

	private -a targs=()

	[[ "${#lp_tar_args}" -ne 0 ]] && targs+=("${lp_tar_args[@]}")
	[[ "${#@}" -ne 0 ]] && targs+=("${@}")

	for i in {1..${#targs[@]}}; do
		arg="${targs[i]}"
		
		if [[ "${arg}" == "--no-include" ]]; then
			lp_tar_include=()
		elif [[ "${arg}" == "--no-exclude" ]]; then
			lp_tar_exclude=()
		elif [[ "${arg}" == "--no-options" ]]; then
			lp_tar_options=()
		elif [[ "${arg}" == "--no-patterns" ]]; then
			lp_tar_patterns=()
		elif [[ "${#lp_tar_options}" -gt $((i + 1)) ]]; then
			arg2="${lp_tar_options[i + 1]}"

			if [[ "${arg}" == "--include" ]]; then
				lp_tar_include+=("${arg2}")
			elif [[ "${arg}" == "--exclude" ]]; then
				lp_tar_exclude+=("${arg2}")
			elif [[ "${arg}" == "--options" ]]; then
				lp_tar_options+=("${arg2}")
			elif [[ "${arg}" == "-s" ]]; then
				lp_tar_patterns+=("${arg2}")
			elif [[ -n "${lp_tar_paramargs[$arg]}" ]]; then
				map_opts[${lp_tar_paramargs[$arg]}]="${arg2}"
			else
				printf "%q\n" "${arg}" "${arg2}"
			fi

			(( i++ ))
		else
			printf "%q\n" "${arg}"
		fi
	done

	[[ ${#lp_tar_include} -ne 0 ]] && printf "--include\n%q\n" ${(@)lp_tar_include}
	[[ ${#lp_tar_exclude} -ne 0 ]] && printf "--exclude\n%q\n" ${(@)lp_tar_exclude}
	[[ ${#lp_tar_patterns} -ne 0 ]] && printf "-s\n%q\n" ${(@)lp_tar_patterns}

	optlist="${(j:,:)lp_tar_options}"
	[[ -n "${optlist}" ]] && printf "%q\n" "--options" "${optlist}"

	if [[ -n "${map_opts[-C]}" ]]; then
		root="${root}/${map_opts[-C]}"
		unset map_opts[-C]
		root="${root:a}"
	fi

	for arg argparam in "${(kv)map_opts[@]}"; do
		printf "%q\n" "${arg}" "${argparam}"
	done

	printf "%q\n" "-C" "${root}"
}

lp_install_download() {
	private downloaded_file="${1}"
	private -a tar_files
	private outname

	# if the downloaded file is a program, put it in /bin
	if lp_is_exec "${downloaded_file}"; then
		outname="bin/${lp_pkg[name]}"
		builtin mkdir -p "${LOCALPKG_PREFIX}/${outname:h}"
		builtin mv "${downloaded_file}" "${LOCALPKG_PREFIX}/${outname}"
		builtin chmod 755 "${LOCALPKG_PREFIX}/${outname}"
		printf "%q\n" "${outname}"

		return
	fi

	private -a tar_args=(${(fQ)"$(lp_prepare_tar_args "${LOCALPKG_PREFIX}")"}) || return 1

	lp_debug "tar_args (${#tar_args}): ${(@)tar_args}"

	private result
	
	if ! tar_files=("${(f)$(command -p bsdtar "-xvf" "${downloaded_file}" "${(@)tar_args}" 2>&1)}"); then
		lp_error "bsdtar failed: ${tar_files[1]}"
		return 1
	fi

	tar_files=("${(@)tar_files:#}")

	if [[ ${#tar_files} -eq 0 ]]; then
		lp_log "No files extracted, retrying with --strip-components 0"
		tar_args+=(--strip-components 0)

		if ! tar_files=("${(f)$(command -p bsdtar "-xvf" "${downloaded_file}" "${(@)tar_args}" 2>&1)}"); then
			lp_error "bsdtar failed: ${tar_files[1]}"
			return 1
		fi

		tar_files=("${(@)tar_files:#}")

		if [[ ${#tar_files} -eq 0 ]]; then
			lp_error "No files extracted"
			return 1
		fi
	fi

	lp_debug "tar_files: ${#tar_files} ${(@)tar_files}"

	private fname
	for fname in "${(@)tar_files}"; do
		fname="${fname:2}"
		if [[ -f "${LOCALPKG_PREFIX}/${fname}" ]]; then
			if [[ "${fname}" != */* && -x "${LOCALPKG_PREFIX}/${fname}" ]]; then
				lp_debug "Moving ${fname} to /bin"
				builtin mkdir -p "${LOCALPKG_PREFIX}/bin"
				builtin mv "${LOCALPKG_PREFIX}/${fname}" "${LOCALPKG_PREFIX}/bin/${fname}"
				fname="bin/${fname}"
			fi
			lp_installed_files+=("${fname}")
		fi
	done

	return 0
}

lp_is_exec() {
	private fname="${1}"
	private fd fmagic

	sysopen -r -u fd "${fname}" || return 1
	if ! sysread -i "${fd}" -s 4 fmagic; then
		exec {fd}<&-
		return 1
	fi
	exec {fd}<&-

	# check for short shebang
	[[ "${fmagic:0:3}" == "#!/"  ]] && return 0

	private -a exec_magics=(
		"#! /" # shebang
		$'\x7fELF' # ELF
		$'\xCA\xFE\xBA\xBE' # Mach-O Universal
		$'\xCF\xFA\xED\xFE' # Mach-O 64-bit
		$'\xCE\xFA\xED\xFE' # Mach-O 32-bit
	)

	[[ " ${exec_magics[@]} " == *" ${fmagic} "* ]]
}

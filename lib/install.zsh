

lp_download_file() {
	local url="${1}"
	local dest="${2}"

	lp_log "Downloading ${url}"
	curl -H "Accept: application/octet-stream" -sL "${url}" -o "${dest}"
	local result=${?}
	lp_log "curl exited with code ${result}"

	return ${result}
}

lp_install_pkg() {
	lp_mktemp
	local tmp_dir="${lpr_tmp_dir}"
	local filename="${lp_pkg_filename:-pkg}"

	lp_download_file "${lp_pkg_url}" "${tmp_dir}/${filename}"
	local result=${?}
	[[ ${result} -ne 0 ]] && return ${result}

	lp_install_download "${tmp_dir}/${filename}"
	result=${?}

	return ${result}
}

lp_install_download() {
	local downloaded_file="${1}"

	typeset -ga lp_pkg_files=()
	if lp_is_exec "${downloaded_file}"; then
		zf_mkdir -p "${LOCALPKG_PREFIX}/bin"
		zf_mv "${downloaded_file}" "${LOCALPKG_PREFIX}/bin/${lp_pkg_name}"
		zf_chmod 755 "${LOCALPKG_PREFIX}/bin/${lp_pkg_name}"
		lp_pkg_files+=("bin/${lp_pkg_name}")

		return 0
	fi

	local tar_args=("-xvf" "${downloaded_file}" "-C" "${LOCALPKG_PREFIX}" "${lp_tar_args[@]}")
	local -a tar_files=("${(f)$(bsdtar "${tar_args[@]}" 2>&1)}")
	local bsdtar_status=${?}

	if [[ ${bsdtar_status} -ne 0 ]]; then
		echo "bsdtar failed with code ${bsdtar_status}: ${output}"
		return ${bsdtar_status}
	fi

	local fname
	for fname in "${tar_files[@]}"; do
		fname="${fname:2}"
		[[ -f "${LOCALPKG_PREFIX}/${fname}" ]] && lp_pkg_files+=("${fname}")
	done

	return 0
}

lp_postinstall() {
	local prefix="${1}"
	# default postinstall - look for executables in the root and move them to bin

	typeset -p lp_pkg_files
	for i in {1..${#lp_pkg_files[@]}}; do
		local fname="${lp_pkg_files[i]}"

		if [[ "${fname}" != */* && -x "${prefix}/${fname}" ]]; then
			zf_mkdir -p "${prefix}/bin"
			zf_mv "${prefix}/${fname}" "${prefix}/bin/${fname}"
			lp_pkg_files[i]="bin/${fname}"
		fi
	done
	set +x
}

lp_is_exec() {
	local fname="${1}"
	local fd

	if ! sysopen -r -u fd "${fname}"; then
		return 1
	fi

	local fmagic

	sysread -i "${fd}" -s 4 fmagic
	exec {fd}<&-

	# check for short shebang
	[[ "${fmagic:0:3}" == "#!/"  ]] && return 0

	local -a exec_magics=(
		"#! /" # shebang
		$'\x7fELF' # ELF
		$'\xCA\xFE\xBA\xBE' # Mach-O Universal
		$'\xCF\xFA\xED\xFE' # Mach-O 64-bit
		$'\xCE\xFA\xED\xFE' # Mach-O 32-bit
	)

	[[ " ${exec_magics[@]} " == *" ${fmagic} "* ]] && return 0

	return 1
}

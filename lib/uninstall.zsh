lp_create_uninstall() {
	# create the uninstall file at pkg/${pkg_name}
	local uninstall_file="${LOCALPKG_PREFIX}/pkg/${lp_pkg_name}"

	zf_mkdir -p "${LOCALPKG_PREFIX}/pkg"

	[[ -f "${uninstall_file}" ]] && rm -f "${uninstall_file}"

	{
		echo "#!/bin/zsh"
		echo "declare -A lpu_files=("

		local fname

		for fname in "${lp_pkg_files[@]}"; do
			if [[ -f "${LOCALPKG_PREFIX}/${fname}" ]]; then
				read csum size pfpath < <(cksum "${LOCALPKG_PREFIX}/${fname}")
        echo "  [\"${(q)fname}\"]=\"${csum} ${size}\""
			fi
		done

		echo ")"
		
		echo "if [[ \"\${#FUNCNAME[@]}\" == 0 ]]; then"
		typeset -pgx LOCALPKG_PREFIX
		if [[ -z "${lp_update_url}" && -n "${lp_gh_repo}" ]]; then
			# full libinstall
			xlp_transclude 1
		else
			# just the uninstaller
			local xlp_mod
			for xlp_mod in "${xlp_mods[@]}"; do
				echo "${xlp_mod}"
			done
			typeset -p lp_pkg_name lp_gh_repo lp_release lp_update_url
			type -f lp_uninstall lp_prune_dirs
		fi
		echo lp_uninstall \"\${@}\"
		echo fi
	} > "${uninstall_file}"

	chmod +x "${uninstall_file}"
}

lp_uninstall() {
	# this is the main for the uninstaller
	if ! cd "${LOCALPKG_PREFIX}"; then
		echo "Failed to change to ${LOCALPKG_PREFIX}"
		exit 1
	fi

	if [[ "${1}" == "remove" ]]; then
		local -aU lpu_top_dirs=("pkg")

		for fname in "${(k)lpu_files[@]}"; do
			lpu_top_dirs+=("${fname%%/*}")
			if [[ ! -f "${fname}" ]]; then
				echo "File not found: ${fname}"
				continue
			fi

			read csum size pfpath < <(cksum "${fname}")
			if [[ "${lpu_files[${fname}]}" != "${csum} ${size}" ]]; then
				echo "Checksum mismatch for ${fname}"
			else
				zf_rm -f "${fname}"
			fi
		done

		zf_rm -f "pkg/${lpu_pkg_name}"
		lp_prune_dirs "${lpu_top_dirs[@]}"

		exit
	elif [[ -n "${lp_update_url}" || -n "${lp_gh_repo}" ]]; then
		if [[ "${1}" == "update" ]]; then 
			[[ -n "${lp_update_url}" ]] && exec curl -sL "${lp_update_url}" | zsh -s update "${ZSH_SCRIPT}"

			# otherwise we have a GitHub repo
			lp_update_gh
		fi

		echo "Usage: ${lp_pkg_name} [remove|update]"
		echo "\tremove: uninstall ${lp_pkg_name}"
		echo "\tupdate: check for an update and install it"
	else
		echo "Usage: ${lp_pkg_name} [remove]"
		echo "\tremove: uninstall ${lp_pkg_name}"
	fi

	echo ""
	echo "${lp_pkg_name} ${lp_release} installed in ${LOCALPKG_PREFIX}"
	exit 1
}

lp_update_gh() {
	local current_release="${lp_release}"
	lp_release=latest

	if ! lp_init || [[ -z "${lp_release}"  ]]; then
		echo "unable to determine latest release for ${lpu_gh_repo}"
		exit 1
	fi

	if [[ "${lp_release}" == "${current_release}" ]]; then
		echo "Already at latest release ${current_release}"
		exit 0
	fi

	echo "Updating ${lp_pkg_name} from ${current_release} to ${lp_release}"
	lp_install_pkg
	lp_postinstall "${LOCALPKG_PREFIX}" "${lp_pkg_name}"

	lp_create_uninstall
	echo "Updated "${lp_pkg_name}" to ${lp_release}"
}

lp_prune_dirs() {
	local -a empty_dirs=()
	local target_dir
	for dir in "${@}"; do
		empty_dirs=("${dir}/"**/(ND^F))

		while [[ ${#empty_dirs[@]} -gt 0 ]]; do
			zf_rmdir "${empty_dirs[@]}" || break
			empty_dirs=("${dir}/"**/(ND^F))
		done
	done
}

# The manager module implements the manager script and its functionality.

typeset -tAg lp_pkg_files=()

lp_mgr_create() {
	private compress="${1:-0}"
	private mgr_file="${LOCALPKG_PREFIX}/pkg/${lp_pkg[name]}"
	builtin mkdir -p "${mgr_file:h}"
	[[ -f "${mgr_file}" ]] && builtin rm -f "${mgr_file}"
	(lp_mgr_build "${@}") > "${mgr_file}"
	builtin chmod 755 "${mgr_file}"

	echo "${mgr_file}"
}

lp_mgr_build() {
	cd "${LOCALPKG_PREFIX}"
	echo "#!/bin/zsh"
	
	private fname

	typeset -pgx LOCALPKG_PREFIX
	typeset -p lp_pkg
	local -A lp_pkg_files=()
	private -a real_files=()
	private linktarget hash 

	for fname in "${(@)lp_installed_files}"; do
		# if it's a symlink, the "hash" is the canonical path of the target
		if [[ -L "${fname}" ]]; then
			linktarget="$(builtin stat +link "${fname}")"
			lp_pkg_files[${fname}]="L${linktarget}"
		elif [[ -f "${fname}" ]]; then
			real_files+=("${fname}")
		fi
	done

	if [[ "${#real_files}" -gt 0 ]]; then
		lp_log "Calculating hashes for ${#real_files} files"
		command -p openssl dgst -r "-${lp_pkg[hashalg]}" "${(@)real_files}" | while read -r hash fname; do
			fname="${fname##\*}"
			lp_pkg_files[${fname}]="${hash}"
		done
	fi

	typeset -p lp_pkg_files
	unset lp_pkg_files
	xlp_transclude

	echo "lp_mgr_main \"\${@}\"\nexit\n"
}

lp_mgr_main()	{
	lp_boot
	lp_manager_init
	exec 0<&-

	if [[ -z "${1}" ]]; then
		private arg0="${ZSH_ARGZERO:-${lp_pkg[name]}}"
		arg0="${arg0/$HOME/~}"

		echo "$(lp_mgr_name) installed in ${LOCALPKG_PREFIX}"
		echo ""

		private -a bins=(${(fQ)"$(lp_mgr_listbins)"})
		if [[ ${#bins} -gt 0 ]]; then
			echo "Commands: ${(@)bins}"
			echo ""
		fi

		echo "To remove:"
		echo "\t${arg0} remove"
		echo ""
		echo "To update:"
		echo "\t${arg0} update"

		return 0
	fi

	lp_cmd lp_mgr_cmd "${@}"
}

lp_mgr_name()	{
	private name="${lp_pkg[name]}"
	[[ -n "${lp_pkg[release]}" ]] && name="${name} ${lp_pkg[release]}"
	[[ -n "${lp_pkg[repo]}" ]] && name="${name} (${lp_pkg[repo]})"
	echo "${name}"
}

lp_mgr_cmd()	{
	# root command, prints information about the package
	# options: --help, -h, --raw, -r
	# arguments: none

	private -A opts
	private prefix="${LOCALPKG_PREFIX/#$HOME/~}"

	zparseopts -D -E -K -A opts h -help r -raw

	if [[ -n "${opts[-r]}" || -n "${opts[--raw]}" ]]; then
		echo -E "prefix ${LOCALPKG_PREFIX}"
		for key val in "${(@kv)lp_pkg}"; do
			echo -E "${key} ${val}"
		done
		return 0
	fi
}

lp_mgr_cmd_help()	{
	private prefix="${LOCALPKG_PREFIX/#$HOME/~}"

	cat <<-EOF
	$(lp_mgr_name) installed in ${prefix}

	Usage: ${ZSH_SCRIPT:A:t} [options]

	Options:
	  -h, --help  Show this help message
	  -r, --raw   Print raw package information

	Subcommands:
	EOF

	lp_cmd_help lp_mgr_cmd
}

lp_mgr_cmd_remove() {
	# remove command, removes the package
	# options: --help, -h
	# arguments: none

	private -A opts

	zparseopts -D -E -K -A opts h -help f -force k -keep P -no-prune

	if [[ -v opts[-h] || -v opts[--help] ]]; then
		echo "Uninstall ${lp_pkg[name]}, retaining modified files by default"
		echo "Usage: ${ZSH_SCRIPT:A:t} remove [options]"
		echo ""
		echo "Options:"
		echo "  -h, --help   Show this help message"
		echo "  -f, --force  Remove files even if they have been modified since installation"
		echo "  -k, --keep   Keep this script if any files are left"
		echo "  -P, --no-prune  Do not prune empty directories"
		return 0
	fi

	private exit_code=0
	private force=0
	[[ -v opts[-f] || -v opts[--force] ]] && force=1
	private prune=1
	[[ -v opts[-P] || -v opts[--no-prune] ]] && prune=0
	lp_uninstaller ${prune} ${force} || exit_code=$?

	if (( ! exit_code )); then
		if [[ ! -v opts[-k] && ! -v opts[--keep] ]]; then
			builtin rm -f "${LOCALPKG_PREFIX}/pkg/${lp_pkg[name]}"
			builtin rmdir "${LOCALPKG_PREFIX}/pkg" 2>/dev/null
		else
			echo "Retaining manager script for ${lp_pkg[name]}"
		fi
		return 0
	fi

	return ${exit_code}
}

lp_uninstaller() {
	private leftovers=0
	private fname sum
	private prune="${1:-1}"
	private force="${2:-0}"
	private -aU dirs
	private -a real_files=()

	cd "${LOCALPKG_PREFIX}"

	for fname sum in "${(@kv)lp_pkg_files}"; do
		# top-level directory
		dirs+=("${fname%%/*}")

		[[ ! -f "${fname}" ]] && continue

		# if the sum starts with L then it's a symlink
		if (( force )); then
			builtin rm -f "${fname}"
		elif [[ "${sum}" == L* ]]; then
			sum="${sum#L}"
			if [[ -L "${fname}" && "${sum}" == "$(builtin stat +link "${fname}")" ]]; then
				builtin rm -f "${fname}"
			else
				(( leftovers++ ))
			fi
		else
			real_files+=("${fname}")
		fi
	done

	if [[ "${#real_files}" -gt 0 ]]; then
		command -p openssl dgst -r "-${lp_pkg[hashalg]}" "${(@)real_files}" | while read -r sum fname; do
			fname="${fname##\*}"

			if [[ "${sum}" == "${lp_pkg_files[${fname}]}" ]]; then
				builtin rm -f "${fname}"
			else
				lp_log "File ${fname} has been modified, not removing"
				(( leftovers++ ))
			fi
		done
	fi

	lp_postremove

	(( prune )) && lp_mgr_prune_dirs "${dirs[@]}"

	if (( leftovers )); then
		echo "Total remaining files: ${leftovers}"
	else
		echo "Package ${lp_pkg[name]} removed"
	fi
}

lp_mgr_cmd_list() {
	# list command, lists the files in the package
	# options: --help, -h
	# arguments: none

	private -A opts

	zparseopts -D -E -K -A opts h -help r -raw

	if [[ -v opts[-h] || -v opts[--help] ]]; then
		echo "List files in ${lp_pkg[name]}"
		echo "Usage: ${ZSH_SCRIPT:A:t} list [options]"
		echo ""
		echo "Options:"
		echo "  -h, --help  Show this help message"
		echo "  -r, --raw   Print raw package information"
		return 0
	fi

	private raw=0
	[[ -v opts[-r] || -v opts[--raw] ]] && raw=1

	for fname in "${(@k)lp_pkg_files}"; do
		if (( raw )); then
			printf '%s\t%s\n' "${lp_pkg_files[${fname}]}" "${fname}"
		else
			printf '%s\n' "${fname}"
		fi
	done
}

lp_mgr_cmd_update() {
	# update command, updates the package
	# options: --help, -h
	# arguments: version (optional)

	private -A opts

	zparseopts -D -E -K -A opts h -help

	if [[ -v opts[-h] || -v opts[--help] ]]; then
		echo "Update ${lp_pkg[name]}"
		echo "Usage: ${ZSH_SCRIPT:a:t} update [options] [version]"
		echo ""
		echo "Options:"
		echo "  -h, --help  Show this help message"
		return 0
	fi

	local -A lp_old_pkg=(${(kv)lp_pkg})
	local -A lp_pkg=(${(kv)lp_old_pkg})

	lp_unset "lp_pkg[package_url]" "lp_pkg[package]" "lp_pkg[package_hash]" "lp_pkg[content_type]" "lp_pkg[effective_url]" \
		"lp_pkg[etag]" "lp_pkg[last_modified]" "lp_pkg[filename]" "lp_pkg[download_hash]"
		
	lp_pkg[release]="${1}"

	lp_launch_installer -u "${ZSH_SCRIPT:A}" # this won't return if there's an installer
	lp_installer
}

lp_mgr_prune_dirs() {
	private -a empty_dirs=()
	private target_dir
	for dir in "${@}"; do
		empty_dirs=("${dir}/"**/(ND^F))

		while [[ ${#empty_dirs[@]} -gt 0 ]]; do
			builtin rmdir "${empty_dirs[@]}" || break
			empty_dirs=("${dir}/"**/(ND^F))
		done
	done
}

lp_mgr_listbins() {
	# list files in the package that are executable and on the PATH
	cd "${LOCALPKG_PREFIX}"
	private -A search_path

	private file

	for file in "${LOCALPKG_PREFIX}/bin/" "${(@)path}"; do
		[[ -d "${file}" ]] && search_path[${file:a}]="${file}"
	done

	for file in "${(@k)lp_pkg_files}"; do
		file="${file:a}"
		lp_debug "Checking ${file}"
		if [[ -x "${file}" && -n "${search_path[${file:h}]}" ]]; then
			printf '%q\n' "${file:t}"
		fi
	done

	return 0
}

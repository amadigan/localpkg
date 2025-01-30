lpcli_cmd_parse() {
	private -A opts=()
	
	zparseopts -D -E -A opts h -help -name:: -package::

	if [[ -v opts[-h] || -v opts[--help] ]]; then
		echo "Parse a release JSON file for package information"
		echo "Usage: ${ZSH_ARGZERO} parse [options] [file]"
		return 0
	fi

	local -A lp_pkg=()

	private key value

	for key value in "${(@kv)opts}"; do
		lp_pkg[${key#--}]="${value}"
	done

	typeset -p lp_pkg

	lp_github_load_release "${1}"

	lp_log Loaded release "${lp_pkg[release]}"

	if [[ ${#lp_release_files} -eq 0 ]]; then
		printf "No files found in release\n"
	else
		printf "Files found in release (%d):\n" ${#lp_release_files}
  	private file url

		for file url in ${(kv)lp_release_files}; do
			printf '%s: %s\n' "${file}" "${url}"
		done
	fi

	printf "Fields:\n"
	for file url in ${(kv)lp_pkg}; do
		printf '%s: %s\n' "${file}" "${url}"
	done

	printf 'Package file: %s\n' "$(lp_filter_release "${(@k)lp_release_files}")"
}

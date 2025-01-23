declare -t lpgh_release
declare -t lp_github_prefix="https://api.github.com/repos"

lp_init() {
	if [[ -n "${lp_gh_repo}" ]]; then
		lp_github_release
		lp_github_findpkg
	fi

	[[ -z "${lp_tar_args}" ]] && lp_tar_args=("${lp_default_tar_args[@]}")
	[[ -z "${lp_executable_types}" ]] && lp_executable_types=("${lp_default_executable_types[@]}")
}

lp_github_release() {
	# Attempts to set lp_pkg_url, lp_pkg_filename, lp_pkg_name, and lp_release based on the GitHub release
	lp_release="${lp_release:-latest}"

	local url="${lp_github_prefix}/${lp_gh_repo}/releases/${lp_release}"

	lp_log "Fetching ${url}"
	lpgh_release="$(curl -sL -H "Accept: application/vnd.github+json" "${url}")"
	local result=${?}
	lp_log "curl exited with code ${result}"
	if [[ ${result} -ne 0 ]]; then
		return ${result}
	fi

	lp_debug "Release: ${lpgh_release}"

	if [[ "${lpgh_release}" == "null" || -z "${lpgh_release}" ]]; then
		lp_debug "Failed to fetch release ${lp_release} for ${lp_gh_repo}"
		return 1
	fi

	local tag_name="$(echo -E "${lpgh_release}" | jq -r '.tag_name')"
	lp_release="${tag_name}"
}

lp_github_findpkg() {
	local -A lp_release_files=()

	local lp_pkg_urls=($(echo -E "${lpgh_release}" | jq -r '.assets[].url'))
	local lp_pkg_names=($(echo -E "${lpgh_release}" | jq -r '.assets[].name'))

	for i in {1..${#lp_pkg_urls[@]}}; do
		if [[ -z "${lp_pkg_file}" || "${lp_pkg_names[i]}" =~ ${lp_pkg_file} ]]; then
			lp_release_files["${lp_pkg_names[i]}"]="${lp_pkg_urls[i]}"
		fi
	done

	if [[ "${#lp_release_files[@]}" -eq 0 ]]; then
		lp_debug "No assets found for ${repo} ${tag_name}"
		return 1
	fi

	lp_debug lp_release_files: "${lp_release_files[@]}"

	lp_filter_release

	if [[ "${#lp_release_files[@]}" -gt 1 ]]; then
		lp_debug "Multiple assets found for ${repo} ${tag_name}: ${(k)lp_release_files}"

		return 1
	elif [[ "${#lp_release_files[@]}" -eq 0 ]]; then
		lp_debug "No assets found for ${repo} ${tag_name}"
		return 1
	else
		lp_debug "Asset found for ${repo} ${tag_name}: ${(k)lp_release_files}"
		local release_files=("${(k)lp_release_files}")
		lp_pkg_filename="${release_files[1]}"
		lp_pkg_url="${lp_release_files[${lp_pkg_filename}]}"
		[[ -z "${lp_pkg_name}" ]] && lp_pkg_name="${lp_gh_repo:t}"
	fi

	return 0
}

lp_filter_release() {
	if [[ "${#lp_release_files[@]}" -gt 1 ]]; then
		lp_filter_patterns '^.*\.asc$' '^.*\.*sum' '^.*\.sig$' '^.*\.sha256$' '^.*\.sha512$' '^.*\.sha1$' '^.*\.md5$' '^.*\.md5$' '^.*\.txt$'
		local -a os_names=()
		case "${OSTYPE}" in
			linux*)
				os_names=("${OSTYPE}" "linux")
				;;
			darwin*)
				os_names=("${OSTYPE}" "macos" "darwin")
				;;
			*)
				os_names=("${OSTYPE}")
				;;
		esac
		lp_scan_names "${os_names[@]}"

		lp_debug names after os scan: "${(k)lp_release_files[@]}"

		if [[ "${#lp_pkg_urls[@]}" -gt 1 ]]; then
			local -a arch_names=()
			case "${CPUTYPE}" in
				amd64|x86_64)
					arch_names=("amd64" "x86_64")
					;;
				aarch64|arm64)
					arch_names=("arm64" "aarch64")
					;;
				*)
					arch_names=("${CPUTYPE}")
					;;
			esac
			lp_scan_names "${arch_names[@]}"
		fi

		lp_debug names after platform scan: "${(k)lp_release_files[@]}"

		if [[ "${#lp_pkg_urls[@]}" -gt 1 ]]; then
			lp_scan_ext '^.*\.tar\.gz$' '^.*\.tar\.xz$' '^.*\.tar\.bz2$' '^.*\.tgz$' '^.*\.tar$' '^.*\.zip$'
		fi

		lp_debug names after ext scan: "${(k)lp_release_files[@]}"
	fi
}

lp_scan_names() {
  local -A new_release_files=()
	local tag

  for tag in "${@}"; do
    local regex="(^|[^a-zA-Z])${(L)tag}([^a-zA-Z]|$)"

		local rfname

		for rfname in ${(k)lp_release_files}; do
			if [[ "${(L)rfname}" =~ ${regex} ]]; then
				new_release_files["${rfname}"]="${lp_release_files[${rfname}]}"
			fi
		done

		if [[ "${#new_release_files[@]}" -gt 0 ]]; then
			lp_release_files=("${(@kv)new_release_files}")

			return
		fi
  done
}

lp_scan_ext() {
	local fname

	for ext in "${@}"; do
		local -A new_release_files=()

		for fname in "${(k)lp_release_files}"; do
			if [[ "${fname}" =~ ${ext} ]]; then
				new_release_files["${fname}"]="${lp_release_files[${fname}]}"
			fi
		done

		if [[ "${#new_release_files[@]}" -gt 0 ]]; then
			lp_release_files=("${(@kv)new_release_files}")

			return
		fi
	done
}

lp_filter_patterns() {
	local fname

	for fname in "${(k)lp_release_files}"; do
		for pattern in "${@}"; do
			if [[ "${fname}" =~ ${pattern} ]]; then
				unset "lp_release_files[${fname}]"
			fi
		done
	done
}


lp_installer_main() {
	lp_boot
	lp_installer_init

	if [[ -z "${lp_pkg[hashalg]}" ]]; then
		lp_pkg[hashalg]="sha256"
		lp_pkg[package_hash]=""
	fi

	[[ -z "${lp_pkg[name]}" && -n "${lp_pkg[repo]}" ]] && lp_pkg[name]="${lp_pkg[repo]:t}"
	if [[ -z "${lp_pkg[name]}" ]]; then
		lp_error "Package name not set"
		return 1
	fi
	[[ "${lp_pkg[release]:-latest}" == "latest" ]] && lp_pkg[release]=""

	# this is the main for the installer script, typically executed directly from GitHub via curl | zsh
	# also executed by the manager script with -u MANAGER_SCRIPT

	private name="${lp_pkg[name]}"
	[[ -n "${lp_pkg[release]}" ]] && name="${name} ${lp_pkg[release]}"
	[[ -n "${lp_pkg[repo]}" ]] && name="${name} (${lp_pkg[repo]})"

	private -A opts=()

	zparseopts -D -E -A opts h -help u: -update: -file:: -download::

	if [[ -v opts[-h] || -v opts[--help] ]]; then
		echo "Install ${name}"
		echo "Usage: "${ZSH_ARGZERO}" [options]"
		echo ""
		echo "Options:"
		echo "  -h, --help    Show this help message"
		echo "  -u, --update [SCRIPT] Update an existing installation"

		return 0
	fi

	[[ -v opts[--file] ]] && lp_pkg[package_url]="file://${opts[--file]:a}"
	[[ -v opts[--download] ]] && lp_pkg[download_to]="${opts[--download]:a}"

	private manager_script="${opts[-u]:-${opts[--update]}}"

	if [[ -z "${manager_script}" || ! -x "${manager_script}" ]]; then
		manager_script="${LOCALPKG_PREFIX}/pkg/${lp_pkg[name]}"
		[[ ! -x "${manager_script}" ]] && manager_script=""
	fi

	local -A lp_old_pkg

	private key value

	if [[ -x "${manager_script}" ]]; then
		"${manager_script}" -r | while read -r key value; do
			lp_old_pkg[${key}]="${value}"
		done

		if lp_version_check; then
			lp_log "Package ${lp_pkg[name]} ${lp_pkg[release]} is already installed"
			return 0
		fi
	fi

	lp_installer "${manager_script}"
}

lp_version_check() {
	[[ -v lp_old_pkg && -n "${lp_old_pkg[release]}" && "${lp_old_pkg[release]}" == "${lp_pkg[release]}" ]]
}

lp_installer() {
	lp_pkg_files=()
	local lp_mktemp_dir
	lp_mktempdir
	local tmpdir="${lp_mktemp_dir}"
	{
		unset lp_mktemp_dir
		local outfile

		if [[ -z "${lp_pkg[package_url]}" ]]; then
			if [[ -z "${lp_pkg[release]}" && -n "${lp_pkg[latest_package_url]}" ]]; then
				lp_pkg[package_url]="${lp_pkg[latest_package_url]}"
			else
				lp_fetch_release # hook
				if lp_version_check; then
					lp_log "Package ${lp_pkg[name]} ${lp_pkg[release]} is already installed"

					return 0
				fi
			fi
		fi

		# lp_fetch_release may set lp_pkg[package_url] or outfile
		[[ -z "${outfile}" && -z "${lp_pkg[package_url]}" && -n "${lp_pkg[repo]}" ]] && lp_installer_github
		# lp_installer_github may set lp_pkg[package_url] or outfile
		[[ -n "${lp_pkg[package_url]}" && -z "${outfile}" ]] && lp_fetch_pkg_curl

		if [[ -z "${outfile}" || ! -f "${outfile}" ]]; then
			lp_error "Unable to determine package URL"
			return 1
		fi

		if [[ -n "${lp_pkg[download_to]}" ]]; then
			lp_log "Downloading ${lp_pkg[package_url]} to ${lp_pkg[download_to]}"
			builtin mv "${outfile}" "${lp_pkg[download_to]}"
			return 0
		fi

		if ! lp_pkg[download_hash]="$(lp_hash_file "${lp_pkg[hashalg]}" "${outfile}")"; then
			lp_error "Failed to hash package"
			return 1
		fi

		if [[ -n "${lp_pkg[package_hash]}" && "${lp_pkg[download_hash]}" != "${lp_pkg[package_hash]}" ]]; then
			lp_error "Package hash mismatch: ${lp_pkg[download_hash]} != ${lp_pkg[package_hash]}"
			return 1
		fi

		if [[ -v lp_old_pkg && "${lp_old_pkg[download_hash]}" == "${lp_pkg[download_hash]}" ]]; then
			lp_log "Package ${lp_pkg[name]} ${lp_pkg[release]} is already installed (hash match)"

			return 0
		fi

		lp_install_download "${outfile}" # adds files to lp_installed_files
		lp_skeleton
		lp_postinstall

		if [[ -n "${1}" ]]; then
			# query the old manager script for the package files and remove files that are no longer needed
			private -A old_files=()
			private -A new_files=()
			private value key hash fname

			for fname in "${(@)lp_installed_files}"; do
				new_files[${fname}]=1
			done

			command "${1}" list -r | while read -r value key; do
				if [[ ! -v new_files[${key}] ]]; then
					if [[ "${value}" == "L"* ]]; then
						if [[ -L "${LOCALPKG_PREFIX}/${key}" ]]; then
							hash="$(builtin stat +link "${LOCALPKG_PREFIX}/${key}")"
							if [[ "${value}" == "L${hash}" ]]; then
								lp_log "Removing outdated file ${key}"
								builtin rm -f "${LOCALPKG_PREFIX}/${key}"
							fi
						fi
					elif [[ -f "${LOCALPKG_PREFIX}/${key}" ]]; then
						old_files[${key}]="${value}"
					fi
				fi
			done

			if [[ ${#old_files} -gt 0 ]]; then
				command -p openssl dgst -r "-${lp_old_pkg[hashalg]}" "${(@k)old_files}" | while read -r hash fname; do
					fname="${fname##\*}"
					if [[ "${old_files[${fname}]}" == "${hash}" ]]; then
						lp_log "Removing outdated file ${fname}"
						builtin rm -f "${LOCALPKG_PREFIX}/${fname}"
					else
						lp_log "Outdated file ${fname} has changed, not removing"
					fi
				done
			fi
		fi

		private mgr="$(lp_mgr_create)" || return 1
		command "${mgr}"
	} always {
		builtin rm -rf "${tmpdir}" 2>/dev/null || true
	}
}

lp_fetch_pkg_curl() {
	# download the package directly
	private -a curl_args=()

	if [[ -n "${lp_pkg[package]}" ]]; then
		outfile="${tmpdir}/${lp_pkg[package]}"
		curl_args+=("--output" "${outfile}")
	else
		curl_args+=(--output-dir "${tmpdir}")
	fi

	if [[ -v lp_old_pkg ]]; then
		if [[ -n "${lp_old_pkg[etag]}" ]]; then
			curl_args+=("--header" "If-None-Match: ${lp_old_pkg[etag}")
		elif [[ -n "${lp_old_pkg[last_modified]}" ]]; then
			curl_args+=("--header" "If-Modified-Since: ${lp_old_pkg[last_modified}")
		fi
	fi

	private -A fetch_info=()
	private key value

	lp_log "Downloading ${lp_pkg[package_url]}"

	lp_curl_file "${(@)curl_args}" "${lp_pkg[package_url]}" | while read -r key value; do
		lp_debug "fetch_info[${key}] = ${value}"
		fetch_info[${key}]="${value}"
	done

	if [[ -n "${fetch_info[errormsg]}" ]]; then
		lp_error "Failed to download ${lp_pkg[package_url]}: ${fetch_info[errormsg]}"
		return 1
	elif [[ "${fetch_info[http_code]}" == "304" ]]; then
		lp_log "Package ${lp_pkg[name]} ${lp_pkg[release]} is already installed"
		return 0
	fi

	[[ -z "${outfile}" ]] && outfile="${fetch_info[filename_effective]}"

	lp_pkg[content_type]="${fetch_info[content_type]}"
	lp_pkg[effective_url]="${fetch_info[url_effective]}"
	lp_pkg[etag]="${fetch_info[etag]}"
	lp_pkg[last_modified]="${fetch_info[last_modified]}"
	lp_pkg[filename]="${outfile:t}"

	lp_log "Downloaded ${outfile:t}"
}

lp_installer_github() {
	private package="${lp_pkg[package]}" # default to the package file name specified in the package definition

	if [[ -z "${lp_pkg[release]}" ]]; then
		# installing latest, look up version
		package="${package:-${lp_pkg[latest_package]}}"

		if [[ -v lp_old_pkg ]]; then
			lp_github_load_release

			if lp_version_check; then
				lp_log "Package ${lp_pkg[name]} ${lp_pkg[release]} is already installed"

				return 0
			fi
		fi
	fi

	if [[ -z "${package}" ]]; then
		lp_github_load_release

		if ! package="$(lp_filter_release ${(k)lp_release_files})"; then
			if [[ -n "${package}" ]]; then 
				lp_error "Multiple files found in release: ${package}"
				return 1
			else
				lp_error "No package found in release"
				return 1
			fi

			return 1
		fi
		
		if [[ "${package}" == *://* ]]; then
			lp_pkg[package_url]="${package}"

			return 0
		fi
	fi

	lp_pkg[package]="${package}"

	if lp_github_use_gh; then
		lp_log "Downloading ${package} from ${lp_pkg[repo]} ${lp_pkg[release]} using gh"
		outfile="${tmpdir}/${package}"
		command gh release download "${lp_pkg[release]}" --repo "${lp_pkg[repo]}" --output "${outfile}" --pattern "${package}"
	elif [[ -v lp_release_files ]]; then
		lp_pkg[package_url]="${lp_release_files[${package}]}"
	else
		lp_pkg[package_url]="${lp_github_url}/${lp_pkg[repo]}/releases/download/${lp_pkg[release]}/${package}"
	fi
}

lp_launch_installer() {
	private name="${lp_pkg[installer]}"
	private url="${lp_pkg[installer_url]}"

	[[ -z "${lp_pkg[repo]}" && -z "${url}" ]] && return 0

	if [[ -z "${url}" ]]; then
		if [[ -z "${lp_pkg[release]}" && -v lp_old_pkg ]]; then
			# if we have an old package, we can check if the release is the same
			lp_github_load_release

			if lp_version_check; then
				lp_log "${lp_pkg[name]} ${lp_pkg[release]} is already installed"

				return 0
			fi
		fi

		if [[ -z "${name}" ]]; then
			lp_github_load_release

			name="$(lp_filter_findinstaller ${(k)lp_release_files})"
			url="${lp_release_files[${name}]}"

			if [[ -z "${url}" && "${name}" == *://* ]]; then
				url="${name}"
				name=""
			fi
		elif [[ -z "${lp_pkg[release]}" ]]; then
			url="${lp_github_url}/${lp_pkg[repo]}/releases/latest/download/${name}"
		else
			url="${lp_github_url}/${lp_pkg[repo]}/releases/download/${lp_pkg[release]}/${name}"
		fi
	fi

	if [[ -n "${name}" ]]; then
		[[ -z "${url}" ]] && lp_installer_exec_gh "${name}" "${@}"
		lp_github_use_gh && lp_installer_exec_gh "${name}" "${@}"
	else
		name="${lp_pkg[name]}"
	fi

	if [[ -n "${url}" ]]; then
		lp_log "Running installer for ${lp_pkg[repo]} ${lp_pkg[release]}"
		lp_installer_exec "${name}" "${url}" "${@}"
	fi

	return 0
}

lp_installer_exec() {
	private name="${1}"
	private url="${2}"
	shift 2

	lp_curl_plain --location --header 'Accept: application/octet-stream' "${url}" | exec -a "${name}" zsh -s "${@}"
}

lp_installer_exec_gh() {
	private name="${1}"
	if lp_github_use_gh; then
		private -a gh_args=( "release" "download" )
		if [[ -n "${lp_pkg[release]}" ]]; then 
			lp_log "Fetching installer for ${lp_pkg[repo]} ${lp_pkg[release]} with gh"
			gh_args+=( "${lp_pkg[release]}" )
		else
			lp_log "Fetching installer for ${lp_pkg[repo]} with gh"
		fi
		gh_args+=( "--repo" "${lp_pkg[repo]}" "--pattern" "${name}" --output - )
		command gh "${gh_args[@]}" | exec -a "${name}" zsh -s "${@}"
	elif [[ -v lp_release_files ]]; then
		lp_log "Fetching ${name} for ${lp_pkg[repo]} ${lp_pkg[release]}"
		lp_installer_exec "${name}" "${lp_release_files[${name}]}" "${@}"
	elif [[ -n "${lp_pkg[release]}" ]]; then
		lp_log "Fetching ${name} for ${lp_pkg[repo]} ${lp_pkg[release]}"
		lp_installer_exec "${name}" "${lp_github_url}/${lp_pkg[repo]}/releases/download/${lp_pkg[release]}/${name}" "${@}"
	else
		lp_log "Fetching ${name} for ${lp_pkg[repo]}"
		lp_installer_exec "${name}" "${lp_github_url}/${lp_pkg[repo]}/releases/latest/download/${name}" "${@}"
	fi
}

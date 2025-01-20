#!/bin/zsh
LOCALPKG_PREFIX="${LOCALPKG_PREFIX:="${HOME}/.local"}"

lp_debug() {
	if [[ -n "${LOCALPKG_DEBUG}" ]]; then
		echo "${@}" >&2
	fi
}

lp_debug "Running zsh version: $ZSH_VERSION"

lp_install_pkg() {
	local pkg_url="${1}"
	local pkg_name="${2}"
	local version="${3}"
	local tmp_dir="$(mktemp -d -t localpkg.${pkg_name}.XXXXXXXXXX)"

	local pkg_path="${tmp_dir}/pkg"

	curl -H "Accept: application/octet-stream" -sL "${pkg_url}" -o "${pkg_path}"

	local tar_args=("-xvf" "${pkg_path}" "-C" "${LOCALPKG_PREFIX}")
	tar_args+=("${lp_tar_args[@]}")

	local output
	output="$(bsdtar "${tar_args[@]}" 2>&1)"
	local bsdtar_status=${?}
	rm -rf "${tmp_dir}"

	if [[ ${bsdtar_status} -ne 0 ]]; then
		echo "bsdtar failed with code ${bsdtar_status}: ${output}"
		return ${bsdtar_status}
	fi

	declare -a lp_pkg_dirs=("pkg")
	local -a csums

	declare -a lp_pkg_files

	while IFS= read -r line; do
		local fname="${line:2}"
		local fdir="${fname%%/*}"

		if [[ ! " ${lp_pkg_dirs[@]} " =~ " ${fdir} " ]]; then
			lp_pkg_dirs+=("${fdir}")
		fi

		if [[ -f "${LOCALPKG_PREFIX}/${fname}" ]]; then
			read csum size pfpath < <(cksum "${LOCALPKG_PREFIX}/${fname}")
			csums+=("${csum} ${size}")

			# check for executables in root of package
			lp_debug "Checking ${fname} in ${fdir}"
			# check if fname does not contain /
			if [[ "${fdir}" == "${fname}" && -x "${LOCALPKG_PREFIX}/${fname}" ]]; then
				mkdir -p "${LOCALPKG_PREFIX}/bin"
				mv "${LOCALPKG_PREFIX}/${fname}" "${LOCALPKG_PREFIX}/bin"
				fname="bin/${fname:t}"
			fi

			lp_pkg_files+=("${fname}")
		fi
	done <<< "$output"

	# if lp_postinstall is defined, call it
	if declare -f lp_postinstall > /dev/null; then
		lp_postinstall "${LOCALPKG_PREFIX}" "${pkg_name}" "${version}"
	fi

	for i in {1..${#lp_pkg_dirs[@]}}; do
		if [[ -f "${LOCALPKG_PREFIX}/${fname}" ]]; then
			read csum size pfpath < <(cksum "${LOCALPKG_PREFIX}/${fname}")
			csums+=("${csum} ${size}")

			lp_debug "Checking ${fname} in ${fdir}"
			if [[ "${fdir}" == "${fname}" && -x "${LOCALPKG_PREFIX}/${fname}" ]]; then
				mkdir -p "${LOCALPKG_PREFIX}/bin"
				mv "${LOCALPKG_PREFIX}/${fname}" "${LOCALPKG_PREFIX}/bin"
				lp_pkg_files[i]="bin/${fname:t}"
			fi
		fi
	done

	# create the uninstall file at pkg/${pkg_name}
	local uninstall_file="${LOCALPKG_PREFIX}/pkg/${pkg_name}"

	mkdir -p "${LOCALPKG_PREFIX}/pkg"
	cat > "${uninstall_file}" <<EOF
#!/bin/zsh
lpu_files=(
EOF

	for file in "${pkg_files[@]}"; do
		echo "  \"${file}\"" >> "${uninstall_file}"
	done

	cat >> "${uninstall_file}" <<EOF
)
lpu_dirs=(
EOF

	for dir in "${lp_pkg_dirs[@]}"; do
		echo "  \"${dir}\"" >> "${uninstall_file}"
	done

	cat >> "${uninstall_file}" <<EOF
)
lpu_csums=(
EOF

	for csum in "${csums[@]}"; do
		echo "  \"${csum}\"" >> "${uninstall_file}"
	done

	cat >> "${uninstall_file}" <<EOF
)

lpu_pkg_name="${pkg_name}"
lpu_pkg_version="${version}"
lpu_pkg_url="${pkg_url}"

if [[ \${#FUNCNAME[@]} == 0 ]]; then
	cd "\${0:a:h}/.."

	if [[ "\${1}" != "remove" ]]; then
		echo "Usage: \${0} remove"
		echo "  Uninstalls \${lpu_pkg_name} \${lpu_pkg_version}"
		exit
	fi

	for ((i=1; i<=\${#lpu_files[@]}; i++)); do
    if [[ ! -f "\${lpu_files[i]}" ]]; then
      continue
    fi
    read csum size pfpath < <(cksum "\${lpu_files[i]}")
    if [[ "\${lpu_csums[i]}" != "\${csum} \${size}" ]]; then
      echo "Checksum mismatch for \${lpu_files[i]}"
    else
      rm -vf "\${lpu_files[i]}"
    fi
  done

	rm -vf "\${0}"

	for d in "\${lpu_dirs[@]}"; do
    find "\${d}" -type d -empty -delete
  done
fi
EOF

	chmod +x "${uninstall_file}"

	echo "Installed ${pkg_name} ${version} to ${LOCALPKG_PREFIX}"
}

lp_ensure_base() {
	mkdir -p "${LOCALPKG_PREFIX}/etc"

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/profile" ]]; then
		cat > "${LOCALPKG_PREFIX}/etc/profile" <<EOF
if [[ -n "\${_LOCALPKG_PROFILE_LOADED}" ]]; then
	return
fi

_LOCALPKG_PROFILE_LOADED=1

export PATH="${LOCALPKG_PREFIX}/bin:\${PATH}"
export MANPATH="${LOCALPKG_PREFIX}/share/man:\${MANPATH}"

if [ -d "${LOCALPKG_PREFIX}/etc/profile.d" ]; then
  for file in "${LOCALPKG_PREFIX}/etc/profile.d"/*.sh; do
    [ -r "\${file}" ] && . "\${file}"
  done
  unset file
fi
EOF
	fi

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/zshenv" ]]; then
		cat > "${LOCALPKG_PREFIX}/etc/zshenv" <<EOF
export PATH="${LOCALPKG_PREFIX}/bin:\${PATH}"

if [ -d "${LOCALPKG_PREFIX}/etc/zshenv.d" ]; then
	for file in "${LOCALPKG_PREFIX}/etc/zshenv.d"/*.zsh; do
		[ -r "\${file}" ] && . "\${file}"
	done
	unset file
fi
EOF
	fi

	if [[ ! -f "${LOCALPKG_PREFIX}/etc/zshrc" ]]; then
		cat > "${LOCALPKG_PREFIX}/etc/zshrc" <<EOF
MANPATH="${LOCALPKG_PREFIX}/share/man:\${MANPATH}"

if [ -d "${LOCALPKG_PREFIX}/etc/zshrc.d" ]; then
	for file in "${LOCALPKG_PREFIX}/etc/zshrc.d"/*.zsh; do
		[ -r "\${file}" ] && . "\${file}"
	done
	unset file
fi
EOF
	fi

	local prefix="${LOCALPKG_PREFIX/#$HOME/\${HOME\}}"

	lp_ensure_file_line "${HOME}/.zshenv" "[[ -r \"${prefix}/etc/zshenv\" ]] && source \"${prefix}/etc/zshenv\" # localpkg DO NOT EDIT"
	lp_ensure_file_line "${HOME}/.zshrc" "[[ -r \"${prefix}/etc/zshrc\" ]] && source \"${prefix}/etc/zshrc\" # localpkg DO NOT EDIT"
	lp_ensure_file_line "${HOME}/.bash_profile" "[[ -r \"${prefix}/etc/profile\" ]] && source \"${prefix}/etc/profile\" # localpkg DO NOT EDIT"
	lp_ensure_file_line "${HOME}/.bashrc" "[[ -r \"${prefix}/etc/profile\" ]] && source \"${prefix}/etc/profile\" # localpkg DO NOT EDIT"
}

lp_ensure_file_line() {
	local file="${1}"
	local line="${2}"

	if [[ ! -f "${file}" ]]; then
		echo Creating "${file}"
		echo "${line}" > "${file}"
		return
	fi

	if ! grep -qxF "${line}" "${file}"; then
		echo "Setting up ${file}"
		echo "${line}" >> "${file}"
	fi
}

lp_github_release() {
	local repo="${1}"
	local version="${2:-latest}"
	local pkg_name="${3}"

	local release="$(curl -sL -H "Accept: application/vnd.github+json" "https://api.github.com/repos/${repo}/releases/${version}")"

	if [[ "${release}" == "null" || -z "${release}" ]]; then
		lp_debug "Failed to fetch latest release for ${repo}"
		return 1
	fi

	local tag_name="$(echo -E "${release}" | jq -r '.tag_name')"

	local lp_pkg_urls=($(echo -E "${release}" | jq -r '.assets[].url'))
	local lp_pkg_names=($(echo -E "${release}" | jq -r '.assets[].name'))

	if [[ -n "${pkg_name}" ]]; then
		local -a new_urls
		local -a new_names

		for i in {1..${#lp_pkg_urls[@]}}; do
			lp_debug "Checking ${lp_pkg_names[i]}" against "${pkg_name}"
			if [[ "${lp_pkg_names[i]}" =~ ${pkg_name} ]]; then
				new_urls+=("${lp_pkg_urls[i]}")
				new_names+=("${lp_pkg_names[i]}")
			fi
		done

		lp_pkg_urls=("${new_urls[@]}")
		lp_pkg_names=("${new_names[@]}")
	fi

	if [[ "${#lp_pkg_urls[@]}" -eq 0 ]]; then
		lp_debug "No assets found for ${repo} ${tag_name}"
		return 1
	fi

	lp_debug names after name scan: "${lp_pkg_names[@]}"

	if [[ "${#lp_pkg_urls[@]}" -gt 1 ]]; then
		lp_filter_patterns '^.*\.asc$' '^.*\.*sum' '^.*\.sig$' '^.*\.sha256$' '^.*\.sha512$' '^.*\.sha1$' '^.*\.md5$' '^.*\.md5$' '^.*\.txt$'
		lp_scan_names "macos" "darwin"

		lp_debug names after os scan: "${lp_pkg_names[@]}"

		if [[ "${#lp_pkg_urls[@]}" -gt 1 ]]; then
			if [[ "${CPUTYPE}" == "x86_64" ]]; then
				lp_scan_names "amd64" "x86_64"
			else
				lp_scan_names "arm64" "aarch64"
			fi
		fi

		lp_debug names after platform scan: "${lp_pkg_names[@]}"

		if [[ "${#lp_pkg_urls[@]}" -gt 1 ]]; then
			lp_scan_ext '^.*\.tar\.gz$' '^.*\.tar\.xz$' '^.*\.tar\.bz2$' '^.*\.tgz$' '^.*\.tar$' '^.*\.zip$'
		fi

		lp_debug names after ext scan: "${lp_pkg_names[@]}"
	fi

	if [[ "${#lp_pkg_urls[@]}" -gt 1 ]]; then
		lp_debug "Multiple assets found for ${repo} ${tag_name}"
		for i in {1..${#lp_pkg_urls[@]}}; do
			lp_debug "${lp_pkg_names[i]}"
		done

		echo "${tag_name}"

		return 1
	fi

	echo "${tag_name}" "${lp_pkg_urls[1]}" "${lp_pkg_names[1]}" 
}

lp_scan_names() {
  local -a out_names
  local -a out_urls

  for tag in "${@}"; do
    local regex="(^|[^a-zA-Z])${(L)tag}([^a-zA-Z]|$)"

		lp_debug regex: "${regex}"

    for i in {1..${#lp_pkg_urls[@]}}; do
			lp_debug "Checking ${lp_pkg_names[i]}"
      if [[ "${(L)lp_pkg_names[i]}" =~ ${regex} ]]; then
        out_names+=("${lp_pkg_names[i]}")
        out_urls+=("${lp_pkg_urls[i]}")
      fi
    done

    if [[ "${#out_urls[@]}" -gt 0 ]]; then
			lp_debug "Found ${#out_urls[@]} assets for ${tag}"
      break
    else
			lp_debug "No assets found for ${tag}"
		fi
  done

  if [[ "${#out_names[@]}" -gt 0 ]]; then
    lp_pkg_names=("${out_names[@]}")
    lp_pkg_urls=("${out_urls[@]}")
  fi
}

lp_scan_ext() {
	local -a exts=("${@}")

	local -a out_names
	local -a out_urls

	for ext in "${exts[@]}"; do
		for i in {1..${#lp_pkg_names[@]}}; do
			lp_debug "Checking ${lp_pkg_names[i]}" against "${ext}"
			if [[ "${lp_pkg_names[i]}" =~ ${ext} ]]; then
				lp_debug "Matched ${lp_pkg_names[i]}"
				out_names+=("${lp_pkg_names[i]}")
				out_urls+=("${lp_pkg_urls[i]}")
			fi
		done

		if [[ "${#out_names[@]}" -gt 0 ]]; then
			break
		fi
	done

	if [[ "${#out_names[@]}" -gt 0 ]]; then
		lp_pkg_names=("${out_names[@]}")
		lp_pkg_urls=("${out_urls[@]}")
	fi
}

lp_filter_patterns() {
	local -a patterns=("${@}")

	local -a out_names
	local -a out_urls

	for pattern in "${patterns[@]}"; do
		for i in {1..${#lp_pkg_names[@]}}; do
			if [[ ! "${lp_pkg_names[i]}" =~ ${pattern} ]]; then
				out_names+=("${lp_pkg_names[i]}")
				out_urls+=("${lp_pkg_urls[i]}")
			fi
		done
	done

	lp_pkg_names=("${out_names[@]}")
	lp_pkg_urls=("${out_urls[@]}")
}

lp_main() {
	# parse options
	while getopts "n:v:" opt; do
		case ${opt} in
			n)
				lp_pkg_name="${OPTARG}"
				;;
			v)
				lp_pkg_version="${OPTARG}"
				;;
			\?)
				lp_usage
				exit 1
				;;
		esac
	done

	shift $((OPTIND - 1))

	if [[ "${1}" =~ ^.*://.*$ ]]; then
		lp_pkg_url="${1}"
		lp_pkg_file="${1}"
	elif [[ -z "${lp_pkg_url}" ]]; then
		if [[ -z "${lp_gh_repo}" ]]; then
			lp_gh_repo="${1}"
		fi

		read -r lp_pkg_version lp_pkg_url lp_pkg_file < <(lp_github_release "${lp_gh_repo}" "${lp_pkg_version}" "${lp_pkgfile_pattern}")
		if [[ "${?}" -ne 0 ]]; then
			echo "Failed to resolve package "${lp_gh_repo}""
			exit 1
		fi

		if [[ -z "${lp_pkg_name}" ]]; then
			lp_pkg_name="${1##*/}"
		fi
	else
		lp_usage
		exit 1
	fi

	if [[ -z "${lp_pkg_url}" ]]; then
		echo "Failed to resolve package "${lp_gh_repo}""
		exit 1
	fi

	echo "Installing ${lp_pkg_name} ${lp_pkg_version} from ${lp_pkg_file}"

	lp_ensure_base
	lp_install_pkg "${lp_pkg_url}" "${lp_pkg_name}" "${lp_pkg_version}"
}

lp_usage() {
	echo "Usage: ${0} <pkg_url> [-n <pkg_name>] [-v <version>]"
}

if [[ "${#FUNCNAME[@]}" == 0 ]]; then
	if [[ -z "${lp_pkg_name}" ]]; then
		lp_tar_args=("--strip-components" "1" "--exclude" '*LICENSE*' "--exclude" '*README*' "--exclude" '*CHANGELOG*' "--exclude" '*COPYING*')
	fi

	lp_main "${@}"
fi

typeset -tg lpcli_localpkg_repo="${GITHUB_REPOSITORY}"
typeset -tg lpcli_localpkg_release="${RELEASE_TAG}"
typeset -tg lpcli_github_root="https://github.com"
typeset -tAg lpcli_aliases=()

lpcli_add_help() {
  echo "Install one or more packages"
  echo "Usage: ${lpcli_arg0} add [options...] [alias|[alias:]owner/repo[@release]]..."
  echo ""
  echo "Options:"
  echo "  -h, --help  Show this help message"
  echo "  -f, --file  Use the specified package file instead of downloading"
  echo "  -a, --alias Use the specified alias instead of the package name"
  echo "  -z, --compress Compress the manager script"
}


lpcli_cmd_add() {
  # add subcommand
  # install packages locally
  # spec: [alias:]owner/repo[@release] or just alias
  local -A add_options=()

  zparseopts -D -E -A add_options h -help f:: -file:: -alias:: z -compress -release:: -download::

  if [[ -v add_options[-h] || -v add_options[--help] ]]; then
    lpcli_add_help
    return 0
  fi

  if [[ -z "${1}" ]]; then
    lp_log "No packages specified"
    lpcli_add_help
    return 1
  fi

  lp_load_aliases "${LOCALPKG_PREFIX}/pkg/aliases.sh" || true


  private -a match
  local -A lp_pkg=()

  if [[ "${#@}" -lt 2 ]]; then
    lp_pkg[name]="${add_options[--alias]}"

    if [[ -n "${lp_pkg[name]}" && "${1}" == *://* ]]; then
      lp_pkg[latest_package_url]="${1}"

      lp_skeleton
      lpcli_add_pkg
      return
    fi

    lp_pkg[release]="${add_options[--release]}"
  fi

  private pkg
  private skeleton=0
  
  for pkg in "${@}"; do
    # check for alias: prefix
    if [[ "${pkg}" =~ ^([^:]+):(.+)$ ]]; then
      lp_pkg[name]="${match[1]}"
      pkg="${match[2]}"
    fi

    # check for @release suffix
    if [[ "${pkg}" =~ ^([^@]+)@(.+)$ ]]; then
      pkg="${match[1]}"
      lp_pkg[release]="${match[2]}"
    fi

    if [[ "${pkg}" =~ ^[^/]+/([^/]+)/([^/]+)$ ]]; then
      lp_pkg[repo]="${match[1]}/${match[2]}"
      
      if [[ -n "${lp_pkg[name]}" || "${match[3]}" == *.* ]]; then
        lp_pkg[package]="${match[3]}"
      elif [[ -z "${lp_pkg[name]}" ]]; then
        lp_pkg[name]="${match[3]}"
      else
        lp_pkg[package]="${match[3]}"
      fi
    elif [[ "${pkg}" =~ ^[^/]+/([^/]+)$ ]]; then
      lp_pkg[repo]="${pkg}"
      [[ -z "${lp_pkg[name]}" ]] && lp_pkg[name]="${match[1]}"
    elif [[ -n "${lp_pkg[name]}" ]]; then
      lp_error "Invalid package specification: ${pkg}"
      return 1
    else
      lp_pkg[name]="${pkg}"
    fi

    if (( ! skeleton )); then
      lp_skeleton
      skeleton=1
    fi

    lpcli_add_pkg

    lp_pkg=()
  done
}

lpcli_add_pkg() {
  lp_pkg[sfx]=0
  lp_pkg[hashalg]="sha256"

  # set sfx to true if compress option is set
  [[ -v add_options[-z] || -v add_options[--compress] ]] && lp_pkg[sfx]=1

  local outfile="${add_options[-f]:-${add_options[--file]}}"
  local tmpdir=""

  if [[ -z "${lp_pkg[package_url]}" && -z "${lp_pkg[release]}" && -n "${lp_pkg[lastest_package_url]}" ]]; then
    lp_pkg[package_url]="${lp_pkg[latest_package_url]}"
  fi

  private download="${add_options[--download]}"

  if [[ -z "${outfile}" ]]; then
    if [[ -z "${lp_pkg[package_url]}" && -z "${lp_pkg[repo]}" ]]; then
      if [[ -n "${lpcli_aliases[${lp_pkg[name]}]}" ]]; then
        private argstring="${lpcli_aliases[${lp_pkg[name]}]}"
        private add_args=("--alias" "${lp_pkg[name]}")
        [[ -n "${lp_pkg[release]}" ]] && add_args+=("--release" "${lp_pkg[release]}")
        [[ -n "${argstring}" ]] && add_args+=("${(z)argstring}")
        lpcli_cmd_add "${(@)add_args}"

        return
      elif [[ -n "${(k)functions[lpcli_builtin_${lp_pkg[name]}]}" ]]; then
        lpcli_builtin_${lp_pkg[name]}
        return
      else
        lp_error "Unrecognized package alias: ${lp_pkg[name]}"
        return 1
      fi
    fi

    local lp_mktemp_dir
	  lp_mktempdir
    tmpdir="${lp_mktemp_dir}"
    unset lp_mktemp_dir

    if [[ -z "${lp_pkg[package_url]}" ]]; then
      lp_github_load_release

      if [[ -n "${lp_pkg[package]}" ]]; then
        private pkgname="${lp_pkg[package]}"

        # special case, a spec like git:railyard-vm/git/git should check for git.localpkg first
        [[ -n "${lp_release_files[${pkgname}.localpkg]}" ]] && lp_installer_exec_gh "${pkgname}.localpkg"

        url="${lp_release_files[${pkgname}]}"
        if [[ -z "${url}" ]]; then
          lp_error "Failed to find package ${pkgname} in release"
          return 1
        fi

        if lp_github_use_gh; then
          lp_log "Downloading ${pkgname} from ${lp_pkg[repo]} ${lp_pkg[release]} using gh"
          outfile="${tmpdir}/${pkgname}"
          command gh release download "${lp_pkg[release]}" --repo "${lp_pkg[repo]}" --output "${outfile}" --pattern "${pkgname}"
        fi
      fi

      [[ -z "${download}" ]] && lp_launch_installer
      lp_installer_github
    fi

    [[ -z "${outfile}" && -n "${lp_pkg[package_url]}" ]] && lp_fetch_pkg_curl
  fi

  if [[ -z "${outfile}" ]]; then
    lp_error "Unable to determine package URL"
    return 1
  fi

  if [[ -n "${download}" ]]; then
    lp_log "Downloading ${outfile:t} to ${download}"
    builtin mv -f "${outfile}" "${download}"
    return 0
  fi

	lp_pkg[download_hash]=$(lp_hash_file "${lp_pkg[hashalg]}" "${outfile}")

  if [[ -v lp_old_pkg && -n "${lp_old_pkg[download_hash]}" == "${lp_pkg[download_hash]}" ]]; then
		lp_log "Package ${lp_pkg[name]} ${lp_pkg[release]} is already installed"

		return 0
	fi

	lp_install_download "${outfile}" || return 1 # adds files to lp_installed_files
  lp_log "Installed ${lp_pkg[name]} ${lp_pkg[release]}"
	[[ -n "${tmpdir}" ]] && builtin rm -f "${tmpdir}"
	unset tmpdir outfile
	lp_skeleton
	private mgr="$(lp_mgr_create)" || return 1
	command "${mgr}"

  return 0
}

lp_load_aliases() {
  [[ ! -r "${1}" ]] && return 1
  
  private alias args
  private -a arg_arr

  while read -r alias args; do
    lp_load_alias "${alias}" "${args}"
  done < "${1}"

  # handle last alias without trailing newline
  lp_load_alias "${alias}" "${args}"
}

lp_load_alias() {
  local alias="${1}"
  local -a arg_arr
  local args="${2}"

  [[ "${alias}" =~ ^# || -z "${alias}" ]] && return 0

  # if alias contains #, skip and log warning
  if [[ "${alias}" =~ ^.*#.*$ ]]; then 
    lp_log "Invalid alias: ${alias}"
    continue
  fi

  # split into array and look for args starting with #
  arg_arr=("${(Z+C+)args}")
  args="${arg_arr[*]}"

  lp_log debug "Adding alias: ${alias}=${args}"
  lpcli_aliases[${alias}]="${args}"
}

lp_load_aliases "${0:A:h}/aliases.sh" || lp_fatal "Failed to load ${0:A:h}/aliases.sh"

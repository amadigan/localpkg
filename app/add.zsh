declare -tL lpcli_localpkg_repo
declare -tL lpcli_localpkg_release

declare -aU lpcli_installer_names=(
	"localpkg-install" "localpkg-install.sh" "localpkg-install.zsh"
	"install-localpkg" "install-localpkg.sh" "install-localpkg.zsh"
	"localpkg" "localpkg.sh" "localpkg.zsh"
)

lpcli_builtin_localpkg() {
  # install localpkg itself
  lp_pkg_name="localpkg"
  lp_update_url=""

  [[ -n "${lpcli_localpkg_repo}" ]] && lp_update_url="https://github.com/${lpcli_localpkg_repo}/releases/latest/download/localpkg"

  lp_pkg_files=("bin/localpkg")
  lpcli_build_self "${LOCALPKG_PREFIX}/bin/localpkg"

  lp_release="${lpcli_localpkg_release}"
  lp_gh_repo="${lpcli_localpkg_repo}"
  lp_pkg_file="localpkg"
  lp_pkg_url=""

  lp_create_uninstall
}

lp_github_findinstaller() {
	local lp_pkg_urls=($(echo -E "${lpgh_release}" | jq -r '.assets[].url'))
	local lp_pkg_names=($(echo -E "${lpgh_release}" | jq -r '.assets[].name'))

	local -A lp_release_files=()

	for i in {1..${#lp_pkg_urls[@]}}; do
		lp_release_files["${lp_pkg_names[i]}"]="${lp_pkg_urls[i]}"
	done

  if [[ "${lp_release_files["${lp_pkg_name}.localpkg"]}" ]]; then
    echo "${lp_release_files["${lp_pkg_name}"]}"
    return 0
  fi

	for installer in "${lpcli_installer_names[@]}"; do
		if [[ -n "${lp_release_files[${installer}]}" ]]; then
			echo "${lp_release_files[${installer}]}"
			return 0
		fi
	done

	local key

	for key in "${(k)lp_release_files}"; do
		if [[ "${key}" =~ ^.*\.localpkg$ ]]; then
			echo "${lp_release_files[${key}]}"
			return 0
		fi
	done

	return 0
}

lpcli_add() {
  # add subcommand
  # install packages locally
  # spec: [alias:]owner/repo[@release] or just alias

  if [[ -z "${1}" ]]; then
    echo "Usage: ${ZSH_ARGZERO} add [alias|[alias:]owner/repo[@release]] ..."
    exit 1
  fi

  local pkg

  for pkg in "${@}"; do
    local alias
    local repo
    local release

    if [[ "${pkg}" =~ ^([^:]+):([^/]+?/[^/]+?)@(.+)$ ]]; then
      alias="${match[1]}"
      repo="${match[2]}"
      release="${match[3]}"
    elif [[ "${pkg}" =~ ^([^:]+):([^/]+/[^/]+)$ ]]; then
      alias="${match[1]}"
      repo="${match[2]}"
    elif [[ "${pkg}" =~ ^([^/]+/[^/]+)@(.+)$ ]]; then
      repo="${match[1]}"
      release="${match[2]}"
    elif [[ "${pkg}" =~ ^([^/]+/[^/]+)$ ]]; then
      repo="${match[1]}"
    else
      echo "Invalid package spec: ${pkg}"
      exit 1
    fi

    lpcli_add_pkg "${alias}" "${repo}" "${release}"
  done
}

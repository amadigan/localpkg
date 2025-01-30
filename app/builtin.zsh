lpcli_builtin_localpkg() {
  # install localpkg itself

  lp_skeleton
  builtin mkdir -p "${LOCALPKG_PREFIX}/bin"
  local -a lp_installed_files=("bin/localpkg")
  
  private -a args=()

  (( ${lp_pkg[sfx]} )) && args+=("-z")

  args+=( "@" "${LOCALPKG_PREFIX}/bin/localpkg" )

  lpcli_cmd_build "${args[@]}"

  lp_pkg[name]="localpkg"
  lp_pkg[repo]="${lpcli_localpkg_repo}"
  lp_pkg[release]="${lpcli_localpkg_release}"
  lp_pkg[package]="localpkg"

  private mgr_file="$(lp_mgr_create "${lp_pkg[sfx]}")"
	"${mgr_file}"
}

function {
  private pkgfile pkgsrc name line

  for pkgfile in "${ZSH_SCRIPT:a:h}"/pkg/*.zsh; do
    name="${pkgfile:t:r}"
    lp_log Adding builtin package "${name}"
    printf -v src 'lpcli_builtin_%s() {\n(\n' "${name}"
    while read -r line; do
      src+=${line}$'\n'
    done < "${pkgfile}"
    src+=${line}$'\n'
    src+=$'\nlp_installer_main "${@}"\n)\n}'
    eval "${src}" || exit 1
  done
}

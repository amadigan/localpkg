lp_pkg[name]="go"
lp_tar_args=(--safe-writes)
lp_tar_exclude=()

lp_fetch_release() {
	if [[ -z "${lp_pkg[release]}" ]]; then
		private release
		command curl --silent 'https://go.dev/VERSION?m=text' | read -r release
		lp_pkg[release]="${release}"
	fi
	lp_pkg[package]="${lp_pkg[release]}.${lp_os}-${lp_arch}.tar.gz"
	lp_pkg[package_url]="https://go.dev/dl/${lp_pkg[package]}"
}

lp_postinstall() {
	# setup symlinks
	builtin mkdir -p "${LOCALPKG_PREFIX}/bin"
	cd "${LOCALPKG_PREFIX}/bin"
	private bin dest exist_target

	for bin in ../go/bin/*; do
		builtin ln -snf "${bin}" "${bin:t}"
		lp_installed_files+=("bin/${dest}")
	done

	cd "${LOCALPKG_PREFIX}"

	builtin mkdir -p "etc/profile.d"

	lp_installed_files+=("etc/profile.d/go.sh")
	{
		printf 'export PATH="$(go env GOPATH)/bin:${PATH}"\n'
		printf '[ -n "${CGO_ENABLED}" ] || xcode-select -p > /dev/null 2>&1 || export CGO_ENABLED=0\n'
	} > "etc/profile.d/go.sh"
}

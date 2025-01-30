# package script for VS Code, this will eventually be a builtin

lp_pkg[name]=code
lp_pkg[repo]=microsoft/vscode

lp_manager_init() {
	private vscode="${HOME}/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

	if [[ -x "${vscode}" ]]; then
		command "${vscode}" --version | read lp_pkg[release]
	fi
}

lp_filter_release() {
	private platform=""

	if [[ "${lp_arch}" == "amd64" ]]; then
		if [[ "${lp_os}" == "darwin" ]]; then
			platform="${lp_os}"
		else
			platform="${lp_os}-x64"
		fi
	else
		platform="${lp_os}-${lp_arch}"
	fi

	printf 'https://update.code.visualstudio.com/%s/%s/stable' "${lp_pkg[release]:-latest}" "${platform}"
}

lp_install_download() {
	private downloaded_file="${1}"

	builtin mkdir -p "${HOME}/Applications"

	lp_log "Extracting ${downloaded_file}"

	lp_log "Installing Visual Studio Code to ~/Applications"
	command -p bsdtar -xf "${downloaded_file}" -C "${HOME}/Applications" --safe-writes

	private vscode_dir="${HOME}/Applications/Visual Studio Code.app"

	if [[ ! -d "${vscode_dir}" ]]; then
		lp_error "Failed to extract Visual Studio Code"
	fi

	private bin dest

	# setup/update symlinks
	for bin in "${vscode_dir}/Contents/Resources/app/bin/"*; do
		if [[ -x "${bin}" ]]; then
			dest="${LOCALPKG_PREFIX}/bin/${bin:t}"
			builtin mkdir -p "${dest:h}"
			builtin ln -snf "${bin}" "${dest}"
			builtin chmod 755 "${dest}"
			lp_installed_files+=("bin/${bin:t}")
		fi
	done

	if [[ -x "${vscode}/Contents/Resources/app/bin/code" ]]; then
		command "${vscode}/Contents/Resources/app/bin/code" --version | read lp_pkg[release]
	fi
}

lp_postremove() {
	# replaces lp_postremove
	lp_log "Removing Visual Studio Code from ~/Applications"
	builtin rm -rf "${HOME}/Applications/Visual Studio Code.app"
}

#!/bin/zsh

lp_pkg_name="git"
lp_tar_args=("--strip-components" "1" "--exclude" '*LICENSE*' "--exclude" '*README*' "--exclude" '*CHANGELOG*' "--exclude" '*COPYING*')
lp_gh_repo="amadigan/localpkg"
lp_pkgfile_pattern="git.*.tar.xz"

lp_postinstall() {
	local prefix="${1}"
	mkdir -p "${prefix}/etc"
	lp_pkg_files+=("etc/profile.d/git.sh" "etc/zshenv.d/git.zsh")

	cat <<EOF > "${prefix}/etc/profile.d/git.sh"
export GIT_EXEC_PATH="${prefix}/libexec/git-core"
EOF

	cat <<EOF > "${prefix}/etc/zshenv.d/git.zsh"
export GIT_EXEC_PATH="${prefix}/libexec/git-core"
EOF

	"${prefix}/bin/git" config --global credential.helper osxkeychain
}

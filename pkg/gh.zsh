#!/bin/zsh

lp_pkg_name="gh"
lp_gh_repo="cli/cli"
lp_tar_args=("--strip-components" "1" "--exclude" '*LICENSE*' "--exclude" '*README*' "--exclude" '*CHANGELOG*' "--exclude" '*COPYING*')

if [[ "${CPUTYPE}" == "arm64" ]]; then
	lp_pkgfile_pattern="gh_.*_macOS_arm64.zip"
else
	lp_pkgfile_pattern="gh_.*_macOS_amd64.zip"
fi

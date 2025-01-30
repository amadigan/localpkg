#!/bin/zsh

zmodload zsh/zutil zsh/files zsh/stat zsh/param/private
setopt errexit

typeset -A args

zparseopts -D -E -A args h -help

if [[ -v args[-h] || -v args[--help] ]]; then
	echo "Build a release to the specified directory (default: .)"
	echo "Usage: ${0} [options] [outdir]"
	echo ""
	echo "Options:"
	echo "  -h, --help  Show this help message"
	exit 0
fi

typeset -g outdir

if [[ -n "${1}" ]]; then
	outdir="${1}"
	builtin mkdir -p "${outdir}"
else
	outdir="."
fi

typeset -g srcdir="${ZSH_SCRIPT:a:h}"

if [[ "${srcdir:A}" == "${outdir:A}" ]]; then
	echo "Refusing to build in the source directory"
	exit 1
fi

cd "${outdir}"

set -x
command "${srcdir}/localpkg.zsh" build @ localpkg.zsh
command "${srcdir}/localpkg.zsh" build --compress @ localpkg
command openssl dgst -r -sha256 localpkg localpkg.zsh > sha256sums.txt

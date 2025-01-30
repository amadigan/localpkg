# functionality allowing libinstall.zsh to create copies of itself in scripts

typeset -gaUt xlp_vars xlp_funcs

lp_compressed_init() {
	# this runs as the top of compressed scripts, it moves stdin to another fd, which is then picked up
	# by the main script
	export __SFX_FD=""
	if [[ -a /dev/fd/0 ]]; then
		zmodload zsh/system
		sysopen -r -u __SFX_FD /dev/fd/0
		export __SFX_FD
	fi
}

lp_compress_script() {
	private name="${1}"
	private srcfile="${2:a}"
	#private init="$(functions lp_compressed_init)"

	# this ends up creating an xzipped tar archive with a single member named '_'
	private -a tar_args=(
		--create --no-xattrs --block-size 1 --options xz:compression-level=9 --xz -s '/.*/_/' --numeric-owner --uid 0 
		--gid 0 --no-mac-metadata --no-acls --no-fflags
	)

	printf "#!/bin/zsh\n%s\n" "${init#lp_compressed_init }"
	printf "command -p bsdtar xO <<'\00\00\00\00\00\00\00\00\00\01' | exec -a \"\${ZSH_SCRIPT:-%s}\" /bin/zsh -sb \"\${@}\"\n" "${name}"
	print "${2}" | command -p bsdtar "${(@)tar_args}" "${srcfile}"
}

xlp_transclude() {
	echo "## libinstall.zsh"
	echo "zmodload zsh/param/private"
	typeset -p "${xlp_vars[@]}"
	typeset -f "${xlp_funcs[@]}"
	echo "## end libinstall.zsh"
}

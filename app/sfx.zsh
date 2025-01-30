
lpcli_cmd_sfx() {
	private -A args

	zparseopts -D -E -K -A args h -help x -extract

	if [[ "${#@}" -gt 2 || "${#@}" -eq 0 || -v args[-h] || -v args[--help] ]]; then
		echo "Create or extract a self-extracting script"
		echo "Usage: lpcli sfx [-x | --extract] input [output]"
		echo "Options:"
		echo "  -h, --help  Show this help message"
		echo "  -x, --extract  Extract the script"
		echo "Output is written to stdout if no output is provided"
		return 0
	fi

	private infile="${1}"
	private outfile="${2:-/dev/fd/1}"

	if [[ -v args[-x] || -v args[--extract] ]]; then
		lpcli_sfx_extract "${infile}" > "${outfile}"
	else
		lp_compress_script "${infile:t}" "${infile}" > "${outfile}"
	fi
}

lpcli_sfx_extract() {
	# extract a self-extracting script
	# input: self-extracting script
	# output: original script

	(
		while read -r line; do
			if [[ "${line}" == *$'\00\00\00\00\00\00\00\00\00\01'* ]]; then
				break
			fi
		done

		command -p bsdtar xO
	) < "${1}"
}

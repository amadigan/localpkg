#!/bin/zsh

lp_srcpath="${0:A:h}"

mkinstall() {
	echo "#!/bin/zsh"
	cat "${1}" | awk 'NR == 1 && /^#!/ { next } { print }'
	echo ''
	cat "${lp_srcpath}/libinstall.zsh" | awk 'NR == 1 && /^#!/ { next } { print }'
}

# expect -o file or -r
outfile=""
run=0

while getopts "o:r" opt; do
	case ${opt} in
		o)
			outfile="${OPTARG}"
			;;
		r)
			run=1
			;;
		\?)
			echo "Invalid option: ${OPTARG}" 1>&2
			exit 1
			;;
	esac
done

shift $((OPTIND -1))

if [[ -n "${outfile}" ]]; then
	mkinstall "${1}" > "${outfile}"
fi

if [[ "${run}" -eq 1 ]]; then
	mkinstall "${1}" | zsh
fi

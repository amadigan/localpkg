lpcli_main() {
	if [[ -z "${1}" ]]; then
		echo "Usage: ${ZSH_ARGZERO} <subcommand> [args...]"
		echo "localpkg subcommands:"
		echo "  build - build a script a localpkg install script"
		exit 1
	fi

	local subcommand="${1}"

	shift

	case "${subcommand}" in
		build)
			lpcli_build "${@}"
			;;
		test)
			lpcli_test "${@}"
			;;
		*)
			echo "Error: Unknown subcommand: ${subcommand}"
			exit 1
			;;
	esac
}

lpcli_usage() {
	echo "Usage: ${0} <pkg_url> [-n <pkg_name>] [-v <version>]"
}

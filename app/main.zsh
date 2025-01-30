lpcli_main() {
	lp_boot

	typeset -g lpcli_arg0="${ZSH_ARGZERO:-localpkg}"
	# replace home with ~
	lpcli_arg0="${lpcli_arg0/$HOME/~}"

	lp_cmd lpcli_cmd "${@}"
	return 
}

lpcli_cmd_help() {
	echo "Manage packages installed in ~/.local"
	echo "Usage: ${lpcli_arg0} <command> [options...]"
	lp_cmd_help lpcli_cmd
}

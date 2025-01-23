
test_mktemp() {
	lp_mktemp
	[[ ! -d "${lpr_tmp_dir}" ]] && lpunit_fail "tmp dir not created"
	lp_debug "tmp dir: ${lpr_tmp_dir}"
	rmdir "${lpr_tmp_dir}"
}

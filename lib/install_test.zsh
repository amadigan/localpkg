test_install_executable() {
	lp_reset_pkg_vars
	lp_mktemp
	export LOCALPKG_PREFIX="${lpr_tmp_dir}"
	lp_mktemp
	local mock_server="${lpr_tmp_dir}"
	local mock_file="${mock_server}/hello.sh"

	echo "mock_file: |${mock_file}|"

	mkhello "${mock_file}"

	file "${mock_file}" || lpunit_fail "File not created"

	lp_pkg_filename="hello.sh"
	lp_pkg_name="hello"
	lp_pkg_url="file://${mock_file}"
	local -a lp_pkg_files=()

	lp_install_pkg || lpunit_fail "lp_install_pkg failed"

	[[ ! -x "${LOCALPKG_PREFIX}/bin/hello" ]] && lpunit_fail "Executable not installed"
	[[ "${lp_pkg_files[1]}" != "bin/hello" ]] && lpunit_fail "bin/hello not in lp_pkg_files"

	return 0
}

test_install_exec_atroot() {
	lp_reset_pkg_vars
	lp_mktemp
	export LOCALPKG_PREFIX="${lpr_tmp_dir}"
	lp_mktemp
	local mock_server="${lpr_tmp_dir}"
	zf_mkdir -p "${mock_server}/hello"

	mkhello "${mock_server}/hello/hello.sh"

	bsdtar -cvf "${mock_server}/hello.tar" -C "${mock_server}" hello

	lp_pkg_filename="hello.tar"
	lp_pkg_name="hello"
	lp_pkg_url="file://${mock_server}/hello.tar"

	local -a lp_pkg_files=()

	lp_install_pkg || lpunit_fail "lp_install_pkg failed"

	[[ ! -x "${LOCALPKG_PREFIX}/hello.sh" ]] && lpunit_fail "Executable not installed"
	[[ "${lp_pkg_files[1]}" != "hello.sh" ]] && lpunit_fail "hello.sh not in lp_pkg_files"

	lp_postinstall "${LOCALPKG_PREFIX}" "${lp_pkg_name}"

	[[ ! -x "${LOCALPKG_PREFIX}/bin/hello.sh" ]] && lpunit_fail "Executable not installed"
	[[ "${lp_pkg_files[1]}" != "bin/hello.sh" ]] && lpunit_fail "bin/hello.sh not in lp_pkg_files"

	return 0
}

mkhello() {
	echo '#!/bin/sh' > "${1}"
	echo 'echo "Hello, world!"' >> "${1}"
	zf_chmod 755 "${1}"
}

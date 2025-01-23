#!/bin/zsh
source "${0:A:h}/../libinstall.zsh"
declare -a lpunit_test_errors=()

lpunit_fail() {
	lpunit_test_errors+=("${1}")
}

lpunit_after_test() {
	lpunit_test_errors+=("exited with ${?}")
	lp_cleanup
}

trap lpunit_after_test EXIT

lpunit_run_file()	{
	# delete all functions and variables starting with test_
	local test_func test_var

	for test_func in ${(k)functions}; do
		if [[ "${test_func}" == test_* ]]; then
			unset -f "${test_func}"
		fi
	done

	for test_var in ${(k)parameters}; do
		if [[ "${test_func}" == test_* ]]; then
			unset "${test_func}"
		fi
	done

	if ! source "${1}"; then
		lpunit_fail "Failed to source ${1}"
		return 1
	fi

	for test_func in ${(k)functions}; do
		if [[ "${test_func}" == test_* ]]; then
			functions -T "${test_func}"
			echo ">>> Running test ${test_func}"
			lp_unit_test_errors=()
			if "${test_func}" && [[ ${#lpunit_test_errors} == 0 ]]; then
				echo ">>> Test ${test_func} passed"
			elif [[ ${#lpunit_test_errors} -gt 0 ]]; then
				echo ">>> Test ${test_func} failed with errors:"
				for lp_unit_test_error in "${lpunit_test_errors[@]}"; do
					echo ">>> ERROR: ${lp_unit_test_error}"
				done
			else
				echo ">>> Test ${test_func} failed"
			fi
		fi
	done
}

lpunit_run_file "${1}"

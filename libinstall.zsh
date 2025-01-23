#!/bin/zsh
# this is really just a wrapper around sourcing the lib files, the code here allows libinstall to translclude itself

[[ "${xlp_loaded}" == "1" ]] && return # prevent double-loading
xlp_loaded=1

typeset -U xlp_funcs xlp_vars xlp_old_funcs xlp_oldmods xlp_mods
typeset -A xlp_old_vars

function {
	local xlp_func xlp_var xlp_mod

	for xlp_func in ${(k)functions}; do
		[[ "${xlp_func}" == lp*_* ]] && xlp_old_funcs+=("${xlp_func}")
	done

	for xlp_var in ${(k)parameters}; do
		[[ "${xlp_var}" == lp_* ]] && xlp_old_vars["${xlp_var}"]="${parameters[${xlp_var}]}"
	done

	while read -r xlp_oldmods; do
		xlp_oldmods+=("${xlp_mod}")
	done < <(zmodload -LF)
}

for xlp_libfile in "${0:A:h}/lib"/*.zsh; do
	[[ "${xlp_libfile}" != *_test.zsh ]] && source "${xlp_libfile}"
done

function {
	local xlp_func xlp_var

	for xlp_func in ${(k)functions}; do
		[[ "${xlp_func}" == lp*_* ]] && xlp_funcs+=("${xlp_func}")
	done

	xlp_funcs=(${(k)xlp_funcs:|xlp_old_funcs})

	for xlp_var in ${(k)parameters}; do
		if [[ "${xlp_var}" == lp_* && ("${xlp_old_vars[${xlp_var}]}" != "${parameters[${xlp_var}]}" || -z "${xlp_old_vars[${xlp_var}]}" ) ]]; then
			xlp_vars+=("${xlp_var}")
		fi
	done

	# remove empty strings
	xlp_vars=(${(M)xlp_vars:#?*})

	while read -r xlp_mod; do
		if [[ " ${xlp_oldmods} " != *" ${xlp_mod} "* ]]; then
			xlp_mods+=("${xlp_mod}")
		fi
	done < <(zmodload -LF)
}

unset xlp_old_funcs xlp_old_vars xlp_oldmods

xlp_transclude() {
	echo "## libinstall.zsh"
	local xlp_func xlp_var xlp_mod
	
	for xlp_mod in "${xlp_mods[@]}"; do
		echo "${xlp_mod}"
	done
	typeset -p "${xlp_vars[@]}"
	typeset -f "${xlp_funcs[@]}"
	typeset -p xlp_vars xlp_funcs xlp_mods
	typeset -f xlp_transclude
	echo "## end libinstall.zsh"
}

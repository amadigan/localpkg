#!/bin/zsh

source "${0:A:h}/libinstall.zsh"

# this ultimately just sources the files in app/. This code allows localpkg to build and install itself

typeset -U xlpcli_vars xlpcli_funcs xlpcli_old_funcs
typeset -A xlpcli_old_vars

function {
	local xlp_func xlp_var

	for xlp_func in ${(k)functions}; do
		[[ "${xlp_func}" == "lpcli_"* ]] && xlpcli_old_funcs+=("${xlp_func}")
	done

	for xlp_var in ${(k)parameters}; do
		[[ "${xlp_var}" == "lpcli_"* ]] && xlpcli_old_vars[${xlp_var}]="${parameters[${xlp_var}]}"
	done
}

for xlp_appfile in "${0:A:h}/app"/*.zsh; do
	source "${xlp_appfile}"
done

unset xlp_appfile

function {
	local xlp_func xlp_var
	
	for xlp_func in ${(k)functions}; do
		[[ "${xlp_func}" == "lpcli_"* ]] && xlpcli_funcs+=("${xlp_func}")
	done

	xlpcli_funcs=(${(k)xlpcli_funcs:|xlpcli_old_funcs})

	for xlp_var in ${(k)parameters}; do
		if [[ "${xlp_var}" == "lpcli_"* && 
				("${xlpcli_old_vars[${xlp_var}]}" != "${parameters[${xlp_var}]}" || -z "${xlpcli_old_vars[${xlp_var}]}" ) 
		]]; then
			xlpcli_vars+=("${xlp_var}")
		fi
	done

	xlpcli_vars+=( "xlpcli_vars" "xlpcli_funcs" )
	xlpcli_vars=(${(M)xlpcli_vars:#?*})
}

lpcli_main "${@}"

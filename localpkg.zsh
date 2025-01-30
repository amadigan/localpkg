#!/bin/zsh

# load lib/*.zsh

zmodload zsh/param/private

typeset -gU xlp_old_funcs xlp_old_vars

xlp_old_funcs=(${(k)functions})
xlp_old_vars=(${(k)parameters})

for xlp_libfile in "${0:A:h}/lib"/*.zsh; do
	[[ "${xlp_libfile}" != *_test.zsh ]] && source "${xlp_libfile}"
done

unset xlp_libfile

function {
	private xlp_var
	
	xlp_vars=()

	for xlp_var in ${(k)parameters:|xlp_old_vars}; do
		[[ "${parameters[${xlp_var}]}" == *-tag* ]] && xlp_vars+=("${xlp_var}")
	done

	# remove empty strings
	xlp_vars=(${(M)xlp_vars:#?*})
	xlp_vars=(${(o)xlp_vars})

	xlp_funcs=(${(k)functions:|xlp_old_funcs})
	xlp_funcs=(${(o)xlp_funcs})

	xlp_old_funcs=(${(k)functions})
	xlp_old_vars=(${(k)parameters})
}

# load app/*.zsh

for xlp_appfile in "${0:A:h}/app"/*.zsh; do
	[[ "${xlp_appfile}" != *_test.zsh ]] && source "${xlp_appfile}"
done

unset xlp_appfile

function {
	private xlp_var
	
	xlpcli_vars=()

	for xlp_var in ${(k)parameters:|xlp_old_vars}; do
		[[ "${parameters[${xlp_var}]}" == *-tag* ]] && xlpcli_vars+=("${xlp_var}")
	done

	xlpcli_vars=(${(M)xlpcli_vars:#?*})
	xlpcli_vars=(${(o)xlpcli_vars})

	xlpcli_funcs=(${(k)functions:|xlp_old_funcs})
	xlpcli_funcs=(${(o)xlpcli_funcs})

	unset xlpcli_old_funcs xlpcli_old_vars
}

lpcli_main "${@}"

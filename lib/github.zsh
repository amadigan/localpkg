
typeset -tg lp_github_api="https://api.github.com"
typeset -tg lp_github_url="https://github.com"

lp_github_use_gh() {
	if [[ ! -v lp_gh_status ]]; then
		typeset -g lp_gh_status=1
		[[ -n "${LOCALPKG_NO_GH}" ]] && command gh auth status -a &>/dev/null && lp_gh_status=0
	fi

	return "${lp_gh_status}"
}

lp_github_load_release() {
	[[ -v lp_release_files ]] && return 0
	typeset -gA lp_release_files
	private file="${1}"
	private jq_prog='"release \(.tag_name)" + "\n" + (.assets | to_entries | map("\(.value.url) \(.value.name)") | join("\n"))'
	private result

	private endpoint="repos/${lp_pkg[repo]}/releases/${lp_pkg[release]:-latest}"

	lp_pkg[release]=""

	if [[ -n "${file}" ]]; then
		lp_log "Parsing release information from ${file}"
		command -p jq -r "${jq_prog}" "${file}" | lp_github_parse_release
	elif lp_github_use_gh; then
		# fetch with gh
		lp_log "Fetching ${endpoint} using gh"
		command gh api "${endpoint}" --jq "${jq_prog}" | lp_github_parse_release
	else
		# fetch with curl
		private url="${lp_github_api}/${endpoint}"
		private curl_args=("--location" "--header" "Accept: application/vnd.github+json")

		lp_log "Fetching ${url}"
		lp_curl_json "${jq_prog}" "${curl_args[@]}" "${url}" | lp_github_parse_release
	fi

	if [[ -z "${lp_pkg[release]}" ]]; then
		lp_error "Failed to fetch release information for ${lp_pkg[repo]}"
		return 1
	fi
	
	return 0
}

lp_github_parse_release() {
	private -a parts
	private first=1
	private url name

	read -r url name
	lp_pkg[release]="${name}"
	
	while read -r url name; do
		[[ -n "${url}" ]] && lp_release_files[${name}]="${url}"
	done
}

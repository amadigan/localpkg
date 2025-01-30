
lp_curl_file() {
	# fetch a file to a specific path or to a temp directory
	# returns lines of metadata
	private -a lp_curl_fields=(
		"http_code %{http_code}"
		"content_type %{content_type}"
		"redirect_url %{redirect_url}"
		"url_effective %{url_effective}"
		"etag %header{etag}"
		"last_modified %header{last-modified}"
		"filename_effective %{filename_effective}"
		"errormsg %{errormsg}"
	)

	private -a lp_curl_opts=(
		"--location"
		"-#"
		"--header" "Accept: application/octet-stream"
		"--xattr"
	)

	[[ "${@}" == *"--output-dir"* ]] && lp_curl_opts+=("--remote-name" "--remote-header-name")

	command -p curl --write-out "${(j:\n:)lp_curl_fields}\n" "${(@)lp_curl_opts}" "${@}"
}

lp_curl_json() {
	# fetch from an API and execute a jq script
	private jq_script="${1}"
	shift

	command -p curl --silent "${@}" | command -p jq -r "${jq_script}"
}

lp_curl_plain() {
	# fetch from an API and return the output
	command -p curl --silent "${@}"
}

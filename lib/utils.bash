#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/matter-labs/foundry-zksync"
TOOL_NAME="foundry-zksync"
TOOL_TEST="forge --version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if foundry-zksync is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	list_github_tags
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"
	# Determine platform and architecture
	local platform
	local arch
	case "$(uname -s)" in
		"Darwin")
			platform="darwin"
			;;
		"Linux")
			platform="linux"
			;;
		*)
			fail "Unsupported platform: $(uname -s)"
			;;
	esac

	case "$(uname -m)" in
		"x86_64")
			arch="amd64"
			;;
		"arm64"|"aarch64")
			arch="arm64"
			;;
		*)
			fail "Unsupported architecture: $(uname -m)"
			;;
	esac

	# Try standard version first
	local version_no_prefix="${version#foundry-zksync-}"
	local standard_archive="foundry_zksync_${version_no_prefix}_${platform}_${arch}.tar.gz"
	local standard_url="$GH_REPO/releases/download/$version/$standard_archive"

	echo "* Trying standard release download for $TOOL_NAME version $version..."
	if curl -sIf "${standard_url}" >/dev/null 2>&1; then
		echo "* Found standard release, downloading..."
		curl "${curl_opts[@]}" -o "$filename" -C - "$standard_url" || fail "Could not download $standard_url"
		return
	fi

	# If standard version fails, try nightly version
	local nightly_archive="foundry_nightly_${platform}_${arch}.tar.gz"
	local nightly_url="$GH_REPO/releases/download/$version/$nightly_archive"

	echo "* Trying nightly release download for $TOOL_NAME version $version..."
	if curl -sIf "${nightly_url}" >/dev/null 2>&1; then
		echo "* Found nightly release, downloading..."
		curl "${curl_opts[@]}" -o "$filename" -C - "$nightly_url" || fail "Could not download $nightly_url"
		return
	fi

	fail "Could not find release for $version with either standard or nightly naming pattern"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

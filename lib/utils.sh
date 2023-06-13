#!/usr/bin/env bash

## mark script as failed
## e.g. `asdf_fail "cannot found git-tag command"`
asdf_fail() {
  local format="$1"
  shift

  printf "[ERR] %s: $format\n" \
    "$ASDF_PLUGIN_NAME" "$@" >&2
  exit 1
}

## log info message to stderr
## e.g. `asdf_info "found git-tag command"`
asdf_info() {
  local format="$1"
  shift

  printf "[INF] $format\n" "$@" >&2
}

## log debug message to stderr (only if $DEBUG had set)
## e.g. `asdf_debug "found git-tag command"`
asdf_debug() {
  if [ -z "${DEBUG:-}" ]; then
    return 0
  fi

  local format="$1"
  shift
  printf "[DBG] $format\n" "$@" >&2
}

## url fetch wrapper; CURL_OPTIONS=() for curl options
## e.g. `asdf_fetch https://google.com`
asdf_fetch() {
  local options=()
  local url="$1"
  local token

  if [[ "$url" =~ ^https://github.com ]]; then
    token="${GITHUB_API_TOKEN:-}"
    [ -z "$token" ] && token="${GITHUB_TOKEN:-}"
    [ -z "$token" ] && token="${GH_TOKEN:-}"
  fi

  if command -v "curl" >/dev/null; then
    options+=(
      --fail
      --silent
      --show-error
    )

    [ -n "$CURL_OPTIONS" ] &&
      options+=("${CURL_OPTIONS[@]}")

    if [ -n "$token" ]; then
      options+=(
        --header
        "Authorization: token $token"
      )
    fi

    asdf_debug "'curl' %s %s" \
      "${options[*]}" "$url"
    if ! curl "${options[@]}" "$url"; then
      asdf_fail "fetching %s failed" "$url"
    fi

    return 0
  fi

  asdf_fail "fetch command (e.g. curl) not found"
}

## fetch url and save to file
## e.g. `asdf_fetch_file https://google.com /tmp/output`
asdf_fetch_file() {
  local url="$1"
  export CURL_OPTIONS=(--output "$2" --location)
  asdf_fetch "$url"
  unset CURL_OPTIONS
}

## fetch url header
## e.g. `asdf_fetch_head https://google.com`
asdf_fetch_head() {
  export CURL_OPTIONS=(--head)
  asdf_fetch "$1"
  unset CURL_OPTIONS
}

## Sorting version
## e.g. `get_versions | asdf_version_sort`
asdf_version_sort() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

## Filtering version
## e.g. `get_versions | asdf_version_filter_by "1.11"`
asdf_version_filter_by() {
  local query="$1"
  grep -iE "^\\s*$query"
}

## Filtering only stable version
## e.g. `get_versions | asdf_version_stable_only`
asdf_version_stable_only() {
  local query='(-src|-dev|-latest|-stm|[-\.]rc|-alpha|-beta|[-\.]pre|-next|snapshot|master)'
  grep -ivE "$query"
}

## List all tags from git repository
## e.g. `asdf_list_git_tags "https://github.com/hello-world/hello-world"`
asdf_list_git_tags() {
  local repo="${1:-$ASDF_PLUGIN_APP_REPO}"

  # NOTE: You might want to adapt `sed` command to remove non-version strings from tags
  git ls-remote --tags --refs "$repo" |
    grep -o 'refs/tags/.*' |
    cut -d/ -f3- |
    sed 's/^v//'
}

## List all version sorted from git repository
## e.g. `asdf_list_versions`
asdf_list_versions() {
  asdf_list_git_tags | asdf_version_sort | xargs echo
}

## Print current OS
## e.g. `asdf_get_os`
asdf_get_os() {
  uname | tr '[:upper:]' '[:lower:]'
}

## Print current arch
## e.g. `asdf_get_arch`
asdf_get_arch() {
  local arch="${ASDF_OVERRIDE_ARCH:-}"
  [ -z "$arch"] && arch="$(uname -m)"

  case "$arch" in
  'x86_64') arch="amd64" ;;
  'powerpc64le' | 'ppc64le') arch="ppc64le" ;;
  'aarch64') arch="arm64" ;;
  'armv7l') arch="arm" ;;
  esac

  printf "%s" "$arch"
}

## Install app to input location (support chmod)
asdf_install() {
  local dldir="$1" itdir="$2"
  local file="$ASDF_PLUGIN_APP_OUTPUT"

  local dlpath="$dldir/$file"
  asdf_debug "installing app at %s" "$itdir"

  if [ -d "$dlpath" ]; then
    mv "$dlpath" "$itdir" &&
      asdf_debug "installed app at %s" "$itdir"
  elif [ -f "$dlpath" ]; then
    local itpath="$itdir/bin"

    mkdir -p "$itpath" 2>/dev/null
    mv "$dlpath" "$itpath" &&
      asdf_debug "installed app at %s" "$itpath"
    chmod +x "$itpath/$file"
  else
    asdf_fail "unknown download path type (%s)" \
      "$dlpath"
  fi

  local name="$ASDF_PLUGIN_APP_NAME"
  local executor="$itdir/bin/$name"
  [ -f "$executor" ] || asdf_fail "'%s' is missing from '%s'" \
    "$name" "$itdir/bin"
  $executor >/dev/null || asdf_fail "'%s' execute failed"

  asdf_info "installed '%s' successfully" \
    "$name"
}

## Download app to input location (support tar.gz extract)
## e.g. `asdf_download v1.0.1 /tmp/test`
asdf_download() {
  local version="$1" outdir="$2" os arch
  os="$(asdf_get_os)"
  arch="$(asdf_get_arch)"

  local download="https://get.helm.sh/helm-v${version}-${os}-${arch}.tar.gz"
  asdf_info "starting download from %s" "$download"

  local tmpfile="helm-v${version}-${os}-${arch}.tar.gz"
  local tmpdir=""
  tmpdir="$(mktemp -d)"
  local tmppath="$tmpdir/$tmpfile"
  asdf_debug "create temp path at %s" "$tmppath"

  local outfile="$ASDF_PLUGIN_APP_OUTPUT"
  local outdir="$2"
  local outpath="$outdir/$outfile"

  asdf_fetch_file "$download" "$tmppath"
  asdf_debug "downloaded app at %s" "$tmppath"

  if [[ "$tmpfile" =~ \.tar\.gz$ ]]; then
    asdf_debug "extracting tar.gz file"
    asdf_extract_tar "$tmppath" "$outpath" &&
      rm "$tmppath"
  else
    asdf_debug "moving app from %s to %s" \
      "$tmppath" "$outpath"
    mv "$tmppath" "$outpath"
  fi

  local name="$ASDF_PLUGIN_APP_NAME"
  asdf_info "downloaded '%s' successfully" \
    "$name"
}

## Extract contents of tar.gz file
## e.g. `asdf_extract_tar /tmp/test.tar.gz /tmp/test`
asdf_extract_tar() {
  local input="$1" output="$2"
  tar -xzf "$input" \
    -C "$output" \
    --strip-components=1
}

## get version marked as latest on Github
## e.g.`asdf_gh_latest`
asdf_gh_latest() {
  local repo="${1:-$ASDF_PLUGIN_APP_REPO}"
  local url="" version=""
  url="$(
    asdf_fetch_head "$repo/releases/latest" |
      sed -n -e "s|^location: *||p" |
      sed -n -e "s|\r||p"
  )"

  asdf_debug "redirect url: %s" "$url"
  if [[ "$url" == "$repo/releases" ]]; then
    asdf_debug "use 'tail' mode get latest version"
    version="$(asdf_list_versions | tail -n1)"
  elif [[ "$url" != "" ]]; then
    asdf_debug "use 'gh-latest' mode get latest version"
    version="$(printf "%s\n" "$url" | sed 's|.*/tag/v\{0,1\}||')"
  fi

  [ -n "$version" ] &&
    printf "%s" "$version" ||
    return 1
}

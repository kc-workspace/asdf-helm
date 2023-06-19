#!/usr/bin/env bash

## Environment variables
## https://asdf-vm.com/plugins/create.html#environment-variables-overview

# shellcheck source-path=SCRIPTDIR/defaults.sh
source "${KC_ASDF_PLUGIN_PATH:?}/lib/common/defaults.sh"
# shellcheck source-path=SCRIPTDIR/internal.sh
source "${KC_ASDF_PLUGIN_PATH:?}/lib/common/internal.sh"

## System information
KC_ASDF_OS="$(kc_asdf_get_os)"
KC_ASDF_ARCH="$(kc_asdf_get_arch)"
## Plugin information
KC_ASDF_ORG="kc-workspace"
KC_ASDF_NAME="asdf-helm"
KC_ASDF_REPO="https://github.com/kc-workspace/asdf-helm"
## Application information
KC_ASDF_APP_NAME="helm"
KC_ASDF_APP_DESC="help manage kubernetes applications"
KC_ASDF_APP_REPO="https://github.com/helm/helm"
## Download settings
KC_ASDF_DOWNLOAD_URL="https://get.helm.sh/helm-v{version}-{os}-{arch}.tar.gz"
KC_ASDF_DOWNLOAD_NAME="helm-v{version}-{os}-{arch}.tar.gz"
KC_ASDF_CHECKSUM_URL="https://get.helm.sh/helm-v{version}-{os}-{arch}.tar.gz.sha256sum"
KC_ASDF_DOWNLOAD_LOC="helm"

## These are set on bin/* scripts
# export KC_ASDF_PLUGIN_ENTRY_PATH
# export KC_ASDF_PLUGIN_ENTRY_NAME
# export KC_ASDF_PLUGIN_PATH
export KC_ASDF_APP_NAME KC_ASDF_APP_DESC KC_ASDF_APP_REPO
export KC_ASDF_DOWNLOAD_URL KC_ASDF_DOWNLOAD_NAME KC_ASDF_DOWNLOAD_LOC
export KC_ASDF_CHECKSUM_URL
export KC_ASDF_ORG KC_ASDF_NAME KC_ASDF_REPO
export KC_ASDF_OS KC_ASDF_ARCH

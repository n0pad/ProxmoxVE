#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/n0pad/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Threadfin/Threadfin

APP="Threadfin"
var_tags="${var_tags:-media}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

# Use ONE repo everywhere (change to Threadfin/Threadfin if you want upstream)
REPO="${REPO:-n0pad/Threadfin}"

header_info "$APP"
variables
color
catch_errors

# -------- helpers --------
ts() { date +%Y%m%d-%H%M%S; }

get_latest_tag() {
  # 1) Try GitHub API
  local api_json tag
  api_json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)"
  if [[ -n "$api_json" ]]; then
    # extract "tag_name": "v1.2.3"
    tag="$(printf '%s' "$api_json" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -n1)"
    if [[ -n "$tag" ]]; then
      printf '%s' "$tag"
      return 0
    fi
  fi
  # 2) Fallback: follow releases/latest redirect and read final URL (/tag/<TAG>)
  local final url
  final="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest" 2>/dev/null || true)"
  # examples: https://github.com/${REPO}/releases/tag/v1.2.3
  url="${final##*/tag/}"
  if [[ -n "$url" && "$url" != "$final" ]]; then
    printf '%s' "$url"
    return 0
  fi
  return 1
}

# -------------------------

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/threadfin ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  # Ensure the version path is a file (not a directory)
  if [[ -d "$HOME/.threadfin" ]]; then
    msg_info "Found directory $HOME/.threadfin; renaming to $HOME/.threadfin.$(ts).bak"
    mv -f "$HOME/.threadfin" "$HOME/.threadfin.$(ts).bak"
  fi
  version_file="${HOME}/.threadfin_version"

  # Robust tag fetch (no broken pipe)
  RELEASE="$(get_latest_tag)" || RELEASE=""
  if [[ -z "$RELEASE" ]]; then
    msg_error "Could not determine latest release tag from ${REPO}."
    exit 1
  fi

  CURRENT_VER="$(cat "$version_file" 2>/dev/null || true)"

  if [[ "$RELEASE" != "$CURRENT_VER" ]] || [[ ! -f "$version_file" ]]; then
    msg_info "Stopping $APP"
    systemctl stop threadfin || true
    msg_ok "Stopped $APP"

    # Fetch from the SAME repo; asset name as used before
    fetch_and_deploy_gh_release "threadfin" "${REPO}" "singlefile" "latest" \
      "/opt/threadfin" "Threadfin_linux_amd64"

    # Persist the version (covers helpers that don’t)
    printf '%s\n' "$RELEASE" > "$version_file"

    msg_info "Starting $APP"
    systemctl start threadfin
    msg_ok "Started $APP"

    msg_ok "Updated Successfully to v${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:34400/web${CL}"

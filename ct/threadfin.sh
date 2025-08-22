#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
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

# --- NEW: choose a single repo and use it everywhere ---
# If you're using your fork, leave n0pad/Threadfin. Otherwise set to Threadfin/Threadfin.
REPO="${REPO:-n0pad/Threadfin}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/threadfin ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # --- NEW: make sure version file is a FILE, not a directory ---
  # Some environments created ~/.threadfin as a directory; move it out of the way.
  if [[ -d "$HOME/.threadfin" ]]; then
    msg_info "Found directory $HOME/.threadfin; renaming to $HOME/.threadfin.bak"
    mv -f "$HOME/.threadfin" "$HOME/.threadfin.bak"
  fi
  # Force the helper to use a sane file path for version tracking (if respected by build.func)
  version_file="${HOME}/.threadfin_version"

  # --- NEW: read latest tag from the SAME repo we will fetch from ---
  RELEASE="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep -m1 '"tag_name"' | awk -F'"' '{print $4}')"

  if [[ -z "$RELEASE" ]]; then
    msg_error "Could not determine latest release tag from ${REPO}."
    exit 1
  fi

  # Compare to current local version (if any)
  CURRENT_VER="$(cat "$HOME/.threadfin_version" 2>/dev/null || true)"

  if [[ "$RELEASE" != "$CURRENT_VER" ]] || [[ ! -f "$HOME/.threadfin_version" ]]; then
    msg_info "Stopping $APP"
    systemctl stop threadfin || true
    msg_ok "Stopped $APP"

    # --- FIX: fetch from the SAME repo; asset name kept as before ---
    fetch_and_deploy_gh_release "threadfin" "${REPO}" "singlefile" "latest" \
      "/opt/threadfin" "Threadfin_linux_amd64"

    # Write version to the file (also covers cases where helper doesn't)
    echo "$RELEASE" > "$HOME/.threadfin_version"

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

#!/usr/bin/env bash
# Threadfin Proxmox LXC installer/updater (hardened)
# - Consistent repo
# - No brittle curl|grep pipelines
# - Version file at ~/.threadfin
# - If ~/.threadfin is a dir: back it up, restore ~/.threadfin.bak (file) to ~/.threadfin

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck | MIT
# Upstream: https://github.com/Threadfin/Threadfin

APP="Threadfin"
var_tags="${var_tags:-media}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

# ---- Choose ONE repo and use it everywhere ----
# Your fork by default; change to Threadfin/Threadfin for upstream.
REPO="${REPO:-n0pad/Threadfin}"

header_info "$APP"
variables
color
catch_errors

# ---------- helpers ----------
ts() { date +%Y%m%d-%H%M%S; }

get_latest_tag() {
  local api_json tag final url
  # 1) GitHub API (no pipe from curl)
  api_json="$(curl -fsSL --retry 3 --retry-delay 2 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)"
  if [[ -n "$api_json" ]]; then
    tag="$(printf '%s' "$api_json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
    if [[ -n "$tag" ]]; then
      printf '%s' "$tag"
      return 0
    fi
  fi
  # 2) Fallback via redirect to /releases/tag/<TAG>
  final="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest" 2>/dev/null || true)"
  url="${final##*/tag/}"
  if [[ -n "$url" && "$url" != "$final" ]]; then
    printf '%s' "$url"
    return 0
  fi
  return 1
}
# ----------------------------

function ensure_version_file() {
  # Standardize on ~/.threadfin as the version FILE
  local vf="$HOME/.threadfin"

  if [[ -d "$vf" ]]; then
    msg_info "Found directory $vf; backing up and restoring file"
    mv -f "$vf" "$vf.dir.$(ts).bak"

    # If a previous backup file exists, restore it as ~/.threadfin
    if [[ -f "$vf.bak" ]]; then
      mv -f "$vf.bak" "$vf"
    else
      : > "$vf"
    fi
  fi

  # If legacy ~/.threadfin_version exists and ~/.threadfin is empty, migrate it
  if [[ -f "$HOME/.threadfin_version" && ! -s "$vf" ]]; then
    mv -f "$HOME/.threadfin_version" "$vf"
  fi

  # Ensure we end up with a real file at ~/.threadfin
  [[ -f "$vf" ]] || : > "$vf"
}


function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/threadfin ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  ensure_version_file
  version_file="$HOME/.threadfin"   # single source of truth

  RELEASE="$(get_latest_tag)" || RELEASE=""
  if [[ -z "$RELEASE" ]]; then
    msg_error "Could not determine latest release tag from ${REPO}."
    exit 1
  fi

  CURRENT_VER="$(cat "$version_file" 2>/dev/null || true)"

  if [[ "$RELEASE" != "$CURRENT_VER" ]] || [[ ! -s "$version_file" ]]; then
    msg_info "Stopping $APP"
    systemctl stop threadfin || true
    msg_ok "Stopped $APP"

    # Fetch from the SAME repo; ensure asset name matches release
    fetch_and_deploy_gh_release "threadfin" "${REPO}" "singlefile" "latest" \
      "/opt/threadfin" "Threadfin_linux_amd64"

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

# ----- normal installer flow (unchanged) -----
start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:34400/web${CL}"

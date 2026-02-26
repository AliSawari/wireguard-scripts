#!/usr/bin/env bash
# wgctl.sh — connect/disconnect 3 hard-coded WireGuard configs by full path
# Usage:
#   ./wgctl.sh u|up     [1|2|3]
#   ./wgctl.sh d|down   [1|2|3]
#   ./wgctl.sh r|restart [1|2|3]
#   ./wgctl.sh status

set -euo pipefail

CFG1_ETH="/home/ali/configs/wireguard/customized/smart1-eth.conf"
CFG2_ETH="/home/ali/configs/wireguard/customized/smart2-eth.conf"
CFG3_ETH="/home/ali/configs/wireguard/customized/smart3-eth.conf"

CFG1_WIFI="/home/ali/configs/wireguard/customized/smart1-wifi.conf"
CFG2_WIFI="/home/ali/configs/wireguard/customized/smart2-wifi.conf"
CFG3_WIFI="/home/ali/configs/wireguard/customized/smart3-wifi.conf"

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"
WGQ="wg-quick"

detect_iface_type() {
  local wg_iface
  wg_iface=$($SUDO wg show interfaces 2>/dev/null)

  if [[ -n "$wg_iface" ]]; then
    # VPN is up — check the active tunnel name for -wifi or -eth
    case "$wg_iface" in
      *wifi*) echo "wifi" ;;
      *eth*)  echo "eth"  ;;
      *)
        # VPN up but can't tell type — fall through to physical detection
        ;;
    esac
    return
  fi

  # No VPN — detect physical interface normally
  local iface
  iface=$(ip route get 1.1.1.1 2>/dev/null \
    | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')

  case "$iface" in
    e*) echo "eth"  ;;
    w*) echo "wifi" ;;
    *)
      echo "ERROR: Unrecognized interface '$iface' — not eth or wifi." >&2
      exit 1
      ;;
  esac
}

# ── Pick the right config set based on detected type ─────────────────────────
set_cfg_vars() {
  local type
  type=$(detect_iface_type)

  case "$type" in
    eth)
      CFG1="$CFG1_ETH"; CFG2="$CFG2_ETH"; CFG3="$CFG3_ETH"
      echo "[iface] Active connection: Ethernet → using eth configs"
      ;;
    wifi)
      CFG1="$CFG1_WIFI"; CFG2="$CFG2_WIFI"; CFG3="$CFG3_WIFI"
      echo "[iface] Active connection: WiFi → using wifi configs"
      ;;
  esac
}

# ── Get active WireGuard config path from wg show ─────────────────────────────
get_active_cfg() {
  local iface
  iface=$(sudo wg show interfaces 2>/dev/null)

  if [[ -z "$iface" ]]; then
    echo "ERROR: No active WireGuard interface found." >&2
    exit 1
  fi

  # Reconstruct full config path from interface name
  # wg-quick uses the filename without .conf as the interface name
  local cfg="/home/ali/configs/wireguard/customized/${iface}.conf"

  if [[ ! -f "$cfg" ]]; then
    echo "ERROR: Config file not found: $cfg" >&2
    exit 1
  fi

  echo "$cfg"
}

cmd_down_active() {
  local cfg
  cfg=$(get_active_cfg)
  echo "↓ Bringing down $cfg"
  sudo wg-quick down "$cfg"
}

get_cfg() {
  case "$1" in
    1) echo "$CFG1" ;;
    2) echo "$CFG2" ;;
    3) echo "$CFG3" ;;
    *) echo "Invalid config index: $1 (choose 1, 2, or 3)" >&2; exit 2 ;;
  esac
}

cmd_up() {
  local cfg
  cfg=$(get_cfg "$1")
  echo "↑ Bringing up $cfg"
  $SUDO $WGQ up "$cfg"
}

cmd_down() {
  cmd_down_active
}

cmd_restart() {
  cmd_down "$1"
  cmd_up "$1"
}

cmd_status() {
  $SUDO wg show || true
}


cmd_refresh_configs(){
  cd /home/ali/configs/wireguard/customized;
  node ./create-conf.js
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1-}" in
  u|up|d|down|r|restart|refresh)
    set_cfg_vars  # detect iface and set CFG1/2/3 before any command
    case "$1" in
      u|up)       shift; cmd_up      "${1:?Choose 1|2|3}" ;;
      d|down)     shift; cmd_down ;;
      r|restart)  shift; cmd_restart "${1:?Choose 1|2|3}" ;;
      refresh)    shift; cmd_refresh_configs ;;
    esac
    ;;
  status|s)
    cmd_status
    ;;
  *)
    # Still need cfg vars for the usage printout
    set_cfg_vars 2>/dev/null || { CFG1="(auto)"; CFG2="(auto)"; CFG3="(auto)"; }
    cat <<EOF
Usage:
  $(basename "$0") u|up       [1|2|3]
  $(basename "$0") d|down
  $(basename "$0") r|restart  [1|2|3]
  $(basename "$0") s|status
  $(basename "$0") refresh

Configs (auto-selected based on active interface):
  1 -> $CFG1
  2 -> $CFG2
  3 -> $CFG3
EOF
    ;;
esac

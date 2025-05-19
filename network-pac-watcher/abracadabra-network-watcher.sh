#!/bin/bash

LOGFILE="/Library/Logs/fabrikantics-network-watcher.log"
STATEFILE="/var/tmp/fabrikantics-net-state"
PAC_URL="http://pac.fabrikantics.com/proxy.pac"
CORP_PREFIXES=("172.16." "192.168.88." "203.0.113.")
WIFI_IF="en0"
MAX_LOG_SIZE=5242880
MAX_LOG_ROTATIONS=3

rotate_logs(){
  [[ -f $LOGFILE && $(stat -f%z "$LOGFILE") -gt $MAX_LOG_SIZE ]] || return
  for ((i=MAX_LOG_ROTATIONS; i>=1; i--)); do
    [[ -f "$LOGFILE.$i" ]] && {
      (( i == MAX_LOG_ROTATIONS )) && rm -f "$LOGFILE.$i" \
        || mv "$LOGFILE.$i" "$LOGFILE.$((i+1))"
    }
  done
  mv "$LOGFILE" "$LOGFILE.1"
  touch "$LOGFILE"
}

log(){ echo "[$(date '+%d-%m-%Y %H:%M:%S')] $*" >> "$LOGFILE"; }

get_service_by_device(){
  networksetup -listallhardwareports | \
    awk -v dev="$1" '
      /^Hardware Port:/ {port=$3}
      $0 == "Device: " dev {print port}
    '
}

get_ip(){ ipconfig getifaddr "$1" 2>/dev/null || echo ""; }

get_wifi_power(){
  local out status power
  out=$(networksetup -getairportpower "$WIFI_IF" 2>&1); status=$?
  if (( status != 0 )); then
    power="Off"
  else
    power=$(printf '%s' "$out" | awk -F': ' '{print $2}')
    [[ -z $power ]] && power="Off"
  fi
  echo "$power"
}

is_corp(){
  for p in "${CORP_PREFIXES[@]}"; do
    [[ $1 == "$p"* ]] && return 0
  done
  return 1
}

apply_pac(){
  local svc=$1 cur enabled
  cur=$(networksetup -getautoproxyurl "$svc" 2>/dev/null | awk '/URL/ {print $2}')
  enabled=$(networksetup -getautoproxyurl "$svc" 2>/dev/null | awk '/Enabled/ {print $2}')
  log "DEBUG: PAC check for $svc - URL='$cur', Enabled='$enabled'"
  if [[ "$enabled" == "Yes" && "$cur" == "$PAC_URL" ]]; then
    log "ℹ️  PAC already present on $svc; skipping."
  else
    networksetup -setautoproxyurl  "$svc" "$PAC_URL"    2>/dev/null \
    && networksetup -setautoproxystate "$svc" on        2>/dev/null \
    && log "✅ Applied PAC on $svc"
  fi
}

clear_pac(){
  local svc=$1 cur enabled
  cur=$(networksetup -getautoproxyurl "$svc" 2>/dev/null | awk '/URL/ {print $2}')
  enabled=$(networksetup -getautoproxyurl "$svc" 2>/dev/null | awk '/Enabled/ {print $2}')
  log "DEBUG: Clear PAC check for $svc - URL='$cur', Enabled='$enabled'"
  if [[ "$enabled" != "Yes" || -z $cur || $cur == "(null)" ]]; then
    log "ℹ️  No PAC to clear on $svc; skipping."
  else
    networksetup -setautoproxystate "$svc" off           2>/dev/null \
    && networksetup -setautoproxyurl  "$svc" ""         2>/dev/null \
    && log "✅ Cleared PAC from $svc"
  fi
}

rotate_logs

# Wi-Fi detection
WIFI_SVC=$(get_service_by_device "$WIFI_IF")
wifi_ip=$(get_ip "$WIFI_IF")
wifi_power=$(get_wifi_power)

# Ethernet detection (first active en* except Wi-Fi)
ETH_IF="" ; ETH_SVC="" ; eth_ip=""
for dev in $(ifconfig -l | tr ' ' '\n' | grep '^en' | grep -v "^${WIFI_IF}\$"); do
  ip=$(get_ip "$dev")
  [[ -n $ip ]] && {
    ETH_IF=$dev
    ETH_SVC=$(get_service_by_device "$dev")
    eth_ip=$ip
    break
  }
done

log "ℹ️  Detected services: Wi-Fi='$WIFI_SVC', Ethernet='$ETH_SVC'"

# Load previous state
if [[ -f $STATEFILE ]]; then
  IFS=',' read -r old_wifi_ip old_wifi_type old_eth_ip old_eth_type old_autooff old_wifi_power \
    < "$STATEFILE"
else
  old_wifi_ip=""; old_wifi_type=""; old_eth_ip=""; old_eth_type=""
  old_autooff="0"; old_wifi_power="On"
fi

log "DEBUG: wifi_power='$wifi_power' old_wifi_power='$old_wifi_power' old_autooff='$old_autooff'"

# Classify network types
if is_corp "$wifi_ip"; then      wifi_type="corp"
elif [[ -n $wifi_ip ]]; then     wifi_type="ext"
else                             wifi_type="";  fi

if is_corp "$eth_ip"; then       eth_type="corp"
elif [[ -n $eth_ip ]]; then      eth_type="ext"
else                             eth_type="";  fi

# Respect manual Wi-Fi Off
if [[ $wifi_power == "Off" && $old_wifi_power == "On" && $old_autooff == "0" && $eth_type != "corp" ]]; then
  log "🔇 Manual Wi-Fi OFF by user; exiting without touching PAC."
  printf "%s,%s,%s,%s,%s,%s\n" \
    "$wifi_ip" "$wifi_type" "$eth_ip" "$eth_type" "$old_autooff" "$wifi_power" \
    > "$STATEFILE"
  exit 0
fi

# Exit if nothing changed
if [[ "$wifi_ip" == "$old_wifi_ip" && "$wifi_type" == "$old_wifi_type" && \
      "$eth_ip"  == "$old_eth_ip"  && "$eth_type"  == "$old_eth_type"  && \
      "$wifi_power" == "$old_wifi_power" ]]; then
  exit 0
fi

# Network change!
log "=== Network change detected ==="
[[ -n $ETH_IF ]] && log "Ethernet: $ETH_SVC, $eth_ip ($eth_type)"
[[ -n $WIFI_IF ]] && log "Wi-Fi:    $WIFI_SVC, $wifi_ip ($wifi_type) (Power: $wifi_power)"

if [[ $eth_type == "corp" ]]; then
  # Corporate Ethernet always wins
  log "🔒 Corporate Ethernet"
  apply_pac "$ETH_SVC"; apply_pac "$WIFI_SVC"
  if [[ $wifi_power == "On" ]]; then
    networksetup -setairportpower "$WIFI_IF" off 2>/dev/null
    log "✂️ Auto-turned Wi-Fi OFF for Corporate Ethernet"
    autooff="1"
  else
    autooff="$old_autooff"
  fi

elif [[ $eth_type == "ext" ]]; then
  # External Ethernet: clear proxy and auto-off Wi-Fi once
  log "🌐 External Ethernet"
  clear_pac "$ETH_SVC"; clear_pac "$WIFI_SVC"
  if [[ $old_autooff == "0" && $wifi_power == "On" ]]; then
    networksetup -setairportpower "$WIFI_IF" off 2>/dev/null
    log "✂️ Auto-turned Wi-Fi OFF for External Ethernet"
    autooff="1"
  else
    autooff="$old_autooff"
  fi

elif [[ $wifi_type == "corp" ]]; then
  # Corporate Wi-Fi only
  log "🔒 Corporate Wi-Fi"
  apply_pac "$WIFI_SVC"
  autooff="0"

elif [[ $wifi_type == "ext" ]]; then
  # External Wi-Fi only: clear proxy, restore Wi-Fi if we auto-off earlier
  log "🌐 External Wi-Fi"
  clear_pac "$WIFI_SVC"
  if [[ $old_autooff == "1" ]]; then
    networksetup -setairportpower "$WIFI_IF" on 2>/dev/null
    log "🔌 Restored Wi-Fi ON after Ethernet unplug"
  fi
  autooff="0"

else
  # No interfaces at all: clear PACs, restore Wi-Fi if needed
  log "❌ No active interfaces"
  clear_pac "$WIFI_SVC"; clear_pac "$ETH_SVC"
  if [[ $old_autooff == "1" ]]; then
    networksetup -setairportpower "$WIFI_IF" on 2>/dev/null
    log "🔌 Restored Wi-Fi ON after all interfaces down"
  fi
  autooff="0"
fi

log "=== End of change ==="

# Save new state
printf "%s,%s,%s,%s,%s,%s\n" \
  "$wifi_ip" "$wifi_type" "$eth_ip" "$eth_type" "$autooff" "$wifi_power" \
  > "$STATEFILE"

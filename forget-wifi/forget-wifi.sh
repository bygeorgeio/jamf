#!/usr/bin/env zsh
set -euo pipefail

# Ensure we’re running as root
[[ $EUID -eq 0 ]] || { echo "Error: this script must be run as root" >&2; exit 1; }

# Fixed paths to avoid PATH hijacking
SECURITYBIN=/usr/bin/security
PLISTBUDDYBIN=/usr/libexec/PlistBuddy
AIRPORT_CLI="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

# Authorization rights to loosen
RIGHTS=(
  system.preferences.network
  system.services.systemconfiguration.network
  com.apple.wifi
)

# airport prefs to suppress admin prompts
AIRPORT_PREFS=(
  RequireAdminNetworkChange=NO
  RequireAdminIBSS=NO
  RequireAdminPowerToggle=NO
)

# Simple logger
log() { echo "[`date -u '+%Y-%m-%d %H:%M:%S UTC'`] $*"; }

# 1. Grant “allow” on the generic System Preferences right
log "Granting standard users the right to unlock Preference Panes…"
"$SECURITYBIN" authorizationdb write system.preferences allow

# 2. Grant “allow” on each network-specific right
log "Granting standard users the right to modify network settings…"
for right in "${RIGHTS[@]}"; do
  "$SECURITYBIN" authorizationdb write "$right" allow
done

# 3. Disable admin prompts via airport CLI
log "Disabling admin prompts in airport prefs…"
"$AIRPORT_CLI" prefs "${AIRPORT_PREFS[@]}"

# 4. Read current system.preferences.network policy into a safe temp file
TMPPLIST=$(mktemp /tmp/authdb_np_XXXXXX.plist)
trap 'rm -f "$TMPPLIST"' EXIT
log "Reading existing system.preferences.network policy…"
"$SECURITYBIN" authorizationdb read system.preferences.network > "$TMPPLIST"

# 5. Helper: enforce a sole “allow” rule
add_allow_rule() {
  local plist="$1"
  log "Enforcing a sole ‘allow’ rule in $plist…"
  "$PLISTBUDDYBIN" -c "Delete :rule"               "$plist" 2>/dev/null || true
  "$PLISTBUDDYBIN" -c "Add    :rule array"         "$plist"
  "$PLISTBUDDYBIN" -c "Add    :rule: string allow" "$plist"
  "$PLISTBUDDYBIN" -c "Set    :shared true"        "$plist"
  "$PLISTBUDDYBIN" -c "Delete :authenticate-user"   "$plist" 2>/dev/null || true
  "$PLISTBUDDYBIN" -c "Delete :group"               "$plist" 2>/dev/null || true
}

# 6. Only modify & write back if “allow” isn’t already the rule
if ! "$PLISTBUDDYBIN" -c "Print :rule:0" "$TMPPLIST" &>/dev/null; then
  add_allow_rule "$TMPPLIST"
  log "Writing modified policy back to authorizationdb…"
  "$SECURITYBIN" authorizationdb write system.preferences.network < "$TMPPLIST"
else
  log "‘allow’ rule already present; skipping plist rewrite."
fi

log "✅ Done. Standard users can now forget Wi‑Fi networks (and otherwise edit Network prefs) without admin prompts."

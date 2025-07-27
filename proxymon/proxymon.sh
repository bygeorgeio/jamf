#!/bin/bash

# Proxymon – monitor a Proxy Auto‑Config (PAC) host and enable or disable the PAC
# URL on all network services accordingly.  Edit the variables below to match
# your environment.

hostName="pac.domain.local"
pacFileUrl="http://${hostName}/filename.pac"

# Function to set or unset the autoproxy settings on all network interfaces.
setPac(){
    local state="$1"
    # List all network services (excluding disabled services marked with '*').
    interfaces=($(networksetup -listallnetworkservices | grep -v '\*'))
    for k in ${interfaces[@]}
    do
        currentSetting=$(networksetup -getautoproxyurl "$k")
        # If the PAC is not currently set and we are enabling proxy, set URL and state.
        if [[ "$currentSetting" != "$pacFileUrl" ]] && [[ "$state" = "on" ]]; then
            networksetup -setautoproxyurl "$k" "$pacFileUrl"
            networksetup -setautoproxystate "$k" on
        # If the PAC is already set and we are enabling proxy, just ensure the state is on.
        elif [[ "$currentSetting" = "$pacFileUrl" ]] && [[ "$state" = "on" ]]; then
            networksetup -setautoproxystate "$k" on
        # Otherwise disable the autoproxy state for this interface.
        else
            networksetup -setautoproxystate "$k" off
        fi
    done
}

# Watch for DNS or network interface changes.  Whenever a change occurs, test
# whether the PAC host is reachable with a one‑second timeout.  If reachable,
# enable the PAC settings on all interfaces; otherwise disable them.
notifyutil -w "com.apple.system.config.network_change.dns" -w \
           "com.apple.system.config.network_change.nwi" | while read -r line; do
    if host -W 1 "$hostName" > /dev/null 2>&1; then
        setPac on
    else
        setPac off
    fi
done

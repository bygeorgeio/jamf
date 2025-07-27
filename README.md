# Proxymon

Proxymon is a lightweight Bash monitor that toggles a Proxy Auto‑Config (PAC) URL on or off based solely on network reachability.  When the PAC host is resolvable, the script enables the PAC across all network services; when unreachable, it disables the PAC【156276101027233†L155-L199】.  Network change events (DNS or interface status) are tracked via `notifyutil` for immediate reaction【156276101027233†L155-L199】.  This stripped‑back approach avoids user state tracking and Wi‑Fi toggling to reduce risk and complexity【156276101027233†L155-L198】.

## Files

| File | Description |
| --- | --- |
| **proxymon.sh** | The main Bash script.  Edit the `hostName` and `pacFileUrl` variables at the top to point to your PAC host and PAC file【156276101027233†L166-L169】.  The script listens for network changes and toggles the autoproxy settings accordingly. |
| **com.proxymon.daemon.plist** | Launch Daemon plist that runs the script at system startup【156276101027233†L201-L217】.  Adjust the `ProgramArguments` path if you place the script somewhere other than `/usr/local/proxymon.sh`. |

## Deployment

1. Copy `proxymon.sh` to `/usr/local/proxymon.sh` and ensure it has executable permissions.
2. Copy `com.proxymon.daemon.plist` to `/Library/LaunchDaemons/com.proxymon.daemon.plist`.
3. Use a management tool such as Jamf Pro to deploy the files and run:

   ```bash
   launchctl load /Library/LaunchDaemons/com.proxymon.daemon.plist
   ```

   This loads the daemon and causes the script to monitor network changes immediately【156276101027233†L219-L225】.

By focusing solely on proxy configuration, Proxymon is easy to maintain and integrates smoothly into existing management workflows【156276101027233†L155-L198】.
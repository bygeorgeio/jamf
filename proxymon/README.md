# Proxymon

Proxymon is a simple proxy monitoring script for macOS. It monitors a designated proxy auto‑config (PAC) host and toggles the system’s PAC settings on or off based on the host’s reachability. Unlike other more complex scripts, Proxymon only manages the PAC settings—it does not modify Wi‑Fi or network services.

## Files

* `proxymon.sh` – bash script that watches for DNS/network‑change events and runs continuously. It checks if `hostName` is reachable with a one‑second timeout using `host -W 1`. When reachable, the script enables the auto proxy URL specified by `pacFileUrl` on all network interfaces and sets the auto proxy state to on; otherwise, it disables the auto proxy state.
* `com.proxymon.daemon.plist` – LaunchDaemon that executes the script at boot. It runs `proxymon.sh` in the background, keeping the process alive at all times.

## Customisation

Edit the variables near the top of `proxymon.sh` to match your environment:

```
hostName="pac.domain.local"    # the DNS name you want to test
pacFileUrl="http://${hostName}/filename.pac"    # the PAC file to set when reachable
```

`hostName` should be a host on your internal network whose DNS resolution indicates whether you are on‑site. `pacFileUrl` is the URL to your proxy auto‑config file.

## Deployment

1. Copy `proxymon.sh` to `/usr/local/proxymon.sh` on the target Mac and set execute permissions (`chmod +x /usr/local/proxymon.sh`).
2. Copy `com.proxymon.daemon.plist` to `/Library/LaunchDaemons/`.
3. Load the LaunchDaemon: `sudo launchctl load -w /Library/LaunchDaemons/com.proxymon.daemon.plist`. This will launch the script at boot and monitor network changes.
4. In Jamf Pro, create a policy that deploys both files to managed Macs and runs the `launchctl load` command as a post‑install script so that Proxymon starts immediately.

Once deployed, Proxymon will run continuously in the background, enabling or disabling your auto‑proxy settings based solely on whether the specified PAC host resolves.

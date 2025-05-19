# Network PAC Watcher for macOS  
*A magical solution from Abracadabra Industries (fictional)*

Automates network proxy (PAC) configuration and Wi-Fi/Ethernet transitions on managed Macs.  
Designed for Jamf Pro but works with any macOS fleet.

## ✨ Features
- Applies a PAC file when connected to a corporate network.
- Clears PAC file on non-corporate networks.
- Auto-disables Wi-Fi when on Ethernet (and restores as needed).
- Respects manual user toggling of Wi-Fi.
- Extensible, well-logged, and easy to tweak.

## 🚀 Setup

1. **Edit your PAC URL and corporate IPs** in `abracadabra-network-watcher.sh`.
2. **Deploy files** via Jamf Pro:
   - Script → `/usr/local/bin/abracadabra-network-watcher.sh`
   - LaunchDaemon → `/Library/LaunchDaemons/com.abracadabra.networkwatcher.plist`
3. **Scope a Jamf policy** to install, load, and monitor.
4. **Profit** (in magical user experience).

## 🧙 Example PAC URL & IPs

- PAC URL: `http://pac.abracadabra-industries.local/magic.pac`
- Corporate IPs: `10.77.`, `192.0.2.`, `203.0.113.`

## 📝 Example

```bash
sudo cp abracadabra-network-watcher.sh /usr/local/bin/
sudo cp com.abracadabra.networkwatcher.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.abracadabra.networkwatcher.plist

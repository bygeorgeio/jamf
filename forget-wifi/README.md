## Forget Wi‑Fi script for Jamf‑managed Macs

This repository contains a simple zsh script that allows standard users to forget Wi‑Fi networks without being prompted for an administrator password on macOS.

### Why?

On macOS the **Forget This Network** button in System Settings normally requires admin privileges. When you manage Macs with Jamf, your users might not have an admin account, so they can’t remove unwanted SSIDs. This script adjusts the macOS `authorizationdb` and `airport` preferences to remove those prompts.

### How it works

1. **Grants `allow` on the generic `system.preferences` right** so standard users can unlock preference panes.
2. **Writes `allow` for specific network‑related rights**:
   * `system.preferences.network`
   * `system.services.systemconfiguration.network`
   * `com.apple.wifi`
3. **Disables admin prompts for Wi‑Fi changes** via the `airport` command‑line interface by setting the hidden preferences `RequireAdminNetworkChange`, `RequireAdminIBSS` and `RequireAdminPowerToggle` to `NO`.
4. **Reads the existing `system.preferences.network` policy**, modifies it to enforce a sole `allow` rule and writes it back to the authorisation database.

The script is idempotent; if the allow rule already exists it won’t make further changes.

### Usage

1. Copy or download `forget-wifi.sh` to your Jamf Pro server.
2. Create a new **Script** in Jamf Pro and paste the contents.
3. Add the script to a **Policy** that runs as root. Set the **Execution Frequency** to **Once per computer**.
4. Deploy the policy to target Macs. Once applied, users can forget Wi‑Fi networks without needing an admin password.

You can also run it manually on a Mac with `sudo`:

``` `sudo /path/to/forget-wifi.sh`

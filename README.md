# 🧹 Autopilot Cleanup

[![Watch a Demo](https://img.youtube.com/vi/SLvbbjJCvHo/hqdefault.jpg)](https://youtu.be/SLvbbjJCvHo?si=lavT9N1emduIkFCH)

[Watch a Demo](https://youtu.be/SLvbbjJCvHo?si=lavT9N1emduIkFCH)


Interactive PowerShell tool for device cleanup across Windows Autopilot, Microsoft Intune, Microsoft Entra ID and Microsoft Defender for Endpoint. Use it to **dispose of devices** (remove them from every service) or to **return a leaver's device to stock** (wipe it, keep it in Autopilot for the next user). Works for bulk tidy-ups from a selection grid, or for a single device by serial number.

## 📸 Screenshots

| Device Selection Grid | Device Verification | Removal Monitoring | Single Device Removal |
|:---:|:---:|:---:|:---:|
| ![GUI](Images/GUI.png) | ![Device Verification](Images/Device-Verification.png) | ![Removal Verification](Images/Removal-Verficiation.png) | ![Single Device](Images/Single-Device.png) |
| WPF grid with search & multi-select | Serial number validation & action menu | Real-time removal progress tracking | Direct serial number targeting |

## ✨ Features

- ♻️ **Two actions** - **Disposal** removes a device from every service; **Leaver** wipes it and returns it to stock, keeping its Autopilot record for the next user
- 🛡️ **Defender for Endpoint tagging** - Tags each device's Defender record (`Disposed` or `Stock` by default) so it can be filtered out of reports
- 🆕 **Autopilot device preparation support** - Windows devices in Intune with no Autopilot record are included in the grid and in `-SerialNumber` lookups
- 📦 **Automatic Module Installation** - Checks for required Microsoft Graph modules and prompts to install missing dependencies
- 🖱️ **Interactive Device Selection** - WPF grid with checkboxes, search and sortable columns, including Entra registration date, last activity, owner and Autopilot assigned user
- 🔄 **Multi-Service Cleanup** - Removes devices from Autopilot, Intune and Entra ID in the correct order
- 🔍 **Serial Number Validation** - Prevents accidental deletion of devices with duplicate names
- 🎯 **Direct Serial Number Targeting** - Target specific devices with `-SerialNumber` parameter, bypassing the WPF grid
- 📊 **Real-Time Monitoring** - Tracks deletion progress with per-service progress bars and automatic verification
- ⚡ **Parallel API Fetching** - Concurrent data retrieval on PowerShell 7+ using thread jobs
- 🚀 **Fast Mode** - Sends commands without waiting for status checks
- 📄 **CSV Report for Every Run** - Per-device status and elapsed time for each service (Intune, Autopilot, Entra ID, Defender)
- 🔑 **Custom App Registration** - Configure a custom Entra app registration with persistent environment variables via `Configure-AutopilotCleanup` / `Clear-AutopilotCleanupConfig`
- 🔄 **Automatic Update Check** - Checks PowerShell Gallery for newer versions on launch
- 👥 **Duplicate Handling** - Identifies and processes duplicate device entries
- 🧪 **WhatIf Mode** - Preview changes without making them
- ⚙️ **Edge Case Management** - Handles pending deletions, missing devices, and other scenarios
- 🔔 **Sound Notifications** - Plays success beeps when cleanup is complete

## 📋 Prerequisites

- PowerShell 7.0 or later
- Required module (auto-installed if missing):
  - `Microsoft.Graph.Authentication`
- For Defender tagging: a [custom app registration](#-custom-app-registration) with the Defender permission (see [Defender for Endpoint Tagging](#️-defender-for-endpoint-tagging))

## 🔐 Required Permissions

Microsoft Graph **delegated** permissions requested at sign-in (the tool signs in as you - it doesn't use application permissions):

| Permission | Used for |
|---|---|
| `Device.Read.All` | Read Entra ID devices |
| `Directory.AccessAsUser.All` | Delete Entra ID devices and remove device owners. Microsoft requires this for deleting devices as a signed-in user; what it allows is limited by your Entra role |
| `DeviceManagementManagedDevices.ReadWrite.All` | Read and delete Intune devices |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` | Wipe and sync Intune devices |
| `DeviceManagementServiceConfig.ReadWrite.All` | Read, update and delete Autopilot devices |
| `User.ReadBasic.All` | Show the Entra device owner's name in the grid |

Your account also needs an Entra role that can delete devices - **Intune Administrator**, **Cloud Device Administrator** or **Windows 365 Administrator**. Removing device owners (`-RemoveEntraOwner`) needs Intune Administrator or Windows 365 Administrator.

> `Device.ReadWrite.All` is an application-only permission. Don't add it to the app registration for this tool - it's never used by a signed-in session and gives the app tenant-wide device access without a user.

Defender for Endpoint (separate API, only for Defender tagging):

| Permission | Used for |
|---|---|
| WindowsDefenderATP `Machine.ReadWrite` (delegated) | Find and tag Defender device records. Your account also needs the Defender role *Manage security settings* |

> After a permission is added, run `Disconnect-MgGraph` and start the tool again - an existing Graph session keeps its old permissions.

## 💻 Installation

1. Clone or download this repository
2. Open PowerShell
3. Navigate to the script directory
4. Run the script - it will automatically check and install required modules

```powershell
cd C:\Autopilot-Cleanup
.\Autopilot-CleanUp.ps1
```

Or import the module and use the `Start-AutopilotCleanup` command:

```powershell
Import-Module .\AutopilotCleanup
Start-AutopilotCleanup
```

## 🚀 Usage

### 🎯 Basic Usage

```powershell
.\Autopilot-CleanUp.ps1
```

1. Script will check for required modules and prompt to install if missing
2. Connects to Microsoft Graph (you'll be prompted to sign in)
3. Retrieves Autopilot devices, plus Windows devices in Intune with no Autopilot record, and adds Intune/Entra ID details
4. Displays the device selection grid
5. **Tick the devices you want, then click OK**
6. Choose an action - Disposal or Leaver (see below)
7. Monitors progress and writes a CSV report

### ♻️ Actions

After selecting devices you choose what to do with them:

```
DISPOSAL - remove from Autopilot, Intune and Entra ID
  STANDARD (monitors removal status):
  [1] Remove records only
  [2] WIPE device(s) + remove all records
  FAST (skips status checks):
  [3] Remove records only
  [4] WIPE device(s) + remove all records

LEAVER - wipe and return to stock (keeps Autopilot, group tag 'Stock')
  [5] WIPE + return to stock (waits for wipe to complete)
  [6] WIPE + return to stock - FAST (does not wait)

[7] Cancel
```

**Disposal** (options 1-4) - the device is leaving the organisation for good:

| Service | What happens |
|---|---|
| Defender | Tagged `Disposed` |
| Intune | Wiped (options 2 and 4), then removed |
| Autopilot | Removed |
| Entra ID | Removed |

**Leaver** (options 5-6) - the user is leaving and the device will be reused:

| Service | Autopilot device | Device preparation device (no Autopilot record) |
|---|---|---|
| Defender | Tagged `Stock` | Tagged `Stock` |
| Autopilot | **Kept** - assigned user removed, group tag set to `Stock` | - |
| Entra ID | **Kept** - dynamic Autopilot groups rely on it. Registered owner removed with `-RemoveEntraOwner` | **Removed** after the wipe - the device creates a new Entra record when it's set up again |
| Intune | Wiped. Intune removes the record once the wipe completes, so the device drops out of compliance reports | Same |

> ⚠️ **Check the stock group tag still gets an Autopilot profile.** If your Autopilot profile groups are based on group tag, make sure devices tagged `Stock` (or your `-StockGroupTag`) are still assigned a profile, or the device won't get one for its next user.

If a Leaver device isn't in Intune it can't be wiped remotely - the tool warns you to wipe it by hand.

### 🎯 Single Device (e.g. a Leaver's Laptop)

```powershell
Start-AutopilotCleanup -SerialNumber "ABC1234"
```

Looks up the serial in Autopilot, then Intune, and skips the grid. Choose the action from the menu as normal. Multiple serials can be passed: `-SerialNumber "ABC1234", "DEF5678"`.

### 🔑 Custom App Registration

Configure a custom app registration for delegated auth (persists across sessions):

```powershell
Import-Module .\AutopilotCleanup
Configure-AutopilotCleanup
```

Or pass credentials directly:

```powershell
.\Autopilot-CleanUp.ps1 -ClientId "your-client-id" -TenantId "your-tenant-id"
```

To clear saved configuration:

```powershell
Clear-AutopilotCleanupConfig
```

**Priority order:** command-line parameters > environment variables > default auth flow

**Required app registration settings:**
- Platform: Mobile and desktop applications
- Redirect URI: `http://localhost`
- Allow public client flows: Yes
- API Permissions (delegated, Microsoft Graph): `Device.Read.All`, `Directory.AccessAsUser.All`, `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementServiceConfig.ReadWrite.All`, `User.ReadBasic.All` - then **grant admin consent**
- Optional (delegated, WindowsDefenderATP): `Machine.ReadWrite` - only for Defender tagging
- No application permissions are needed

### 🛡️ Defender for Endpoint Tagging

Defender device records can't be deleted - once a device stops reporting it goes *Inactive* and eventually drops out of the device list. Tagging lets you filter disposed and in-stock devices out of Defender reports straight away. The tool doesn't offboard devices: a wipe removes the Defender sensor anyway.

Defender uses its own API, not Microsoft Graph, so tagging needs a custom app registration:

1. In your app registration go to **API permissions → Add a permission → APIs my organization uses → WindowsDefenderATP → Delegated permissions**
2. Add **Machine.ReadWrite** and **grant admin consent**
3. Make sure your account has the Defender role **Manage security settings**

On the first run a browser window opens once to sign in to Defender. Devices are matched by Entra device ID, falling back to device name, and every matching Defender record is tagged (a rebuilt device can have more than one).

Without a custom app registration, tagging is skipped with a message and the CSV shows `Skipped - not connected`. Use `-SkipDefenderTag` to turn tagging off.

### 🧪 WhatIf Mode (Test Run)

Preview what would happen without making changes:

```powershell
.\Autopilot-CleanUp.ps1 -WhatIf
```

A good first test of the Leaver action is one spare device:

```powershell
Start-AutopilotCleanup -SerialNumber "ABC1234" -WhatIf
```

## 📝 Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-WhatIf` | Switch | No | Preview mode - shows what would change without making changes |
| `-ClientId` | String | No | Client ID of a custom app registration for delegated auth |
| `-TenantId` | String | No | Tenant ID to use with the custom app registration |
| `-SerialNumber` | String[] | No | One or more serial numbers to target directly, bypasses the WPF grid |
| `-StockGroupTag` | String | No | Autopilot group tag set by the Leaver action. Default `Stock` |
| `-LeaverDefenderTag` | String | No | Defender tag applied by the Leaver action. Default `Stock` |
| `-DisposalDefenderTag` | String | No | Defender tag applied by the Disposal actions. Default `Disposed` |
| `-SkipDefenderTag` | Switch | No | Don't tag devices in Defender for Endpoint |
| `-RemoveEntraOwner` | Switch | No | Leaver action also removes the Entra device's registered owner. Needs the Intune Administrator or Windows 365 Administrator role |

## 🔧 How It Works

1. **Module Validation** - Verifies required PowerShell modules are installed
2. **Authentication** - Connects to Microsoft Graph with required scopes
3. **Data Retrieval** - Fetches Autopilot, Intune and Entra ID devices (in parallel on PowerShell 7+) and matches them by serial number and Entra device ID
4. **Device Selection** - Displays the WPF grid where you tick the devices to work on
5. **Action** - Choose Disposal or Leaver
6. **Defender** - Tags each device's Defender record (if connected)
7. **Disposal** removes the device in this order:
   - Microsoft Intune (management layer)
   - Windows Autopilot (deployment service)
   - Microsoft Entra ID (identity source)

   **Leaver** keeps the Autopilot record (user unassigned, group tag set to stock), keeps the Entra device for Autopilot devices, and wipes the device through Intune
8. **Verification** - Monitors and confirms the result (standard modes)
9. **Report** - Writes a CSV to the current folder

## 📋 Device Selection Grid

The grid shows every Autopilot device, plus every Windows device in Intune that has no Autopilot record.

| Column | Description |
|--------|-------------|
| Display Name | Device display name |
| Serial Number | Hardware serial number |
| Model | Device model |
| Group Tag | Autopilot group tag (`N/A` for devices with no Autopilot record) |
| Autopilot | Whether the device has an Autopilot record |
| Intune | Whether the device exists in Intune |
| Entra | Whether the device exists in Entra ID |
| Intune Name | Device name in Intune |
| Entra Name | Device name in Entra ID |
| Entra Registered | Date the device registered in Entra ID |
| Entra Last Activity | Approximate last sign-in date in Entra ID |
| Entra Owner | Registered owner of the Entra device |
| Autopilot Assigned User | User assigned to the Autopilot record |

Dates use your Windows regional date format. Empty values show `null`.

**✅ To select devices**:
- Tick the checkbox on each device you want, then click **OK**
- **Select All** / **Clear All** apply to the devices currently shown by the search
- Type in the search box to filter by name, serial number, model or group tag
- Click a column header to sort; click again to reverse the order

## 📄 CSV Report

Every run writes a CSV to the current folder - `DeviceRemoval_<timestamp>.csv` for Disposal, `DeviceLeaver_<timestamp>.csv` for Leaver (with `_WhatIf` added under `-WhatIf`).

For each device it records the action, mode, whether a wipe was sent, and for each of Defender, Intune, Autopilot and Entra ID a **status** and an **elapsed time** (`hh:mm:ss`):

- **Standard modes** - time from sending the request until removal (or the wipe) is confirmed
- **Fast modes** - time for the request itself
- **Entra ID** - time for the delete call (Entra removal is immediate)

Typical statuses: `Removed`, `Removal sent`, `Failed`, `Not found`, `Timed out`, `Wiped`, `Wipe sent`, `Wipe failed`, `Wipe timed out`, `Kept - ...` (Leaver), `Tagged 'Stock' (1)` (Defender).

## 📺 Example Output

```
[ A U T O P I L O T   C L E A N U P ]  v2.2.5
    with PowerShell

Auth: Default Microsoft Graph (delegated)

Checking required PowerShell modules...
✓ Module 'Microsoft.Graph.Authentication' is already installed
All required modules are installed.

Connecting to Microsoft Graph...
✓ Successfully connected to Microsoft Graph

Fetching all Autopilot devices...
Found 15 Autopilot devices

Processing: DESKTOP-ABC123 (Serial: 1234-5678-9012)
------------------------------

Step 1: Removing from Intune...
✓ Successfully queued device for removal from Intune

Step 2: Removing from Autopilot...
✓ Successfully queued device for removal from Autopilot

Step 3: Removing from Entra ID...
✓ Successfully queued device for removal from Entra ID

✓ Device successfully removed
  Name:           DESKTOP-ABC123
  Serial Number:  1234-5678-9012
```

## ⚠️ Important Notes

- 🚨 **Deletion is permanent** - Devices removed from these services cannot be easily restored
- 💾 **Wipes are permanent** - Options 2, 4, 5 and 6 factory reset the device and ask you to type `WIPE` to confirm
- ♻️ **Leaver keeps Autopilot and Entra** - Don't delete the Entra device of an Autopilot device you plan to reuse; dynamic Autopilot groups depend on it
- 🔢 **Serial number validation** - The script validates serial numbers to prevent accidental deletion of duplicate device names
- ⚡ **Deletion order matters** - Devices are removed in the correct order (Intune → Autopilot → Entra ID) to prevent dependency issues
- ⏱️ **Monitoring timeout** - The script monitors deletion progress for up to 30 minutes
- 👤 **No admin required** - Module installation uses CurrentUser scope, avoiding the need for administrator privileges
- 🔔 **Success notification** - Three ascending beeps play when device cleanup is successfully verified across all services

## 🔧 Troubleshooting

### ❌ Modules Won't Install
- Ensure you have internet connectivity
- Run PowerShell with appropriate permissions
- Manually install modules: `Install-Module -Name Microsoft.Graph -Scope CurrentUser`

### 🔒 Authentication Fails
- Verify your account has the required Graph API permissions
- Check if MFA is properly configured
- Try disconnecting and reconnecting: `Disconnect-MgGraph` then run the script again

### 👤 Entra Owner Shows an ID or `null`
- **An ID instead of a name** - the Graph session doesn't have `User.ReadBasic.All`. Run `Disconnect-MgGraph` and start again; with a custom app registration, add the permission to the app first
- **`null`** - the device has no registered owner, which is normal for self-deploying and pre-provisioned devices

### 🛡️ Defender Tagging Skipped or Failing
- `Skipped - not connected` - no custom app registration is configured, or the Defender sign-in failed. See [Defender for Endpoint Tagging](#️-defender-for-endpoint-tagging)
- `Not found` - the device has no Defender record (never onboarded, or outside your retention period)
- Tagging errors - check the app has WindowsDefenderATP `Machine.ReadWrite` with admin consent, and your account has *Manage security settings* and access to the device's Defender device group

### 👥 Owner Not Removed
- Owner removal needs `Directory.AccessAsUser.All`. If the tool says the session doesn't have it, run `Disconnect-MgGraph` and start again; with a custom app registration, check the permission is added and consented
- Your account also needs the Intune Administrator or Windows 365 Administrator role

### 🗑️ Entra ID Device Not Deleted
- Deleting Entra devices needs `Directory.AccessAsUser.All` (delegated) and the Intune Administrator, Cloud Device Administrator or Windows 365 Administrator role
- Run `(Get-MgContext).Scopes` to see which permissions the current session actually has

### 🔍 Device Not Found
- Device may already be deleted
- Serial number or device name may be incorrect
- Check if device exists in each service individually
- Devices that are only in Entra ID (not in Autopilot or Intune) aren't listed

### ⏳ Deletion Hangs
- Large deletions can take time (up to 30 minutes)
- Check Azure portal to verify deletion status
- Script will timeout after 30 minutes of monitoring

## ⚙️ Environment Variables

| Variable | Description |
|----------|-------------|
| `AUTOPILOTCLEANUP_CLIENTID` | Saved app registration Client ID (set via `Configure-AutopilotCleanup`) |
| `AUTOPILOTCLEANUP_TENANTID` | Saved Tenant ID (set via `Configure-AutopilotCleanup`) |
| `AUTOPILOTCLEANUP_DISABLE_UPDATE_CHECK` | Set to `true` to skip the update check on launch |

## 📜 Version History

**Unreleased**
- **Leaver action** (menu options 5-6) - wipe a device and return it to stock: Autopilot record kept with the user unassigned and group tag set to `Stock`, Entra device kept for Autopilot devices, optional registered owner removal (`-RemoveEntraOwner`)
- **Defender for Endpoint tagging** - tags devices `Disposed` (Disposal) or `Stock` (Leaver); needs a custom app registration with WindowsDefenderATP `Machine.ReadWrite`. New parameters `-LeaverDefenderTag`, `-DisposalDefenderTag`, `-SkipDefenderTag`
- **Autopilot device preparation devices** - Windows devices in Intune with no Autopilot record now appear in the grid and in `-SerialNumber` lookups
- CSV report for every run (previously fast mode only), with per-service status and elapsed time, action, and Defender status
- New grid columns: Autopilot, Entra Registered, Entra Last Activity, Entra Owner, Autopilot Assigned User; click a column header to sort
- Graph permissions corrected to delegated scopes: `Device.ReadWrite.All` (application-only) replaced with `Device.Read.All` and `Directory.AccessAsUser.All`, which Microsoft requires for deleting Entra devices as a signed-in user; `User.ReadBasic.All` added for Entra owner names
- New parameters `-StockGroupTag` and `-RemoveEntraOwner`

**Version 2.2.5**
- Entra ID removal is now treated as immediate instead of being polled - the monitoring loop no longer waits on a Graph read-back that lags the delete, which could stall cleanup until the 30 minute timeout
- Removal status for Entra ID is reported inline, including a "not found" skip
- Update check now runs from `Invoke-AutopilotCleanup` so it applies to both entry points

**Version 2.2.4**
- Minimum PowerShell version updated to 7.0
- README updates: consolidated features list, updated version history and example output

**Version 2.2.3**
- Targeted API queries for `-SerialNumber` (no longer fetches entire tenant)
- WPF grid performance improvements (UI virtualization, CollectionView filtering, search debounce)

**Version 2.2.2**
- Fix `SerialNumber` parameter variable collision causing type conversion errors during device removal

**Version 2.2.1**
- Per-service progress bars during parallel fetch (page count and record count per service)
- Terminal indication when WPF device selection window is open
- Shared concurrent progress tracker for real-time thread job monitoring

**Version 2.2.0**
- `-SerialNumber` parameter for direct device targeting (single or multiple), bypasses the WPF grid
- Parallel API fetching on PowerShell 7+ using thread jobs (Autopilot, Intune, Entra ID fetched concurrently)
- Automatic fallback to sequential fetch if parallel jobs fail
- Progress bars during pagination for large tenant data retrieval

**Version 2.1.0**
- Custom app registration support (`Configure-AutopilotCleanup` / `Clear-AutopilotCleanupConfig`)
- `Start-AutopilotCleanup` module entry point
- Automatic update check from PowerShell Gallery
- Cleaner console UI - replaced heavy box-drawing with minimal section headers

**Version 2.0.0**
- PowerShell module architecture (Public/Private function structure)
- WPF device selection grid with search and multi-select
- Fast bulk removal mode with CSV export
- GroupTag filtering
- Serial number validation
- Real-time deletion monitoring
- WhatIf mode
- Automatic module installation

## 👨‍💻 Author

**Mark Orr**  
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/markorr321/)

## 📄 License

This script is provided as-is without warranty. Use at your own risk.

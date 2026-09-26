<#
.SYNOPSIS
    Bulk removal tool for devices from Windows Autopilot, Microsoft Intune, and Microsoft Entra ID

.DESCRIPTION
    Wrapper script that imports the AutopilotCleanup module and runs the interactive cleanup process.

    Features:
    - Automatic validation and installation of required Microsoft Graph PowerShell modules
    - Retrieves Windows Autopilot devices, plus Windows devices in Intune with no Autopilot record
      (Autopilot device preparation), enriched with Intune and Entra ID information
    - Interactive grid view for device selection
    - Disposal: removes selected devices from all three services (Intune, Autopilot, and Entra ID)
    - Leaver: wipes selected devices and returns them to stock, keeping the Autopilot record
    - Optional Defender for Endpoint tagging
    - Validates serial numbers to prevent accidental deletion of duplicate device names
    - Real-time monitoring of deletion progress with automatic verification
    - Handles edge cases like pending deletions, duplicates, and missing devices
    - Supports WhatIf mode for safe testing without actual deletions

    Required Permissions:
    - Device.Read.All
    - Directory.AccessAsUser.All (deleting Entra devices and owners; limited by your Entra role)
    - DeviceManagementManagedDevices.ReadWrite.All
    - DeviceManagementManagedDevices.PrivilegedOperations.All
    - DeviceManagementServiceConfig.ReadWrite.All
    - User.ReadBasic.All
    - WindowsDefenderATP Machine.ReadWrite (only for Defender tagging, custom app registration)

.PARAMETER WhatIf
    Preview mode that shows what would be deleted without performing actual deletions

.PARAMETER StockGroupTag
    Autopilot group tag applied by the Leaver action. Defaults to "Stock".

.PARAMETER LeaverDefenderTag
    Defender for Endpoint tag applied by the Leaver action. Defaults to "Stock".

.PARAMETER DisposalDefenderTag
    Defender for Endpoint tag applied by the Disposal actions. Defaults to "Disposed".

.PARAMETER SkipDefenderTag
    Don't tag devices in Defender for Endpoint.

.PARAMETER RemoveEntraOwner
    The Leaver action also removes the Entra device's registered owner.

.NOTES
    Author: Mark Orr
    Requires: Microsoft Graph PowerShell SDK modules
    Version: 2.0
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Client ID of the app registration to use for delegated auth")]
    [string]$ClientId,

    [Parameter(HelpMessage = "Tenant ID to use with the specified app registration")]
    [string]$TenantId,

    [Parameter(HelpMessage = "One or more serial numbers to target for removal. Bypasses the device selection grid.")]
    [string[]]$SerialNumber,

    [Parameter(HelpMessage = "Autopilot group tag applied to devices returned to stock by the Leaver action")]
    [string]$StockGroupTag,

    [Parameter(HelpMessage = "Defender for Endpoint tag applied by the Leaver action")]
    [string]$LeaverDefenderTag,

    [Parameter(HelpMessage = "Defender for Endpoint tag applied by the Disposal actions")]
    [string]$DisposalDefenderTag,

    [Parameter(HelpMessage = "Skip tagging devices in Defender for Endpoint")]
    [switch]$SkipDefenderTag,

    [Parameter(HelpMessage = "Leaver action also removes the Entra device's registered owner")]
    [switch]$RemoveEntraOwner
)

# Import the module from the adjacent directory
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'AutopilotCleanup'
Import-Module $modulePath -Force

# Build parameters to forward
$invokeParams = @{}
if ($WhatIf) { $invokeParams['WhatIf'] = $true }
if ($ClientId) { $invokeParams['ClientId'] = $ClientId }
if ($TenantId) { $invokeParams['TenantId'] = $TenantId }
if ($SerialNumber) { $invokeParams['SerialNumber'] = $SerialNumber }
if ($StockGroupTag) { $invokeParams['StockGroupTag'] = $StockGroupTag }
if ($LeaverDefenderTag) { $invokeParams['LeaverDefenderTag'] = $LeaverDefenderTag }
if ($DisposalDefenderTag) { $invokeParams['DisposalDefenderTag'] = $DisposalDefenderTag }
if ($SkipDefenderTag) { $invokeParams['SkipDefenderTag'] = $true }
if ($RemoveEntraOwner) { $invokeParams['RemoveEntraOwner'] = $true }

# Run the main cleanup function
Invoke-AutopilotCleanup @invokeParams

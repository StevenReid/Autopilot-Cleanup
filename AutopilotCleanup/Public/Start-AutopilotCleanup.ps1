function Start-AutopilotCleanup {
    <#
    .SYNOPSIS
        Launches the Autopilot Cleanup tool.

    .DESCRIPTION
        Opens an interactive console application for bulk removal of devices from
        Windows Autopilot, Microsoft Intune, and Microsoft Entra ID.

        If ClientId and TenantId are not provided as parameters, the function will
        check for environment variables set via Configure-AutopilotCleanup. If neither
        are found, it uses the default authentication flow.

    .PARAMETER ClientId
        Client ID of the app registration to use for delegated auth.
        If not provided, checks AUTOPILOTCLEANUP_CLIENTID environment variable.

    .PARAMETER TenantId
        Tenant ID to use with the specified app registration.
        If not provided, checks AUTOPILOTCLEANUP_TENANTID environment variable.

    .PARAMETER SerialNumber
        One or more device serial numbers to target for removal.
        When provided, bypasses the interactive device selection grid and
        automatically selects the matching devices for the cleanup routine.

    .PARAMETER StockGroupTag
        Autopilot group tag applied by the Leaver action when a device is returned to stock.
        Defaults to "Stock". Make sure an Autopilot profile is still assigned to devices with
        this tag, or the device won't get a profile for its next user.

    .PARAMETER LeaverDefenderTag
        Defender for Endpoint tag applied by the Leaver action. Defaults to "Stock".

    .PARAMETER DisposalDefenderTag
        Defender for Endpoint tag applied by the Disposal actions. Defaults to "Disposed".

    .PARAMETER SkipDefenderTag
        Don't tag devices in Defender for Endpoint. Defender tagging needs a custom app
        registration with the delegated WindowsDefenderATP permission Machine.ReadWrite.

    .PARAMETER RemoveEntraOwner
        The Leaver action also removes the Entra device's registered owner. Needs the
        Intune Administrator or Windows 365 Administrator role.

    .PARAMETER WhatIf
        Preview mode that shows what would be deleted without performing actual deletions.

    .EXAMPLE
        Start-AutopilotCleanup

    .EXAMPLE
        Start-AutopilotCleanup -SerialNumber "ABC1234"

    .EXAMPLE
        Start-AutopilotCleanup -SerialNumber "ABC1234", "DEF5678", "GHI9012"

    .EXAMPLE
        Start-AutopilotCleanup -SerialNumber "ABC1234" -RemoveEntraOwner

        Target one device (e.g. a leaver's laptop) and choose the Leaver action from the menu.

    .EXAMPLE
        Start-AutopilotCleanup -ClientId "b7463ebe-e5a7-4a1a-ba64-34b99135a27a" -TenantId "51eb883f-451f-4194-b108-4df354b35bf4"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
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

    # Note: the update check runs inside Invoke-AutopilotCleanup, so it is not
    # repeated here - otherwise both entry points would prompt.

    # Build parameters to forward
    $invokeParams = @{}
    if ($WhatIfPreference) { $invokeParams['WhatIf'] = $true }
    if ($ClientId) { $invokeParams['ClientId'] = $ClientId }
    if ($TenantId) { $invokeParams['TenantId'] = $TenantId }
    if ($SerialNumber) { $invokeParams['SerialNumber'] = $SerialNumber }
    if ($StockGroupTag) { $invokeParams['StockGroupTag'] = $StockGroupTag }
    if ($LeaverDefenderTag) { $invokeParams['LeaverDefenderTag'] = $LeaverDefenderTag }
    if ($DisposalDefenderTag) { $invokeParams['DisposalDefenderTag'] = $DisposalDefenderTag }
    if ($SkipDefenderTag) { $invokeParams['SkipDefenderTag'] = $true }
    if ($RemoveEntraOwner) { $invokeParams['RemoveEntraOwner'] = $true }

    Invoke-AutopilotCleanup @invokeParams
}

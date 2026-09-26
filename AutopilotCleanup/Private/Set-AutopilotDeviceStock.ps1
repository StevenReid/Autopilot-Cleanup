function Set-AutopilotDeviceStock {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        $AutopilotDevice,
        [Parameter(Mandatory)]
        [string]$GroupTag
    )

    $baseUri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$($AutopilotDevice.id)"
    $changes = @()

    try {
        if ($PSCmdlet.ShouldProcess("$($AutopilotDevice.displayName) (Serial: $($AutopilotDevice.serialNumber))", "Unassign user and set Autopilot group tag '$GroupTag'")) {
            if ($AutopilotDevice.userPrincipalName) {
                Invoke-MgGraphRequest -Uri "$baseUri/unassignUserFromDevice" -Method POST
                $changes += "user unassigned"
            }
            if ($AutopilotDevice.groupTag -ne $GroupTag) {
                # Only the properties supplied are changed
                Invoke-MgGraphRequest -Uri "$baseUri/updateDeviceProperties" -Method POST -Body (@{ groupTag = $GroupTag } | ConvertTo-Json)
                $changes += "group tag '$GroupTag'"
            }
        } else {
            Write-ColorOutput "WHATIF: Would unassign user and set group tag '$GroupTag' on Autopilot device $($AutopilotDevice.serialNumber)" "Yellow"
            $changes += "WhatIf"
        }

        if ($changes.Count -eq 0) { $changes += "already in stock" }
        Write-ColorOutput "  ✓ Autopilot kept ($($changes -join ', '))" "Green"
        return @{ Success = $true; Changes = $changes; Error = $null }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-ColorOutput "✗ Error updating Autopilot device $($AutopilotDevice.serialNumber): $errorMsg" "Red"
        return @{ Success = $false; Changes = $changes; Error = $errorMsg }
    }
}

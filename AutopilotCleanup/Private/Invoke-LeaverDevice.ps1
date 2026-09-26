function Invoke-LeaverDevice {
    # Leaver: wipe the device and return it to stock for the next user.
    #  - Autopilot record is KEPT: assigned user removed, group tag set to the stock tag
    #  - Entra device is KEPT for Autopilot devices (dynamic Autopilot groups rely on it);
    #    registered owner optionally removed
    #  - Intune record is removed by Intune itself once the wipe completes
    #  - Devices with no Autopilot record (Autopilot device preparation) create a new Entra
    #    device when they are set up again, so the old Entra device is deleted after the wipe
    # Updates the hashtables on $DeviceResult in place.
    param(
        [Parameter(Mandatory)]
        $FullDevice,
        [Parameter(Mandatory)]
        $DeviceResult,
        [bool]$WaitForWipe = $true,
        [string]$StockGroupTag = "Stock",
        [bool]$RemoveOwner = $false
    )

    $deviceName = $FullDevice.DisplayName
    $deviceSerial = $FullDevice.SerialNumber
    $autopilotDevice = $FullDevice._AutopilotDevice
    $entraDevice = $FullDevice._EntraDevice

    Write-ColorOutput "Leaver - returning $deviceName to stock..." "Cyan"

    # Autopilot: keep the record, unassign the user and move it to the stock group tag
    if ($autopilotDevice) {
        $DeviceResult.Autopilot.Found = $true
        $DeviceResult.Autopilot.StartTime = Get-Date
        $stockResult = Set-AutopilotDeviceStock -AutopilotDevice $autopilotDevice -GroupTag $StockGroupTag
        $DeviceResult.Autopilot.Success = $stockResult.Success
        $DeviceResult.Autopilot.Error = $stockResult.Error
        $DeviceResult.Autopilot.Elapsed = Format-ElapsedTime $DeviceResult.Autopilot.StartTime
        $DeviceResult.Autopilot.Status = if ($stockResult.Success) { "Kept - $($stockResult.Changes -join ', ')" } else { "Kept - update failed" }
    } else {
        Write-ColorOutput "  - Autopilot (no record - device preparation device)" "Gray"
    }

    # Entra (Autopilot devices): keep the device object, optionally remove the leaver as owner
    if ($autopilotDevice -and $entraDevice) {
        $DeviceResult.EntraID.Found = $true
        $DeviceResult.EntraID.StartTime = Get-Date
        if ($RemoveOwner) {
            $ownerResult = Remove-EntraDeviceOwner -EntraDevice $entraDevice
            $DeviceResult.EntraID.Success = $ownerResult.Success
            $DeviceResult.EntraID.Errors = @($ownerResult.Error | Where-Object { $_ })
            $DeviceResult.EntraID.Status = if (-not $ownerResult.Success) { "Kept - owner removal failed" } elseif ($ownerResult.OwnerCount -eq 0) { "Kept - no owner" } else { "Kept - owner removed" }
        } else {
            $DeviceResult.EntraID.Success = $true
            $DeviceResult.EntraID.Status = "Kept"
            Write-ColorOutput "  ✓ Entra ID kept" "Green"
        }
        $DeviceResult.EntraID.Elapsed = Format-ElapsedTime $DeviceResult.EntraID.StartTime
    }

    # Intune: wipe - the managed device record is removed by Intune once the wipe completes
    $wipeSucceeded = $false
    $intuneDevice = Get-IntuneDevice -DeviceName $deviceName -SerialNumber $deviceSerial
    if (-not $intuneDevice) {
        Write-ColorOutput "  ⚠ Device not found in Intune - it cannot be wiped remotely. Wipe it manually before reuse." "Yellow"
    } elseif ($WhatIfPreference) {
        Write-ColorOutput "WHATIF: Would wipe device $deviceName" "Yellow"
        $DeviceResult.Intune.Found = $true
        $DeviceResult.Intune.Status = "WhatIf"
        $wipeSucceeded = $true
    } else {
        $DeviceResult.Intune.Found = $true
        $DeviceResult.Intune.StartTime = Get-Date
        if (Invoke-IntuneDeviceWipe -ManagedDeviceId $intuneDevice.id) {
            Write-ColorOutput "  ✓ Wipe command sent" "Green"
            $DeviceResult.Wiped = $true
            if ($WaitForWipe) {
                if (Invoke-IntuneDeviceSync -ManagedDeviceId $intuneDevice.id) {
                    Write-ColorOutput "  ✓ Sync command sent" "Green"
                }
                Write-ColorOutput "  Waiting for wipe to complete..." "Yellow"
                $wipeSucceeded = Wait-ForDeviceWipe -ManagedDeviceId $intuneDevice.id -DeviceName $intuneDevice.deviceName -TimeoutMinutes 30 -PollIntervalSeconds 30
                $DeviceResult.Intune.Status = if ($wipeSucceeded) { "Wiped" } else { "Wipe timed out" }
            } else {
                $wipeSucceeded = $true
                $DeviceResult.Intune.Status = "Wipe sent"
            }
            $DeviceResult.Intune.Success = $wipeSucceeded
        } else {
            $DeviceResult.Intune.Status = "Wipe failed"
        }
        $DeviceResult.Intune.Elapsed = Format-ElapsedTime $DeviceResult.Intune.StartTime
    }

    # Entra (device preparation devices): the old device object is replaced at the next setup, so delete it
    if (-not $autopilotDevice) {
        $entraDevices = Get-EntraDeviceByName -DeviceName $deviceName -SerialNumber $deviceSerial -EntraDeviceId $FullDevice.EntraDeviceId
        if ($entraDevices -and $entraDevices.Count -gt 0) {
            $DeviceResult.EntraID.Found = $true
            if ($wipeSucceeded) {
                $DeviceResult.EntraID.StartTime = Get-Date
                $entraResult = Remove-EntraDevices -Devices $entraDevices -DeviceName $deviceName -SerialNumber $deviceSerial
                $DeviceResult.EntraID.Success = $entraResult.Success
                $DeviceResult.EntraID.DeletedCount = $entraResult.DeletedCount
                $DeviceResult.EntraID.FailedCount = $entraResult.FailedCount
                $DeviceResult.EntraID.Errors = $entraResult.Errors
                $DeviceResult.EntraID.Elapsed = Format-ElapsedTime $DeviceResult.EntraID.StartTime
                $DeviceResult.EntraID.Status = if ($entraResult.Success) { "Removed" } else { "Failed" }
            } else {
                Write-ColorOutput "  - Entra ID kept (wipe not confirmed - remove it once the device is wiped)" "Yellow"
                $DeviceResult.EntraID.Status = "Kept - wipe not confirmed"
            }
        }
    }
}

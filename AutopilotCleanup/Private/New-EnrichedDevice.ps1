function New-EnrichedDevice {
    param(
        $AutopilotDevice,
        $IntuneDevice,
        $EntraDevice
    )

    # Intune reports an empty GUID when the device has no Entra registration
    $intuneEntraId = if ($IntuneDevice.azureADDeviceId -and $IntuneDevice.azureADDeviceId -ne '00000000-0000-0000-0000-000000000000') {
        $IntuneDevice.azureADDeviceId
    } else { $null }

    $serialNumber = if ($AutopilotDevice.serialNumber) { $AutopilotDevice.serialNumber } else { $IntuneDevice.serialNumber }

    # Create a meaningful display name
    $displayName = if ($AutopilotDevice.displayName) {
        $AutopilotDevice.displayName
    } elseif ($IntuneDevice.deviceName) {
        $IntuneDevice.deviceName
    } elseif ($EntraDevice.displayName) {
        $EntraDevice.displayName
    } elseif ($serialNumber) {
        "Device-$serialNumber"
    } else {
        $recordId = if ($AutopilotDevice) { $AutopilotDevice.id } else { $IntuneDevice.id }
        "Unknown-$($recordId.Substring(0,8))"
    }

    [PSCustomObject]@{
        AutopilotId = if ($AutopilotDevice) { $AutopilotDevice.id } else { $null }
        DisplayName = $displayName
        SerialNumber = $serialNumber
        Model = if ($AutopilotDevice.model) { $AutopilotDevice.model } else { $IntuneDevice.model }
        Manufacturer = if ($AutopilotDevice.manufacturer) { $AutopilotDevice.manufacturer } else { $IntuneDevice.manufacturer }
        GroupTag = if (-not $AutopilotDevice) { "N/A" } elseif ($AutopilotDevice.groupTag) { $AutopilotDevice.groupTag } else { "None" }
        AutopilotFound = if ($AutopilotDevice) { "Yes" } else { "No" }
        IntuneFound = if ($IntuneDevice) { "Yes" } else { "No" }
        IntuneId = if ($IntuneDevice) { $IntuneDevice.id } else { $null }
        IntuneName = if ($IntuneDevice) { $IntuneDevice.deviceName } else { "N/A" }
        EntraFound = if ($EntraDevice) { "Yes" } else { "No" }
        EntraId = if ($EntraDevice) { $EntraDevice.id } else { $null }
        EntraDeviceId = if ($EntraDevice.deviceId) { $EntraDevice.deviceId } elseif ($AutopilotDevice.azureActiveDirectoryDeviceId) { $AutopilotDevice.azureActiveDirectoryDeviceId } else { $intuneEntraId }
        EntraName = if ($EntraDevice) { $EntraDevice.displayName } else { "N/A" }
        EntraRegistered = if ($EntraDevice.registrationDateTime) { $EntraDevice.registrationDateTime } else { "null" }
        EntraLastActivity = if ($EntraDevice.approximateLastSignInDateTime) { $EntraDevice.approximateLastSignInDateTime } else { "null" }
        EntraOwner = Get-EntraDeviceOwner -EntraDevice $EntraDevice
        AutopilotAssignedUser = if ($AutopilotDevice.userPrincipalName) { $AutopilotDevice.userPrincipalName } else { "null" }
        # Store original objects for deletion
        _AutopilotDevice = $AutopilotDevice
        _IntuneDevice = $IntuneDevice
        _EntraDevice = $EntraDevice
    }
}

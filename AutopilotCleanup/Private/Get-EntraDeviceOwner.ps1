function Get-EntraDeviceOwner {
    param(
        $EntraDevice
    )

    # Owners are returned inline when the device was queried with $expand=registeredOwners
    if (-not $EntraDevice -or -not $EntraDevice.registeredOwners) {
        return "null"
    }

    $owners = foreach ($owner in @($EntraDevice.registeredOwners)) {
        if ($owner.userPrincipalName) {
            $owner.userPrincipalName
        } elseif ($owner.displayName) {
            $owner.displayName
        } elseif ($owner.id) {
            # Owner exists but Graph returned no name - usually missing User.ReadBasic.All consent
            $owner.id
        }
    }

    if ($owners) {
        return ($owners -join "; ")
    }
    return "null"
}

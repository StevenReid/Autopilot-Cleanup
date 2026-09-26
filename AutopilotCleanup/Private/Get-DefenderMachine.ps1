function Get-DefenderMachine {
    param(
        [string]$EntraDeviceId,
        [string]$DeviceName
    )

    $baseUri = "https://api.security.microsoft.com/api/machines"

    # The machines API returns 404 when a filter matches nothing
    $query = {
        param($filter)
        try {
            @((Invoke-DefenderRequest -Uri "$baseUri`?`$filter=$([uri]::EscapeDataString($filter))").value)
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404) { @() } else { throw }
        }
    }

    # aadDeviceId is the Entra device ID (not the object ID). A device can have several
    # Defender records (e.g. re-onboarded after a rebuild) - return them all
    if ($EntraDeviceId) {
        # OData GUID literal is unquoted; retry quoted in case the API rejects it
        try {
            $machines = & $query "aadDeviceId eq $EntraDeviceId"
        }
        catch {
            $machines = & $query "aadDeviceId eq '$EntraDeviceId'"
        }
        if ($machines.Count -gt 0) { return $machines }
    }

    # Fall back to the computer name - computerDnsName can be a FQDN, so match on the host part
    if ($DeviceName) {
        $safeName = $DeviceName.Replace("'", "''")
        $machines = & $query "startswith(computerDnsName,'$safeName')" | Where-Object {
            $_.computerDnsName -eq $DeviceName -or $_.computerDnsName -like "$DeviceName.*"
        }
        return @($machines)
    }

    return @()
}

function Remove-EntraDeviceOwner {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        $EntraDevice
    )

    $owners = @($EntraDevice.registeredOwners | Where-Object { $_.id })
    $result = @{ Success = $true; RemovedCount = 0; OwnerCount = $owners.Count; Error = $null }

    foreach ($owner in $owners) {
        $ownerLabel = if ($owner.userPrincipalName) { $owner.userPrincipalName } else { $owner.id }
        # The /$ref suffix is essential - without it Graph deletes the USER object, not just the owner link.
        # Single-quoted format string so $ref is never expanded.
        $uri = 'https://graph.microsoft.com/v1.0/devices/{0}/registeredOwners/{1}/$ref' -f $EntraDevice.id, $owner.id

        try {
            if ($PSCmdlet.ShouldProcess("$($EntraDevice.displayName) (owner: $ownerLabel)", "Remove Entra device owner")) {
                Invoke-MgGraphRequest -Uri $uri -Method DELETE
            } else {
                Write-ColorOutput "WHATIF: Would remove owner $ownerLabel from Entra device $($EntraDevice.displayName)" "Yellow"
            }
            $result.RemovedCount++
        }
        catch {
            $result.Success = $false
            $result.Error = $_.Exception.Message
            Write-ColorOutput "✗ Error removing owner $ownerLabel from Entra device $($EntraDevice.displayName): $($result.Error)" "Red"
        }
    }

    if ($result.RemovedCount -gt 0) {
        Write-ColorOutput "  ✓ Entra ID owner removed ($($result.RemovedCount) of $($owners.Count))" "Green"
    }
    return $result
}

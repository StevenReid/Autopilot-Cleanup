function Set-DefenderMachineTag {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$EntraDeviceId,
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [string]$Tag
    )

    $result = @{ Found = $false; Success = $false; TaggedCount = 0; Error = $null }

    try {
        $machines = @(Get-DefenderMachine -EntraDeviceId $EntraDeviceId -DeviceName $DeviceName)
    }
    catch {
        $result.Error = $_.Exception.Message
        Write-ColorOutput "✗ Error searching Defender for $DeviceName`: $($result.Error)" "Red"
        return $result
    }

    if ($machines.Count -eq 0) {
        Write-ColorOutput "  - Defender (not found)" "Yellow"
        return $result
    }

    $result.Found = $true
    foreach ($machine in $machines) {
        try {
            if ($PSCmdlet.ShouldProcess("$($machine.computerDnsName) (Defender ID: $($machine.id))", "Add Defender tag '$Tag'")) {
                $uri = "https://api.security.microsoft.com/api/machines/$($machine.id)/tags"
                $null = Invoke-DefenderRequest -Uri $uri -Method POST -Body @{ Value = $Tag; Action = "Add" }
            } else {
                Write-ColorOutput "WHATIF: Would add Defender tag '$Tag' to $($machine.computerDnsName) (Defender ID: $($machine.id))" "Yellow"
            }
            $result.TaggedCount++
        }
        catch {
            $result.Error = $_.Exception.Message
            Write-ColorOutput "✗ Error tagging Defender device $($machine.computerDnsName): $($result.Error)" "Red"
        }
    }

    $result.Success = $result.TaggedCount -eq $machines.Count
    if ($result.TaggedCount -gt 0) {
        Write-ColorOutput "  ✓ Defender (tagged '$Tag' on $($result.TaggedCount) of $($machines.Count) record(s))" "Green"
    }
    return $result
}

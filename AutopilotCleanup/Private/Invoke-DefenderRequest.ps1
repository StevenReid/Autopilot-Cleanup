function Invoke-DefenderRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [string]$Method = "GET",
        $Body
    )

    if (-not (Connect-DefenderApi)) {
        throw "Not connected to the Defender for Endpoint API"
    }

    $requestParams = @{
        Uri         = $Uri
        Method      = $Method
        Headers     = @{ Authorization = "Bearer $($script:DefenderToken)" }
        ErrorAction = 'Stop'
    }
    if ($Body) {
        $requestParams['Body'] = $Body | ConvertTo-Json -Depth 5
        $requestParams['ContentType'] = "application/json"
    }

    Invoke-RestMethod @requestParams
}

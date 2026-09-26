function Connect-DefenderApi {
    # Defender for Endpoint is a separate API from Microsoft Graph, so it needs its own token.
    # Uses the custom app registration (delegated WindowsDefenderATP Machine.ReadWrite) with an
    # authorization code + PKCE sign-in through the app's http://localhost redirect URI.

    if ($script:DefenderUnavailable) { return $false }

    # Reuse the current token while it has at least 5 minutes left
    if ($script:DefenderToken -and $script:DefenderTokenExpiry -gt (Get-Date).AddMinutes(5)) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($script:CustomClientId)) {
        Write-ColorOutput "Defender tagging skipped: requires a custom app registration (see Configure-AutopilotCleanup)" "Yellow"
        Write-ColorOutput "  with the delegated WindowsDefenderATP API permission 'Machine.ReadWrite'" "Gray"
        $script:DefenderUnavailable = $true
        return $false
    }

    $context = Get-MgContext
    $tenantId = if (-not [string]::IsNullOrWhiteSpace($script:CustomTenantId)) { $script:CustomTenantId } else { $context.TenantId }
    $scope = "https://api.securitycenter.microsoft.com/Machine.ReadWrite offline_access"
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    # Silent renewal when we already hold a refresh token
    if ($script:DefenderRefreshToken) {
        try {
            $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body @{
                client_id     = $script:CustomClientId
                scope         = $scope
                grant_type    = "refresh_token"
                refresh_token = $script:DefenderRefreshToken
            }
            $script:DefenderToken = $tokenResponse.access_token
            $script:DefenderTokenExpiry = (Get-Date).AddSeconds([int]$tokenResponse.expires_in)
            if ($tokenResponse.refresh_token) { $script:DefenderRefreshToken = $tokenResponse.refresh_token }
            return $true
        }
        catch {
            $script:DefenderRefreshToken = $null
        }
    }

    Write-ColorOutput "Connecting to Defender for Endpoint API..." "Yellow"

    $listener = $null
    try {
        # PKCE code verifier and challenge
        $codeVerifier = -join ((48..57) + (65..90) + (97..122) + 45, 46, 95, 126 | Get-Random -Count 64 | ForEach-Object { [char]$_ })
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $codeChallenge = [Convert]::ToBase64String($sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($codeVerifier))) -replace '\+', '-' -replace '/', '_' -replace '=', ''
        $state = [guid]::NewGuid().ToString()

        # Any free port works - Entra ignores the port for http://localhost redirect URIs on public clients
        $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $tcp.Start()
        $port = $tcp.LocalEndpoint.Port
        $tcp.Stop()
        $redirectUri = "http://localhost:$port/"

        $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$($script:CustomClientId)&response_type=code&redirect_uri=$([uri]::EscapeDataString($redirectUri))&response_mode=query&scope=$([uri]::EscapeDataString($scope))&state=$state&code_challenge=$codeChallenge&code_challenge_method=S256"
        if ($context.Account) {
            $authUrl += "&login_hint=$([uri]::EscapeDataString($context.Account))"
        }

        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($redirectUri)
        $listener.Start()

        Write-ColorOutput "  Opening browser for Defender sign-in..." "Cyan"
        Write-ColorOutput "  If the browser doesn't open or sign-in fails, paste this URL into a browser (e.g. an InPrivate window):" "Gray"
        Write-ColorOutput "  $authUrl" "Gray"
        Start-Process $authUrl

        # Wait for the redirect carrying the code (ignore other requests such as favicon)
        $query = @{}
        $deadline = (Get-Date).AddMinutes(3)
        while (-not ($query.code -or $query.error) -and (Get-Date) -lt $deadline) {
            $contextTask = $listener.GetContextAsync()
            $remaining = $deadline - (Get-Date)
            if ($remaining -le [TimeSpan]::Zero -or -not $contextTask.Wait($remaining)) { break }

            $httpContext = $contextTask.Result
            $query = @{}
            foreach ($pair in $httpContext.Request.Url.Query.TrimStart('?').Split('&', [System.StringSplitOptions]::RemoveEmptyEntries)) {
                $parts = $pair.Split('=', 2)
                $value = if ($parts.Count -gt 1) { [uri]::UnescapeDataString($parts[1].Replace('+', ' ')) } else { "" }
                $query[[uri]::UnescapeDataString($parts[0])] = $value
            }

            $html = if ($query.code) {
                "<html><body style='font-family:Segoe UI,Arial;text-align:center;padding-top:80px'><h2>Defender sign-in complete</h2><p>You can close this window and return to PowerShell.</p></body></html>"
            } else {
                "<html><body></body></html>"
            }
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $httpContext.Response.ContentLength64 = $buffer.Length
            $httpContext.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $httpContext.Response.OutputStream.Close()
        }

        if ($query.error) {
            throw "$($query.error): $($query.error_description)"
        }
        if (-not $query.code) {
            throw "Timed out waiting for sign-in"
        }
        if ($query.state -ne $state) {
            throw "State mismatch in sign-in response"
        }

        $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body @{
            client_id     = $script:CustomClientId
            scope         = $scope
            code          = $query.code
            redirect_uri  = $redirectUri
            grant_type    = "authorization_code"
            code_verifier = $codeVerifier
        }

        $script:DefenderToken = $tokenResponse.access_token
        $script:DefenderTokenExpiry = (Get-Date).AddSeconds([int]$tokenResponse.expires_in)
        $script:DefenderRefreshToken = $tokenResponse.refresh_token
        Write-ColorOutput "✓ Connected to Defender for Endpoint API" "Green"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($errorDetails.error_description) { $errorMsg = $errorDetails.error_description }
        Write-ColorOutput "✗ Failed to connect to Defender for Endpoint API: $errorMsg" "Red"
        Write-ColorOutput "  Defender tagging will be skipped for this run" "Yellow"
        $script:DefenderUnavailable = $true
        return $false
    }
    finally {
        if ($listener -and $listener.IsListening) { $listener.Stop() }
    }
}

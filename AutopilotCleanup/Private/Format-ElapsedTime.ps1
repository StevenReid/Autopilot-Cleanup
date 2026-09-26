function Format-ElapsedTime {
    param(
        $Start,
        $End
    )

    # Time between a step starting and finishing as hh:mm:ss for the CSV export
    if (-not $Start) { return "N/A" }
    if (-not $End) { $End = Get-Date }
    return ($End - $Start).ToString("hh\:mm\:ss")
}

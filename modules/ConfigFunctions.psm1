enum IdleTimeConfig {
    Enabled
    Disabled
}

enum ThemeConfig {
    Light
    Dark
}

function WriteGGConfig() {
    param(
        [Parameter(Mandatory)] [string]$Key,
        [Parameter(Mandatory)] [object]$Value
    )

    $ggConfigPath = ".\config.ini"

    if (-Not (Test-Path $ggConfigPath)) {
        New-Item -Path $ggConfigPath -ItemType File -Force | Out-Null
        Log "Created config file at $ggConfigPath"
    }

    $content = Get-Content -Path $ggConfigPath -Raw
    $pattern = "(?m)^$Key\s*=\s*.+$"

    if ($content -match $pattern) {
        $newContent = $content -replace $pattern, "$Key=$Value"
    }
    else {
        $newContent = $content + "$Key=$Value`n"
    }

    Set-Content -Path $ggConfigPath -Value $newContent -Force -NoNewline
    Log "Config updated: $Key=$Value"
}

function ReadGGConfig() {
    param(
        [Parameter(Mandatory)] [string]$Key,
        [type]$AsType = [string] # Defaults to string if no enum type is provided
    )

    $ggConfigPath = ".\config.ini"

    if (-Not (Test-Path $ggConfigPath)) {
        Log "Config file not found at $ggConfigPath"
        return $null
    }

    $content = Get-Content -Path $ggConfigPath -Raw
    $pattern = "(?m)^$Key\s*=\s*(.+)$"

    if ($content -match $pattern) {
        $rawValue = $Matches[1].Trim()
        
        # If a specific type (like an Enum) was requested, convert it here
        if ($AsType -ne [string]) {
            return [Enum]::Parse($AsType, $rawValue, $true)
        }
        return $rawValue
    }

    return $null
}
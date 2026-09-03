#requires -Version 7.5
# =============================================================================
#  Localization.ps1 — Application localization system
#  Version: 0.2
#  Description: Loads language resources, detects system language,
#               provides translation functions for UI elements.
#               Supports dynamic language files (strings.??.json).
# =============================================================================

# === Constants ===
 $script:LocalizationDir = Join-Path $PSScriptRoot ".." "localization"
 $script:CurrentLanguage = "en"
 $script:Strings = @{}
 $script:AvailableLanguages = @()

# --- Detect system language ---
function Get-SystemLanguage {
    <#
    .SYNOPSIS
        Detects the current system UI language.
        Returns two-letter ISO code (e.g., 'ru', 'en', 'fr').
    #>
    $cult = [System.Globalization.CultureInfo]::CurrentUICulture
    return $cult.TwoLetterISOLanguageName
}

# --- Load localization strings ---
function Initialize-Localization {
    <#
    .SYNOPSIS
        Initializes localization. Loads English as fallback,
        then merges the system language if available.
    #>
    param(
        [string]$LanguageCode = (Get-SystemLanguage)
    )
    
    $enPath = Join-Path $script:LocalizationDir "strings.en.json"
    if (-not (Test-Path -LiteralPath $enPath)) {
        throw "Critical Error: English localization file (strings.en.json) not found in $script:LocalizationDir"
    }

    # Load English as base
    $script:Strings = @{}
    $enJson = Get-Content -LiteralPath $enPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    foreach ($k in $enJson.Keys) { $script:Strings[$k] = $enJson[$k] }
    
    $script:CurrentLanguage = "en"

    # Scan for available languages (strings.??.json)
    $script:AvailableLanguages = @("en")
    $files = Get-ChildItem -Path $script:LocalizationDir -Filter "strings.??.json" -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $code = $f.BaseName.Split('.')[1]
        if ($code -ne "en" -and $script:AvailableLanguages -notcontains $code) {
            $script:AvailableLanguages += $code
        }
    }

    $null = Set-Language -LanguageCode $LanguageCode -ShowWarningIfMissing
}

# --- Get localized string by key ---
function Get-String {
    <#
    .SYNOPSIS
        Returns a localized string by key.
        Supports parameter replacement: $1, $2, etc.
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$Params
    )
    
    if ($script:Strings.ContainsKey($Key)) {
        $text = $script:Strings[$Key]
        if ($Params -and $Params.Count -gt 0) {
            for ($i = 0; $i -lt $Params.Count; $i++) {
                $text = $text.Replace("`$$($i + 1)", [string]$Params[$i])
            }
        }
        return $text
    }
    
    # Fallback: return key
    Write-Warning "Missing localization key: $Key"
    return $Key
}

# --- Change current language ---
function Set-Language {
    <#
    .SYNOPSIS
        Changes the current UI language.
        Merges specific language over English base.
    #>
    param(
        [Parameter(Mandatory)][string]$LanguageCode,
        [switch]$ShowWarningIfMissing
    )
    
    $enPath = Join-Path $script:LocalizationDir "strings.en.json"
    if (-not (Test-Path -LiteralPath $enPath)) { return $false }

    # Reset to English base
    $script:Strings = @{}
    $enJson = Get-Content -LiteralPath $enPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    foreach ($k in $enJson.Keys) { $script:Strings[$k] = $enJson[$k] }
    
    $script:CurrentLanguage = "en"
    
    if ($LanguageCode -eq "en") { return $true }
    
    $langPath = Join-Path $script:LocalizationDir "strings.$LanguageCode.json"
    
    if (Test-Path -LiteralPath $langPath) {
        $langJson = Get-Content -LiteralPath $langPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
        # Merge: overwrite English values with specific language values
        foreach ($k in $langJson.Keys) { $script:Strings[$k] = $langJson[$k] }
        $script:CurrentLanguage = $LanguageCode
        return $true
    } else {
        if ($ShowWarningIfMissing) {
            Write-Host "System language: $(Get-SystemLanguage), localization file 'strings.$LanguageCode.json' is missing. Using English."
        }
        return $false
    }
}

# --- Get list of supported languages for UI ---
function Get-LanguageList {
    <#
    .SYNOPSIS
        Returns a hashtable of available languages (Code -> NativeName).
    #>
    $result = @{}
    foreach ($code in $script:AvailableLanguages) {
        try {
            $culture = [System.Globalization.CultureInfo]::GetCultureInfo($code)
            $result[$code] = $culture.NativeName
        } catch {
            $result[$code] = $code.ToUpper()
        }
    }
    return $result
}

# --- Get current language code ---
function Get-CurrentLanguage {
    return $script:CurrentLanguage
}


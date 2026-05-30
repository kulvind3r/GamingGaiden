# --- CONFIGURATION ---
$srcDir    = "src"
$buildDir  = "build"
$resDir    = "resources"
$indexFile = "index.html"

# JS and CSS assets to fingerprint (cache-bust on content change)
$fingerprintFiles = @("script.js", "style.css")

# Assets copied as-is (no fingerprinting needed)
$copyFiles = @("favicon.ico", "banner.png")

Write-Host "[BUILD] Starting Gaming Gaiden website build..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------"

# --- CLEAN & PREPARE BUILD DIRECTORIES ---
if (Test-Path $buildDir) {
    Write-Host "[CLEAN] Wiping existing '$buildDir' directory..."
    Remove-Item -Recurse -Force $buildDir | Out-Null
}
Write-Host "[DIR] Creating fresh '$buildDir' and subdirectories..."
New-Item -ItemType Directory -Path "$buildDir/$resDir/screenshots" -Force | Out-Null

# --- COPY INDEX.HTML ---
$srcIndexPath   = "$srcDir/$indexFile"
$buildIndexPath = "$buildDir/$indexFile"

if (-not (Test-Path $srcIndexPath)) {
    Write-Host "[ERROR] $indexFile not found in $srcDir!" -ForegroundColor Red
    Pause
    exit
}
Write-Host "[COPY] Copying $indexFile to $buildDir..."
Copy-Item $srcIndexPath $buildIndexPath

# --- COPY content.json ---
$contentSrc = "$srcDir/content.json"
if (Test-Path $contentSrc) {
    Write-Host "[COPY] Copying content.json..."
    Copy-Item $contentSrc "$buildDir/content.json"
} else {
    Write-Host "[WARN] content.json not found - skipping." -ForegroundColor Yellow
}

# --- COPY UNFINGERPRINTED ASSETS ---
foreach ($file in $copyFiles) {
    $srcPath = "$srcDir/$resDir/$file"
    if (Test-Path $srcPath) {
        Write-Host "[COPY] $resDir/$file"
        Copy-Item $srcPath "$buildDir/$resDir/$file"
    } else {
        Write-Host "[WARN] File not found: $srcPath - Skipping." -ForegroundColor Yellow
    }
}

# --- COPY SCREENSHOTS ---
$screenshotSrc = "$srcDir/$resDir/screenshots"
if (Test-Path $screenshotSrc) {
    $screenshots = Get-ChildItem $screenshotSrc -File
    if ($screenshots.Count -gt 0) {
        Write-Host "[COPY] Copying $($screenshots.Count) screenshot(s)..."
        Copy-Item "$screenshotSrc/*" "$buildDir/$resDir/screenshots/" -Recurse
    } else {
        Write-Host "[INFO] No screenshots found - directory created but empty."
    }
}

# --- FINGERPRINT JS & CSS ---
Write-Host "[BUILD] Processing fingerprinted assets..."

foreach ($file in $fingerprintFiles) {
    $srcPath = "$srcDir/$resDir/$file"

    if (Test-Path $srcPath) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $ext  = [System.IO.Path]::GetExtension($file)

        $hash = (Get-FileHash $srcPath -Algorithm SHA256).Hash.Substring(0, 8).ToLower()
        $newFileName = "$name.$hash$ext"

        Write-Host "[PROCESS] $resDir/$file -> $resDir/$newFileName"
        Copy-Item $srcPath "$buildDir/$resDir/$newFileName"

        $content = Get-Content $buildIndexPath -Raw
        $pattern = "$resDir/$name(\.[a-fA-F0-9]+)?$ext"
        $replacement = "$resDir/$newFileName"
        $content -replace $pattern, $replacement | Set-Content $buildIndexPath
    } else {
        Write-Host "[WARN] File not found: $srcPath - Skipping." -ForegroundColor Yellow
    }
}

Write-Host "--------------------------------------------------"
Write-Host "[BUILD] Production build created in '$buildDir'!" -ForegroundColor Green

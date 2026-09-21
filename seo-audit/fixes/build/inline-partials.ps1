<#
.SYNOPSIS
    One-time (repeatable) header/footer inliner for core-asset-sol.com — Windows edition.

.DESCRIPTION
    Writes the real contents of partials\header.html and partials\footer.html directly into
    every page's HTML, so the navigation ships in the served markup instead of being fetched
    by app.js at runtime.

    Built for the way you actually work: a local folder of static HTML, uploaded straight to
    Cloudflare Pages. No GitHub, no build pipeline, no Node, no CI. You run this on your PC
    whenever you change the header or footer, then upload.

    It FILLS the placeholder <div>s rather than replacing them, because assets\app.js needs
    both wrappers to survive:
      - loadPartial() looks up getElementById('header-placeholder'). If the element is gone it
        returns early and initHeaderChrome() never runs, breaking the mobile menu button.
      - adjustFooter() selects '#footer-placeholder .site-footer'. Remove the wrapper and
        footer spacing silently dies.

    Safe to re-run. A page whose placeholder is already filled is skipped, so running it twice
    does not duplicate the nav.

.PARAMETER Source
    Folder containing your site (the one with index.html and the partials subfolder).
    Defaults to the current folder.

.PARAMETER Backup
    Copy each file to <name>.html.bak before editing. On by default. -Backup:$false to skip.

.PARAMETER Check
    Report only. Changes nothing. Use it to confirm a folder is fully inlined before uploading.

.EXAMPLE
    .\inline-partials.ps1 -Source "C:\Users\Will\core-asset-solutions"

.EXAMPLE
    .\inline-partials.ps1 -Source "C:\...\site" -Check

.NOTES
    If Windows blocks the script:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[CmdletBinding()]
param(
    [string]$Source = ".",
    [switch]$Backup = $true,
    [switch]$Check
)

$ErrorActionPreference = "Stop"

function Say([string]$m, [string]$c = "Gray") { Write-Host $m -ForegroundColor $c }

$Source = (Resolve-Path $Source).Path
$headerFile = Join-Path $Source "partials\header.html"
$footerFile = Join-Path $Source "partials\footer.html"

Say ""
Say "Source folder : $Source" "Cyan"

foreach ($f in @($headerFile, $footerFile)) {
    if (-not (Test-Path $f)) {
        Say "FATAL: missing $f" "Red"
        Say "Expected a 'partials' subfolder containing header.html and footer.html." "Red"
        exit 1
    }
}

$header = (Get-Content $headerFile -Raw).Trim()
$footer = (Get-Content $footerFile -Raw).Trim()
Say ("header.html   : {0:N0} chars" -f $header.Length)
Say ("footer.html   : {0:N0} chars" -f $footer.Length)

# Captures: 1 = opening div tag, 2 = current inner content, 3 = closing tag
$headerRe = '(?is)(<div\s+id="header-placeholder"[^>]*>)(.*?)(</div>)'
$footerRe = '(?is)(<div\s+id="footer-placeholder"[^>]*>)(.*?)(</div>)'

# Skip the partials folder itself and anything already backed up.
# Match either path separator so the script behaves the same on Windows and elsewhere.
$files = Get-ChildItem -Path $Source -Filter *.html -Recurse -File |
         Where-Object { $_.FullName -notmatch '[\\/]partials[\\/]' -and $_.Name -notmatch '\.bak$' }

Say ("HTML files    : {0}" -f $files.Count)
Say ""

$filled = 0; $already = 0; $noPlaceholder = @(); $emptyStill = @()

foreach ($f in $files) {
    $rel  = $f.FullName.Substring($Source.Length).TrimStart('\')
    $html = Get-Content $f.FullName -Raw
    $orig = $html

    $hm = [regex]::Match($html, $headerRe)
    $fm = [regex]::Match($html, $footerRe)

    if (-not $hm.Success -and -not $fm.Success) { $noPlaceholder += $rel; continue }

    if ($Check) {
        $bad = $false
        if ($hm.Success -and [string]::IsNullOrWhiteSpace($hm.Groups[2].Value)) { $bad = $true }
        if ($fm.Success -and [string]::IsNullOrWhiteSpace($fm.Groups[2].Value)) { $bad = $true }
        if ($bad) { $emptyStill += $rel }
        continue
    }

    $did = $false

    if ($hm.Success -and [string]::IsNullOrWhiteSpace($hm.Groups[2].Value)) {
        $repl = $hm.Groups[1].Value + "`r`n" + $header + "`r`n" + $hm.Groups[3].Value
        $html = $html.Remove($hm.Index, $hm.Length).Insert($hm.Index, $repl)
        $did = $true
    }

    # Re-match: indexes shifted after the header insert.
    $fm = [regex]::Match($html, $footerRe)
    if ($fm.Success -and [string]::IsNullOrWhiteSpace($fm.Groups[2].Value)) {
        $repl = $fm.Groups[1].Value + "`r`n" + $footer + "`r`n" + $fm.Groups[3].Value
        $html = $html.Remove($fm.Index, $fm.Length).Insert($fm.Index, $repl)
        $did = $true
    }

    if ($did) {
        if ($Backup) { Copy-Item $f.FullName "$($f.FullName).bak" -Force }
        # UTF8 without BOM — a BOM before <!doctype> can upset some parsers.
        [IO.File]::WriteAllText($f.FullName, $html, (New-Object Text.UTF8Encoding $false))
        Say ("  filled   {0}" -f $rel) "Green"
        $filled++
    } else {
        $already++
    }
}

Say ""
if ($Check) {
    if ($emptyStill.Count -eq 0) {
        Say ("OK: no empty placeholders across {0} HTML files." -f $files.Count) "Green"
        exit 0
    }
    Say ("FAIL: {0} file(s) still have an EMPTY placeholder:" -f $emptyStill.Count) "Red"
    $emptyStill | ForEach-Object { Say ("   {0}" -f $_) "Red" }
    exit 1
}

Say ("Filled            : {0}" -f $filled) "Green"
Say ("Already inlined   : {0}" -f $already)
if ($noPlaceholder.Count) {
    Say ("No placeholder    : {0}" -f $noPlaceholder.Count) "Yellow"
    $noPlaceholder | Select-Object -First 15 | ForEach-Object { Say ("   {0}" -f $_) "Yellow" }
    Say "   (usually intentional - check these are meant to have no header/footer)" "DarkYellow"
}
if ($Backup -and $filled -gt 0) { Say "Backups written as <file>.html.bak" "DarkGray" }

Say ""
Say "NEXT STEPS" "Cyan"
Say "  1. Apply the three-line loadPartial change in assets\app.js (see app.js.patch.md)"
Say "     so the browser does not re-fetch what is now inlined."
Say "  2. Spot-check a page in a browser: mobile menu opens, footer spacing looks right."
Say "  3. Remove 'Disallow: /partials/' from robots.txt."
Say "  4. Upload the folder to Cloudflare Pages."
Say "  5. Confirm with:  .\verify.ps1 -Only P2-1"
Say ""
Say "IMPORTANT: re-run this script every time you edit partials\header.html or" "Yellow"
Say "partials\footer.html. Editing the partial no longer updates the pages by itself." "Yellow"
Say "Delete the .bak files once you are happy, and do not upload them." "Yellow"
Say ""

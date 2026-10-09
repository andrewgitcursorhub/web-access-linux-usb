<#
.SYNOPSIS
    Windows / PowerShell version of verify.sh — re-runs every check from the audit against
    the live core-asset-sol.com site.

.DESCRIPTION
    Works in Windows PowerShell 5.1 (built into Windows, nothing to install) and in
    PowerShell 7+. Uses System.Net.HttpWebRequest rather than Invoke-WebRequest so redirects
    and error statuses read cleanly on both versions.

.EXAMPLE
    .\verify.ps1

.EXAMPLE
    # One section only
    .\verify.ps1 -Only P2-1

.NOTES
    If Windows blocks the script, allow it for this session only:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[CmdletBinding()]
param(
    [string]$Site = "https://core-asset-sol.com",
    [string]$Only = ""
)

$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$UA = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

$script:Pass = 0
$script:Fail = 0

function Write-Head([string]$t) { Write-Host ""; Write-Host $t -ForegroundColor White -BackgroundColor DarkBlue }
function Write-Ok([string]$m)   { Write-Host "  PASS  " -ForegroundColor Green -NoNewline; Write-Host $m; $script:Pass++ }
function Write-Bad([string]$m)  { Write-Host "  FAIL  " -ForegroundColor Red   -NoNewline; Write-Host $m; $script:Fail++ }
function Write-Info([string]$m) { Write-Host "        $m" -ForegroundColor DarkGray }

function Should-Run([string]$tag) {
    if ([string]::IsNullOrWhiteSpace($Only)) { return $true }
    return $tag -like "*$Only*"
}

# Never throws. Returns Status / Location / Body / Headers.
function Get-Url {
    param([string]$Url, [switch]$Follow, [switch]$IncludeBody, [int]$TimeoutSec = 30)
    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.UserAgent         = $UA
        $req.AllowAutoRedirect = [bool]$Follow
        $req.Timeout           = $TimeoutSec * 1000
        $req.ReadWriteTimeout  = $TimeoutSec * 1000
        $req.Method            = "GET"
        $resp = $req.GetResponse()
        $body = ""
        if ($IncludeBody) { $sr = New-Object IO.StreamReader($resp.GetResponseStream()); $body = $sr.ReadToEnd(); $sr.Close() }
        $out = [pscustomobject]@{ Status=[int]$resp.StatusCode; Location=$resp.Headers["Location"]; Body=$body; Headers=$resp.Headers; Error=$null }
        $resp.Close(); return $out
    } catch [System.Net.WebException] {
        $r = $_.Exception.Response
        if ($r) {
            $body = ""
            if ($IncludeBody) { try { $sr = New-Object IO.StreamReader($r.GetResponseStream()); $body = $sr.ReadToEnd(); $sr.Close() } catch {} }
            $out = [pscustomobject]@{ Status=[int]$r.StatusCode; Location=$r.Headers["Location"]; Body=$body; Headers=$r.Headers; Error=$null }
            $r.Close(); return $out
        }
        return [pscustomobject]@{ Status=0; Location=$null; Body=""; Headers=$null; Error=$_.Exception.Message }
    } catch {
        return [pscustomobject]@{ Status=0; Location=$null; Body=""; Headers=$null; Error=$_.Exception.Message }
    }
}

function Get-JsonField([string]$Html, [string]$Field) {
    $m = [regex]::Match($Html, ('"{0}"\s*:\s*"([^"]+)"' -f $Field))
    if ($m.Success) { return $m.Groups[1].Value } else { return "" }
}

Write-Host ""
Write-Host "Verifying $Site" -ForegroundColor Cyan
Write-Host ("Started {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) -ForegroundColor DarkGray

$homePage = Get-Url "$Site/" -Follow -IncludeBody     # NB: never name this $home, $HOME is read-only

# ------------------------------------------------------------------ P0-1
if (Should-Run "P0-1") {
    Write-Head "P0-1  Homepage business entity is a valid schema.org type"
    if ($homePage.Body -match '"@type"\s*:\s*"Recycling Center"') {
        Write-Bad 'homepage still declares "Recycling Center" - schema.org type names cannot contain spaces'
    } elseif ($homePage.Body -match '"@type"\s*:\s*"RecyclingCenter"') {
        Write-Ok "homepage declares RecyclingCenter (valid)"
    } else { Write-Bad "no RecyclingCenter entity found on the homepage" }
}

# ------------------------------------------------------------------ P0-2
if (Should-Run "P0-2") {
    Write-Head "P0-2  Every JSON-LD block parses as valid JSON"
    $p = Get-Url "$Site/specialty-equipment-we-handle" -Follow -IncludeBody
    $blocks = [regex]::Matches($p.Body, '(?is)<script[^>]+application/ld\+json[^>]*>(.*?)</script>')
    $bad = 0
    for ($i = 0; $i -lt $blocks.Count; $i++) {
        try { $null = $blocks[$i].Groups[1].Value | ConvertFrom-Json }
        catch { Write-Bad ("/specialty-equipment-we-handle JSON-LD block #{0}: {1}" -f ($i+1), $_.Exception.Message); $bad++ }
    }
    if ($bad -eq 0) { Write-Ok ("all {0} JSON-LD blocks parse" -f $blocks.Count) }
}

# ------------------------------------------------------------------ sitemap
$sm = Get-Url "$Site/sitemap.xml" -Follow -IncludeBody
$smUrls = @([regex]::Matches($sm.Body, '<loc>\s*([^<]+?)\s*</loc>') | ForEach-Object { $_.Groups[1].Value })

if (Should-Run "P0-3") {
    Write-Head "P0-3  Sitemap contains no redirecting or non-200 URLs"
    Write-Info ("sitemap declares {0} URLs" -f $smUrls.Count)
    $smBad = 0
    foreach ($u in $smUrls) { $r = Get-Url $u; if ($r.Status -ne 200) { Write-Bad ("sitemap URL returns {0}: {1}" -f $r.Status, $u); $smBad++ } }
    if ($smBad -eq 0) { Write-Ok "every sitemap URL returns 200 directly (no redirects)" }
}

# ------------------------------------------------------------------ P0-4
if (Should-Run "P0-4") {
    Write-Head "P0-4  www resolves, 301s to the apex, preserves the path, lands on a 200"
    foreach ($p in @("/", "/contact", "/services/itad")) {
        $r = Get-Url "https://www.core-asset-sol.com$p"
        $want = "https://core-asset-sol.com$p"
        if ($r.Status -eq 0)           { Write-Bad ("www{0} did not respond: {1}" -f $p, $r.Error) }
        elseif ($r.Status -ne 301)     { Write-Bad ("www{0} returned {1} (expected 301)" -f $p, $r.Status) }
        elseif ($r.Location -match ':splat|\$\{\d\}|\*') { Write-Bad ("www{0} 301s to an UNINTERPOLATED PLACEHOLDER: {1}" -f $p, $r.Location) }
        elseif ($r.Location -ne $want) { Write-Bad ("www{0} 301s to {1} (expected {2})" -f $p, $r.Location, $want) }
        else {
            $f = Get-Url "https://www.core-asset-sol.com$p" -Follow
            if ($f.Status -eq 200) { Write-Ok ("www{0} -> 301 -> {1} -> 200" -f $p, $r.Location) }
            else { Write-Bad ("www{0} 301s correctly but destination returns {1}" -f $p, $f.Status) }
        }
    }
    $q = Get-Url "https://www.core-asset-sol.com/services?utm_source=test&x=1"
    if ($q.Location -like "*utm_source=test*") { Write-Ok "query string preserved through the www redirect" }
    else { Write-Bad ("query string lost: {0}" -f $q.Location) }
    $h = Get-Url "http://www.core-asset-sol.com/"
    if ($h.Status -eq 301) { Write-Ok "http://www 301s (no 522)" } else { Write-Bad ("http://www returns {0} (expected 301)" -f $h.Status) }
}

# ------------------------------------------------------------------ P1-1
if (Should-Run "P1-1") {
    Write-Head "P1-1  Query-string URLs are 200+canonical or 301, never 302"
    $qbad = 0
    foreach ($q in @("ref=x","utm_source=g","gclid=abc","fbclid=xyz","page=2","a=1&b=2")) {
        $r = Get-Url "$Site/services?$q"
        if ($r.Status -eq 302) { Write-Bad ("?{0} returns 302 temporary - should be 200+canonical or 301" -f $q); $qbad++ }
        elseif ($r.Status -notin @(200,301)) { Write-Bad ("?{0} returns {1}" -f $q, $r.Status); $qbad++ }
    }
    if ($qbad -eq 0) { Write-Ok "all tested query-string forms return 200 or 301 (no 302s)" }
}

# ------------------------------------------------------------------ P1-2 / P1-3
if (Should-Run "P1-2") {
    Write-Head "P1-2  The 404 template does not return HTTP 200"
    $r = Get-Url "$Site/404"
    if ($r.Status -eq 200) { Write-Bad "/404 returns 200 (soft 404)" } else { Write-Ok ("/404 returns {0}" -f $r.Status) }
    $r = Get-Url "$Site/this-page-really-does-not-exist-98765"
    if ($r.Status -eq 404) { Write-Ok "unknown URLs correctly return 404" } else { Write-Bad ("unknown URL returned {0}" -f $r.Status) }
}
if (Should-Run "P1-3") {
    Write-Head "P1-3  Previously-404ing PDF now resolves"
    $r = Get-Url "$Site/resources/Certificate-Of-Destruction.pdf" -Follow
    if ($r.Status -eq 200) { Write-Ok "Certificate-Of-Destruction.pdf resolves" }
    else { Write-Bad ("Certificate-Of-Destruction.pdf returns {0} (the real file uses underscores)" -f $r.Status) }
}

# ------------------------------------------------------------------ P1-4
if (Should-Run "P1-4") {
    Write-Head "P1-4  Navigation partials are not indexable, and not robots-blocked"
    foreach ($p in @("/partials/header","/partials/footer")) {
        $r = Get-Url "$Site$p"
        $xr = if ($r.Headers) { $r.Headers["X-Robots-Tag"] } else { $null }
        if ($xr -and $xr -match "noindex") { Write-Ok ("{0} sends X-Robots-Tag noindex" -f $p) }
        else { Write-Bad ("{0} has no noindex X-Robots-Tag" -f $p) }
    }
    $rb = Get-Url "$Site/robots.txt" -Follow -IncludeBody
    $homeHasPlaceholder = $homePage.Body -match 'id="(header|footer)-placeholder"'
    if ($rb.Body -match '(?im)^\s*Disallow:\s*/partials/') {
        if ($homeHasPlaceholder) {
            Write-Bad "robots.txt blocks /partials/ WHILE the nav is still client-side injected - Googlebot can see no navigation at all. Remove the Disallow line."
        } else {
            Write-Ok "robots.txt blocks /partials/ (safe now that the nav is inlined)"
        }
    } else { Write-Ok "robots.txt does not block /partials/" }
}

# ------------------------------------------------------------------ P1-6 / P1-7
if (Should-Run "P1-6") {
    Write-Head "P1-6  Previously-orphaned pages are in the sitemap"
    foreach ($p in @("/privacy","/terms","/sitemap")) {
        if ($smUrls -contains "$Site$p") { Write-Ok ("{0} is in the sitemap" -f $p) } else { Write-Bad ("{0} is missing from the sitemap" -f $p) }
    }
    Write-Head "P1-7  Sitemap carries lastmod"
    if ($sm.Body -match "<lastmod>") { Write-Ok "sitemap has <lastmod>" } else { Write-Bad "sitemap has no <lastmod>" }
}

# ------------------------------------------------------------------ P2-1
if (Should-Run "P2-1") {
    Write-Head "P2-1  Header and footer are in the served HTML"
    if ($homePage.Body -match 'id="header-placeholder"\s*>\s*<') { Write-Bad "header placeholder is EMPTY - nav is injected client-side, Googlebot sees zero nav links" }
    else { Write-Ok "header content is present in the served HTML" }
    if ($homePage.Body -match 'id="footer-placeholder"\s*>\s*<') { Write-Bad "footer placeholder is EMPTY - footer is injected client-side" }
    else { Write-Ok "footer content is present in the served HTML" }
    $links = ([regex]::Matches($homePage.Body, 'href="(/[^"#]*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique).Count
    if ($links -ge 30) { Write-Ok ("homepage exposes {0} unique internal links in raw HTML" -f $links) }
    else { Write-Bad ("homepage exposes only {0} unique internal links in raw HTML (expect 40+ once inlined)" -f $links) }
}

# ------------------------------------------------------------------ P2-2
if (Should-Run "P2-2") {
    Write-Head "P2-2  sameAs lists all four live social profiles"
    foreach ($s in @("linkedin.com/company/coreassetsolutions","facebook.com/CoreAssetSolutions","instagram.com/coreassetsolutions","x.com/coreassetsol")) {
        if ($homePage.Body -like "*$s*") { Write-Ok ("sameAs includes {0}" -f $s) } else { Write-Bad ("sameAs is missing {0}" -f $s) }
    }
}

# ------------------------------------------------------------------ P2-3  NAP
if (Should-Run "P2-3") {
    Write-Head "P2-3  NAP is consistent across pages"
    $contact = Get-Url "$Site/contact" -Follow -IncludeBody
    foreach ($fld in @("streetAddress","addressLocality","addressRegion","postalCode","telephone")) {
        $v1 = Get-JsonField $homePage.Body $fld
        $v2 = Get-JsonField $contact.Body  $fld
        if (-not $v1 -and -not $v2) { continue }
        if ($v1 -eq $v2) { Write-Ok ("{0} matches: {1}" -f $fld, $v1) }
        else { Write-Bad ("{0} DIFFERS - home='{1}' contact='{2}'" -f $fld, $(if($v1){$v1}else{"<none>"}), $(if($v2){$v2}else{"<none>"})) }
    }
    $street = Get-JsonField $homePage.Body "streetAddress"
    $vis = [regex]::Replace([regex]::Replace($contact.Body,'(?is)<script[\s\S]*?</script>',' '),'<[^>]+>',' ')
    if ($street -and $vis -like "*$street*") { Write-Ok "schema streetAddress also appears verbatim in visible text" }
    else { Write-Bad ("schema streetAddress '{0}' does NOT appear verbatim in the visible text of /contact" -f $street) }
}

# ------------------------------------------------------------------ P2-4  GBP
if (Should-Run "P2-4") {
    Write-Head "P2-4  Google Business Profile is linked from structured data"
    if ($homePage.Body -match '"hasMap"') { Write-Ok "homepage declares hasMap" }
    else { Write-Bad "no hasMap - the Google Business Profile is not linked in structured data" }
}

# ------------------------------------------------------------------ P2-5  entity coverage
if (Should-Run "P2-5") {
    Write-Head "P2-5  A COMPLETE business entity ships on every page"
    $full = 0; $stub = 0; $none = 0
    foreach ($u in $smUrls) {
        $pb = (Get-Url $u -Follow -IncludeBody).Body
        $hasFull = $false; $hasAny = $false
        foreach ($m in [regex]::Matches($pb, '(?is)<script[^>]+application/ld\+json[^>]*>(.*?)</script>')) {
            $raw = $m.Groups[1].Value
            if ($raw -match '"@type"\s*:\s*"(RecyclingCenter|LocalBusiness|Organization)"') {
                $hasAny = $true
                if ($raw -match '"address"\s*:') { $hasFull = $true }
            }
        }
        if ($hasFull) { $full++ } elseif ($hasAny) { $stub++ } else { $none++ }
    }
    if ($full -eq $smUrls.Count) { Write-Ok ("all {0} pages carry a complete business entity" -f $smUrls.Count) }
    else { Write-Bad ("only {0} of {1} pages carry a COMPLETE business entity ({2} have a bare stub, {3} have nothing) - ship _business-node.jsonld site-wide" -f $full, $smUrls.Count, $stub, $none) }
}

# ------------------------------------------------------------------ canonicals
if (Should-Run "canonical") {
    Write-Head "Canonical integrity across every sitemap URL"
    $cbad = 0
    foreach ($u in $smUrls) {
        $r = Get-Url $u -Follow -IncludeBody
        $m = [regex]::Match($r.Body, '(?is)<link[^>]*rel="canonical"[^>]*>|<link[^>]*canonical[^>]*>')
        $can = if ($m.Success) { ([regex]::Match($m.Value,'href="([^"]+)"')).Groups[1].Value } else { "" }
        if ($can -ne $u) { Write-Bad ("canonical mismatch on {0} -> {1}" -f $u, $(if($can){$can}else{"<none>"})); $cbad++ }
    }
    if ($cbad -eq 0) { Write-Ok ("all {0} sitemap URLs self-canonicalise correctly" -f $smUrls.Count) }
}

# ------------------------------------------------------------------ FAQ visibility
if (Should-Run "FAQ") {
    Write-Head "FAQ answers are present in the rendered HTML"
    $faqBad = 0
    foreach ($u in $smUrls) {
        $r = Get-Url $u -Follow -IncludeBody
        $vis = [regex]::Replace([regex]::Replace($r.Body,'(?is)<script[\s\S]*?</script>',' '),'<[^>]+>',' ')
        $vis = [regex]::Replace($vis,'\s+',' ')
        foreach ($m in [regex]::Matches($r.Body, '(?is)<script[^>]+application/ld\+json[^>]*>(.*?)</script>')) {
            if ($m.Groups[1].Value -notmatch '"FAQPage"') { continue }
            try { $j = $m.Groups[1].Value | ConvertFrom-Json } catch { continue }
            $qs = @($j.mainEntity); $missing = 0
            foreach ($q in $qs) {
                $a = $null; try { $a = $q.acceptedAnswer.text } catch {}
                if (-not $a) { continue }
                $probe = ([regex]::Replace($a,'\s+',' '))
                if ($probe.Length -gt 55) { $probe = $probe.Substring(0,55) }
                if ($vis -notlike "*$probe*") { $missing++ }
            }
            if ($missing -gt 0) { Write-Bad ("{0}: {1} of {2} FAQ answers are NOT in the page HTML" -f $u, $missing, $qs.Count); $faqBad++ }
        }
    }
    if ($faqBad -eq 0) { Write-Ok "every FAQ answer appears in its page's rendered HTML" }
}

# ------------------------------------------------------------------ summary
Write-Host ""
Write-Host "SUMMARY  " -NoNewline
Write-Host ("{0} passed" -f $script:Pass) -ForegroundColor Green -NoNewline
Write-Host ", " -NoNewline
Write-Host ("{0} failed" -f $script:Fail) -ForegroundColor $(if ($script:Fail -gt 0) { "Red" } else { "Green" })
Write-Host ""
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

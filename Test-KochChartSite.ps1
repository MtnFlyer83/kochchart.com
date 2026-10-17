# KochChart static-site link and asset checker (read-only)
# Usage: .\Test-KochChartSite.ps1 -SiteRoot 'C:\git\KochChart.com'
param(
    [string]$SiteRoot = 'C:\git\KochChart.com',
    [switch]$CheckExternal
)

$ErrorActionPreference = 'Stop'
$SiteRoot = [IO.Path]::GetFullPath($SiteRoot)
if (-not (Test-Path -LiteralPath $SiteRoot -PathType Container)) {
    throw "Site directory not found: $SiteRoot"
}

$pages = @(Get-ChildItem -LiteralPath $SiteRoot -Recurse -File | Where-Object {
    $_.FullName -notmatch '[\\/](\.git|\.vs|node_modules)[\\/]' -and $_.Extension.ToLowerInvariant() -in @('.html','.htm','.css')
})

$issues = [System.Collections.Generic.List[object]]::new()
$externals = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$checked = 0
foreach ($page in $pages) {
    $content = Get-Content -LiteralPath $page.FullName -Raw
    # Covers HTML src/href/poster/srcset-independent common refs and CSS url()/@import.
    $matches = @([regex]::Matches($content, '(?is)\b(?:src|href|poster)\s*=\s*["'']([^"'']+)["'']')) +
               @([regex]::Matches($content, '(?is)url\(\s*["'']?([^\)"'']+)["'']?\s*\)')) +
               @([regex]::Matches($content, '(?im)@import\s+["'']([^"'']+)["'']'))
    foreach ($match in $matches) {
        $ref = $match.Groups[1].Value.Trim()
        if (-not $ref -or $ref.StartsWith('#') -or $ref -match '^(?i)(data:|mailto:|tel:|javascript:|blob:)') { continue }
        if ($ref -match '^(?i)https?://') {
            [void]$externals.Add($ref)
            continue
        }
        if ($ref.StartsWith('//')) { [void]$externals.Add('https:' + $ref); continue }
        # Strip anchors and query params, then decode URL escapes.
        $plain = ($ref -split '[?#]',2)[0]
        $plain = [uri]::UnescapeDataString($plain) -replace '/', [IO.Path]::DirectorySeparatorChar
        if (-not $plain) { continue }
        if ($plain.StartsWith([IO.Path]::DirectorySeparatorChar)) {
            $target = Join-Path $SiteRoot $plain.TrimStart([IO.Path]::DirectorySeparatorChar)
        } else {
            $target = Join-Path $page.DirectoryName $plain
        }
        $checked++
        if (-not (Test-Path -LiteralPath $target)) {
            $issues.Add([pscustomobject]@{
                File = $page.FullName.Substring($SiteRoot.Length).TrimStart('\','/')
                Reference = $ref
                Problem = 'Missing local file'
            })
        }
    }
}

Write-Host "Site: $SiteRoot"
Write-Host "HTML/CSS files inspected: $($pages.Count)"
Write-Host "Local references checked: $checked"
Write-Host "External URLs found: $($externals.Count)"
Write-Host "Missing local references: $($issues.Count)" -ForegroundColor $(if($issues.Count){'Yellow'}else{'Green'})
if ($issues.Count) { $issues | Sort-Object File,Reference -Unique | Format-Table -AutoSize -Wrap }

if ($CheckExternal) {
    Write-Host "`nChecking external URLs (some servers reject automated requests):"
    foreach ($url in ($externals | Sort-Object)) {
        try {
            $result = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 12 -MaximumRedirection 5 -UseBasicParsing
            Write-Host "  $($result.StatusCode) $url"
        } catch {
            Write-Host "  CHECK MANUALLY $url ($($_.Exception.Message))" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "`nExternal addresses were collected but not requested. Add -CheckExternal to test them."
}

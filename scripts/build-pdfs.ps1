[CmdletBinding()]
param(
    [ValidateSet('All', 'terms-of-service', 'privacy-policy', 'dpa')]
    [string]$Document = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$stylePath = Join-Path $repositoryRoot 'assets/pdf.css'
$rendererPath = Join-Path $PSScriptRoot 'render-pdf.mjs'

$documents = @(
    [PSCustomObject]@{
        Name = 'terms-of-service'
        BaseName = 'Entovist-Terms-of-Service'
    }
    [PSCustomObject]@{
        Name = 'privacy-policy'
        BaseName = 'Entovist-Privacy-Policy'
    }
    [PSCustomObject]@{
        Name = 'dpa'
        BaseName = 'Entovist-DPA'
    }
)

if ($Document -ne 'All') {
    $documents = @($documents | Where-Object Name -eq $Document)
}

function Get-FrontMatter {
    param([Parameter(Mandatory)][string]$Content)

    $match = [regex]::Match(
        $Content,
        '\A---\s*\r?\n(?<Yaml>.*?)\r?\n---\s*\r?\n',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if (-not $match.Success) {
        throw 'The document does not contain valid YAML front matter.'
    }

    $values = @{}
    foreach ($line in ($match.Groups['Yaml'].Value -split '\r?\n')) {
        if ($line -match '^([A-Za-z0-9_]+):\s*(.*?)\s*$') {
            $values[$Matches[1]] = $Matches[2].Trim('"', "'")
        }
    }

    return [PSCustomObject]@{
        Values = $values
        Body = $Content.Substring($match.Length)
    }
}

function Resolve-EdgePath {
    if ($env:PDF_BROWSER -and (Test-Path -LiteralPath $env:PDF_BROWSER -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $env:PDF_BROWSER).Path
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    $edgeCommand = Get-Command msedge -ErrorAction SilentlyContinue
    if ($edgeCommand) {
        return $edgeCommand.Source
    }

    throw 'Microsoft Edge was not found. Set PDF_BROWSER to a Chromium-compatible browser executable.'
}

function Add-HeadingIds {
    param([Parameter(Mandatory)][string]$Html)

    $slugCounts = @{}
    $headingPattern = '<h(?<Level>[1-6])>(?<Content>.*?)</h\k<Level>>'

    return [regex]::Replace(
        $Html,
        $headingPattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)

            $plainText = [regex]::Replace($match.Groups['Content'].Value, '<[^>]+>', '')
            $plainText = [System.Net.WebUtility]::HtmlDecode($plainText).ToLowerInvariant()
            $slug = [regex]::Replace($plainText, '[^\p{L}\p{Nd}\s-]', '')
            $slug = [regex]::Replace($slug, '\s', '-')

            if (-not $slug) {
                $slug = 'section'
            }

            if ($slugCounts.ContainsKey($slug)) {
                $slugCounts[$slug]++
                $slug = "$slug-$($slugCounts[$slug])"
            }
            else {
                $slugCounts[$slug] = 0
            }

            return "<h$($match.Groups['Level'].Value) id=`"$slug`">$($match.Groups['Content'].Value)</h$($match.Groups['Level'].Value)>"
        },
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
}

function Convert-MarkdownToPdf {
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$BrowserPath,
        [Parameter(Mandatory)][string]$MarkedPath,
        [Parameter(Mandatory)][string]$NodePath,
        [Parameter(Mandatory)][string]$RendererPath,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Css
    )

    $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("entovist-pdf-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null

    try {
        $markdownPath = Join-Path $temporaryDirectory 'document.md'
        $bodyPath = Join-Path $temporaryDirectory 'body.html'
        $htmlPath = Join-Path $temporaryDirectory 'document.html'
        $pdfPath = Join-Path $temporaryDirectory 'document.pdf'
        $utf8 = [System.Text.UTF8Encoding]::new($false)

        [System.IO.File]::WriteAllText($markdownPath, $Markdown, $utf8)

        & $MarkedPath --gfm --input $markdownPath --output $bodyPath
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $bodyPath -PathType Leaf)) {
            throw "Markdown rendering failed with exit code $LASTEXITCODE."
        }

        $body = Add-HeadingIds -Html ([System.IO.File]::ReadAllText($bodyPath))
        $encodedTitle = [System.Net.WebUtility]::HtmlEncode($Title)
        $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$encodedTitle</title>
  <style>
$Css
  </style>
</head>
<body>
  <main>
$body
  </main>
</body>
</html>
"@
        [System.IO.File]::WriteAllText($htmlPath, $html, $utf8)

        & $NodePath $RendererPath `
            --html $htmlPath `
            --output $pdfPath `
            --browser $BrowserPath `
            --title $Title `
            --version $Version
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pdfPath -PathType Leaf)) {
            throw "PDF generation failed with exit code $LASTEXITCODE."
        }

        $outputDirectory = Split-Path -Parent $OutputPath
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        Copy-Item -LiteralPath $pdfPath -Destination $OutputPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryDirectory) {
            $removed = $false
            for ($attempt = 0; $attempt -lt 40; $attempt++) {
                try {
                    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction Stop
                    $removed = $true
                    break
                }
                catch {
                    Start-Sleep -Milliseconds 250
                }
            }

            if (-not $removed) {
                Write-Warning "Could not remove temporary browser profile: $temporaryDirectory"
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $stylePath -PathType Leaf)) {
    throw "Missing PDF stylesheet: $stylePath"
}

if (-not (Test-Path -LiteralPath $rendererPath -PathType Leaf)) {
    throw "Missing PDF renderer: $rendererPath"
}

$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCommand) {
    throw 'Node.js is required to build PDFs.'
}

$markedPath = Join-Path $repositoryRoot 'node_modules/.bin/marked.cmd'
if (-not (Test-Path -LiteralPath $markedPath -PathType Leaf)) {
    throw "PDF dependencies are not installed. Run 'npm ci' in $repositoryRoot."
}

$browserPath = Resolve-EdgePath
$css = [System.IO.File]::ReadAllText($stylePath)

foreach ($item in $documents) {
    $documentDirectory = Join-Path $repositoryRoot $item.Name
    $canonicalMarkdown = Join-Path $documentDirectory ($item.BaseName + '.md')
    $canonicalPdf = Join-Path $documentDirectory ($item.BaseName + '.pdf')

    if (-not (Test-Path -LiteralPath $canonicalMarkdown -PathType Leaf)) {
        throw "Missing canonical document: $canonicalMarkdown"
    }

    $content = [System.IO.File]::ReadAllText($canonicalMarkdown)
    $frontMatter = Get-FrontMatter -Content $content

    foreach ($requiredField in @('version', 'title')) {
        if (-not $frontMatter.Values.ContainsKey($requiredField) -or -not $frontMatter.Values[$requiredField]) {
            throw "Missing '$requiredField' metadata in $canonicalMarkdown"
        }
    }

    $version = $frontMatter.Values['version']
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version '$version' in $canonicalMarkdown"
    }

    $archiveDirectory = Join-Path $documentDirectory 'archive'
    $archiveMarkdown = Join-Path $archiveDirectory ($item.BaseName + "-v$version.md")
    $archivePdf = Join-Path $archiveDirectory ($item.BaseName + "-v$version.pdf")
    New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null

    if (Test-Path -LiteralPath $archiveMarkdown -PathType Leaf) {
        $canonicalHash = (Get-FileHash -LiteralPath $canonicalMarkdown -Algorithm SHA256).Hash
        $archiveHash = (Get-FileHash -LiteralPath $archiveMarkdown -Algorithm SHA256).Hash
        if ($canonicalHash -ne $archiveHash) {
            throw "The canonical document differs from archived version $version. Increment the version before building: $canonicalMarkdown"
        }
    }
    else {
        Copy-Item -LiteralPath $canonicalMarkdown -Destination $archiveMarkdown
        Write-Host "Created Markdown snapshot: $archiveMarkdown"
    }

    if (Test-Path -LiteralPath $archivePdf -PathType Leaf) {
        Copy-Item -LiteralPath $archivePdf -Destination $canonicalPdf -Force
        Write-Host "Restored canonical PDF from immutable archive: $canonicalPdf"
        continue
    }

    $temporaryPdf = Join-Path ([System.IO.Path]::GetTempPath()) ("entovist-release-" + [guid]::NewGuid().ToString('N') + '.pdf')
    try {
        Convert-MarkdownToPdf `
            -Markdown $frontMatter.Body `
            -Title $frontMatter.Values['title'] `
            -OutputPath $temporaryPdf `
            -BrowserPath $browserPath `
            -MarkedPath $markedPath `
            -NodePath $nodeCommand.Source `
            -RendererPath $rendererPath `
            -Version $version `
            -Css $css

        Copy-Item -LiteralPath $temporaryPdf -Destination $archivePdf
        Copy-Item -LiteralPath $temporaryPdf -Destination $canonicalPdf -Force
        Write-Host "Created release PDF: $archivePdf"
        Write-Host "Created canonical PDF: $canonicalPdf"
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPdf) {
            Remove-Item -LiteralPath $temporaryPdf -Force
        }
    }
}

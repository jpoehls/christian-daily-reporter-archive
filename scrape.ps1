param(
    [switch]$Commit
)

Set-StrictMode -Version Latest

function makeJsonFeed([Microsoft.PowerShell.Commands.HtmlWebResponseObject]$Response, [string]$OutFile) {
    $externalLinks = $Response.Links | Where-Object {
        $href = $_.href
        return ($href.StartsWith("http:") -or $href.StartsWith("https:")) -and $href -notmatch "christiandailyreporter.com"
    }

    $json = @{}
    $json.version = "https://jsonfeed.org/version/1"
    $json.title = "Christian Daily Reporter"
    $json.home_page_url = "https://www.christiandailyreporter.com"
    $json.feed_url = "https://raw.githubusercontent.com/jpoehls/christian-daily-reporter-archive/master/index.html.feed.json"
    $json.author = @{}
    $json.author.name = "Adam Ford"
    $json.author.url = "https://www.christiandailyreporter.com"
    $json.items = @()
    
    $externalLinks | % {
        $item = @{}        
        $item.title = $_.innerText
        $item.id = $_.href
        $item.url = $_.href
        $item.external_url = $_.href
        $item.content_html = "<p>" + $_.outerHTML + "</p>"
        $item.content_text = $_.innerText + "`n" + $_.href

        $json.items += $item
    }

    $json | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath $OutFile
}

function scrape([string]$Url, [string]$OutFile) {
    Write-Host "scraping $Url"

    $ts = Get-Date
    $resp = Invoke-WebRequest -Uri $Url -OutFile $OutFile -PassThru

    $hash = "sha256:" + (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash
    
    $hashFile = $OutFile + ".hash"
    $prevHash = Get-Content -LiteralPath $hashFile | Select-Object -First 1

    if ($hash -ne $prevHash) {
        Write-Host "website updated"
        Write-Host "updating $hashFile"
        @"
$hash
$($ts.ToUniversalTime().ToString("s"))Z
"@ | Out-File $hashFile -Encoding ascii

        Write-Host "making JSON feed"
        $jsonFeedFile = $OutFile + ".feed.json"
        makeJsonFeed -Response $resp -OutFile $jsonFeedFile

        if ($Commit) {
            Write-Host "committing to git"
            & git reset
            & git add $OutFile
            & git add $hashFile
            & git add $jsonFeedFile
            & git commit -m "$Url updated"

            Write-Host "pushing to git remote"
            & git push origin
        }
    }
    else {
        Write-Host "website hasn't changed"
    }
}

scrape -Url "https://www.christiandailyreporter.com" -OutFile "index.html"
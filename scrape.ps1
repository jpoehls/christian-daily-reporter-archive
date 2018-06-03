param(
    [switch]$Commit,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

class Feed {
    Feed() {
        
    }

    [string]$Title
    [string]$HomePageUrl
    [string]$FeedUrl
    [string]$AuthorName
    [DateTime]$UpdatedAt
    [FeedItem[]]$Items

    [void] WriteAtomFeedFile([string]$OutFile) {
        $atom = New-Object System.Xml.Linq.XDocument
        
        $root = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"{http://www.w3.org/2005/Atom}feed")
        $atom.Add($root)
        
        $feedId = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}id", $this.FeedUrl
        $root.Add($feedId)

        $feedTitle = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}title", $this.Title
        $root.Add($feedTitle)

        $feedUpdated = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}updated", $this.UpdatedAt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $root.Add($feedUpdated)

        $feedAuthor = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"{http://www.w3.org/2005/Atom}author")
        $root.Add($feedAuthor)
        $feedAuthorName = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}name", $this.AuthorName
        $feedAuthor.Add($feedAuthorName)

        $this.Items | % {
            $entry = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"{http://www.w3.org/2005/Atom}entry")
            $root.Add($entry)

            $entryId = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}id", $_.Url
            $entry.Add($entryId)
    
            $entryTitle = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}title", $_.Title
            $entry.Add($entryTitle)

            $entryLink = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"{http://www.w3.org/2005/Atom}link")
            $entry.Add($entryLink)

            $entryLinkHref = New-Object System.Xml.Linq.XAttribute "href", $_.Url
            $entryLink.Add($entryLinkHref)
    
            $entryUpdated = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}updated", $this.UpdatedAt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            $entry.Add($entryUpdated)

            $entrySummary = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}summary", $_.ContentText
            $entry.Add($entrySummary)

            $entryContent = New-Object System.Xml.Linq.XElement "{http://www.w3.org/2005/Atom}content", $_.ContentHtml
            $entry.Add($entryContent)

            $entryContentType = New-Object System.Xml.Linq.XAttribute "type", "html"
            $entryContent.Add($entryContentType)
        }

        $atom.Save($OutFile)
    }

    [void] WriteJsonFeedFile([string]$OutFile) {
        $json = @{}
        $json.version = "https://jsonfeed.org/version/1"
        $json.title = $this.Title
        $json.home_page_url = $this.HomePageUrl
        $json.feed_url = $this.FeedUrl
        $json.author = @{}
        $json.author.name = $this.AuthorName
        $json.author.url = $this.HomePageUrl
        $json.items = @()
        
        $this.Items | % {
            $item = @{}        
            $item.title = $_.Title
            $item.id = $_.Id
            $item.url = $_.Url
            $item.external_url = $_.ExternalUrl
            $item.content_html = $_.ContentHtml
            $item.content_text = $_.ContentText
    
            $json.items += $item
        }
    
        $json | ConvertTo-Json | Out-File -Encoding utf8 -LiteralPath $OutFile
    }
}

class FeedItem {
    [string]$Id
    [string]$Url
    [string]$Title
    [string]$ExternalUrl
    [string]$ContentHtml
    [string]$ContentText
}

function makeFeed($Response) {
    $feed = New-Object Feed

    $feed.Title = "Christian Daily Reporter"
    $feed.HomePageUrl = "https://www.christiandailyreporter.com"
    $feed.AuthorName = "Adam Ford"

    $externalLinks = $Response.Links | Where-Object {
        $href = $_.href
        return ($href.StartsWith("http:") -or $href.StartsWith("https:")) -and $href -notmatch "christiandailyreporter.com"
    }

    $externalLinks | % {
        if ($_ | Get-Member -Name 'innerText') {
            $innerText = $_.innerText
        }
        else {
            # Ugly hack to strip the HTML tags and build the "inner text" ourself.
            # Kudos https://stackoverflow.com/a/29930250/31308
            $innerText = $_.outerHTML -replace '<[^>]+>',''
        }

        $item = New-Object FeedItem
        $item.Title = $innerText
        $item.Id = $_.href
        $item.Url = $_.href
        $item.ExternalUrl = $_.href
        $item.ContentText = "$innerText`n`nArticle: $($item.Url)`n`nChristian Daily Reporter: $($feed.HomePageUrl)"

        $html = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"div")
        $html.Add((createHtmlParagraphWithText $item.Title))
        $html.Add((createHtmlParagraphWithLabeledLink -Label "Article" -Url $item.Url))
        $html.Add((createHtmlParagraphWithLabeledLink -Label "Christian Daily Reporter" -Url $feed.HomePageUrl))
        $item.ContentHtml = $html.ToString()

        $feed.Items += $item
    }

    return $feed
}

function createHtmlParagraphWithText([string]$Text) {
    $p = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"p")
    $t = New-Object System.Xml.Linq.XText $Text
    $p.Add($t)
    return $p
}

function createHtmlParagraphWithLabeledLink([string]$Label, [string]$Url) {
    $p = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"p")
    $t = New-Object System.Xml.Linq.XText ($Label + ": ")
    $p.Add($t)
    $a = New-Object System.Xml.Linq.XElement ([System.Xml.Linq.XName]"a")
    $p.Add($a)
    $t = New-Object System.Xml.Linq.XText $Url
    $a.Add($t)
    $href = New-Object System.Xml.Linq.XAttribute ([System.Xml.Linq.XName]"href"), $Url
    $a.Add($href)
    return $p
}

function scrape([string]$Url, [string]$OutFile) {
    Write-Host "scraping $Url"

    $ts = Get-Date
    $resp = Invoke-WebRequest -Uri $Url -OutFile $OutFile -PassThru

    $hash = "sha256:" + (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash
    
    $hashFile = $OutFile + ".hash"
    $prevHash = Get-Content -LiteralPath $hashFile | Select-Object -First 1

    $websiteUpdated = $hash -ne $prevHash

    if ($websiteUpdated -or $Force) {
        if ($websiteUpdated) {
            Write-Host "website updated"
        }
        else {
            Write-Host "website hasn't changed but -Force"
        }

        Write-Host "updating $hashFile"
        @"
$hash
$($ts.ToUniversalTime().ToString("s"))Z
"@ | Out-File $hashFile -Encoding ascii

        Write-Host "building feed from website content"
        $feed = makeFeed -Response $resp
        $feed.UpdatedAt = $ts

        Write-Host "making JSON Feed"
        $jsonFeedFile = $OutFile + ".feed.json"
        $feed.FeedUrl = "https://rawgit.com/jpoehls/christian-daily-reporter-archive/master/index.html.feed.json"
        $feed.WriteJsonFeedFile($jsonFeedFile)

        Write-Host "making Atom Feed"
        $atomFeedFile = $OutFile + ".feed.xml"
        $feed.FeedUrl = "https://rawgit.com/jpoehls/christian-daily-reporter-archive/master/index.html.feed.xml"
        $feed.WriteAtomFeedFile($atomFeedFile)

        if ($Commit) {
            Write-Host "committing to git"
            & git reset
            & git add $OutFile
            & git add $hashFile
            & git add $jsonFeedFile
            & git add $atomFeedFile
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
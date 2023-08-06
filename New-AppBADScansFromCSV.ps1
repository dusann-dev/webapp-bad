Param(
    [Parameter(Mandatory=$true)]
    [string]
    $ApiEndpoint,
    [Parameter(Mandatory=$true)]
    [string]
    $Path,
    [Parameter(Mandatory=$true)]
    [string]
    $PageUrlBase,
    [string]
    $ChromeBinaryPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    [Parameter(Mandatory=$true)]
    [string]
    $WebDriverDirectory
)

Install-Module -Name Selenium -Scope CurrentUser

Function New-ABADWebScan {
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $Elements,
        [datetime]
        $Timestamp
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")

    $response = Invoke-RestMethod "http://$ApiEndpoint/api/scan" -Method 'POST' -Headers $headers -Body $Elements
    $response | ConvertTo-Json

}

# open browser
$driver = Start-SeChrome -BinaryPath $ChromeBinaryPath -WebDriverDirectory $WebDriverDirectory
try {

    # load page urls from CSV and iterate through them
    Get-Content -Path $Path | ConvertFrom-Csv -Delimiter "," -Header @("url", "xpath")  | % {
        [string] $relativeUrl = $_.url 
        [string] $elemToScan = $_.xpath
        $fullUrlToScan = $PageUrlBase + $relativeUrl
        Write-Host "Going to $fullUrlToScan to scan $elemToScan"
        Enter-SeUrl -Driver $Driver -Url $fullUrlToScan
        sleep 5 # simple waiting until page is loaded, replace with p
        $now =  ([datetime]::UtcNow).ToString("yyyy-MM-ddTHH:mm:ss")
        $scriptGetElements = "return (function () {
                function getElementByXpath(path) {
                    return document.evaluate(path, document, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE, null);
                }
                var inputs = [];
                var elementInterator = getElementByXpath('" + $elemToScan + "');
            
                while (node = elementInterator.iterateNext()) {
                    inputs.push({
                        domContent: node.outerHTML,
                        width: node.clientWidth,
                        height: node.clientHeight

                    });
                }
                var result = {
                      context : {
                        url : '$relativeUrl',
                        elementXPath : '$elemToScan',
                        tags : []
                      },
                      data : inputs,
                      timestamp : '$now'
                }
                return JSON.stringify(result)
            })(); "

        $elements = $driver.executeScript($scriptGetElements)

        New-ABADWebScan -Elements $elements -Timestamp $now
    }
}
catch {
    Write-Error  $_
}
finally {
    Stop-SeDriver -Driver $driver
}
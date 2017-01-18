$SCRIPT:CONFIG:UserAgent = "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:50.0) Gecko/20100101 Firefox/50.0"
$SCRIPT:CONFIG:TestHost = "sc81u2.474869.sup"
$SCRIPT:CONFIG:TestUri = "http://$($SCRIPT:CONFIG:TestHost)"

$SCRIPT:CONFIG:OutFolder = "c:\tmp\sc.xp.content.test.automation"
$SCRIPT:CONFIG:TraceFile = Join-Path $SCRIPT:CONFIG:OutFolder "trace.txt"
$SCRIPT:CONFIG:SessionStorageFolder = Join-Path $SCRIPT:CONFIG:OutFolder "sessions"

# Ensure output folders exist ( can be created )
if (-not(Test-Path $SCRIPT:CONFIG:OutFolder -PathType Container)) {
    New-Item -Path $SCRIPT:CONFIG:OutFolder -ItemType Directory -ErrorAction Stop
}

if (-not(Test-Path $SCRIPT:CONFIG:TraceFile -PathType Leaf)) {
    New-Item -Path $SCRIPT:CONFIG:TraceFile -ItemType File -ErrorAction Stop
}

if (-not(Test-Path $SCRIPT:CONFIG:SessionStorageFolder -PathType Container)) {
    New-Item -Path $SCRIPT:CONFIG:SessionStorageFolder -ItemType Directory
}

function Trace {
    param (
        $msg
    )

    $msg | Tee-Object -FilePath $SCRIPT:CONFIG:TraceFile -Append
}

#Initial request, initializes $contextWebSession variable ( used as a cookie container )
$response = Invoke-WebRequest -Uri $SCRIPT:CONFIG:TestUri -SessionVariable contextWebSession -UserAgent $SCRIPT:CONFIG:UserAgent

$currentRequestAspNetSession = $contextWebSession.Cookies.GetCookies($SCRIPT:CONFIG:TestUri) | ? { $_.Name -eq 'ASP.NET_SessionId'} | select -ExpandProperty Value
if ($currentRequestAspNetSession -eq $null) {
    Trace "[ERR] NULL ASP.NET session cookie for the current web session"
}

$userIsToScoreGoal = $false
$randomScore = get-random -Minimum 1 -Maximum 100
if       ($response.RawContent.Contains("Variation 1")) {
    if ($randomScore -lt 50) { # User scores a goal with ~50% chance ( in case 'Variation 1' is present in response )
        $userIsToScoreGoal = $true
        Trace "[$currentRequestAspNetSession][Is to score a goal for Variation 1]"
    } 
} elseif ($response.RawContent.Contains("Variation 2")) {
    if ($randomScore -lt 25) { # User scores a goal with ~25% chance ( in case 'Variation 2' is present in response )
        $userIsToScoreGoal = $true 
        Trace "[$currentRequestAspNetSession][Is to score a goal for Variation 2]"
    } 
}
if ($userIsToScoreGoal) {
    #Subsequent invocation of the "goal" page ( to "earn" score for the visit ). $contextWebSession is used to persist user's session ( cookies )
    $response = Invoke-WebRequest -Uri "$($SCRIPT:CONFIG:TestUri)/goalitem.aspx" -WebSession $contextWebSession -UserAgent $SCRIPT:CONFIG:UserAgent
} else {
    Trace "[$currentRequestAspNetSession][Is not to score]"
}

#persist session
$sessionOutFile = Join-Path $SCRIPT:CONFIG:SessionStorageFolder "$currentRequestAspNetSession.txt"
New-Item -Path $sessionOutFile -ItemType File -ErrorAction Stop | Out-Null

$contextWebSession.Cookies.GetCookies($SCRIPT:CONFIG:TestUri) | Export-Clixml -Depth 4 -Path $sessionOutFile
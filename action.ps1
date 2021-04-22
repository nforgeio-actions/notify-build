#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

#------------------------------------------------------------------------------
# Sends a build related notification to a Teams channel.
#
# INPUTS:
#
#   channel         - Target Teams channel webhook URI
#   operation       - Identifies what's being built
#   start-time      - Time when the build started (formatted like YYYY-MM-DD HH-MM:SSZ)
#   finish-time     - Time when the build completed (formatted like YYYY-MM-DD HH-MM:SSZ)
#   build-outcome   - Build step outcome, one of: 'success', 'failure', 'cancelled', or 'skipped'
    
# Verify that we're running on a properly configured neonFORGE jobrunner 
# and import the deployment and action scripts from neonCLOUD.

# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.

$ncRoot = $env:NC_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
  throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell
. ./includes.ps1
Pop-Location
      
# Fetch the inputs.

$channel      = Get-ActionInput "channel"       $true
$operation    = Get-ActionInput "operation"     $true
$startTime    = Get-ActionInput "start-time"    $true
$finishTime   = Get-ActionInput "finish-time"   $true
$buildOutcome = Get-ActionInput "build-outcome" $true

# Parse the start/finish times and compute the elapsed time.

$startTime   = [System.DateTime]::Parse($startTime)
$finishTime  = [System.DateTime]::Parse($finishTime)
$elapsedTime = $(New-TimeSpan $startTime $finishTime)

# Determine the workflow run URI.

$workflowRunUri = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# We're going to use search/replace to modify a template card.

$card = 
@'
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "themeColor": "3d006d",
    "summary": "neon automation",
    "sections": [
        {
            "activityTitle": "@operation",
            "activitySubtitle": "@runner",
            "activityText": "@build-outcome",
            "activityImage": "@status-link"
        },
        {
            "title": "",
            "facts": [
                {
                    "name": "started:",
                    "value": "@start-time"
                },
                {
                    "name": "finished:",
                    "value": "@finish-time"
                },
                {
                    "name": "elapsed:",
                    "value": "@elapsed-time"
                },
                {
                    "name": "link:",
                    "value": "@channel"
                }
            ]
        }
    ]
}    
'@

$card = $card.Replace("@operation", $operation)
$card = $card.Replace("@runner", $env:COMPUTERNAME)
$card = $card.Replace("@build-outcome", $buildOutcome.ToUpper())
$card = $card.Replace("@status-link", $statusLink)
$card = $card.Replace("@start-time", $startTime.ToString("u"))
$card = $card.Replace("@finish-time", $finishTime.ToString("u"))
$card = $card.Replace("@elapsed-time", $elapsedTime.ToString("c"))

# Post the card to Microsoft Teams.

Invoke-WebRequest -Method "POST" -Uri $channel -ContentType "application/json" -Body $card | Out-Null

#------------------------------------------------------------------------------
# FILE:         script.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

#------------------------------------------------------------------------------
# Sends an automated operation related message to a Teams channel.
#
# INPUTS:
#
#   channel         - Target Teams channel webhook URI
#   operation       - Identifies what's being built
#   start-time      - Time when the operation started
#   finish-time     - Time when the operation completed or failed
#   elapsed-time    - Elapsed operation run time
#   status          - Operation status, one of: 'ok', 'warning', or 'failed'
    
# Verify that we're running on a properly configured neonFORGE jobrunner 
# and import the deployment and action scripts from neonCLOUD.

# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.

$ncRoot = $env:NC_ROOT

if (![System.IO.Directory]::Exists($ncRoot))
{
  throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Write-Output $"ncPowershell = $ncPowershell"

Push-Location $ncPowershell
. ./includes.ps1
Pop-Location
      
# Fetch the inputs.

$channel     = Get-ActionInput "channel"      $true
$operation   = Get-ActionInput "operation"    $true
$startTime   = Get-ActionInput "start-time"   $true
$finishTime  = Get-ActionInput "finish-time"  $true
$elapsedTime = Get-ActionInput "elapsed-time" $true
$status      = Get-ActionInput "status"       $true

# Determine the devbot image link based on the status.

Switch ($status)
{
    "ok"
    {
        $statusLink = "https://github.com/nforgeio-actions/images/blob/master/teams/ok.png"
    }
    
    "warning"
    {
        $statusLink = "https://github.com/nforgeio-actions/images/blob/master/teams/warning.png"
    }
    
    "error"
    {
        $statusLink = "https://github.com/nforgeio-actions/images/blob/master/teams/error.png"
    }
    
    default
    {
        throw "[$status] is not a valid status code."
    }
}

$workflowRunUri = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# We're going to use search/replace to modify a template message.

$message = 
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
            "activityText": "@status",
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

$message  = $message.Replace("@operation", $operation)
$message  = $message.Replace("@runner", $env:COMPUTERNAME)
$message  = $message.Replace("@status", $status.ToUpper())
$message  = $message.Replace("@status-link", $statusLink)
$message  = $message.Replace("@start-time", $startTime)
$message  = $message.Replace("@finish-time", $finishTime)
$message  = $message.Replace("@elapsed-time", $elapsedTime)

# Post the message to Microsoft Teams.

Invoke-WebRequest -Method "POST" -Uri $channel -ContentType "application/json" -Body $message 



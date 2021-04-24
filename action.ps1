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
#   send-on         - Optionally specifies the comma separated list of [build-outcome] values
#                     that will trigger the notification.  The default is to always send the
#                     notification.
    
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

$channel        = Get-ActionInput "channel"          $true
$operation      = Get-ActionInput "operation"        $true
$buildBranch    = Get-ActionInput "build-branch"     $false
$buildCommit    = Get-ActionInput "build-commit"     $false
$buildCommitUri = Get-ActionInput "build-commit-uri" $false
$startTime      = Get-ActionInput "start-time"       $false
$finishTime     = Get-ActionInput "finish-time"      $false
$buildOutcome   = Get-ActionInput "build-outcome"    $true
$workflowRef    = Get-ActionInput "workflow-ref"     $true
$sendOn         = Get-ActionInput "send-on"          $false

# Exit if the notification shouldn't be transmitted based on the build outcome.
# We're going to do a simple string match here rather than parsing [send-on].

$sendAlways = ($sendOn -eq $null) -or ($sendOn.Contains("always"))

if (!$sendAlways -and !$sendOn.Contains($buildOutcome))
{
    return
}

# Handle missing [build-branch] and [build-commit-uri] inputs.

if ([System.String]::IsNullOrEmpty($buildBranch))
{
    $buildBranch = "-na-"
}
else
{
    $buildBranch = "**$buildBranch**"
}

if ([System.String]::IsNullOrEmpty($buildCommit) -or [System.String]::IsNullOrEmpty($buildCommitUri))
{
    $buildCommitUri = "-na-"
}
else
{
    $buildCommitUri = "[$buildCommit]($buildCommitUri)"
}

# Parse the optional start/finish times and compute the elapsed time.  Note that
# we're going to display "-na" when either of these timestamps were not passed.

Write-Output "**************************************"
Write-Output "start-time:  $startTime"
Write-Output "finish-time: $finishTime"
Write-Output "**************************************"

if ([System.String]::IsNullOrEmpty($startTime) -or [System.String]::IsNullOrEmpty($finishTime))
{
    $startTime   = "-na-"
    $finishTime  = "-na-"
    $elapsedTime = "-na-"
}
else
{
    $startTime   = [System.DateTime]::Parse($startTime).ToString("u")
    $finishTime  = [System.DateTime]::Parse($finishTime).ToString("u")
    $elapsedTime = $(New-TimeSpan $startTime $finishTime).ToString("c")
}

Write-Output "**************************************"

# Determine the workflow run URI.

$workflowRunUri = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# Convert [$workflowRef] into the URI to referencing the correct workflow branch.  We're
# going to use the GITHUB_REF environment variable.  This includes the branch like:
#
#       refs/heads/master
#
# Note that the workflow may be executing on a different branch than the repo build.

if (!$workflowRef.Contains("/blob/master/"))
{
    throw "[workflow-ref=$workflowRef] is missing '/blob/master/'."
}

$githubRef      = $env:GITHUB_REF
$lastSlashPos   = $githubRef.LastIndexOf("/")
$workflowBranch = $githubRef.Substring($lastSlashPos + 1)
$workflowUri    = $workflowRef.Replace("/blob/master/", "/blob/$workflowBranch/")

# Determine the reason why the workflow was started based on the GITHUB_EVENT_NAME
# and GITHUB_ACTOR environment variables.

$event = $env:GITHUB_EVENT_NAME
$actor = $env:GITHUB_ACTOR

if (![System.String]::IsNullOrEmpty($actor))
{
    $actor = $actor.ToUpper()
}

if (![System.String]::IsNullOrEmpty($event))
{
    $event = $event.ToUpper()
}

if ($event -eq "workflow_dispatch")
{
    $reason = "Started by: **$actor**"
}
else
{
    $reason = "Event: **$event**"
}

# Set the theme color based on the build outcome.

$themeColor = "ff0000" # green

Switch ($buildOutcome)
{
    "success"
    {
        $themeColor = "00ff00" # green
    }

    "cancelled"
    {
        $themeColor = "ffa500" # orange
    }

    "skipped"
    {
        $themeColor = "ffa500" # orange
    }

    "failure"
    {
        $themeColor = "ff0000" # red
    }
}

# Format $buildOutcome

$buildOutcome = "**$buildOutcome**"

# This is the legacy MessageCard format (Adaptive Cards are not supported by
# the Team Connector at this time):
#
#   https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference

$card = 
@'
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "themeColor": "@theme-color",
    "summary": "neon automation",
    "sections": [
        {
            "activityTitle": "@operation",
            "activitySubtitle": "@reason",
        },
        {
            "facts": [
                {
                    "name": "Outcome:",
                    "value": "build-outcome"
                },
                {
                    "name": "Runner:",
                    "value": "@runner"
                },
                {
                    "name": "Branch:",
                    "value": "@build-branch"
                },
                {
                    "name": "Commit:",
                    "value": "@build-commit-uri"
                },
                {
                    "name": "Finished:",
                    "value": "@finish-time"
                },
                {
                    "name": "Elapsed:",
                    "value": "@elapsed-time"
                }
            ]
        }
    ],
    "potentialAction": [
      {
          "@type": "OpenUri",
          "name": "Show Workflow Run",
          "targets": [
            {
                "os": "default",
                "uri": "@workflow-run-uri"
            }
          ]
      },
      {
          "@type": "OpenUri",
          "name": "Show Workflow",
          "targets": [
            {
                "os": "default",
                "uri": "@workflow-uri"
            }
          ]
      }
    ]
}    
'@

$card = $card.Replace("@operation", $operation)
$card = $card.Replace("@reason", $reason)
$card = $card.Replace("@runner", $env:COMPUTERNAME)
$card = $card.Replace("@build-branch", $buildBranch)
$card = $card.Replace("@build-commit-uri", $buildCommitUri)
$card = $card.Replace("@build-outcome", $buildOutcome.ToUpper())
$card = $card.Replace("@build-outcome-color", $buildOutcomeColor)
$card = $card.Replace("@workflow-run-uri", $workflowRunUri)
$card = $card.Replace("@workflow-uri", $workflowUri)
$card = $card.Replace("@finish-time", $finishTime)
$card = $card.Replace("@elapsed-time", $elapsedTime)
$card = $card.Replace("@theme-color", $themeColor)

# Post the card to Microsoft Teams.

Invoke-WebRequest -Method "POST" -Uri $channel -ContentType "application/json" -Body $card | Out-Null

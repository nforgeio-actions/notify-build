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

$channel      = Get-ActionInput "channel"       $true
$operation    = Get-ActionInput "operation"     $true
$startTime    = Get-ActionInput "start-time"    $true
$finishTime   = Get-ActionInput "finish-time"   $true
$buildOutcome = Get-ActionInput "build-outcome" $true
$workflowRef  = Get-ActionInput "workflow-ref"  $true
$sendOn       = Get-ActionInput "send-on"       $false

# Exit if the notification shouldn't be transmitted based on the build outcome.
# We're going to do a simple string match here rather than parsing [send-on].

if (($sendOn -ne $null) -and ($sendOn.Contains($buildOutcome)))
{
    return
}

# Parse the start/finish times and compute the elapsed time.

$startTime   = [System.DateTime]::Parse($startTime)
$finishTime  = [System.DateTime]::Parse($finishTime)
$elapsedTime = $(New-TimeSpan $startTime $finishTime)

# Determine the workflow run URI.

$workflowRunUri = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# Convert [$workflowRef] into the URI to referencing the correct branch.  We're
# going to use the GITHUB_REF environment variable.  This includes the branch like:
#
#       refs/heads/master

if (!$workflowRef.Contains("/blob/master/"))
{
    throw "[workflow-ref=$workflowRef] is missing '/blob/master/'."
}

$githubRef    = $env:GITHUB_REF
$lastSlashPos = $githubRef.LastIndexOf("/")
$branch       = $githubRef.Substring($lastSlashPos + 1)
$workflowUri  = $workflowRef.Replace("/blob/master/", "/blob/$branch/")

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

# Set the accents based on the build outcome.

$buildOutcomeColor    = "default"
$buildOutcomeColorUri = "https://github.com/nforgeio-actions/images/blob/master/teams/warning.png"
$themeColor           = "ff0000" # green

Switch ($buildOutcome)
{
    "success"
    {
        $buildOutcomeColor    = "good"
        $buildOutcomeColorUri = "https://github.com/nforgeio-actions/images/blob/master/teams/ok.png"
        $themeColor           = "00ff00" # green
    }

    "cancelled"
    {
        $buildOutcomeColor    = "warning"
        $buildOutcomeColorUri = "https://github.com/nforgeio-actions/images/blob/master/teams/warning.png"
        $themeColor           = "ffa500" # orange
    }

    "skipped"
    {
        $buildOutcomeColor    = "warning"
        $buildOutcomeColorUri = "https://github.com/nforgeio-actions/images/blob/master/teams/warning.png"
        $themeColor           = "ffa500" # orange
    }

    "failure"
    {
        $buildOutcomeColor    = "attention"
        $buildOutcomeColorUri = "https://github.com/nforgeio-actions/images/blob/master/teams/error.png"
        $themeColor           = "ff0000" # red
    }
}

# The Teams connector doesn't support adaptive cards yet although they claim
# this feature is in testing for the better part of a year (by Alex Bauer no less):
#
#       https://microsoftteams.uservoice.com/forums/555103-public/suggestions/35793883-adaptive-cards-webhooks?page=1&per_page=20
#
# I wasted a couple hours laying out the adaptive card below.  I'll retain the
# code though, in case MSFT gets on the ball and releases this.

if ($false)
{
    # We're going to use search/replace to modify a template card.  Here's the
    # card documentation:
    #
    #   https://adaptivecards.io/explorer/

    $card = 
@'
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.3",
  "body": [
    {
      "type": "Container",
      "backgroundImage": "@buildOutcomeColorUri",
      "items": [
        {
          "type": "TextBlock",
          "text": "@operation",
          "weight": "bolder",
          "size": "medium"
        },
        {
          "type": "ColumnSet",
          "columns": [
            {
              "type": "Column",
              "width": "auto",
              "items": [
                {
                  "type": "Image",
                  "url": "https://github.com/nforgeio-actions/images/blob/master/teams/devbot.png",
                  "size": "small",
                  "style": "person"
                }
              ]
            },
            {
              "type": "Column",
              "width": "stretch",
              "items": [
                {
                  "type": "TextBlock",
                  "spacing": "none",
                  "text": "devbot (neonFORGE)",
                  "wrap": true
                },
                {
                  "type": "TextBlock",
                  "spacing": "none",
                  "text": "@finish-time",
                  "isSubtle": true,
                  "wrap": true
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "type": "Container",
      "items": [
        {
          "type": "FactSet",
          "facts": [
            {
              "title": "Outcome:",
              "value": "@build-outcome",
              "color": "@build-outcome-color"
            },
            {
              "title": "Runner:",
              "value": "@runner"
            },
            {
              "title": "Elapsed:",
              "value": "@elapsed-time"
            }
          ]
        },
        {
          "type": "ColumnSet",
          "columns": [
            {
              "type": "Column",
              "width": "stretch",
              "items": [
                {
                  "type": "ActionSet",
                  "actions": [
                    {
                      "type": "Action.OpenUrl",
                      "title": "Show Workflow Run",
                      "url": "@workflow-run-uri",
                      "style": "positive"
                    }
                  ]
                }
              ]
            },
            {
              "type": "Column",
              "width": "stretch",
              "items": [
                {
                  "type": "ActionSet",
                  "actions": [
                    {
                      "type": "Action.OpenUrl",
                      "title": "Show Workflow",
                      "url": "@workflow-uri",
                      "style": "positive"
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
'@
}
else
{
    # This is the old MessageCard format:
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
                    "value": "**@build-outcome**"
                },
                {
                    "name": "Branch:",
                    "value": "**@branch**"
                },
                {
                    "name": "Runner:",
                    "value": "@runner"
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
}

$card = $card.Replace("@operation", $operation)
$card = $card.Replace("@reason", $reason)
$card = $card.Replace("@runner", $env:COMPUTERNAME)
$card = $card.Replace("@branch", $branch.ToUpper())
$card = $card.Replace("@build-outcome", $buildOutcome.ToUpper())
$card = $card.Replace("@build-outcome-color", $buildOutcomeColor)
$card = $card.Replace("@workflow-run-uri", $workflowRunUri)
$card = $card.Replace("@workflow-uri", $workflowUri)
$card = $card.Replace("@start-time", $startTime.ToString("u"))
$card = $card.Replace("@finish-time", $finishTime.ToString("u"))
$card = $card.Replace("@elapsed-time", $elapsedTime.ToString("c"))
$card = $card.Replace("@theme-color", $themeColor)

# Post the card to Microsoft Teams.

Invoke-WebRequest -Method "POST" -Uri $channel -ContentType "application/json" -Body $card | Out-Null

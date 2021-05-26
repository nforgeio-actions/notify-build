#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

#------------------------------------------------------------------------------
# Sends a build related notification message to a Microsoft Teams channel URI.
    
# Verify that we're running on a properly configured neonFORGE GitHub runner 
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

Push-Location $ncPowershell | Out-Null
. ./includes.ps1
Pop-Location | Out-Null

# Implement the operation.

try
{      
    # Fetch the inputs.

    $channel        = Get-ActionInput     "channel"          $true
    $buildSummary   = Get-ActionInput     "build-summary"    $true
    $buildBranch    = Get-ActionInput     "build-branch"     $false
    $buildConfig    = Get-ActionInput     "build-config"     $false
    $buildCommit    = Get-ActionInput     "build-commit"     $false
    $buildCommitUri = Get-ActionInput     "build-commit-uri" $false
    $startTime      = Get-ActionInput     "start-time"       $false
    $finishTime     = Get-ActionInput     "finish-time"      $false
    $buildOutcome   = Get-ActionInput     "build-outcome"    $true
    $buildSuccess   = Get-ActionInputBool "build-success"
    $buildIssueUri  = Get-ActionInput     "build-issue-uri"  $false
    $sendOn         = Get-ActionInput     "send-on"          $false

    if ([System.String]::IsNullOrEmpty($buildConfig))
    {
        $buildConfig = "-na-"
    }
    else
    {
        $buildConfig = $buildConfig.ToLower()
    }

    if ([System.String]::IsNullOrEmpty($testFilter))
    {
        $testFilter = "-na-"
    }

    if ([System.String]::IsNullOrEmpty($buildIssueUri))
    {
        $buildIssueUri = "-na-"
    }

    # Exit if the notification shouldn't be transmitted based on the build step outcome
    # and its success output.  We're going to do a simple string match here rather than parsing
    # [send-on].

    $sendAlways = $sendOn.Contains("always")

    if (!$sendAlways -and !$sendOn.Contains($buildOutcome))
    {
        # Handle the build-success/fail build step result.

        if ($buildSuccess -and $sendOn.Contains("build-success"))
        {
            # Send the notification below.
        }
        elseif (!$buildSuccess -and $sendOn.Contains("build-fail"))
        {
            # Send the notification below.
        }
        else 
        {
            # Exit so we don't send a notification.

            return
        }
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

    # Fetch the workflow and run run URIs.

    $workflowUri    = Get-ActionWorkflowUri
    $workflowRunUri = Get-ActionWorkflowRunUri

    # Determine the reason why the workflow was triggered based on the GITHUB_EVENT_NAME
    # and GITHUB_ACTOR environment variables.

    $eventName = $env:GITHUB_EVENT_NAME
    $actor     = $env:GITHUB_ACTOR

    if (![System.String]::IsNullOrEmpty($actor))
    {
        $actor = $actor.ToUpper()
    }

    if (![System.String]::IsNullOrEmpty($eventName))
    {
        $eventName = $eventName.ToUpper()
    }

    if ($eventName -eq "workflow_dispatch")
    {
        $trigger = "Started by: **$actor**"
    }
    else
    {
        $trigger = "Event trigger: **$eventName**"
    }

    # Set the theme color based on the build outcome/success inputs.

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

    if (!$buildSuccess)
    {
        $themeColor   = "ff0000" # red
        $buildOutcome = "BUILD FAILED"
    }

    # Format $buildOutcome

    $buildOutcome = "**$buildOutcome**"

    # This is the legacy MessageCard format (Adaptive Cards are not supported by
    # the Teams Connector at this time):
    #
    #   https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference

    $card = 
@'
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "themeColor": "@theme-color",
  "summary": "@build-summary",
  "sections": [
    {
      "activityTitle": "@build-summary",
      "activitySubtitle": "@trigger",
    },
    {
      "facts": [
        {
          "name": "Outcome:",
          "value": "@build-outcome"
        },
        {
          "name": "Branch:",
          "value": "@build-branch"
        },
        {
          "name": "Config:",
          "value": "@build-config"
        },
        {
          "name": "Commit:",
          "value": "@build-commit-uri"
        },
        {
          "name": "Issue:",
          "value": "@issue-uri"
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

    $card = $card.Replace("@build-summary", $buildSummary)
    $card = $card.Replace("@trigger", $trigger)
    $card = $card.Replace("@issue-uri", $buildIssueUri)
    $card = $card.Replace("@runner", $env:COMPUTERNAME)
    $card = $card.Replace("@build-branch", $buildBranch)
    $card = $card.Replace("@build-config", $buildConfig)
    $card = $card.Replace("@build-commit-uri", $buildCommitUri)
    $card = $card.Replace("@build-outcome", $buildOutcome.ToUpper())
    $card = $card.Replace("@workflow-run-uri", $workflowRunUri)
    $card = $card.Replace("@workflow-uri", $workflowUri)
    $card = $card.Replace("@finish-time", $finishTime)
    $card = $card.Replace("@elapsed-time", $elapsedTime)
    $card = $card.Replace("@theme-color", $themeColor)

    # Post the card to Microsoft Teams.

    Invoke-WebRequest -Method "POST" -Uri $channel -ContentType "application/json" -Body $card | Out-Null
}
catch
{
    Write-ActionException $_
    exit 1
}

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

    $channel          = Get-ActionInput     "channel"            $true
    $buildSummary     = Get-ActionInput     "build-summary"      $true
    $buildBranch      = Get-ActionInput     "build-branch"       $false
    $buildConfig      = Get-ActionInput     "build-config"       $false
    $buildCommit      = Get-ActionInput     "build-commit"       $false
    $buildCommitUri   = Get-ActionInput     "build-commit-uri"   $false
    $buildLogUri      = Get-ActionInput     "build-log-uri"      $false
    $startTime        = Get-ActionInput     "start-time"         $false
    $finishTime       = Get-ActionInput     "finish-time"        $false
    $buildOutcome     = Get-ActionInput     "build-outcome"      $true
    $buildSuccess     = Get-ActionInputBool "build-success"      $false $false
    $issueRepo        = Get-ActionInput     "issue-repo"         $false
    $issueTitle       = Get-ActionInput     "issue-title"        $false
    $issueAssignees   = Get-ActionInput     "issue-assignees"    $false
    $issueLabels      = Get-ActionInput     "issue-labels"       $false
    $issueAppendLabel = Get-ActionInput     "issue-append-label" $false
    $sendOn           = Get-ActionInput     "send-on"            $false

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
        $buildBranchHtml = "-na-"
        $buildBranchMd   = "-na-"
    }
    else
    {
        $buildBranchHtml = "<b>$buildBranch</b>"
        $buildBranchMd   = "**$buildBranch**"
    }

    if ([System.String]::IsNullOrEmpty($buildCommit) -or [System.String]::IsNullOrEmpty($buildCommitUri))
    {
        $buildCommitUri = "-na-"
    }
    else
    {
        $buildCommitUri = "[$buildCommit]($buildCommitUri)"
    }

    # Set $buildLogHtmlLink and $buildLogMdLink to the HTML and Mark Down
    # links to the build log, if any.

    if ([System.String]::IsNullOrEmpty($buildLogUri))
    {
        $buildLogHtmlLink = "-na-"
        $buildLogMdLink   = "-na-"
    }
    else
    {
        $buildLogHtmlLink = "<a href=`"$buildLogUri`">build log</a>"
        $buildLogMdLink   = "[build log]($buildLogUri)"
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

    # Fetch the runner name.

    $runner = Get-ProfileValue "runner.name"
    $runner = $runner.ToUpper()

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

    #--------------------------------------------------------------------------
    # Create an issue if enabled and the build failed or append to an existing
    # open issue with the same title and label.

    $issueUri = "-na-"

    if (!$buildSuccess -and ![System.String]::IsNullOrEmpty($issueRepo))
    {
        if ([System.String]::IsNullOrEmpty($issueTitle))
        {
            $issueTitle = "Build failed!"
        }
        else
        {
            $issueTitle = "FAILED: $issueTitle"
        }

        $assignees = @()

        if (![System.String]::IsNullOrEmpty($issueAssignees))
        {
            ForEach ($assignee in $issueAssignees.Split(" "))
            {
                $assignee = $assignee.Trim();
                
                if ([System.String]::IsNullOrEmpty($asignee))
                {
                    Continue;
                }

                $assignees += $assignee
            }
        }

        $labels = @()

        if (![System.String]::IsNullOrEmpty($issueLabels))
        {
            ForEach ($label in $issueLabels.Split(" "))
            {
                $label = $label.Trim();
                
                if ([System.String]::IsNullOrEmpty($label))
                {
                    Continue;
                }

                $labels += $label
            }
        }

        $issueBody =
@'
<table>
<tr>
  <td><b>Outcome:</b></td>
  <td><b>BUILD FAILED</b></td>
</tr>
<tr>
  <td><b>Branch:</b></td>
  <td>@build-branch</td>
</tr>
<tr>
  <td><b>Config:</b></td>
  <td>@build-config</td>
</tr>
<tr>
  <td><b>Commit:</b></td>
  <td>@build-commit</td>
</tr>
<tr>
  <td><b>Log:</b></td>
  <td>@build-log-link</td>
</tr>
<tr>
  <td><b>Runner:</b></td>
  <td>@runner</td>
</tr>
<tr>
  <td><b>Workflow Run:</b></td>
  <td><a href="@workflow-run-uri">link</a></td>
</tr>
<tr>
  <td><b>Workflow:</b></td>
  <td><a href="@workflow-uri">link</a></td>
</tr>
</table>
'@
        if ([System.String]::IsNullOrEmpty($buildConfig))
        {
            $buildConfig = "-na-"
        }

        if (![System.String]::IsNullOrEmpty($buildCommit) -and ![System.String]::IsNullOrEmpty($buildCommitUri))
        {
            $buildCommit = "<a href=`"$buildCommitUri`">$buildCommit</a>"
        }
        else
        {
            $buildCommit = "-na-"
        }

        $issueBody = $issueBody.Replace("@build-log-link", $buildLogHtmlLink)
        $issueBody = $issueBody.Replace("@build-branch", $buildBranchHtml)
        $issueBody = $issueBody.Replace("@build-config", $buildConfig)
        $issueBody = $issueBody.Replace("@build-commit", $buildCommit)
        $issueBody = $issueBody.Replace("@runner", $runner)
        $issueBody = $issueBody.Replace("@workflow-run-uri", $workflowRunUri)
        $issueBody = $issueBody.Replace("@workflow-uri", $workflowUri)

        # Create the new issue or append to an existing one with the 
        # same author, append label, and title.

        $issueUri = New-GitHubIssue -Repo           $issueRepo `
                                    -Title          $issueTitle `
                                    -Body           $issueBody `
                                    -AppendLabel    $issueAppendLabel `
                                    -Labels         $labels `
                                    -Assignees      $issueAssignees `
                                    -MasterPassword $env:MASTER_PASSWORD
    }

    #--------------------------------------------------------------------------
    # Send the MSFT Teams notification

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
          "name": "Log:",
          "value": "@build-log-uri"
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
    $card = $card.Replace("@runner", $runner)
    $card = $card.Replace("@build-branch", $buildBranchMd)
    $card = $card.Replace("@build-config", $buildConfig)
    $card = $card.Replace("@build-commit-uri", $buildCommitUri)
    $card = $card.Replace("@build-log-uri", $buildLogMdLink)
    $card = $card.Replace("@issue-uri", $issueUri)
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

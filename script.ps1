#------------------------------------------------------------------------------
# FILE:         script.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

Write-Output "HELLO WORLD!"

#------------------------------------------------------------------------------
# Sends an automated operation related message to a Teams channel.
#
# ARGUMENTS:
#
#   channel         - Target Teams channel webhook URI
#   operation       - Identifies what's being built
#   startTime       - Time when the operation started
#   endTime         - Time when the operation completed or failed
#   elapsedTime     - Elapsed operation run time
#   status          - Operation status, one of: 'ok', 'warning', or 'failed'

[CmdletBinding()]
param
(
    [Parameter(Position=0, Mandatory=1)]
    [string] $channel,
    [Parameter(Position=1, Mandatory=1)]
    [string] $operation,
    [Parameter(Position=2, Mandatory=1)]
    [string] $startTime,
    [Parameter(Position=3, Mandatory=1)]
    [string] $endTime,
    [Parameter(Position=4, Mandatory=1)]
    [string] $elapsedTime,
    [Parameter(Position=5, Mandatory=1)]
    [string] $status
)
    
# Check the parameters.

if ([System.String]::IsNullOrEmpty($channel))
{
    throw "[channel] parameter is required."
}

if ([System.String]::IsNullOrEmpty($operation))
{
    throw "[operation] parameter is required."
}

if ([System.String]::IsNullOrEmpty($startTime))
{
    throw "[startTime] parameter is required."
}

if ([System.String]::IsNullOrEmpty($endTime))
{
    throw "[endTime] parameter is required."
}

if ([System.String]::IsNullOrEmpty($elapsedTime))
{
    throw "[elapsedTime] parameter is required."
}

if ([System.String]::IsNullOrEmpty($status))
{
    throw "[status] parameter is required."
}

if (($status -ne "ok") -and ($status -ne "warning") -and ($status -ne "error"))
{
    throw "[$status] is not a valid status code."
}

$workflowRunUri = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# We're going to use search/replace to modify a template message.

$message = 
@'
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "themeColor": "3d006d",
    "sections": [
        {
            "activityTitle": "@operation",
            "activitySubtitle": "@runner",
            "activityText": "@status",
            "activityImage": "@statusLink"
        },
        {
            "title": "Details:",
            "facts": [
                {
                    "name": "started:",
                    "value": "@startTime"
                },
                {
                    "name": "finished:",
                    "value": "@finishTime"
                },
                {
                    "name": "elapsed:",
                    "value": "@elapsedTime"
                },
                {
                    "name": "link:",
                    "value": "@workflowRunUri"
                }
            ]
        }
    ]
}    
'@

$message = $template.Replace("@operation", $operation)
$message = $template.Replace("@runner", $env:COMPUTERNAME)
$message = $template.Replace("@status", $status.ToUpper())
$message = $template.Replace("@startTime", $startTime)
$message = $template.Replace("@finishTime", $finishTime)
$message = $template.Replace("@elapsedTime", $elapsedTime)
$message = $template.Replace("@workflowRunUri", $workflowRunUri)

# Post the message to Microsoft Teams.

Invoke-WebRequest -Method "POST" -Uri $channel -ContentType "application/json" -Body $message



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
#   end-time        - Time when the operation completed or failed
#   elapsed-time    - Elapsed operation run time
#   status          - Operation status, one of: 'ok', 'warning', or 'failed'
    
# Fetch the inputs.

$channel     = Get-ActionIput "channel"
$operation   = Get-ActionIput "operation"
$startTime   = Get-ActionIput "start-time"
$endTime     = Get-ActionIput "end-time"
$elapsedTime = Get-ActionIput "elapsed-time"
$status      = Get-ActionIput "status"

if ([System.String]::IsNullOrEmpty($channel))
{
    throw "[channel] input is required."
}

if ([System.String]::IsNullOrEmpty($operation))
{
    throw "[operation] input is required."
}

if ([System.String]::IsNullOrEmpty($startTime))
{
    throw "[start-time] input is required."
}

if ([System.String]::IsNullOrEmpty($endTime))
{
    throw "[end-time] input is required."
}

if ([System.String]::IsNullOrEmpty($elapsedTime))
{
    throw "[elapsed-tTime] input is required."
}

if ([System.String]::IsNullOrEmpty($status))
{
    throw "[status] input is required."
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
                    "value": "@@channel"
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
$message = $template.Replace("@channel", $channel)

# Post the message to Microsoft Teams.

Invoke-WebRequest -Method "POST" -Uri $channel -ContentType "application/json" -Body $message



#------------------------------------------------------------------------------
# FILE:         script.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#------------------------------------------------------------------------------
# Sends an automated operation related message to a Teams channel.
#
# ARGUMENTS:
#
#   channelUri      - Target Teams channel webhook URI
#   operation       - Identifies what's being built
#   startTime       - Time when the operation started
#   endTime         - Time when the operation completed or failed
#   elapsedTime     - Elapsed operation run time
#   status          - Operation status, one of: 'ok', 'warning', or 'failed'

[CmdletBinding()]
param
(
    [Parameter(Position=0, Mandatory=1)]
    [string] $channelUri,
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

if ([System.String]::IsNullOrEmpty($channelUri))
{
    throw "[channelUri] parameter is required."
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

if (($status -ne "ok") -or ($status -ne "warning") -or ($status -ne "error"))
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

Invoke-WebRequest -Method "POST" -Uri $channelUri -ContentType "application/json" -Body $message



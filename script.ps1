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
# Sends a build related message.
#
# ARGUMENTS:
#
#   channelUri      - Target Teams channel webhook URI
#   operation       - Identifies what's being built
#   workflowName:   - Identifies the workflow
#   startTime       - Time when the build started
#   endTime         - Time when the build completed or failed
#   elapsedTime     - Elapsed build time
#   status          - Operation status, one of: 'ok', 'warning', or 'failed'
#   workflowRunUri  - URI to the workflow run

function Send-BuildMessage
{
    [CmdletBinding()]
    param 
	  (
        [Parameter(Position=0, Mandatory=1)]
        [string] $channelUri,
        [Parameter(Position=1, Mandatory=1)]
        [string] $operation,
        [Parameter(Position=2, Mandatory=1)]
        [string] $workflowName,
        [Parameter(Position=3, Mandatory=1)]
        [string] $startTime,
        [Parameter(Position=4, Mandatory=1)]
        [string] $endTime,
        [Parameter(Position=5, Mandatory=1)]
        [string] $elapsedTime,
        [Parameter(Position=6, Mandatory=1)]
        [string] $status,
    )

    
}


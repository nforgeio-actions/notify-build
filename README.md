# teams-notify-build

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason why this repo is public is because GitHub requires it.

Sends a build related notification to a Microsoft Teams channel via a user-specific channel webhook URI.

## Examples

**Capture the start/end timestamps for a build and then report to a Teams channel**
```
name: test-build
on:
  workflow_dispatch:
jobs:
  test:
    runs-on: self-hosted
    steps:
    - id: setup-node
      uses: actions/setup-node@v2
      with:
        node-version: '14'    
    - id: environment
      uses: nforgeio-actions/environment@master
      with:
        master-password: ${{ secrets.DEVBOT_MASTER_PASSWORD }}
    - id: checkout-repos
      uses: nforgeio-actions/checkout@master
      with:
        branch: master
    - id: start-timestamp
      uses: nforgeio-actions/timestamp@master
    - id: build
      uses: nforgeio-actions/build@master
    - id: end-timestamp
      uses: nforgeio-actions/timestamp@master

    # Here's the notification step.  Note how we're obtaining the start/end
    # timestamps from [timestamp] actions surrounding the build step and also
    # that we're passing the build step's outcome as well.

    - id: teams-notification
      uses: nforgeio-actions/teams-notify-build@master
      if: ${{ always() }}
      with:
        operation: neonFORGE Build
        channel: ${{ steps.environment.outputs.TEAM_DEVOPS_CHANNEL }}
        start-time: ${{ steps.start-timestamp.outputs.value }}
        finish-time: ${{ steps.end-timestamp.outputs.value }}
        build-outcome: ${{ steps.build.outcome }}
        workflow-ref: https://github.com/nforgeio/neonCLOUD/blob/master/.github/workflows/action-test.yaml

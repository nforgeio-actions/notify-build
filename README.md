# teams-notify-build

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason why this repo is public is because GitHub requires it.

Sends a build related notification to a Microsoft Teams channel via a user-specific channel webhook URI.

## Examples

**Do a build and then report to a Teams channel**
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
    - id: build
      uses: nforgeio-actions/build@master

    # Here's the notification step.

    - id: teams-notification
      uses: nforgeio-actions/teams-notify-build@master
      if: ${{ always() }}
      with:
        operation: neonFORGE Build
        channel: ${{ steps.environment.outputs.TEAM_DEVOPS_CHANNEL }}
        build-outcome: ${{ steps.build.outcome }}
        workflow-ref: https://github.com/nforgeio/neonCLOUD/blob/master/.github/workflows/action-test.yaml
```

**Report only for non-successful builds:**
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
    - id: build
      uses: nforgeio-actions/build@master

    # Here's the notification step.  Note how the [send-on] input
    # specifies all of the non-success outcomes.

    - id: teams-notification
      uses: nforgeio-actions/teams-notify-build@master
      if: ${{ always() }}
      with:
        operation: neonFORGE Build
        channel: ${{ steps.environment.outputs.TEAM_DEVOPS_CHANNEL }}
        build-outcome: ${{ steps.build.outcome }}
        workflow-ref: https://github.com/nforgeio/neonCLOUD/blob/master/.github/workflows/action-test.yaml
        send-on: "failure, cancelled, skipped""
```

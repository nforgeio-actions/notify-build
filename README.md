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
        channel: ${{ steps.environment.outputs.TEAM_DEVOPS_CHANNEL }}
        build-summary: neonFORGE Build
        build-outcome: ${{ steps.build.outcome }}
        build-success: ${{ steps.build.outputs.success }}
        workflow-ref: https://github.com/nforgeio/neonCLOUD/blob/master/.github/workflows/action-test.yaml
```

**Notify only for non-successful builds:**
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
        channel: ${{ steps.environment.outputs.TEAM_DEVOPS_CHANNEL }}
        build-summary: neonFORGE Build
        build-outcome: ${{ steps.build.outcome }}
        build-success: ${{ steps.build.outputs.success }}
        workflow-ref: https://github.com/nforgeio/neonCLOUD/blob/master/.github/workflows/action-test.yaml
        send-on: "build-fail failure cancelled skipped"
```

**Include build time in the notification:**
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

    # Surround the build step with start/finish timestamp steps.

    - id: start-timestamp
      uses: nforgeio-actions/timestamp@master
      if: ${{ always() }}

    - id: build
      uses: nforgeio-actions/build@master

    - id: finish-timestamp
      uses: nforgeio-actions/timestamp@master
      if: ${{ always() }}

    # Here's the notification step.  Note how we're passing the
    # timestamp step outputs.

    - id: teams-notification
      uses: nforgeio-actions/teams-notify-build@master
      if: ${{ always() }}
      with:
        channel: ${{ steps.environment.outputs.TEAM_DEVOPS_CHANNEL }}
        start-time: ${{ steps.start-timestamp.outputs.value }}
        finish-time: ${{ steps.finish-timestamp.outputs.value }}
        build-summary: neonFORGE Build
        build-outcome: ${{ steps.build.outcome }}
        build-success: ${{ steps.build.outputs.success }}
        workflow-ref: https://github.com/nforgeio/neonCLOUD/blob/master/.github/workflows/action-test.yaml
```

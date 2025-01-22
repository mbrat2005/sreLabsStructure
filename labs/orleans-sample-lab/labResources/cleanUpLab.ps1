# function to find and remove deployment stacks related to the lab

Function Start-LabInstanceCleanup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $labInstancePrefix,

        [Parameter(Mandatory=$false)]
        [switch]
        $whatIf
    )

    # if no lab instance prefix was provided, get all subscription level deployment stacks
    If (-not $labInstancePrefix) {
        $deploymentStacks = Get-AzSubscriptionDeploymentStack
    }
    Else {

    # get all deployment stacks related to the lab
    $deploymentStacks = Get-AzSubscriptionDeploymentStack | Where-Object { $_.Name -like "$labInstancePrefix*" }
    }

    # if more than one deployment stack found, allow the user to select the one to remove
    If ($deploymentStacks.Count -gt 1) {
        Write-Host "Multiple deployment stacks found for lab instance prefix '$labInstancePrefix'. Select the one to remove in the new window.`n"

        $deploymentStacks | Format-Table Name, Location
        $deploymentStack = $deploymentStacks | Out-GridView -Title "Select the deployment stack to remove" -PassThru
    }
    # if only one deployment stack found, use that one
    ElseIf ($deploymentStacks.Count -eq 1) {
        $deploymentStack = $deploymentStacks[0]
    }
    # if no deployment stack found, exit
    Else {
        Write-Host "No deployment stacks found for lab instance prefix '$labInstancePrefix'"
        exit
    }

    # remove all deployment stacks related to the lab
    Write-Host "Removing deployment stack '$($deploymentStack.Name)'..."

    Remove-AzSubscriptionDeploymentStack -Name $deploymentStack.Name -Force -ActionOnUnmanage DeleteAll -WhatIf:$whatIf

    If ($?) {
        Write-Host "Deployment stack '$($deploymentStack.Name)' removed"
    }
    Else {
        Write-Host "Failed to remove deployment stack '$($deploymentStack.Name)'. See above error for details."
    }
}
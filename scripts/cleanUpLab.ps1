<#
.SYNOPSIS
    Cleans up an instance of an SRE Academy lab
.DESCRIPTION
    This script cleans up an instance of an SRE Academy lab by removing the deployment stack associated with the lab instance prefix.
.NOTES
    Removal of the Deployment Stack ensures that all resources created by the lab are removed from the subscription.
.LINK
    
.EXAMPLE
    .\cleanUpLab.ps1 -labInstancePrefix 'orleans-lab-20210901120000'
    Removes the deployment stack associated with the Orleans sample lab instance prefix 'orleans-lab-20210901120000'

.EXAMPLE
    .\cleanUpLab.ps1 -labInstancePrefix 'orleans-lab-20210901120000' -whatIf
    Tests prerequisites for removing the deployment stack associated with the Orleans sample lab instance prefix 'orleans-lab-20210901120000', but does not remove the deployment stack
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]
    $labInstancePrefix,

    [Parameter(Mandatory=$false)]
    [switch]
    $whatIf
)

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
        $deploymentStacks = Get-AzSubscriptionDeploymentStack | Where-Object { $_.tags.Keys -contains 'labInstancePrefix' }
    }
    Else {

    # get all deployment stacks related to the lab
    $deploymentStacks = Get-AzSubscriptionDeploymentStack | Where-Object { $_.Name -like "$labInstancePrefix*" -and $_.tags.Keys -contains 'labInstancePrefix'}
    }

    # if more than one deployment stack found, allow the user to select the one to remove
    If ($deploymentStacks.Count -gt 1) {
        Write-Host "Multiple deployment stacks found for lab instance prefix '$labInstancePrefix'. Select the one to remove in the new window.`n"

        for ($i = 0; $i -lt $deploymentStacks.Count; $i++) {
            Write-Host "$i. $($deploymentStacks[$i].Name)"
        }

        $selection = Read-Host "Enter the number of the deployment stack to remove"
        if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -lt $deploymentStacks.Count) {
            $deploymentStack = $deploymentStacks[$selection]
        } else {
            Write-Host "Invalid selection. Exiting."
            exit
        }
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

    # warn user that they are about to delete the selected deployment stack
    Write-Host "You are about to delete the following deployment stack:`n"
    $deploymentStack | Format-Table Name, Location
    Write-Host "`nThis action cannot be undone.`n"
    # confirm with the user that they want to delete the selected deployment stack
    $confirm = $false
    While (-not $confirm) {
        $response = (Read-Host "Are you sure you want to delete the deployment stack '$($deploymentStack.Name)'? (y/n)")
        If ($response -match '[yY]') { $confirm = $true }
        ElseIf ($response -match '[nN]') { exit }
    }

    # remove all deployment stacks related to the lab
    Write-Host "Removing deployment stack '$($deploymentStack.Name)'..."

    try {
        Remove-AzSubscriptionDeploymentStack -Name $deploymentStack.Name -Force -ActionOnUnmanage DeleteAll -WhatIf:$whatIf -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to remove deployment stack '$($deploymentStack.Name)'. See error for details $_"
        exit
    }

    If ($?) {
        Write-Host "Deployment stack '$($deploymentStack.Name)' removed"
    }
    Else {
        Write-Host "Failed to remove deployment stack '$($deploymentStack.Name)'. See above error for details."
    }
}

Write-Host "SRE Academy Labs are deployed as Deployment Stacks at the subscription level. To clean up a lab's contents, we remove the Deployment Stack. This script finds deployed SRE lab deployment stacks and cleans them up by your selection."

Start-LabInstanceCleanup @PSBoundParameters
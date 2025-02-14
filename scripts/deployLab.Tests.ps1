# Import the script to test
. "$PSScriptRoot/deployLab.ps1"

Describe "Test-LabPrerequisites" {
    It "Throws an error if lab metadata file is not found" {
        { Test-LabPrerequisites -labMetadataPath "invalidPath" -labResourcesPath "validPath" } | Should -Throw "Lab metadata file not found at 'invalidPath'"
    }

    It "Throws an error if lab metadata file is not valid JSON" {
        $labMetadataPath = "validPath"
        Set-Content -Path $labMetadataPath -Value "invalid JSON"
        { Test-LabPrerequisites -labMetadataPath $labMetadataPath -labResourcesPath "validPath" } | Should -Throw "Lab metadata file at 'validPath' is not valid JSON"
    }

    It "Throws an error if lab resources file is not found" {
        $labMetadataPath = "validPath"
        Set-Content -Path $labMetadataPath -Value '{"validRegions": ["eastus"]}'
        { Test-LabPrerequisites -labMetadataPath $labMetadataPath -labResourcesPath "invalidPath" } | Should -Throw "Lab resources file not found at invalidPath"
    }

    It "Throws an error if Bicep CLI is not found in PATH" {
        $labMetadataPath = "validPath"
        $labResourcesPath = "validPath"
        Set-Content -Path $labMetadataPath -Value '{"validRegions": ["eastus"]}'
        { Test-LabPrerequisites -labMetadataPath $labMetadataPath -labResourcesPath $labResourcesPath } | Should -Throw "Bicep CLI not found in PATH"
    }

    It "Throws an error if Azure PowerShell Module is not found" {
        $labMetadataPath = "validPath"
        $labResourcesPath = "validPath"
        Set-Content -Path $labMetadataPath -Value '{"validRegions": ["eastus"]}'
        { Test-LabPrerequisites -labMetadataPath $labMetadataPath -labResourcesPath $labResourcesPath } | Should -Throw "Azure PowerShell Module not found"
    }

    It "Throws an error if not logged into Azure" {
        $labMetadataPath = "validPath"
        $labResourcesPath = "validPath"
        Set-Content -Path $labMetadataPath -Value '{"validRegions": ["eastus"]}'
        { Test-LabPrerequisites -labMetadataPath $labMetadataPath -labResourcesPath $labResourcesPath } | Should -Throw "Run 'Connect-AzAccount' before executing this script!"
    }
}

Describe "Start-LabDeployment" {
    It "Deploys the lab with correct parameters" {
        $labMetadataPath = "validPath"
        $labResourcesPath = "validPath"
        $deploymentLocation = "eastus"
        $labInstancePrefix = "test-lab"
        $studentAlias = "testAlias"
        $expirationDate = Get-Date

        Mock New-AzSubscriptionDeploymentStack

        Start-LabDeployment -labMetadataPath $labMetadataPath -labResourcesPath $labResourcesPath -deploymentLocation $deploymentLocation -labInstancePrefix $labInstancePrefix -studentAlias $studentAlias -expirationDate $expirationDate

        Assert-MockCalled New-AzSubscriptionDeploymentStack -Exactly 1 -Scope It
    }
}

Describe "Main Script Logic" {
    It "Prompts for lab content path if not provided" {
        Mock Read-Host { "validPath" }
        Mock Test-Path { $true }

        . "$PSScriptRoot/deployLab.ps1"

        Assert-MockCalled Read-Host -Exactly 1 -Scope It
    }

    It "Prompts for student alias if not provided" {
        Mock Read-Host { "testAlias" }

        . "$PSScriptRoot/deployLab.ps1"

        Assert-MockCalled Read-Host -Exactly 1 -Scope It
    }

    It "Skips deployment if -whatIf flag is set" {
        Mock Write-Host

        . "$PSScriptRoot/deployLab.ps1" -whatIf

        Assert-MockCalled Write-Host -Exactly 1 -Scope It -ParameterFilter { $_ -eq "Skipping deployment due to -whatIf flag" }
    }
}
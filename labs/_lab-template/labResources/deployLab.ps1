[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $deploymentLocation
)

Function Test-LabPrerequisites {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $labMetadataPath,

        [Parameter()]
        [string]
        $labResourcesPath,

        [Parameter()]
        [string]
        $deploymentLocation
    )

    # check for lab metadata file
    if (-not (Test-Path $labMetadataPath)) {
        throw "Lab metadata file not found at $labMetadataPath"
    }

    $labMetadata = Get-Content $labMetadataPath | ConvertFrom-Json

    # check that deployment location is in lab metadata
    If (-not ($labMetadata.validRegions -contains $deploymentLocation)) {
        throw "Deployment location '$deploymentLocation' not found in lab metadata. Valid locations are $($labMetadata.locations -join ', ')"
    }

    # check for lab resources file
    if (-not (Test-Path $labResourcesPath)) {
        throw "Lab resources file not found at $labResourcesPath"
    }

    # check for bicep in PATH
    If (-not (Get-Command -CommandType Application -Name bicep.exe -ErrorAction SilentlyContinue)) {
        throw "Bicep CLI not found in PATH. Please install Bicep CLI"
    }

    # check for Azure PowerShell Module
    If (-not (Get-Module -Name Az -ListAvailable)) {
        throw "Azure PowerShell Module not found. Please install Azure PowerShell Module"
    }

    # check that Azure is logged in and correct subscription selected
    If ( -NOT ($azContext = Get-AzContext)) {
        throw "Run 'Connect-AzAccount' before executing this script!"
    }
    ElseIf ($confirm) {
        do { $response = (Read-Host "Resources will be created in subscription '$($azContext.Subscription.Name)' in region '$location'. If this is not the correct subscription, use 'Select-AzSubscription' before running this script and specify an alternate location with the -Location parameter. Proceed? (y/n)") }
        until ($response -match '[nNYy]')
    
        If ($response -match 'nN') { exit }
    }

    # check that Az.Quota module is installed
    If (-not (Get-Module -Name Az.Quota -ListAvailable)) {
        Write-Warning "Az.Quota module not found. Please install Az.Quota module to check quotas"

        Install-Module Az.Quota -Scope CurrentUser
    }

    # TODO check that quotas are available in required regions
    # ForEach ($requiredQuota in $labMetadata.requiredQuotas) {
    #     $quota = Get-AzVMUsage -Location $requiredQuota.location | Where-Object {$_.Name -eq $requiredQuota.resourceType}
    #     If ($requiredQuota.quotaAmount -ge $quota.Limit) {
    #         throw "Quota for '$($requiredQuota.quotaName)' in $requiredQuota.location is at limit. Please request a quota increase."
    #     }
    # }

    # TODO check that required permissions for lab resources are available
    # $labMetadata.deploymentPermissions

    Write-Host "All prerequisites met"
}

Function Start-LabDeployment {
    # TODO
}

$labMetadataPath = './labMetadata.json'
$labResourcesPath = './labResources/main.bicep'

Test-LabPrerequisites -labMetadataPath $labMetadataPath -labResourcesPath $labResourcesPath -deploymentLocation $deploymentLocation

Start-LabDeployment
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $deploymentLocation,

    [Parameter()]
    [string]
    $labInstancePrefix = ('adhoc-sre-lab_{0}' -f (Get-Date -Format 'yyyyMMddHHmmss'))
)

Function Test-LabPrerequisites {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $labMetadataPath,

        [Parameter(Mandatory=$true)]
        [string]
        $labResourcesPath,

        [Parameter(Mandatory=$false)]
        [string]
        $deploymentLocation
    )

    # check for lab metadata file
    if (-not (Test-Path $labMetadataPath)) {
        throw "Lab metadata file not found at '$labMetadataPath'"
    }

    # convert lab metadata file from JSON to PowerShell object
    $labMetadata = Get-Content $labMetadataPath | ConvertFrom-Json

    # set deployment location if none was provided
    If (-not $deploymentLocation) {
        $deploymentLocation = $labMetadata.validRegions[0]
    }

    # check that deployment location is in lab metadata
    If (-not ($labMetadata.validRegions -contains $deploymentLocation)) {
        throw "Deployment location '$deploymentLocation' not found in lab metadata. Valid locations are $($labMetadata.validRegions -join ', ')"
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
    If (-not (Get-Module -Name Az.* -ListAvailable)) {
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

    # check that quotas are available in required regions
    ForEach ($requiredQuota in $labMetadata.requiredQuotas) {
        $scopeString = "/subscriptions/{0}/providers/{1}/locations/{2}" -f $azContext.Subscription.Id, $requiredQuota.quotaResourceProvider, $deploymentLocation
        
        Write-Verbose "Checking quota for '$scopeString'"
        $quota = Get-AzQuota -Scope $scopeString -ResourceName $requiredQuota.quotaName
        $usage = Get-AzQuotaUsage -Scope $scopeString -Name $requiredQuota.quotaName

        Write-Verbose "Calculating available quota by subtracting usage ('$($usage.UsageValue)') from limit ('$($quota.Limit.Value)')"
        $availableQuota = $quota.Limit.Value - $usage.UsageValue

        If ($requiredQuota.quotaAmount -ge $availableQuota) {
            throw "Quota for '$($requiredQuota.quotaName)' in $($deploymentLocation) is at limit. Required '$($requiredQuota.quotaAmount)', Available: '$availableQuota'. Either use another region or subscription for you deployment which as sufficient quota."
        }
        Else {
            Write-Verbose "Sufficient quota for '$($requiredQuota.quotaName)' in '$deploymentLocation'. Required: '$($requiredQuota.quotaAmount)', Available: '$availableQuota'"
        }
    }

    # check that required permissions for lab resources are available
    # $labMetadata.deploymentPermissions

    Write-Host "All prerequisites met"
}

Function Start-LabDeployment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $labMetadataPath,

        [Parameter(Mandatory=$true)]
        [string]
        $labResourcesPath,

        [Parameter(Mandatory=$false)]
        [string]
        $deploymentLocation,

        [Parameter(Mandatory=$true)]
        [string]
        $labInstancePrefix
    )

    $labMetadata = Get-Content $labMetadataPath | ConvertFrom-Json

    New-AzSubscriptionDeploymentStack -Name $labInstancePrefix -Location $deploymentLocation -TemplateFile $labResourcesPath -ActionOnUnmanage DeleteAll -DenySettingsMode None -TemplateParameterObject @{
        location = $deploymentLocation
        labInstancePrefix = $labInstancePrefix
    }
}

$labMetadataPath = './labMetadata.json'
$labResourcesPath = './labResources/main.bicep'

$hardCodedLocation = 'eastus'

Test-LabPrerequisites -labMetadataPath $labMetadataPath -labResourcesPath $labResourcesPath -deploymentLocation $hardCodedLocation

Start-LabDeployment -labMetadataPath $labMetadataPath -labResourcesPath $labResourcesPath -deploymentLocation $hardCodedLocation -labInstancePrefix $labInstancePrefix 
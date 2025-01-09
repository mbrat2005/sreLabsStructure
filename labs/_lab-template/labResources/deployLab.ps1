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

    # check that quotas are available in required regions
    ForEach ($requiredQuota in $labMetadata.requiredQuotas) {
        $scopeString = "/subscriptions/{0}/providers/{1}/locations/{2}/{3}" -f $azContext.Subscription.Id, $requiredQuota.resourceProvider, $requiredQuota.location,$requiredQuota.quotaName
        
        Write-Verbose "Checking quota for '$scopeString'"
        $quota = Get-AzQuota -Scope $scopeString
        $usage = Get-AzQuotaUsage -Scope $scopeString

        Write-Verbose "Calculating available quota by subtracting usage ('$($usage.UsageValue)') from limit ('$($quota.Limit)')"
        $availableQuota = $quota.Limit - $usage.UsageValue

        If ($requiredQuota.quotaAmount -ge $availableQuota) {
            throw "Quota for '$($requiredQuota.quotaName)' in $($requiredQuota.location) is at limit. Required '$($requiredQuota.quotaAmount)', Available: '$availableQuota'. Either use another region or subscription for you deployment which as sufficient quota."
        }
        Else {
            Write-Verbose "Sufficient quota for '$($requiredQuota.quotaName)' in $requiredQuota.location. Required: '$($requiredQuota.quotaAmount)', Available: '$availableQuota'"
        }
    }

    # check that required permissions for lab resources are available
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
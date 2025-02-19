<#
.SYNOPSIS
    Deploys an SRE Academy lab from a local directory
.DESCRIPTION
    This PowerShell script test prerequisites, then deploys the selected lab from the SRE Academy lab content directory.
.NOTES
    
.LINK
    
.EXAMPLE
    .\deployLab.ps1 -labContentPath 'C:\users\sre\sreAcademyLabs\orleans-sample-lab' -deploymentLocation 'eastus' -studentAlias 'newsre123' -expirationDate '2025-03-01'
    Deploys the Orleans sample lab from the specified directory to the 'eastus' region

.EXAMPLE
    .\deployLab.ps1 -labContentPath 'C:\users\sre\sreAcademyLabs\orleans-sample-lab' -deploymentLocation 'eastus' -labInstancePrefix 'orleans-lab-20210901120000' -studentAlias 'newsre123' -expirationDate '2025-03-01'
    Deploys the Orleans sample lab from the specified directory to the 'eastus' region with the specified lab instance prefix

.EXAMPLE
    .\deployLab.ps1 -labContentPath 'C:\users\sre\sreAcademyLabs\orleans-sample-lab' -whatIf
    Tests prerequisites for deploying the Orleans sample lab from the specified directory, but does not deploy the lab
#>


[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $labContentPath,

    [Parameter()]
    [string]
    $deploymentLocation,

    [Parameter()]
    [string]
    $labInstancePrefix = ('adhoc-sre-lab_{0}' -f (Get-Date -Format 'yyyyMMddHHmmss')),

    [Parameter()]
    [string]
    $studentAlias,

    # when centrally managed, specify to help manage cleanup automation (not implemented)
    [Parameter()]
    [datetime]
    $expirationDate,

    # skips the configured quota check before deployment. deployment may fail if quotas are exceeded
    # use to work around issue installing in the Az.Quota module, registering the Microsoft.Quota resource provider, or incorrect quota definition
    [Parameter()]
    [switch]
    $skipQuotaCheck,

    [Parameter()]
    [switch]
    $whatIf
)

$ErrorActionPreference = 'Stop'

Function Test-LabPrerequisites {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $labMetadataPath,

        [Parameter(Mandatory = $true)]
        [string]
        $labResourcesPath,

        [Parameter(Mandatory = $false)]
        [string]
        $deploymentLocation
    )

    # check for lab metadata file
    if (-not (Test-Path $labMetadataPath)) {
        throw "Lab metadata file not found at '$labMetadataPath'"
    }

    # convert lab metadata file from JSON to PowerShell object
    $labMetadataContent = Get-Content $labMetadataPath -Raw
    Write-Debug "Lab metadata content: $labMetadataContent"
    If ($labMetadataContent | Test-Json) {
        $labMetadata = $labMetadataContent | ConvertFrom-Json
    }
    Else {
        throw "Lab metadata file at '$labMetadataPath' is not valid JSON"
    }

    # set deployment location if none was provided
    If (-not $deploymentLocation) {
        If ($labMetadata.validRegions.count -ge 1) {
            $deploymentLocation = $labMetadata.validRegions | Get-Random
        }
        Else {
            Write-Verbose "Selecting random region for deployment, since -deploymentLocation was not specified and no valid regions were listed in lab metadata"
            $deploymentLocation = (get-azlocation).location | Get-Random
        }
    }

    # set deployment location in global scope
    $script:deploymentLocation = $deploymentLocation

    # check that deployment location is in lab metadata
    If (-not ($labMetadata.validRegions -contains $deploymentLocation) -or [string]::IsNullOrEmpty($labMetadata.validRegions)) {
        throw "Location '$deploymentLocation' specified by -deploymentLocation not listed as a valid location in lab metadata. Valid locations are $($labMetadata.validRegions -join ', ')"
    }

    # check for lab resources file
    if (-not (Test-Path $labResourcesPath)) {
        throw "Lab resources file not found at $labResourcesPath"
    }

    # check for bicep in PATH
    If (-not (Get-Command -CommandType Application -Name bicep -ErrorAction SilentlyContinue)) {
        throw "Bicep CLI not found in PATH. Please install Bicep CLI following the instructions at https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-powershell"
    }

    # check for Azure PowerShell Module
    If (-not (Get-Module -Name Az.* -ListAvailable)) {
        throw "Azure PowerShell Module not found. Please install Azure PowerShell Module following the instructions at https://learn.microsoft.com/powershell/azure/install-az-ps#install-the-azure-powershell-module"
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

    # check for available quota in the target subscription. Since registering RP, installing modules, and checking quota can be complicated, -skipQuotaCheck bypasses this step for troubleshooting
    If (!$skipQuotaCheck) {

        # check that Quota resource provider is registered
        if ((Get-AzResourceProvider -ProviderNamespace Microsoft.Quota -Location $deploymentLocation | Where-Object { $_.ResourceTypes.ResourceTypeName -eq 'quotas' } ).RegistrationState -ne 'Registered') {
            Write-Host "Microsoft.Quota resource provider not registered. We will register it now."

            try {
                Register-AzResourceProvider -ProviderNamespace Microsoft.Quota -ErrorAction Stop
            }
            catch {
                throw "An error occurred when attempting to register the Microsoft.Quota resource provider, which is required to verify available quota in the target subscription. To try again bypassing this step, use the -skipQuotaCheck flag. Error: $_"
            }

            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            While ((Get-AzResourceProvider -ProviderNamespace Microsoft.Quota -Location $deploymentLocation | Where-Object { $_.ResourceTypes.ResourceTypeName -eq 'quotas' } ).RegistrationState -ne 'Registered' -and $stopWatch.Elapsed.TotalMinutes -lt 15) {
                Write-Host "Waiting for Microsoft.Quota resource provider to register..."
                Start-Sleep -Seconds 5
            }

            If ($stopWatch.Elapsed.TotalMinutes -ge 15) {
                throw "Microsoft.Quota resource provider registration timed out. Please try again later."
            }
        }
        Else {
            Write-Verbose "Microsoft.Quota resource provider is registered"
        }

        # check that Az.Quota module is installed
        If (-not (Get-Module -Name Az.Quota -ListAvailable)) {
            Write-Host -ForegroundColor Yellow "Az.Quota module not found. Installing..."

            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            Install-Module Az.Quota -Scope CurrentUser
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
        }
        Else {
            Write-Verbose "Az.Quota module is installed"
        }

        # check that quotas are available in required regions
        ForEach ($requiredQuota in $labMetadata.requiredQuotas) {
            $scopeString = "/subscriptions/{0}/providers/{1}/locations/{2}" -f $azContext.Subscription.Id, $requiredQuota.quotaResourceProvider, $deploymentLocation
        
            Write-Verbose "Checking quota for '$scopeString'"
            $quota = Get-AzQuota -Scope $scopeString -ResourceName $requiredQuota.quotaName
            $usage = Get-AzQuotaUsage -Scope $scopeString -Name $requiredQuota.quotaName

            Write-Verbose "Calculating available quota by subtracting usage ('$($usage.UsageValue)') from limit ('$($quota.Limit.Value)')"
            $availableQuota = $quota.Limit.Value - $usage.UsageValue

            If ($requiredQuota.quotaAmount -gt $availableQuota) {
                throw "Quota for '$($requiredQuota.quotaName)' in $($deploymentLocation) is at the available limit. Required '$($requiredQuota.quotaAmount)', Available: '$availableQuota'. This means that the Azure subscription you are attempting to deploy into already has more of this resource type than the current quota allows in this region or that none are allowed. Either use another region or subscription for you deployment which as sufficient quota. Alternatively, clean up the resources using your quota or request a quota increase in the Portal > Subscriptions > Quotas page."
            }
            Else {
                Write-Verbose "Sufficient quota for '$($requiredQuota.quotaName)' in '$deploymentLocation'. Required: '$($requiredQuota.quotaAmount)', Available: '$availableQuota'"
            }
        }
    }
    Else {
        Write-Host "Skipping quota check due to -skipQuotaCheck flag"
    }

    # check that required permissions for lab resources are available
    ## check for owner-level permissions on subscription (default)
    If (!$labMetadata.deploymentPermissions -or $labMetadata.deploymentPermissions.count -eq 0 -or $labMetadata.deploymentPermissions.builtInRoleName -ieq 'owner') {
        Write-Verbose "No deployment permission specified, or 'Owner' role specified. Checking for owner-level permissions on subscription"

        $sufficientPermissions = $false
        $uri = 'https://management.azure.com/subscriptions/{0}/providers/Microsoft.Authorization/permissions?api-version=2022-04-01' -f $azContext.Subscription.Id
        Invoke-AzRestMethod -Method GET -Uri $uri | Select-object -expand Content | ConvertFrom-Json | Select-Object -expand Value | ForEach-Object {
            Write-Verbose "actions: $($_.actions), notActions: $($_.notActions)"
            If ($_.actions -eq '*' -and [string]::IsNullOrEmpty($_.notActions)) {
                Write-Verbose "Owner-level permissions found on subscription '$($azContext.Subscription.Name)'"
                $sufficientPermissions = $true
            }
            Else {
                Write-Verbose "Role assignment does not have 'Owner' level permissions on subscription '$($azContext.Subscription.Name)'"
            }
        }

        If (!$?) {
            Write-Warning "Failed to check for 'Owner' level permissions on the subscription. Deployment will be attempted but may fail due to insufficient permissions"
        }

        If (!$sufficientPermissions) {
            throw "Owner-level permissions not found on subscription '$($azContext.Subscription.Name)' for the current user. Please assign the 'Owner' role to the user before running this script"
        }
        Else {
            Write-Verbose "Owner-level permissions confirmed on subscription '$($azContext.Subscription.Name)'"
        }
    }
    Else {
        # check for specified role assignments on subscription by name
        $currentUser = Get-AzADUser -SignedIn
        $existingRoleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($azContext.Subscription.Id)" -ObjectId $currentUser.Id
        ForEach ($requiredRole in $labMetadata.deploymentPermissions ) {
            If ($existingRoleAssignments.RoleDefinitionName -notcontains $requiredRole.builtInRoleName) {
                Write-Verbose "Existing role assignments: '$($existingRoleAssignments.RoleDefinitionName -join ', ')' on subscription '$($azContext.Subscription.Name)'"
                throw "Required role '$($requiredRole.builtInRoleName)' not assigned to user '$($currentUser.Id)' in subscription '$($azContext.Subscription.Name)'. Please assign the required role to the user before running this script"
            }
            Else {
                Write-Verbose "Required role '$($requiredRole.builtInRoleName)' assigned to user '$($currentUser.Id)' in subscription '$($azContext.Subscription.Name)'"
            }
        }
    }

    Write-Host "All prerequisites met"
}

Function Start-LabDeployment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $labMetadataPath,

        [Parameter(Mandatory = $true)]
        [string]
        $labResourcesPath,

        [Parameter(Mandatory = $false)]
        [string]
        $deploymentLocation,

        [Parameter(Mandatory = $true)]
        [string]
        $labInstancePrefix,

        [Parameter(Mandatory = $true)]
        [string]
        $studentAlias,

        [Parameter(Mandatory = $true)]
        [datetime]
        $expirationDate
    )

    New-AzSubscriptionDeploymentStack -Name $labInstancePrefix -Location $deploymentLocation -TemplateFile $labResourcesPath -ActionOnUnmanage DeleteAll -DenySettingsMode None -TemplateParameterObject @{
        location          = $deploymentLocation
        labInstancePrefix = $labInstancePrefix
        studentAlias      = $studentAlias
        expirationDate    = $expirationDate
    } -Tag @{studentAlias = $studentAlias; labInstancePrefix = $labInstancePrefix; expirationDate = $expirationDate }
}

If (!$labContentPath) {

    If ((Get-Item $pwd).BaseName -eq 'scripts' -and (Get-ChildItem '../labs' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^_' }).count -gt 0) {
        Write-Verbose "Current directory is 'scripts'. Assuming lab content is in parent directory"

        $labDirList = Get-ChildItem -Path '../labs' -Directory | Where-Object { $_.Name -notmatch '^_' }

        If ($labDirList.Count -eq 0) {
            Write-Error "No labs found in the '../labs' directory. Please provide the path to the lab content directory" -ErrorAction Stop
        }

        Write-Host "Labs found in the '../labs' directory:"
        for ($i = 1; $i -eq ($labDirList.Count ); $i++) {
            Write-Host "`t$i. $($labDirList[$i -1].Name)"
        }

        do {
            $selection = Read-Host "Select the lab to deploy by number"
            if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $labDirList.Count) {
                $labContentPath = $labDirList[$selection - 1].FullName
            }
            else {
                Write-Host "Invalid selection. Please enter a valid lab number."
                $selection = $null
            }
        } while (-not $labContentPath)
    }
    Else {
        While (!$labContentPath) {
            $labContentPath = Read-Host "Lab content path"

            Write-Host "Checking for lab content at '$labContentPath'"
            If (-not (Test-Path $labContentPath -PathType Container)) {
                Write-Host "Directory '$labContentPath' was not found or the provided path is not a directory. Please enter a valid path"
                $labContentPath = $null
            }
            ElseIf (!(Test-Path -Path "$labContentPath/labMetadata.json")) {
                Write-Host "Directory '$labContentPath' was found, but it does not contain a 'labMetadata.json' file. Please enter a valid path to a lab's content directory"
                $labContentPath = $null
            }
            Else {
                Write-Host "Lab content found at '$labContentPath'"
            }
        }
    }
}

$labMetadataPath = Join-Path -Path $labContentPath -ChildPath 'labMetadata.json'
$labResourcesPath = Join-Path -Path $labContentPath -ChildPath 'labResources/main.bicep'

If (!$whatIf -and !$studentAlias) {
    Write-Host "Enter the student Microsoft alias for the lab deployment (used in tracking). For example: 'newsre123'"
    $studentAlias = Read-Host "Student alias"
} 

# todo: if cleanup automation is implemented, require expiration date
# If (!$whatIf -and !$expirationDate) {
#     Write-Host "Enter the expiration date for the lab deployment (used for cleanup in managed lab environments). For example: 'yyyy-MM-dd'"
#     $expirationDateString = Read-Host "Expiration date"

#     While (!($expirationDateString -as [datetime])) {
#         Write-Host "Invalid date format. Please enter a valid date in the format 'yyyy-MM-dd'"
#         $expirationDateString = Read-Host "Expiration date"
#     }

#     $expirationDate = $expirationDateString -as [datetime]    
# }
If (!$expirationDate) {
    $expirationDate = '01/01/2000'
}

# set initial lab parameters object for testing prerequisites
$labParameters = @{
    labMetadataPath    = $labMetadataPath
    labResourcesPath   = $labResourcesPath
    deploymentLocation = $deploymentLocation
}

Test-LabPrerequisites @labParameters

# update lab parameters object for deployment
$labParameters.Add('labInstancePrefix', $labInstancePrefix)
$labParameters.Add('studentAlias', $studentAlias)
$labParameters.Add('expirationDate', $expirationDate)
$labParameters.deploymentLocation = $script:deploymentLocation

If (!$whatIf) {
    Start-LabDeployment @labParameters
}
Else {
    Write-Host "Skipping deployment due to -whatIf flag"
}
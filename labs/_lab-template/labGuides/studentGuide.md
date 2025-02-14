# Student Lab Guide

<lab description>

Learning objectives:

* <objective>
* <objective>
* <objective>

## Lab Deployment or Configuration Requirements

1. Open the [Azure Cloud Shell](https://shell.azure.com) and select Powershell if prompted (or ensure that you are using PowerShell by checking that the toolbar has the button 'Switch to Bash'). By using Cloud Shell, we ensure that you do not have to set up any tooling locally.
1. In Cloud Shell, download a copy of this Git repo using `git clone https://github.com/mbrat2005/sreLabsStructure.git`. 
1. Navigate to the downloaded repo `scripts` directory using the `cd` command.
1. From the `scripts` directory, call the `deployLab.ps1` script.
1. Follow the prompts to ensure you are logged in to Azure and have met the prerequisites, then proceed with the deployment. _Note: the deployment runs using a subscription-level Deployment Stack for easy clean up.`

### Alternative ZIP Download Steps

1. Open the [Azure Cloud Shell](https://shell.azure.com) and select Powershell if prompted (or ensure that you are using PowerShell by checking that the toolbar has the button 'Switch to Bash'). By using Cloud Shell, we ensure that you do not have to set up any tooling locally.
1. In your browser, navigate to the Git repo [https://github.com/mbrat2005/sreLabsStructure](https://github.com/mbrat2005/sreLabsStructure)
1. Click the green Code button, then choose _Download ZIP_
1. Back in the Cloud Shell, click the _Manage Files_ button at the top, then _Upload_
1. Browse to the downloaded ZIP file and upload it
1. In the Cloud Shell, type `Expand-Archive sreLabsStructure-main.zip`
1. Change directories to the scripts folder with `cd ./sreLabsStructure-main/sreLabsStructure-main/scripts/`
1. Run `./deployLab.ps1`. Follow the prompts to ensure you are logged in to Azure and have met the prerequisites, then proceed with the deployment. _Note: the deployment runs using a subscription-level Deployment Stack for easy clean up.`

## Lab Steps

### Verify Lab Deployment and Test Resources

1. <verify step>
1. <verify step>
1. <test step>

### Lab Step 1

1.
1.

### Lab Step 2

## Lab Cleanup

1. In Cloud Shell, navigate to the directory `scripts` at the root of the lab folder
1. Run `cleanUpLab.ps1`

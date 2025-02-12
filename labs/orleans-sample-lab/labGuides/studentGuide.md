# Student Lab Guide

In this lab, you will deploy an Azure Container App to run a simple URL shortener application based on the Orleans framework. 

Learning objectives:

* Familiarize yourself with Container Apps and related resources
* Learn how to update the image on a Container App
* View logs in Log Analytics

## Lab Deployment or Configuration Requirements

This lab can be deployed in any Azure subscription--it has no dependencies on Microsoft identities or specific subscription offers. To deploy the lab, follow these steps:

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

1. Verify the lab has successfully deployed by checking the output of the deployLab.ps1 script from above for errors or looking at Subscriptions > Deployment Stacks in the Azure Portal.
1. Navigate to the Container App resource and click the URL in the `Application URL` property found in the Portal. This will connect to your Container App and verify that it is accessible and functioning. In the initial deployment, the Container App is running a .NET sample application which will display a 'Welcome to .NET' message and output some version information.
1. Now that you have called your application, navigate to Log Analytics resource in the Portal and look for your successful call in the logs and metrics.

### Build Custom Container Image

1. Next, we will build our custom container image using the Azure Container Registry, then switch our Container App to use our new image:
1. Copy the PowerShell script below to a text editor and update the values in <> to match your deployment (Resource Group name and Container Registry name):

    ```azurepowershell
    $RegistryName = "<your Azure Container Registry Name ex: 'containerregbbvqrfwqlrtv6'>"
    $ImageName = "$RegistryName/mycustomimage:v1"
    $Platform = "linux"
    $FilePath = "./web/Dockerfile"
    $ResourceGroup = "<your resource group name>"
    
    az acr build --image $imageName --registry $registryName --platform $platform --file $filePath --resource-group $resourceGroup .
    ```
1. In Cloud Shell, change directories to `labs/orleans-sample-lab/labResources/data/src`
1. Run the updated script contents in your Cloud Shell console. This will instruct Azure Container Registry to build a new container image with our custom application.

### Update Container App Image

1. After confirming that your build is complete by checking your ACR > Services > Runs list, navigate to your Container App
1. Click Application > Containers > Edit and Deploy.
1. Select the existing container and delete it.
1. Click Add > App Container
1. Name the container 'myapp', then select your image from your ACR.
1. In the Container Resource Allocation, choose .25 cores and .5 Gi, then click Add > Create.
1. Once the create action completes, navigate back to your Container App's URL. (If you still see the .NET Welcome page, try a hard refresh)
1. You should see instructions on using the URL shortener app.

## Lab Cleanup

1. In Cloud Shell, navigate to the directory `scripts` at the root of the lab folder
1. Run cleanUpLab.ps1
# Azure Functions OAuth 1.0 Authorization Header Generator
A semi-elegant way of navigating a rather clunky scenario, allowing you to create an OAuth 1.0 authorization header.

## Info
Microsoft Custom Connectors are great, however they lack the ability to integrate custom APIs that use OAuth 1.0. As a work around I've *hodgepodged* this PowerShell script together based on elements from [Miguel Gutierrez Rodriguez](https://mgr.medium.com/how-to-connect-to-netsuite-from-microsoft-power-automate-using-oauth-1-0-1d7670972406) and [That API Guy](https://thatapiguy.tech/2020/02/16/oauth-1-0-connection-in-power-automate-post-tweets-with-user-mentions-and-send-dms-using-twitter-api/). 

The intended use case is to have Azure deal with creating the authorization header, then pass it's output into a Power Automate [HTTP Action](https://docs.microsoft.com/en-us/power-automate/desktop-flows/actions-reference/web) "Authorization" header parameter.

The downside of this is that you need to pass the query parameters into both this function and the HTTP request you want to make.

I've chosen, for security (and simplicity), to store the API credentials within the function environment variables. This means you'll need to create a new function for each API you're using.

## Contents
- [Azure Setup](#azure-setup)
- [Power Automate Usage](#power-automate-usage)
- [Known Issues](#known-issues)

## Azure Setup
1. 	Go to [Azure](https://portal.azure.com/) > All services > **Functions App** (you'll find it under the *Compute* heading)
2. 	Click on **Create**:
	- Select the *Subscription*
	- Select the *Resource Group* (or create a new one)
	- Enter a *Function App name* (e.g. TwitterApiAuthorization)
	- Leave *Publish* set to **Code**
	- Set *Runtime stack* to **PowerShell Core**
	- Set *Version* to 7.0
	- Choose the *Region* closest to your local
	- Click **Review + create**
	- Confirm your configuration, then click **Create** and wait for your function to be deployed
3.	Once deployed, open the function app you just created
4.	Navigate to **Functions** (conveniently under the *Functions* heading)
5.	Click **Create**:
	- Set the *Development environment* to **Develop in portal**
	- Set the *Template* to **HTTP trigger**
6.	You'll be redirected to the newly created function, click on **Code + Test**
7.	Copy raw contents from [OAuth.ps1](OAuth.ps1) and paste it into your functions **run.ps1** file, then click **Save**
8.	Navigate to **Integration** in the function:
	- Click **HTTP (Request)** and set the *Selected HTTP methods* that you require (it's best to include ***only*** the ones that you're going to use to avoid accidents)
	- Click **Save**
10.	Navigate back to the functions app (easiest way I've found is to go to *Overview*, and then clicking on the **Functions app** link)
11.	Navigate to **Configuration** (under the *Settings* heading)
12.	Here we're going to be creating the API credentials environment variables using the names as follows; 'apiConsumerKey', 'apiConsumerSecret', 'apiAccessToken', 'apiAccessTokenSecret'). For each:
	- Click **New application setting**
	- Set the *Name* accordingly
	- Set the *Value* to your corresponding API credential
	- Click **OK** to confirm each entry
13.	Navigate back to **Functions**, open the function you created earlier
14.	Click **Get Function Url** and save it for later

## Power Automate Usage
1.	Go to [Power Automate](https://flow.microsoft.com/)
2.	Click **Create** > **Instant cloud flow**
3.	Name the Flow
4.	Select the **Manually trigger a flow** trigger, then click **Create**
5.	Add a **New step** > **Initialize variable** action
	- Rename the action to **URL**
	- Set *Name* to **URL**
	- Set *Type* to **String**
	- Set *Value* to the API URL you want to make the request (***don't*** include the query parameters in the URL)
6.	Add a **New step** > **HTTP** action
	- Rename the action to **Authorization Header**
	- Set *Method* to the same method that you're requesting the API with
	- Set *URI* to the function URL that we saved earlier
	- Add a *Header* parameter called **BaseUrl** and set the value to the **URL** variable (**@{variables('URL')}**)
	- Add any additional headers, or queries as required
7.	Add another **New step** > **HTTP** action (this will be for the actual API request)
	- Set *Method* to the required method (it should be identical the previous step)
	- Set *URI* to the **URL** variable (**@{variables('URL')}**)
	- Add a *Header* parameter called **Authorization** and set the value to the **Body** of the *Authorization Header* action (**@body('Authorization_Header')**)
	- Add any additional headers, or queries as required (they should be identical the previous step)
	- Add **Body** content if making a PUT, or POST request (if required)
8.	Click **Save**
9.	Click **Test**
	- Select **Manually**, and then click **Test**
	- Click **Run flow**, then click **Done**
	- Sit tight while it runs
10.	Success (hopefully; see [Known Issues](#known-issues))!

## Known Issues
- Power Automate may return the **Authorization Header** step as **Unauthenticated**. To fix this go to the functions app > open the function > **Integration** > click **HTTP (Request)** > set *Authorization level* to **Anonymous**. Be aware, this is unsecure and will leave your function (and it's abilities) exposed to anyone with the URL

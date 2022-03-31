using namespace System.Net;

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata);

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request.";

# Interact with environment variables.
$OAuth = @{
	'ApiKey'            = [Uri]::EscapeDataString($env:apiConsumerKey);
	'ApiSecret'         = [Uri]::EscapeDataString($env:apiConsumerSecret);
	'AccessToken'       = [Uri]::EscapeDataString($env:apiAccessToken);
	'AccessTokenSecret' = [Uri]::EscapeDataString($env:apiAccessTokenSecret);
}

# Interact with request header parameters.
$BaseUrl = $Request.Headers.BaseUrl;
$RequestHeader = @{
	'Operation'   = $Request.Method.toUpper();
	'ResourceUrl' = $BaseUrl.ToLower();
};

# Interact with request query or body parameters.
$RequestQuery = $Request.Query;
$RequestQueryParams = @{};

ForEach ($key in $RequestQuery.Keys) {
	$keyIndex = $($RequestQuery.Keys).indexOf($key);
	if ($RequestQuery.Keys.Count -gt 1) {
		$keyValue = $($RequestQuery.Values)[$keyIndex]
	}
	else {
		$keyValue = $RequestQuery.Values
	}
	$RequestQueryParams[$key] = $( $keyValue -replace 'http.*://', "" -replace ':', "" );
	$RequestQueryParams.Remove('code');
}

## Generate a random 11 character alphanumeric string.
$OauthNonce = -join(((48..57)+(65..90)+(97..122)) * 80 | Get-Random -Count 11 | % {[char]$_});

## Find the total seconds since 1/1/1970 (epoch time).
$EpochTimeNow = [DateTime]::UtcNow - [DateTime]::ParseExact("01/01/1970", "dd'/'MM'/'yyyy", $null);
$OauthTimestamp = [Convert]::ToInt64($EpochTimeNow.TotalSeconds).ToString();

## Build the signature.
$SignatureParams = @{
	'oauth_consumer_key'     = $OAuth.ApiKey;
	'oauth_token'            = $OAuth.AccessToken;
	'oauth_signature_method' = 'HMAC-SHA1';
	'oauth_nonce'            = $OauthNonce;
	'oauth_timestamp'        = $OauthTimestamp;
	'oauth_version'          = '1.0';
}
$SignatureQueryParams = @{};
$SignatureParams.Keys | % { $SignatureQueryParams.Add($_, $SignatureParams.Item($_)) };
$RequestQueryParams.Keys | % { $SignatureQueryParams.Add($_, [Uri]::EscapeDataString($RequestQueryParams.Item($_))) };
$SignatureQueryParams = $SignatureQueryParams.GetEnumerator() | Sort-Object -Property Name;

## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &.
$SignatureBase = [Uri]::EscapeDataString($RequestHeader.ResourceUrl);
$SignatureQueryParams.GetEnumerator() | ForEach-Object { $SignatureParamsString += ("$($_.Key)=$($_.Value)&") };
$SignatureParamsString = $SignatureParamsString.TrimEnd('&');
$SignatureParamsString = [Uri]::EscapeDataString($SignatureParamsString);
$SignatureBase = $RequestHeader.Operation + '&' + $SignatureBase + '&' + $SignatureParamsString;

### Create the hashed string from the base signature.
$SignatureKey = $OAuth.ApiSecret + "&" + $OAuth.AccessTokenSecret;
$hmacsha = New-Object System.Security.Cryptography.HMACSHA1;
$hmacsha.Key = [Text.Encoding]::ASCII.GetBytes($SignatureKey);
$OauthSignature = [Uri]::EscapeDataString([Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($SignatureBase))));

## Build the authorization headers using most of the signature headers elements.
$AuthorizationParams = $SignatureParams;
$AuthorizationParams.Add('oauth_signature', $OauthSignature);
$AuthorizationString = 'OAuth ';
$AuthorizationParams.GetEnumerator() | ForEach-Object { $AuthorizationString += $_.Name + '="' + $_.Value + '", ' };
$AuthorizationString = $AuthorizationString.TrimEnd(', ');
$AuthorizationString;

# Return the Signature created
$Body = $AuthorizationString;

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
		StatusCode = [HttpStatusCode]::OK;
		Body       = $Body;
	})

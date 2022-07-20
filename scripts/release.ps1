#Requires -Version 5.0

param (
    [parameter(Mandatory = $true)] [string]$Version,
    [parameter(Mandatory = $true)] [securestring]$GitHubApiKey,
    [parameter(Mandatory = $false)] [string]$GitHubUsername = "rancher",
    [parameter(Mandatory = $false)] [string]$GitHubRepository = "wins",
    [parameter(Mandatory = $false)] [string]$Artifact = "wins.exe",
    [parameter(Mandatory = $false)] [string]$ArtifactOutputDirectory = "C:\package"
)

$ProgressPreference = 'SilentlyContinue' ; $ErrorActionPreference = 'Stop'

function Test-Release {
    $result = Invoke-WebRequest -Uri "https://github.com/$GitHubUsername/$GitHubRepository/releases/$Version" -Method 'GET'

    if ($result.StatusCode -ne 200) {
        Write-Error -ForegroundColor Red "Unexpected StatusCode when checking if $Artifact is published for ($Version)"
        exit 1
    }
    if (-Not $result.Content.Contains($Artifact)) {
        Write-Host -ForegroundColor Blue "$Artifact has not been published for ($Version), preparing to publish"
    }
}

# written to be exportable
function Publish-Binary($Version, $ArtifactOutputDirectory, $Artifact, $GitHubUsername, $GitHubRepository, $GitHubApiKey) {
    $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Encrypted + ":x-oauth-basic"));

    $releaseParams = @{
        Uri = "https://api.github.com/repos/$GitHubUsername/$GitHubRepository/releases";
        Method = 'POST';
        Headers = @{
          Authorization = $auth;
        }
        ContentType = 'application/json';
        Body = (ConvertTo-Json $releaseData -Compress)
     }
    $result = Invoke-RestMethod @releaseParams 

    $uploadUri = $result | Select-Object -ExpandProperty upload_url
    Write-Host $uploadUri
    $uploadUri = $uploadUri -creplace '\{\?name,label\}'  #, "?name=$artifact"
    $uploadUri = $uploadUri + "?name=$Artifact"
    $uploadFile = Join-Path -path $ArtifactOutputDirectory -childpath $Artifact

    $uploadParams = @{
      Uri = $uploadUri;
      Method = 'POST';
      Headers = @{
        Authorization = $auth;
      }
      ContentType = 'application/octet-stream';
      InFile = $uploadFile
    }
    $result = Invoke-RestMethod @uploadParams
    Write-Debug -ForegroundColor Yellow "Published $Artifact to $uploadUri"
    Write-Host -ForegroundColor Green "Successfully Published $Artifact for $Version to $GitHubUsername/$GitHubRepository"
}

if (-Not $Version) {
    Write-Error -ForegroundColor Red "Unexpected StatusCode when checking if wins.exe is published for ($Version)"
}
Test-Release
$Encrypted = ConvertFrom-SecureString -SecureString $GitHubApiKey
Publish-Binary -Version $Version -ArtifactOutputDirectory $ArtifactOutputDirectory \
  -Artifact $Artifact -GitHubUsername $GitHubUsername -GitHubRepository $GitHubRepository -GitHubApiKey $Encrypted
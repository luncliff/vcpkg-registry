<#
.SYNOPSIS
    PowerShell script to remove Workflow run in the GitHub Actions

.PARAMETER Repository
    The name of the repository.
.PARAMETER Workflow
    The name of the workflow in the repository.
.PARAMETER Branch
    Branch of the workflow runs. Used to select the matching runs.
.PARAMETER Conclusion
    Final status of the workflow run. ex) cancelled
.PARAMETER GitHubHost
    Hostname for GitHub CLI, API request. github.com, git.company.com

.LINK
    https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/using-workflow-run-logs

#>
param
(
    [String]$Repository = "",
    [Parameter(Mandatory = $true)][String]$Workflow,
    [String]$Branch = "main",
    [String]$Conclusion = "cancelled",
    [String]$GitHubHost = "github.com" 
)

# If the Repository is empty, we will parse it from the origin URL
if ($Repository -eq "") {
    [String]$OriginURL = $(git remote get-url origin)
    # Parse the organization and repository name from OriginURL
    # For example, if the URL is https://github.com/luncliff/vcpkg-registry, the value will be "luncliff/vcpkg-registry"
    $Repository = $OriginURL -replace "https://$GitHubHost/", "" -replace ".git", ""
    Write-Output "Repository: $Repository"
}

# ex) '.workflow_runs[] | select(.conclusion != "") | .id'
[String]$Query = ".workflow_runs[] | select(.head_branch == ""$Branch"") | select(.conclusion == ""$Conclusion"") | .id"
Write-Output "Query: $Query"

gh api `
    -H "Accept: application/vnd.github+json" `
    -H "X-GitHub-Api-Version: 2022-11-28" `
    "/repos/$Repository/actions/workflows/$Workflow/runs" `
    --paginate `
    --jq $Query > "runs.txt"

foreach ($RunID in Get-Content "runs.txt") {
    gh api `
        --method DELETE `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        "/repos/$Repository/actions/runs/$RunID"
    Write-Output "Deleted: $RunID"
    Start-Sleep -Milliseconds 100
}

Remove-Item -Force "runs.txt"

param
(
    [String]$Repository = "luncliff/vcpkg-registry",
    [String]$Branch = "main",
    [UInt16]$Count = 100,
    [string]$CacheFile = "caches.txt"
)
# gh auth login
# gh extension install actions/gh-actions-cache
gh actions-cache list -R $Repository -B $Branch --limit $Count > $CacheFile

Get-Content $CacheFile | ForEach-Object {
    $Fields = $_ -split ',|\t'
    $Key = $Fields[0]
    gh actions-cache delete $Key -R $Repository --confirm
}

Remove-Item $CacheFile

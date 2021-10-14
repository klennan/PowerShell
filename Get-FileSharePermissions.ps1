function Get-FileSharePermissions {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [alias("Dir","FullName","FullPath")]
        [string]$Path,
        [switch]$NoRecurse
    )
    Write-Verbose "Getting recursive directory list"
    if (Test-Path $Path) {
        if ($NoRecurse) {
            $Path | Get-AclRule
        }
        else {
            try {
                Get-ChildItem -Path $Path -Recurse -Directory | Get-AclRule
            }
            catch {
                Write-Error "Could not access $Path"
                $Path | Get-AclRule
            }
        }
    }
    else {
        Write-Error "Invalid path: $Path"
    }
}

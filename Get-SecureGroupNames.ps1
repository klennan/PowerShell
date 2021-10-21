function Get-SecureGroupNames {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [alias("Path")]
        [string]$FullPath,

        [switch]$Parent
    )
    Write-Verbose "Trying $Fullpath"
    $FullPath = $FullPath.TrimEnd('\')

    if ($FullPath.StartsWith("\\")) # UNC
    {
        $ShareHost = $FullPath.Split("\")[2] # \\ServerName
        $ShareRoot = $FullPath.Split("\")[3] # ..\RootShare
        if (($env:USERDOMAIN -eq "KUHA") -and (
            ($FullPath.toLower().StartsWith("\\kuha.kumed.com\shares\departments")) -or
            ($FullPath.toLower().StartsWith("\\kuha\shares\departments"))
            )) {
            $ShareRoot = "Shares\Departments"
        }
        $ParentPath = Split-Path $FullPath -Parent
        $ShareGroupName = $FullPath -iReplace [regex]::Escape("\\$ShareHost\$ShareRoot\"),"" -Replace "_","" -Replace [regex]::Escape("\"),"_" -Replace " ","" -Replace ",","-" -Replace "'",""

        # Get the length of the whole string, the length of the last split on _ add 1 for the underscore, and remove the last split-word
        if (!($Parent)) {
            try {
                # $ShareGroupParentName = $ShareGroupname.Remove($ShareGroupName.Length - ($ShareGroupName.Split("_")[-1].length + 1)).TrimEnd("_")
                $ShareGroupParentName = (Get-SecureGroupNames -Fullpath $ParentPath -Parent).Base
                if ($ParentPath.toLower().EndsWith($ShareRoot.toLower())) {
                    $isRootFolder = $true
                    $ShareGroupParentName = ""
                }
                else {  $isRootFolder = $false }
            }
            catch {
                Write-Verbose "Failed to get ShareGroupParentName. Root folder?"
                $isRootFolder = $true
                $ShareGroupParentName = ""
            }
        }
        $GroupDescription = $FullPath
    }
    elseif ($FullPath.Substring(1,1) -eq ":") # Drive letter
    {
        $ShareRoot = $FullPath.Split("\")[0] # Drive letter:
        $ShareGroupName = $env:COMPUTERNAME + "_" + ($FullPath -Replace ":","$" -Replace "_","" -Replace [regex]::Escape("\"),"_" -Replace " ","" -Replace ",","-" -Replace "'","")

        if (!($Parent)) {
            try {
                $ParentPath = Split-Path $FullPath -Parent
                # $ShareGroupParentName = $ShareGroupname.Remove($ShareGroupName.Length - ($ShareGroupName.Split("_")[-1].length + 1)).TrimEnd("_")

                if ($ParentPath.EndsWith(":\")) {
                    $isRootFolder = $true
                    $ShareGroupParentName = ""
                }
                else {
                    $ShareGroupParentName = (Get-SecureGroupNames -Fullpath $ParentPath -Parent).Base
                    $isRootFolder = $false
                }
            }
            catch {
                Write-Verbose "Failed to get ShareGroupParentName. Root folder?"
                $ParentPath = ""
                $ShareGroupParentName = ""
                $isRootFolder = $true
            }
        }
        $GroupDescription = "\\$($env:COMPUTERNAME)\" + $FullPath.Replace(':','$')
    }
    else
    {
        Write-Error "Invalid/Unhandled path provided."
        return;
    }

    $GroupNames = [Ordered]@{
        Description  = $GroupDescription
        Manager   = "SHARE_" + $ShareGroupName + "__MGR"
        ReadWrite = "SHARE_" + $ShareGroupName + "_RW"
        ReadOnly  = "SHARE_" + $ShareGroupName + "_RO"
        Traversal = "SHARE_" + $ShareGroupParentName + "__T"
        isRootFolder = $isRootFolder
        ParentPath   = $ParentPath
        Base         = $ShareGroupName
        _ShareRoot   = $ShareRoot
    }

    $GroupNames
}

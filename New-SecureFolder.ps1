function New-SecureFolder {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [alias("FullName")]
        [String[]]$Path,

        [Parameter(ValueFromPipelineByPropertyName)]
        [alias("BaseOU","OrganizationalUnit")]
        [String]$OU = "OU=Shares,OU=Groups,DC=COMPANY,DC=com", # Modify this to the OU where you keep security groups

        [Parameter(ValueFromPipelineByPropertyName)]
        [alias("Manager")]
        [String]$ManagedBy,

        [Parameter(ValueFromPipelineByPropertyName)]
        [alias("Domain")]
        [String]$DomainName = $env:USERDOMAIN,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$DescriptionPrefix = "\\server\Shares", # Modify this to your share base path

        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$Notes,

        [Parameter(HelpMessage="Do not apply ACL")]
        [Switch]$NoAclAction,

        [Parameter(HelpMessage="Do not try to create traversal ACL")]
        [Switch]$NoTraversalACL,

        [Parameter(HelpMessage="Verify and report, does not make any changes")]
        [Switch]$VerifyOnly
    )
    BEGIN {
        while (!($OUExists))
        {
            Write-Verbose "Testing OU $OU"
            try {
                Get-ADObject $OU -ErrorAction "SilentlyContinue" | Out-Null;
                Write-Verbose "OU Exists. Continuing..."
                $OUExists = $true
            }
            catch {
                Write-Verbose "OU value is not an Active Directory object: $OU"
                $OU = Read-Host "Please enter a valid OU DistinguishedName"
            }
        }
    }

    PROCESS {
        foreach ($FullPath in $Path)
        {
            if ($FullPath.GetType().Name -eq "DirectoryInfo") { $FullPath = $FullPath.FullName }
            $FullPath = $FullPath.TrimEnd("\")

            if (!(Test-Path -Path $FullPath))
            {
                if ($VerifyOnly) { Write-Host "[-] The path does not exist: $FullPath" -ForegroundColor Red }
                else {
                    try {
                        Write-Verbose "Path does not exist. Creating $FullPath"
                        New-Item -Path $FullPath -ItemType Directory
                    }
                    catch {
                        Write-Warning "Unable to create new folder."
                        break;
                    }
                }
            }
            
            if ((Test-Path -Path $FullPath))
            {
                Write-Verbose "Path Exists ($FullPath). Continuing..."

                $GroupNames = Get-SecureGroupNames -FullPath $FullPath

                if ($ManagedBy)
                {
                    while (!(Get-ADObject -filter {SamAccountName -eq $ManagedBy}))
                    {
                        Write-Verbose "ManagedBy value is not an Active Directory object: $ManagedBy"
                        $ManagedBy = Read-Host "Please enter a valid user or group name as the folder manager"
                    }
                }
                else { $ManagedBy = $GroupNames.Manager }

                # Manager group
                $GrpMgr = $null
                try {
                    # Manager group
                    try {
                        $GrpMgr = Get-Adgroup $GroupNames.Manager -Properties Description,ManagedBy
                        Write-Verbose "AD Group exists ($($GroupNames.Manager)). Continuing..."

                        if ($VerifyOnly) { Write-Host "[+] Manager AD Group Exists: $($GroupNames.Manager)" -ForegroundColor Green }
                        else {
                            if ($null -eq $GrpMgr.Description) {
                                Write-Verbose "AD Group ($($GroupNames.Manager)) Description is empty. Applying..."
                                Set-ADGroup -Identity $GroupNames.Manager -Description "Manager of $($GroupNames.Manager))"
                            }

                            if ($null -eq $Grp.ManagedBy) {
                                Write-Verbose "AD Group ($($GroupNames.Manager)) manager is empty. Applying..."
                                Set-ADGroup -Identity $GroupNames.Manager -ManagedBy $ManagedBy
                            }
                        }

                    }
                    catch {
                        Write-Verbose "Creating group: $($GroupNames.Manager) managed by $ManagedBy"
                        if ($VerifyOnly) { Write-Host "[-] Manager AD Group does NOT exist: $($GroupNames.Manager)" -ForegroundColor Red }
                        else {
                            New-ADGroup -Path $OU -Name $GroupNames.Manager -Description "Manager of $($GroupNames.ReadWrite)" -GroupScope DomainLocal -GroupCategory Security
                            Set-ADGroup -Identity $GroupNames.Manager -ManagedBy $ManagedBy
                            if ($Notes) { Set-ADGroup -Identity $GroupNames.Manager -Replace @{info="$Notes"} }
                        }
                    } # End GrpMGR block

                    # Read/Write group
                    $GrpRW = $null
                    try {
                        $GrpRW = Get-ADGroup $GroupNames.ReadWrite -Properties Description,ManagedBy,Members
                        Write-Verbose "AD Group exists ($($GrpRW.SamAccountName)). Continuing..."

                        if ($VerifyOnly) { Write-Host "[+] Read/Write AD Group exists: $($GrpRW.SamAccountName)"  -ForegroundColor Green }
                        else {
                            if ($null -eq $GrpRW.Description) {
                                Write-Verbose "AD Group ($($GrpRW.SamAccountName)) Description is empty. Applying..."
                                Set-ADGroup -Identity $GroupNames.ReadWrite -Description $GroupNames.Description
                            }

                            if ($null -eq $GrpRW.ManagedBy) {
                                Write-Verbose "AD Group ($($GrpRW.SamAccountName)) manager is empty. Applying..."
                                Set-ADGroup -Identity $GroupNames.ReadWrite -ManagedBy $ManagedBy
                            }
                        }
                    }
                    catch
                    {
                        Write-Verbose "Read/Write AD Group does NOT exist ($($GroupNames.ReadWrite)). Creating..."
                        if ($VerifyOnly) { Write-Host "[-] Read/Write AD Group does NOT exist: $($GroupNames.ReadWrite)" -ForegroundColor Red }
                        else {
                            Write-Verbose "Creating group: $($GroupNames.ReadWrite) managed by $ManagedBy"
                            try {
                                New-ADGroup -Path $OU -Name $GroupNames.ReadWrite -Description $GroupNames.Description -ManagedBy $ManagedBy -GroupScope DomainLocal -GroupCategory Security
                                if ($Notes) { Set-ADGroup -Identity $$GroupNames.ReadWrite -Replace @{info="$Notes"} }
                                $GrpRW = Get-ADGroup $GroupNames.ReadWrite -Properties Description,ManagedBy,Members
                            }
                            catch {
                                Write-Error "Failed to create AD Group: $($GroupNames.ReadWrite) $($Error[0])"
                            }
                        }
                    } # End GrpRW block

                    # Read Only group
                    $GrpRO = $null
                    try {
                        $GrpRO = Get-Adgroup $GroupNames.ReadOnly -Properties Description,ManagedBy,Members
                        Write-Verbose "AD Group exists ($($GrpRO.SamAccountName)). Continuing..."

                        if ($VerifyOnly) { Write-Host "[+] Read-Only AD Group exists: $($GroupNames.ReadOnly)" -ForegroundColor Green}
                        else {
                            if ($null -eq $GrpRO.Description) {
                                Write-Verbose "AD Group ($($GroupNames.ReadOnly)) Description is empty. Applying..."
                                Set-ADGroup -Identity $GroupNames.ReadOnly -Description $GroupNames.Description
                            }

                            if ($null -eq $GrpRO.ManagedBy) {
                                Write-Verbose "AD Group ($($GroupNames.ReadOnly)) manager is empty. Applying..."
                                Set-ADGroup -Identity $GroupNames.ReadOnly -ManagedBy $ManagedBy
                            }
                        }
                    }
                    catch
                    {
                        Write-Verbose "Read-Only AD Group does NOT exist ($($GroupNames.ReadOnly)). Creating..."

                        if ($VerifyOnly) { Write-Host "[-] Read-Only AD Group does NOT exist: $($GroupNames.ReadOnly)" -ForegroundColor Red }
                        else {
                            Write-Verbose "Creating group: $($GroupNames.ReadOnly) managed by $ManagedBy"
                            try {
                                New-ADGroup -Path $OU -Name $GroupNames.ReadOnly -Description $GroupNames.Description -ManagedBy $ManagedBy -GroupScope DomainLocal -GroupCategory Security
                                if ($Notes) { Set-ADGroup -Identity $GroupNames.ReadOnly -Replace @{info="$Notes"} }
                                $GrpRO = Get-Adgroup $GroupNames.ReadOnly -Properties Description,ManagedBy,Members
                            }
                            catch {
                                Write-Error "Failed to create AD Group: $($GroupNames.ReadOnly) $($Error[0])"
                            }
                        }
                    } # End GrpRO block

                    # Traversal Group
                    if (!($GroupNames.isRootFolder))
                    {
                        try {
                            $GrpTrv = Get-ADGroup $GroupNames.Traversal -Properties Description,ManagedBy,Members
                            Write-Verbose "Traversal AD Group exists ($($GrpTrv.SamAccountName)). Continuing..."

                            if ($VerifyOnly) { Write-Host "[+] Traversal AD Group exists: $($GrpTrv.SamAccountName)" -ForegroundColor Green }
                            else {
                                if (($null -eq $GrpTrv.Description) -or ($GrpTrv.Description -notcontains $GroupNames.ParentPath)) {
                                    Write-Verbose "AD Group ($($GroupNames.Traversal)) Description is empty or inaccurate. Applying..."
                                    Set-ADGroup -Identity $GroupNames.Traversal -Description "Traversal of $($GroupNames.ParentPath)"
                                }
                            }
                        }
                        catch
                        {
                            if ($VerifyOnly) { Write-Host "[-] Traversal AD Group does NOT exist: $($GroupNames.Traversal)" -ForegroundColor Red }
                            else {
                                Write-Verbose "Traversal group does not exist. Creating $($GroupNames.Traversal)"
                                try {
                                    New-ADGroup -Path $OU -name $GroupNames.Traversal -Description "Traversal of $($GroupNames.ParentPath)" -GroupScope DomainLocal -GroupCategory Security
                                    if ($Notes) { Set-ADGroup -Identity $GroupNames.Traversal -Replace @{info="$Notes"} }
                                    $GrpTrv = Get-ADGroup $GroupNames.Traversal -Properties Description,ManagedBy,Members
                                }
                                catch {
                                    Write-Error "Failed to create Traversal group: $($GroupNames.Traversal) $($Error[0])"
                                }
                            }
                        }

                        # Nest traversal group
                        try {
                            $GroupTRVMembers = $GrpTrv.Members

                            if (!($GroupTRVMembers.contains($GrpRW.DistinguishedName)))
                            {
                                Write-Verbose "$($GroupNames.Traversal) does not contain $($GrpRW.DistinguishedName)"
                                if ($VerifyOnly) { Write-Host "[-] Read/Write AD Group is NOT a member of the Traversal group: $($GroupNames.ReadWrite) -> $($GroupNames.Traversal)" -ForegroundColor Red }
                                else {
                                    Write-Verbose "Adding group membership: $($GroupNames.ReadWrite) to $($GroupNames.Traversal)"
                                    Add-ADGroupMember -identity $GroupNames.Traversal -members $GroupNames.ReadWrite
                                }
                            }
                            else {
                                if ($VerifyOnly) { Write-Host "[+] Read/Write AD Group is a member of the Traversal group: $($GroupNames.ReadWrite) -> $($GroupNames.Traversal)" -ForegroundColor Green }
                            }

                            if (!($GroupTRVMembers.contains($GrpRO.DistinguishedName)))
                            {
                                if ($VerifyOnly) { Write-Host "[-] Read-Only AD Group is NOT a member of the Traversal group: $($GroupNames.ReadOnly) -> $($GroupNames.Traversal)" -ForegroundColor Red }
                                else {
                                    Write-Verbose "Adding group membership: $($GroupNames.ReadOnly) to $($GroupNames.Traversal)"
                                    Add-ADGroupMember -identity $GroupNames.Traversal -members $GroupNames.ReadOnly
                                }
                            }
                            else {
                                if ($VerifyOnly) { Write-Host "[+] Read-Only AD Group is a member of the Traversal group: $($GroupNames.ReadOnly) -> $($GroupNames.Traversal)" -ForegroundColor Green }
                            }
                        }

                        catch {
                            if ($VerifyOnly) { Write-Host "[-] Could not retrive members of Traversal group." -ForegroundColor Red }
                            else {
                                Write-Error "Failed to retrieve members of Traversal group: $Error[0]"
                            }
                        }
                    } # End GrpTRV block

                    # Nest manager group
                    try { $GroupRWMembers = $GrpRW.Members }
                    catch { Write-Error "Could not collect $($GroupNames.ReadWrite) members."}

                    if (!($GroupRWMembers.contains($GrpMgr.DistinguishedName)))
                    {
                        if ($VerifyOnly) { Write-Host "[-] Manager AD Group is NOT a member of the Read/Write group: $($GroupNames.Manager) -> $($GroupNames.ReadWrite)" -ForegroundColor Red }
                        else {
                            Write-Verbose "Adding manager group membership: $($GroupNames.Manager) to $($GroupNames.ReadWrite)"
                            Add-ADGroupMember -identity $GroupNames.ReadWrite -members $GroupNames.Manager
                        }
                    }
                    else {
                        if ($VerifyOnly) { Write-Host "[+] Manager AD Group is a member of the Read/Write group: $($GroupNames.Manager) -> $($GroupNames.ReadWrite)" -ForegroundColor Green }
                    }
                }
                catch {
                    if ($VerifyOnly) { $false }
                    else {
                        Write-Error "Failed to create required AD Group(s). $($Error[0])"
                        break;
                    }
                } # End AD Groups block

                if (!($NoACLAction)) {
                    Write-Verbose "Gathering existing directory ACLs..."
                    $ParentPathACL = Get-ACL -Path $GroupNames.ParentPath
                    $FullPathACL   = Get-ACL -Path $FullPath
                    if (!($GroupNames.isRootFolder)) {
                        $AccessRuleTrv = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainName\$($GroupNames.Traversal)","ReadAndExecute","None","None","Allow") # This folder only
                    }
                    $AccessRuleRW  = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainName\$($GroupNames.ReadWrite)","Modify","ContainerInherit, ObjectInherit","None","Allow") # Subfolders and files
                    $AccessRuleRO  = New-Object System.Security.AccessControl.FileSystemAccessRule("$DomainName\$($GroupNames.ReadOnly)","ReadAndExecute","ContainerInherit, ObjectInherit","None","Allow") # Subfolders and files

                    $IDReferences = @()
                    foreach ($Rule in $ParentPathACL.Access) { $IDReferences += $Rule.IdentityReference.value }

                    if (!($GroupNames.isRootFolder)) {
                        if (!($IDReferences.contains("$DomainName\$($GrpTrv.SamAccountName)")))
                        {
                            if ($VerifyOnly) { Write-Host "[-] Traversal AD Group is NOT applied to the parent path: $($GrpTrv.SamAccountName) -> $($GroupNames.ParentPath)" -ForegroundColor Red }

                            $attempts = 1; $ACLSuccess = $false
                            while (!($ACLSuccess) -and ($attempts -le 20)) {
                                try {
                                    $ParentPathACL.AddAccessRule($AccessRuleTrv)
                                    $ACLSuccess = $true
                                }
                                catch {
                                    Write-Verbose "Failed to build traversal ACL ($attempts). Retrying..."
                                    $attempts++
                                    $ACLSuccess = $false
                                    Start-Sleep -Seconds 2
                                }
                            }

                            Write-Verbose "Build ACL Success: $ACLSuccess - Attempts: $attempts"

                            if ($ACLSuccess) {
                                if ($VerifyOnly) { Write-Host "[+] The Traversal ACL was successfully built for $FullPath" -ForegroundColor Green }
                                else {
                                    try {
                                        Write-Verbose "Applying Traversal ACL to $($GroupNames.ParentPath)"
                                        (Get-Item $GroupNames.ParentPath).SetAccessControl($ParentPathACL)
                                    }
                                    catch { Write-Error "Something went wrong while applying the Traversal ACL to $($GroupNames.ParentPath)" }
                                }
                            }
                            else {
                                if ($VerifyOnly) { Write-Host "[-] The Traversal ACL was NOT successfully built for $($GroupNames.ParentPath)" -ForegroundColor Red }
                            }
                        }
                        else {
                            if ($VerifyOnly) { Write-Host "[+] Traversal AD Group is applied to the parent path: $($GroupNames.Traversal) -> $($GroupNames.ParentPath)" -ForegroundColor Green }
                            Write-Verbose "Parent Path already contains traversal ACL. Continuing..."
                        }
                    }

                    Write-Verbose "Building ACL for $FullPath"

                    $attempts = 1; $ACLSuccess = $false
                    if ($VerifyOnly) { $attempts = 20 <# try once #> }

                    while (!($ACLSuccess) -and ($attempts -le 20)) {
                        try {
                            $FullPathACL.AddAccessRule($AccessRuleRW)
                            $FullPathACL.AddAccessRule($AccessRuleRO)
                            $ACLSuccess = $true
                        }
                        catch {
                            Write-Verbose "Failed to build ACL ($attempts). Retrying..."
                            $attempts++
                            $ACLSuccess = $false
                            Start-Sleep -Seconds 2
                        }
                    }

                    Write-Verbose "Build ACL Success: $($ACLSuccess) - Attempts: $attempts"

                    if ($ACLSuccess) {
                        if ($VerifyOnly) { Write-Host "[+] The ACL was successfully built for $FullPath" -ForegroundColor Green }
                        else {
                            Write-Verbose "Applying RW/RO ACL to $FullPath"
                            try { (Get-Item $FullPath).SetAccessControl($FullPathACL) }
                            catch { Write-Error "Something went wrong while applying the ACL to $FullPath" }
                        }
                    }
                    else {
                        if ($VerifyOnly) { Write-Host "[-] The ACL was NOT successfully built for $FullPath" -ForegroundColor Red }
                    }
                } # End ACL Actions
            }
        } # END Foreach Path
    } # END PROCESS
}

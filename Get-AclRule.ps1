# Handle getting each ACL for each Dir
function Get-AclRule {
<#
.SYNOPSIS
    Uses Get-Acl and adds additional properties to the returned object to make it SQL Report friendly.
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> $F
    Explanation of what the example does
.NOTES
    General notes
#>
    Param(
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [String[]]$Fullname     # PSObject attribute name of a directory
    )
    BEGIN {
        ## This is the name of the SQL table to store data in
        $Table = "FileshareACL"
        $ScanDate = Get-Date
    }
    PROCESS {
        foreach ($Dir in $Fullname) {
            try {
                $ACL = Get-ACL -Path $Dir

                foreach ($Rule in $ACL.Access) {
                    # Make object with Path,Group,Allow/Deny,Rights,Owner
                    Add-Member -InputObject $Rule -MemberType NoteProperty -Name Path -Value $Dir
                    Add-Member -InputObject $Rule -MemberType NoteProperty -Name Owner -Value $ACL.Owner
                    Add-Member -InputObject $Rule -MemberType NoteProperty -Name ScanDate -Value $ScanDate
                    # Add SQL report tag
                    $Rule.psobject.TypeNames.Insert(0,"Report.$Table")
                    # You should pipe this to Save-ReportData
                    $Rule
                }
            }
            catch {
                Write-Host "Could not access $Dir"
                $RuleProp = @{
                    Path              = "$Dir";
                    FileSystemRights  = "Access Denied";
                    AccessControlType = "Access Denied";
                    IdentityReference = "Access Denied";
                    IsInherited       = $false;
                    InheritanceFlags  = "Access Denied";
                    PropagationFlags  = "Access Denied";
                    ScanDate          = $ScanDate;
                }
                $Rule = New-Object -TypeName psobject -Property $RuleProp
                $Rule.psobject.TypeNames.Insert(0,"Report.$Table")
                $Rule
            }
        } # end Foreach dir
    } # end Process
    END {}
}

# Handle removing & inserting records by path
function Update-AclRule
{
    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [String[]]$FullName,
        [String]$SqlServer = "", # "<Your SQL Server Instance>",
        [String]$SqlDb = "" # "<Your SQL Database>"
    )
    BEGIN { }

    PROCESS {
        foreach ($Dir in $FullName)
        {

            # Double up single quote for SQL
            $SqlDir = $Dir.replace("'","''")
            # SQL to remove records matching path
            # delete where path like '$FullName%'
            Write-Verbose "Removing existing records from SQL for $Dir"
            Invoke-SQLCmd -ServerInstance $SqlServer -Query "DELETE FROM $SqlDb WHERE [Path] LIKE '$SqlDir%'" -QueryTimeout 30

            # use Get-ACLRule to insert the path again

            Write-Verbose "Gathering ACLs for $Dir and sending to SQL"

            # We get the ACL on the exact path sent, because Get-Childitem -Recurse doesn't include it.
            Write-Debug "Current Path: $Dir"
            Get-AclRule -FullName $Dir | Add-FileSharePermissiontoSQL

            # We recursively scan the directory provided, send each oen to Get-ACLRule for the object, and pass to Insert-ACLRule
            # to make the SQL Insertions
            Write-Debug "Getting directory list in $Dir"
            Get-ChildItem -Recurse -Path $Dir -Directory | Get-AclRule | Add-FileSharePermissiontoSQL

        }
    }
}

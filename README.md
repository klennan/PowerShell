# PowerShell
My public PowerShell code

## File Share Proceedure

### Investigation & Recording

**Using the function _Get-FileSharePermissions_**

This function requires a path to explore, and supports an optional -NoRecurse switch.
It will check that the path exists, and use Get-ChildItem to recursively retrieve directories.
The directories are then passed to Get-MAAclRule, which does the work or retrieving the ACLs for each directory (Get-ACL) and then adds additional properties to the object (The full path, ACL owner, scan date and the attribute to support the SQLReporting module).

An object per ACL rule will be returned. To save these to SQL, simply pipe them to _Add-FileShareRuleToSQL_
The additional ScanDate attribute enables tracking of changes over time.

```ps
Get-FileSharePermissions -Path "\\Server\Sharename" | Add-FileShareRuleToSQL`
```

**Using the function _Add-FileSharePermissionToSQL_**

This function requires a SQL database to store the ACLs found on the file structure.
Using simple queries on this table can surface undesired ACLs which need repaired or removed.

Look for user accounts with permission applied directly on the directories:

```sql
SELECT * from <database>.dbo.FileShareACL WHERE [IsInherited] = 0 AND [IdentityReference] not like '<Domain>\SHARE_%'
```

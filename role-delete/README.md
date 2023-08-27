# role-delete
Roles cannot be deleted in SEP if there are any assignments and/or grants currently attached to the role.
This script automatically removes those dependencies from the role prior to deleting the role. Essentially
this is a 'force' delete of a role.

**Requirements:**
- This script assumes that the user performing the operations is a member of the sysadmin role

**Usage:** 

The script requires four parameters.

`role-delete.sh -s [sep url] -r [role name] -u [sysadmin user] -p [sysadmin password]`

*sep url* is the base URL for accessing SEP. Example: https://localhost:8443

*role name* is the name of the role to delete. Example: public (try this one if you want to see an error)

*sysadmin user* and *sysadmin password* are the credentials used to log into SEP.


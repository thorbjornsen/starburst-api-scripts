#!/usr/bin/env bash

if [ $# -ne 8 ]; then
  echo "Usage: $0 -s [sep url] -r [role name] -u [sysadmin user] -p [sysadmin password]" && exit 1
fi

while getopts 's:r:u:p:' opt; do
  case "$opt" in
    s)
      sep="$OPTARG"
      ;;
    r)
      role_name="$OPTARG"
      ;;
    u)
      user="$OPTARG"
      ;;
    p)
      pass="$OPTARG"
      ;;
    *)
      echo "Usage: $0 -s [sep url] -r [role name] -u [sysadmin user] -p [sysadmin password]" && exit 1
  esac
done

# Need to get the role id from the role name - role names are guaranteed to be unique
result=`curl -s -k -u $user:$pass -H 'X-Trino-Role: system=ROLE{sysadmin}' -H 'Accept:application/json' ${sep}/api/v1/biac/roles`

# First chance to check the credentials
if [[ $result == *"Access Denied: Invalid credentials"* ]]; then
  echo "Error: Invalid credentials for user $user" && exit 1
fi

# First chance to check if the user is granted sysadmin
if [[ $result == *"Access Denied: Cannot set role sysadmin"* ]]; then
  echo "Error: User $user is not a member of sysadmin" && exit 1
fi

# Sometimes SEP doesn't throw an exception, so check for an error code
if [ "$(echo $result | jq '.errorCode')" != null ]; then
  echo "Error: User $user is not a member of sysadmin" && exit 1
fi

role_id=$(echo $result | jq ".result | .[] | select(.name==\"$role_name\")" | jq '.id')

if [ -z "$role_id" ]; then
  echo "Error: Role $role_name does not exist" && exit 1
fi

# Get the users assigned to the role
result=`curl -s -k -u $user:$pass -H 'X-Trino-Role: system=ROLE{sysadmin}' -H 'Accept:application/json' ${sep}/api/v1/biac/roles/${role_id}/assignments`

# Loop over all of the assignments and delete them one at a time
echo $result | jq -c '.result | .[]' | while read i; do
  id=$(echo $i | jq '.id')
  type="$(echo $i | jq -r '.subject.type')"

  case "$type" in
    USER)
      type="users"
      value="$(echo $i | jq -r '.subject.username')"
      ;;
    GROUP)
      type="groups"
      value="$(echo $i | jq -r '.subject.groupName')"
      ;;
    ROLE)
      type="roles"
      value="$(echo $i | jq '.subject.roleId')"
      ;;
    *)
      echo "Error: Invalid subject type $type found" && exit 1
  esac

  # URLs for deleting assignments
  #${sep}/api/v1/biac/subjects/users/{username}/assignments/{assignmentId}
  #${sep}/api/v1/biac/subjects/groups/{groupName}/assignments/{assignmentId}
  #${sep}/api/v1/biac/subjects/roles/{roleId}/assignments/{assignmentId}

  # Doesn't return any JSON data, so force it to return the status code
  result=`curl -s -k -u $user:$pass -X 'DELETE' -H 'X-Trino-Role: system=ROLE{sysadmin}' -H 'Accept:application/json' --write-out '%{http_code}' ${sep}/api/v1/biac/subjects/${type}/${value}/assignments/${id}`

  if [ $result != 204 ]; then
    echo "Error: Status $result returned for ${sep}/api/v1/biac/subjects/${type}/${value}/assignments/${id}" && exit 1
  fi
done

# Get all grants assigned to the role
result=`curl -s -k -u $user:$pass -H 'X-Trino-Role: system=ROLE{sysadmin}' -H "Accept:application/json" ${sep}/api/v1/biac/roles/${role_id}/grants`

# Loop over all of the grants and delete them one at a time
echo $result | jq -c '.result | .[]' | while read i; do
  id=$(echo $i | jq '.id')

  # Doesn't return any JSON data, so force it to return the status code
  result=`curl -s -k -u $user:$pass -X 'DELETE' -H 'X-Trino-Role: system=ROLE{sysadmin}' -H 'Accept:application/json' --write-out '%{http_code}' ${sep}/api/v1/biac/roles/${role_id}/grants/${id}`

  if [ $result != 204 ]; then
    echo "Error: Status $result returned for ${sep}/api/v1/biac/roles/${role_id}/grants/${id}" && exit 1
  fi
done

# Finally, the role can be deleted
result=`curl -s -k -u $user:$pass -X 'DELETE' -H 'X-Trino-Role: system=ROLE{sysadmin}' -H 'Accept:application/json' --write-out '%{http_code}' ${sep}/api/v1/biac/roles/${role_id}`

if [ $result != 204 ]; then
  echo "Error: Status $result returned for ${sep}/api/v1/biac/roles/${role_id}" && exit 1
fi

echo "$role_name has been deleted"
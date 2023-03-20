#!/usr/bin/env bash
source common/functions.sh

#check_project_ids
#
#to_id=$(get_to_project_id)

#TAB=$'\t'


# structure is
#name,#email,#productionRole,#stagingRole,#developmentRole
userArray=(
'test1,florent.huck+7@platform.sh,admin,admin,admin'
'test2,florent.huck+8@platform.sh,production:v,staging:c,dev%:a'
)

for user in "${userArray[@]}"
do
   userInfo=(${user//,/ })
   name=${userInfo[0]}
   email=${userInfo[1]}
   roleProd=${userInfo[2]}
   roleStaging=${userInfo[3]}
   roleDev=${userInfo[4]}

   platform user:add --project fi6p3ap6k4n44 --role $roleProd --role $roleStaging --role $roleDev $email --yes

   printf "return = $return\n"
done
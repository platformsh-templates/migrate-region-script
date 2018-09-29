#!/usr/bin/env bash
source common/functions.sh

check_project_ids

from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

TAB=$'\t'
users=$(platform user:list --project $from_id --format tsv | tail -n +2 | grep ${TAB}admin${TAB} | awk '{print $1}')
for user in $users;
do
    platform user:add --project $to_id --role admin $user --yes
done
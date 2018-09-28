#!/usr/bin/env bash
source common/functions.sh

check_project_ids

from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

domains=$(platform domain:list --project=$from_id --format tsv 2>/dev/null | tail -n +2 | awk '{print $1}')
to_edge_host=$(platform environment:info --project=$to_id --environment=master -- edge_hostname)
if [ -z "$domains" ] ; then
    echo "[ERROR] No domains are assigned to \"$to_id\" platform.sh project"
    exit 1
fi

list=""
for domain in $domains;
do
    list=$(printf "$list\n- $domain")
done
message=$(printf "Please point following domain(s):$list\nto\n$to_edge_host\nConfirm")
confirm_message "$message" false


lastDomain=${domains##*$'\n'}
# Remove domains from old projects
for domain in $domains;
do
    wait="--no-wait"
    if [ "$domain" = "$lastDomain" ] ; then
        wait="--wait"
    fi
    platform domain:delete --project=$from_id $domain --yes $wait
done
# Add domains to new project
for domain in $domains;
do
    wait="--no-wait"
    if [ "$domain" = "$lastDomain" ] ; then
        wait="--wait"
    fi
    platform domain:add --project=$to_id $domain --yes $wait
done


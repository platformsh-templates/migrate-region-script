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

from_region=$(platform project:info --project=$from_id git | sed "s/$from_id\@git.//" | sed "s/\:${from_id}.git//")
to_region=$(platform project:info --project=$to_id git | sed "s/$to_id\@git.//" | sed "s/\:${to_id}.git//")

lastDomain=${domains##*$'\n'}
# If regions are the same, we need to detach domains from old project first
# Otherwise we will be unable to attach them to a new project
if [ "$from_region" = "$to_region" ] ; then
    for domain in $domains;
    do
        wait="--no-wait"
        if [ "$domain" = "$lastDomain" ] ; then
            wait="--wait"
        fi
        platform domain:delete --project=$from_id $domain --yes $wait
    done
fi

# Attach domains to new project
# At this point DNS is still pointed to old project. It means LE challenge will fail,
# and no valid SSL certs will be generated. So build/deploy hook will be no triggered on each domain
for domain in $domains;
do
    wait="--no-wait"
    if [ "$domain" = "$lastDomain" ] ; then
        wait="--wait"
    fi
    platform domain:add --project=$to_id $domain --yes $wait
done

message=$(printf "Please point following domain(s):$list\nto\n$to_edge_host\n\nAlternatively, you can change DNS later.\n\nConfirm DNS change (y/n)?")
read -p "$message" choice
case "$choice" in
  y|Y ) redeploy $to_id master;;
esac
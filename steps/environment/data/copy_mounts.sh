#!/usr/bin/env bash
source common/functions.sh

check_project_ids

env=$1
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

mounts=$(platform mount:list --project=$from_id --environment=$env --format tsv 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '^source_path:' | grep -v '^.shared$')
for mount in $mounts;
do
    traget="./.local/tmp/mounts/$mount"
    echo $traget
    mkdir -p $traget
    printf "\Downloading mounts from project $from_id"
    platform mount:download --project=$from_id --environment=$env --mount=$mount --target=$traget --yes
    printf "\nUploading mounts to project $to_id"
    platform mount:upload --project=$to_id --environment=$env --mount=$mount --source=$traget --yes
    rm -Rf $traget
done

redeploy $to_id $env
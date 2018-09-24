#!/usr/bin/env bash
source common/functions.sh

check_project_ids

env=${1:-master}
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

mounts=$(platform mount:list --project=$from_id --environment=$env --format tsv 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '^source_path:' | grep -v '^.shared$')
for mount in $mounts;
do
    traget="./.local/tmp/mounts/$mount"
    echo $traget
    mkdir -p $traget
    platform mount:download --project=$from_id --environment=$env --mount=$mount --target=$traget --yes
    platform mount:upload --project=$to_id --environment=$env --mount=$mount --source=$traget --yes
    rm -Rf $traget
done

platform project:variable:set --project=$to_id env:BUSINESS_HOURS_IGNORE 1
platform redeploy --project=$to_id --environment=$env --yes
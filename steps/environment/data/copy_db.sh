#!/usr/bin/env bash
source common/functions.sh

check_project_ids
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

DEFAULT_BRANCH=$(platform project:info --project=$from_id -- default_branch)
env=${1:-$DEFAULT_BRANCH}
app=$2

# Database
mkdir -p .local/tmp
printf "\nDump data from $from_id\n"
platform db:dump --project=$from_id --environment=$env --file=.local/tmp/dump.sql --yes --app=$app
printf "\nImport data into $to_id\n"
printf "\nplatform db:sql --project=$to_id --environment=$env --app=$app < .local/tmp/dump.sql\n"
platform db:sql --project=$to_id --environment=$env --app=$app -vvv < .local/tmp/dump.sql
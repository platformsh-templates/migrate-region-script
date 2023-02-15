#!/usr/bin/env bash
source common/functions.sh

check_project_ids

env=$1
app=$2
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

# Database
mkdir -p .local/tmp
platform db:dump --project=$from_id --environment=$env --file=.local/tmp/dump.sql --yes --app=$app
platform db:sql --project=$to_id --environment=$env --app=$app < .local/tmp/dump.sql
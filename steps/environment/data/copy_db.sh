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
printf "\nbefore dump\n"
printf "platform db:dump --project=$from_id --environment=$env --file=.local/tmp/dump.sql --yes --app=$app\n"
platform db:dump --project=$from_id --environment=$env --file=.local/tmp/dump.sql --yes --app=$app

printf "\nbefore import\n"

now=$(date)
printf "%s\n" "$now --> refresh env:info"
platform env:info -p $to_id --refresh
#
#printf "platform env:list -p $to_id"
#platform env:list -p $to_id
#
#printf "\nplatform project:curl -p $to_id /environments/$env | jq -r '.status'\n"
#ENV_CHECK=$(platform project:curl -p $to_id /environments/$env | jq -r '.status')
#printf "\nEnv $env from project $to_id is $ENV_CHECK\n"
#
#printf "\nPlatform ssh list platform ssh -p $to_id --all\n"
#platform ssh -p $to_id --all
#
#printf "\n$(platform ssh -p cmu7r7fhyuplg --all)\n"
#until [ $(platform ssh -p cmu7r7fhyuplg --all | wc -l) > 0 ]
#do
#     printf "wait 5"
#     sleep 5s
#done
#printf "\nUrl founded\n"
#platform ssh -p $to_id --all
#
#printf "\nPlatform activities platform act -p $to_id \n"
#platform act -p $to_id
#
#printf "\nEnvironment $env info\n"
#platform env:info -p $to_id -e $env

printf "\nTest ssh connection with ls -l\n"
platform ssh -p $to_id -e $env -- ls -l

printf "\nplatform db:sql --project=$to_id --environment=$env < .local/tmp/dump.sql\n"
platform db:sql --project=$to_id --environment=$env --app=$app < .local/tmp/dump.sql
printf "\nEnd copy DB\n"

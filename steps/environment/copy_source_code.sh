#!/usr/bin/env bash
source common/functions.sh

check_project_ids
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

DEFAULT_BRANCH=$(platform project:info --project=$from_id -- default_branch)
env=${1:-$DEFAULT_BRANCH}

#from_git_url=$(platform project:info --project=$from_id repository.url)
#working_dir=$(pwd)
#rm -Rf .local/source_code
#mkdir -p .local/source_code
#git clone --branch $env $from_git_url .local/source_code
#
#to_git_url=$(platform project:info --project=$to_id repository.url)
#cd .local/source_code
#git remote add to-project $to_git_url
#
## https://www.contextualcode.com/Blog/Managing-global-client-timezones-in-the-deployment-workflow
#platform project:variable:set --project=$to_id env:BUSINESS_HOURS_IGNORE 1 > /dev/null 2>&1
#git push to-project ${env}:${env} --force
#platform project:variable:delete --project=$to_id env:BUSINESS_HOURS_IGNORE --yes > /dev/null 2>&1
#
#cd $pwd
#rm -Rf .local/source_code

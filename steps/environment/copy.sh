#!/usr/bin/env bash
source common/functions.sh

check_project_ids
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

DEFAULT_BRANCH=$(platform project:info --project=$from_id -- default_branch)
env=${1:-$DEFAULT_BRANCH}

tmp=$(platform environment:list --project=$from_id --format tsv 2>/dev/null | grep Active | grep $env | wc -l)
if [ "$tmp" -eq 0 ] ; then
    echo "[ERROR] \"$env\" environment is not active in \"from\" project"
    exit 1
fi

tmp=$(platform environment:list --project=$to_id --format tsv 2>/dev/null | grep Active | grep $env | wc -l)
if [ "$tmp" -gt 0 ] ; then
    echo "[ERROR] \"$env\" active environment already exists in \"to\" project"
    exit 1
fi

#ENV_TYPE=$(platform project:curl -p $from_id /environments/$env | jq -r '.type')
#if [ "$ENV_TYPE" != production  ] ; then
#    parent=$(platform environment:info --project=$from_id --environment=$env -- parent)
#    platform environment:branch --project=$to_id --force --no-clone-parent -- $env $parent
#fi

TAB=$'\t'
tmp=$(platform environment:list --project=$to_id --format tsv 2>/dev/null | grep "^$env$TAB" | wc -l)
if [ "$tmp" -eq 0 ] ; then
    echo "[ERROR] Unable to create \"$env\" environment in \"to\" project"
    exit 1
fi

# Outgoing emails
value=$(platform environment:info --project=$from_id --environment=$env enable_smtp)
platform environment:info --project=$to_id --environment=$env -- enable_smtp $value
# Indexing by Search Engines
value=$(platform environment:info --project=$from_id --environment=$env restrict_robots)
platform environment:info --project=$to_id --environment=$env -- restrict_robots $value
# HTTP Access Control
basic_auth=$(platform environment:info --project=$from_id --environment=$env --format tsv http_access.basic_auth | grep -v '{  }' | wc -l)
addresses=$(platform environment:info --project=$from_id --environment=$env --format tsv http_access.addresses | grep -v '{  }' | wc -l)
tmp=$((basic_auth + addresses))
if [ "$tmp" -gt 0 ] ; then
    echo "[NOTICE] Please update HTTP Access Control configs manually"
fi

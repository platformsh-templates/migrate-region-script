#!/usr/bin/env bash
source common/functions.sh

check_project_ids

env=${1:-master}
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

tmp=$(platform environment:list --project=$from_id --format tsv 2>/dev/null | grep Active | grep $env | wc -l)
if [ "$tmp" -eq 0 ] ; then
    echo "[ERROR] \"$env\" environment does not exist in \"from\" project"
    exit 1
fi

tmp=$(platform environment:list --project=$to_id --format tsv 2>/dev/null | grep Active | grep $env | wc -l)
if [ "$tmp" -gt 0 ] ; then
    echo "[ERROR] \"$env\" active environment already exists in \"to\" project"
    exit 1
fi

if [ "$env" != "master" ] ; then
    parent=$(platform environment:info --project=$from_id --environment=$env -- parent)
    platform environment:branch --project=$to_id --force -- $env $parent
fi

tmp=$(platform environment:list --project=$to_id --format tsv 2>/dev/null | grep "^$env\t" | wc -l)
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
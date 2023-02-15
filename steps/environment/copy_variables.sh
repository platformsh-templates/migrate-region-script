#!/usr/bin/env bash
source common/functions.sh

check_project_ids

env=$1
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

TAB=$'\t'
vars=$(platform variable:list --project $from_id --level environment --environment $env --format tsv | tail -n +2 | awk '{print $1}')
for variable in $vars;
do
    value=$(platform variable:get --project $from_id --level environment --environment $env --property value "$variable" 2>/dev/null)
    is_sensitive=$(platform variable:get --project $from_id --level environment --environment $env --property is_sensitive "$variable" 2>/dev/null)
    is_json=$(platform variable:get --project $from_id --level environment --environment $env --property is_json "$variable" 2>/dev/null)
    if [ "$is_sensitive" = true ] ; then
        if [ "$is_json" = true ] ; then
            value="{\"value\": \"secret\"}"
        else
            value="<secret>"
        fi
    fi

    [ -z "$value" ] && continue

    is_enabled=$(platform variable:get --project $from_id --level environment --environment $env --property is_enabled "$variable" 2>/dev/null)
    is_inheritable=$(platform variable:get --project $from_id --level environment --environment $env --property is_inheritable "$variable" 2>/dev/null)

    echo "[$variable] ..."
    create_or_update_variable $to_id $variable "${value}" environment /dev/tty false false $is_json $is_sensitive $is_enabled $is_inheritable $env
done

sensetive_vars=$(platform variable:list --project=$to_id --level=environment --environment=$env --format=tsv 2>/dev/null | tail -n +2 | grep 'Hidden: sensitive value' | awk '{print $1}')
if [ ! -z "$sensetive_vars" ] ; then
    list=""
    for var in $sensetive_vars;
    do
        list=$(printf "$list\n- $var")
    done
    message=$(printf "Please manually set following sensitive environment variable(s):$list\nConfirm")
    confirm_message "$message"
fi
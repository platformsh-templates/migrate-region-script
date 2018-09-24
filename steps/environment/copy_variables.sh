#!/usr/bin/env bash
source common/functions.sh

check_project_ids

env=${1:-master}
from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

TAB=$'\t'
vars=$(platform variable:list --project $from_id --level environment --environment $env --format tsv | tail -n +2 | awk '{print $1}')
for variable in $vars;
do
    value=$(platform variable:get --project $from_id --level environment --environment $env --format tsv -- "$variable" 2>/dev/null | grep value | sed -e "s/value${TAB}//g")
    is_sensitive=$(platform variable:get --project $from_id --level environment --environment $env --format tsv -- "$variable" 2>/dev/null | grep is_sensitive | sed -e "s/is_sensitive${TAB}//g")
    if [ "$is_sensitive" = true ] ; then
        value="<secret>"
    fi

    [ -z "$value" ] && continue

    is_json=$(platform variable:get --project $from_id --level environment --environment $env --format tsv -- "$variable" 2>/dev/null | grep is_json | sed -e "s/is_json${TAB}//g")
    is_enabled=$(platform variable:get --project $from_id --level environment --environment $env --format tsv -- "$variable" 2>/dev/null | grep is_enabled | sed -e "s/is_enabled${TAB}//g")
    is_inheritable=$(platform variable:get --project $from_id --level environment --environment $env --format tsv -- "$variable" 2>/dev/null | grep is_inheritable | sed -e "s/is_inheritable${TAB}//g")

    echo "[$variable] ..."
    crete_or_update_variable $to_id $variable "${value}" environment /dev/tty false false $is_json $is_sensitive $is_enabled $is_inheritable $env
done

sensetive_vars=$(platform variable:list --project=$to_id --level=environment --environment=$env --format=tsv 2>/dev/null | tail -n +2 | grep 'Hidden: sensitive value' | awk '{print $1}')
if [ ! -z "$sensetive_vars" ] ; then
    vars=$(printf ", %s" "${sensetive_vars[@]}")
    vars=${vars:2}
    confirm_message "Please manually set following sensetive environment variable(s): \"$vars\""
fi
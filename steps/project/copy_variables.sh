#!/usr/bin/env bash
source common/functions.sh

check_project_ids

from_id=$(get_from_project_id)
to_id=$(get_to_project_id)


TAB=$'\t'
vars=$(platform variable:list --project $from_id --level project --format tsv | tail -n +2 | awk '{print $1}')
for variable in $vars;
do
    [ "$variable" = "$MIGRATION_VAR_NAME" ] && continue;

    value=$(platform variable:get --project $from_id --level project --property value "$variable" 2>/dev/null)
    is_sensitive=$(platform variable:get --project $from_id --level project --property is_sensitive "$variable" 2>/dev/null)
    is_json=$(platform variable:get --project $from_id --level project --property is_json "$variable" 2>/dev/null)
    if [ "$is_sensitive" = true ] ; then
        if [ "$is_json" = true ] ; then
            value="{\"value\": \"secret\"}"
        else
            value="<secret>"
        fi
    fi

    [ -z "$value" ] && continue

    visible_build=$(platform variable:get --project $from_id --level project --property visible_build "$variable" 2>/dev/null)
    visible_runtime=$(platform variable:get --project $from_id --level project --property visible_runtime "$variable" 2>/dev/null)

    echo "[$variable] ..."
    create_or_update_variable $to_id $variable "${value}" project /dev/tty $visible_build $visible_runtime $is_json $is_sensitive
done

sensetive_vars=$(platform variable:list --project $to_id --level project --format tsv | tail -n +2 | grep 'Hidden: sensitive value' | awk '{print $1}')
if [ ! -z "$sensetive_vars" ] ; then
    list=""
    for var in $sensetive_vars;
    do
        list=$(printf "$list\n- $var")
    done
    message=$(printf "Please manually set following sensitive project variable(s):$list\nConfirm")
    confirm_message "$message"
fi
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
    value=$(platform variable:get --project $from_id --level project --format tsv -- "$variable" 2>/dev/null | grep value | sed -e "s/value${TAB}//g")
    [ -z "$value" ] && continue

    visible_build=$(platform variable:get --project $from_id --level project --format tsv -- "$variable" 2>/dev/null | grep visible_build | sed -e "s/visible_build${TAB}//g")
    visible_runtime=$(platform variable:get --project $from_id --level project --format tsv -- "$variable" 2>/dev/null | grep visible_runtime | sed -e "s/visible_runtime${TAB}//g")
    is_json=$(platform variable:get --project $from_id --level project --format tsv -- "$variable" 2>/dev/null | grep is_json | sed -e "s/is_json${TAB}//g")
    is_sensitive=$(platform variable:get --project $from_id --level project --format tsv -- "$variable" 2>/dev/null | grep is_sensitive | sed -e "s/is_sensitive${TAB}//g")

    echo "[$variable] ..."
    crete_or_update_variable $to_id "$variable" "$value" project /dev/tty $visible_build $visible_runtime $is_json $is_sensitive
done
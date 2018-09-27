#!/usr/bin/env bash

MIGRATION_VAR_NAME=REGION_MIGRATION
MIGRATION_VAL_FROM=from
MIGRATION_VAL_TO=to

get_project_id() {
    echo $(cat .local/$1_id)
}

get_from_project_id() {
    echo $(get_project_id from)
}

get_to_project_id() {
    echo $(get_project_id to)
}

check_project_ids() {
    from_id=$(get_from_project_id)
    to_id=$(get_to_project_id)

    tmp=$(platform variable:get --level project --project $from_id --format tsv $MIGRATION_VAR_NAME | grep value | awk '{print $2}')
    if [ "$tmp" != "$MIGRATION_VAL_FROM" ]; then
        echo "[ERROR] \"$from_id\" is invalid "from" project. Please run ./step/set_projects.sh <FROM_ID> <TO_ID>"
        exit 1
    fi
    tmp=$(platform variable:get --level project --project $to_id --format tsv $MIGRATION_VAR_NAME | grep value | awk '{print $2}')
    if [ "$tmp" != "$MIGRATION_VAL_TO" ]; then
        echo "[ERROR] \"$to_id\" is invalid "to" project. Please run ./step/set_projects.sh <FROM_PROJECT_ID> <TO_PROJECT_ID>"
        exit 1
    fi
}

create_or_update_variable() {
    PROJECT_ID=$1
    VAR_NAME=$2
    VAR_VALUE=$3
    LEVEL=$4
    REDIRECT=${5:-/dev/tty}
    REDIRECT=/dev/tty
    VISIBLE_BUILD=${6-false}
    VISIBLE_RUNTIME=${7-false}
    JSON=${8-false}
    SENSETIVE=${9-false}
    ENABLED=${10-true}
    INHERITABLE=${11-false}
    ENV=${12-master}

    # wash double quotes
    VAR_VALUE=$(echo $VAR_VALUE | sed 's/^"//g' | sed 's/"$//g')
    # double quotes are coded to two double quotes, because we are using `--format tsv` to get variable value
    # so we need to decode them back
    VAR_VALUE=$(echo $VAR_VALUE | sed 's/""/"/g')

    tmp=$(platform variable:list --project=$PROJECT_ID --level=$LEVEL --environment $ENV --format tsv 2>/dev/null | awk '{print $1}' | grep "^$VAR_NAME$" | wc -l)
    if [ "$tmp" -eq 0 ] ; then
        platform variable:create --project=$PROJECT_ID --level=$LEVEL --name=$VAR_NAME --value="$VAR_VALUE" --json=$JSON --sensitive=$SENSETIVE --prefix=none --visible-build=$VISIBLE_BUILD --visible-runtime=$VISIBLE_RUNTIME --enabled=$ENABLED --inheritable=$INHERITABLE --environment=$ENV &> $REDIRECT
    else
        platform variable:update --project=$PROJECT_ID --level=$LEVEL --value="$VAR_VALUE" --json=$JSON --sensitive=$SENSETIVE --visible-build=$VISIBLE_BUILD --visible-runtime=$VISIBLE_RUNTIME --enabled=$ENABLED --inheritable=$INHERITABLE --environment=$ENV $VAR_NAME &> $REDIRECT
    fi
}

confirm_message() {
    MESSAGE=$1
    EXIT=${2:-true}

    read -p "$MESSAGE (y/n)?: " choice
    case "$choice" in
      y|Y )
        if [ "$EXIT" = true ]; then
            exit 0
        fi;;
      n|N ) confirm_message "$MESSAGE" $EXIT;;
      * ) confirm_message "$MESSAGE" $EXIT;;
    esac
}
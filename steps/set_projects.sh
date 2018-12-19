#!/usr/bin/env bash
source common/functions.sh

has_error=false
if [ -z "$1" ] ; then
    echo "[ERROR] Please provide \"from\" project platform.sh id"
    has_error=true
fi
if [ -z "$2" ] ; then
    echo "[ERROR] Please provide \"to\" project platform.sh id"
    has_error=true
fi
if [ "$has_error" = true ] ; then
    exit 1
fi

if [ "$1" = "$2" ] ; then
    echo "[ERROR] \"form\" and \"to\" project ids can not be the same"
    exit 1
fi

status=$(platform project:info --project $1 status 2>/dev/null)
if [ "$status" != "active" ]; then
    echo "[ERROR] \"$1\" does not seems to be valid Platform.sh project id, or you do not have access to it"
    has_error=true
fi
status=$(platform project:info --project $2 status 2>/dev/null)
if [ "$status" != "active" ]; then
    echo "[ERROR] \"$2\" does not seems to be valid Platform.sh project id, or you do not have access to it"
    has_error=true
fi
if [ "$has_error" = true ] ; then
    exit 1
fi

mkdir -p .local
echo $1 > .local/from_id
echo $2 > .local/to_id

create_or_update_variable $1 "$MIGRATION_VAR_NAME" "$MIGRATION_VAL_FROM" project /dev/null
create_or_update_variable $2 "$MIGRATION_VAR_NAME" "$MIGRATION_VAL_TO" project /dev/null

echo "[OK] Platform.sh project ids were saved. Please ignore previous prompts to redeploy the project. No additional deploys are required."
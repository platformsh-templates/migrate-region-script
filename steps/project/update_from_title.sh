#!/usr/bin/env bash
source common/functions.sh

check_project_ids

from_id=$(get_from_project_id)

title=$(platform project:info --project $from_id title)
new_title="[MIGRATED] $title"
printf "Rename project $P1_PROJECT_ID from \"$title\" to \"$new_title\".\n"

platform project:info --project $from_id -- title "$new_title"
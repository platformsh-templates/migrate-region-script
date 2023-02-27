#!/usr/bin/env bash
source common/functions.sh

check_project_ids

from_id=$(get_from_project_id)
to_id=$(get_to_project_id)

title=$(platform project:info --project $from_id title)
platform project:info --project $to_id -- title "$title"
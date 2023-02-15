#!/usr/bin/env bash
source common/functions.sh

check_project_ids

to_id=$(get_to_project_id)
echo ""
platform project:info --project $to_id repository.client_ssh_key
echo ""

#FIXME FHK : i didn't get why you're displaying this as a confirmation message, do we need to do anything?
#confirm_message "Please set new deploy key in GitHub/GitLab/Bitbucket/etc (alternatively, you can ignore this step if no submodules are in use). Continue"
#!/usr/bin/env bash
source common/functions.sh

check_project_ids

to_id=$(get_to_project_id)
echo ""
platform project:info --project $to_id repository.client_ssh_key
echo ""

confirm_message "Have you set new deploy key in GitHub/GitLab/Bitbucket/etc"
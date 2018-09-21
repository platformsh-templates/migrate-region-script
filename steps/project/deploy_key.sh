#!/usr/bin/env bash
source common/functions.sh

check_project_ids

to_id=$(get_to_project_id)
echo ""
platform project:info --project $to_id repository.client_ssh_key
echo ""

confirm_new_deployment_key() {
    read -p "Have you set new deploy key in GitHub/GitLab/Bitbucket/etc (y/n)?: " choice
    case "$choice" in
      y|Y ) exit 0;;
      n|N ) confirm_new_deployment_key;;
      * ) confirm_new_deployment_key;;
    esac
}
confirm_new_deployment_key
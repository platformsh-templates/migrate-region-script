#!/usr/bin/env bash

FROM_PROJECT_ID=$1
TO_PROJECT_ID=$2
ENVS=$3

steps/set_projects.sh $FROM_PROJECT_ID $TO_PROJECT_ID

[[ $? -ne 0 ]] && exit
steps/copy_project.sh

IFS=',' read -ra ENVS_ARRAY <<< "$ENVS"
for ENV in "${ENVS_ARRAY[@]}"; do
    printf "\nCopy env $ENV"
    steps/copy_environment.sh $ENV
    # Wait 1 minute, just to be sure new env is up and running
    sleep 60s
    steps/copy_data.sh $ENV
done

read -p "Would you like to transfer domains now (y/n)?: " choice
case "$choice" in
  y|Y ) steps/project/transfer_domains.sh;
esac
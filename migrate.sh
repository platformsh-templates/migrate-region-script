#!/usr/bin/env bash

FROM_PROJECT_ID=$1
TO_PROJECT_ID=$2
ENV=${3:-master}

steps/set_projects.sh $1 $2
[[ $? -ne 0 ]] && exit
steps/copy_project.sh
steps/copy_environment.sh $3
steps/copy_data.sh $3
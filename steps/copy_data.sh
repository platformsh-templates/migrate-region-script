#!/usr/bin/env bash

env=${1:-master}

echo "---------------------------------------------------------------------------------------------------------"
echo "Copying Database ..."
echo "---------------------------------------------------------------------------------------------------------"
./steps/environment/data/copy_db.sh $env
echo ""
echo "---------------------------------------------------------------------------------------------------------"
echo "Copying Mounts ..."
echo "---------------------------------------------------------------------------------------------------------"
./steps/environment/data/copy_mounts.sh $env
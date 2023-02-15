#!/usr/bin/env bash

env=${1:-main}

echo "---------------------------------------------------------------------------------------------------------"
echo "Copying environment ..."
echo "---------------------------------------------------------------------------------------------------------"
./steps/environment/copy.sh $env
echo ""
echo "---------------------------------------------------------------------------------------------------------"
echo "Copying environment variables ..."
echo "---------------------------------------------------------------------------------------------------------"
./steps/environment/copy_variables.sh $env
echo ""
echo "---------------------------------------------------------------------------------------------------------"
echo "Copying cource code ..."
echo "---------------------------------------------------------------------------------------------------------"
./steps/environment/copy_source_code.sh $env
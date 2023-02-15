if [ -n "$ZSH_VERSION" ]; then emulate -L ksh; fi
######################################################
# fleet migration of a project to another region (and possibly organization), using the CLI.
#
# Usage
# 1. source this script: `. fleet_migrate_region.sh` or `source fleet_migrate_region.sh`
# 2. run `migrate_project_to_region`
# 2. answer questions to define:
#   PROJECT_ID=b7dfyoqjnumua
#   REGION=ca-1.platform.sh
#   ORGANIZATION=devrel-projects
#   GITHUB_API_TOKEN=xxx
#   DATABASE_APP=app
######################################################

migrate_project_to_region () {
  echo "> Enter project ID to migrate:"
  printf ": "
  read P1_PROJECT_ID

  echo "\n> The region where the new project will be hosted
  [au.platform.sh  ] Sydney, Australia (AWS) [867 gC02eq/kWh]
  [au-2.platform.sh] Sydney, Australia (AZURE) [867 gC02eq/kWh]
  [ca-1.platform.sh] Montreal, Canada (AWS) [27 gC02eq/kWh]
  [de-2.platform.sh] Frankfurt, Germany (GCP) [520 gC02eq/kWh]
  [eu-3.platform.sh] Dublin, Ireland (AWS) [482 gC02eq/kWh]
  [eu-5.platform.sh] Stockholm, Sweden (AWS) [62 gC02eq/kWh]
  [fr-1.platform.sh] France (ORANGE) [58 gC02eq/kWh]
  [fr-3.platform.sh] Gravelines, France (OVH) [58 gC02eq/kWh]
  [fr-4.platform.sh] Paris, France (AZURE) [58 gC02eq/kWh]
  [uk-1.platform.sh] London, United Kingdom (GCP) [350 gC02eq/kWh]
  [us-2.platform.sh] Washington, United States (AWS) [514 gC02eq/kWh]
  [us-3.platform.sh] Moses Lake, United States (AZURE) [24 gC02eq/kWh]
  [us-4.platform.sh] Charleston, United States (GCP) [480 gC02eq/kWh]"
  printf ": "
  read REGION

  echo "\n> On which organization do you want the new project to be?"
  platform organization:list --columns=name --no-header
  printf ": "
  read ORGANIZATION

  P1_DEFAULT_BRANCH=$(platform project:info -p $P1_PROJECT_ID default_branch)

  echo "\n> Please provide the app that contains the database to migrate (ex: app)"
  platform app:list -p $P1_PROJECT_ID -e $P1_DEFAULT_BRANCH --no-header --columns=name
  printf ": "
  read DATABASE_APP

  echo "\n> Please provide a valid Github API Token:"
  printf ": "
  read GITHUB_API_TOKEN

  echo "\nproject ID is $P1_PROJECT_ID"

  # get project P1 name
  P1_NAME=$(platform project:info -p $P1_PROJECT_ID title)
  printf "\nProject name is $P1_NAME"

  # get project P1 production env
  P1_DEFAULT_BRANCH=$(platform project:info -p $P1_PROJECT_ID default_branch)
  printf "\nProject default branch is $P1_DEFAULT_BRANCH \n"

  P1_PLAN=$(platform project:info -p $P1_PROJECT_ID subscription.plan)
  printf "\nProject plan is $P1_PLAN\n"

  # create new project P2 with
  #   - the same project P1 name on $REGION region
  #   - the same env name for production env (default env)
  #   - the same plan
  P2_PROJECT_ID=$(platform project:create --title="[NEW] $P1_NAME" --region=$REGION --default-branch="$P1_DEFAULT_BRANCH" --environments=21 --no-interaction --org=$ORGANIZATION --plan=$P1_PLAN)
  printf "\nNew project ID is $P2_PROJECT_ID"

  # get P1 integration repo
  P1_INTEGRATION_REPO=$(platform project:curl -p $P1_PROJECT_ID /integrations | jq -r '.[]|select(.type | contains("github"))' | jq '.repository'| tr -d '"')
  P1_INTEGRATION_ID=$(platform project:curl -p $P1_PROJECT_ID /integrations | jq -r '.[]|select(.type | contains("github"))' | jq '.id')
  printf "\nP1 Integration repo is $P1_INTEGRATION_REPO and ID is $P1_INTEGRATION_ID"
  printf $P1_INTEGRATION_REPO
  printf "\n"

  # remove P1 integration
  #TODO uncomment
  # REMOVE_INTEGRATION=$(platform integration:delete -p $P1_PROJECT_ID --yes $P1_INTEGRATION_ID)

  # create integration (github api token) on P2 project and catch errors
  (
    set -e
    INTEGRATION=$(platform integration:add --type=github --project=$P2_PROJECT_ID --repository=$P1_INTEGRATION_REPO --token=$GITHUB_API_TOKEN --no-interaction -vvv)
    printf "\nplatform integration:add --type=github --project=$P2_PROJECT_ID --repository=$P1_INTEGRATION_REPO --token=$GITHUB_API_TOKEN --no-interaction -vvv"
    printf "\nP2 Integration is $INTEGRATION"
  )
  errorCode=$?
  if [ $errorCode -ne 0 ]; then
    echo "We have an error"
    printf "\nP2 Integration already exists"
  fi

  # get P1 project envs
  ENV_LIST=$(platform environment:list -p $P1_PROJECT_ID --pipe)
  P1_ENVS=($ENV_LIST)

  steps/set_projects.sh $P1_PROJECT_ID $P2_PROJECT_ID

  [[ $? -ne 0 ]] && exit
  steps/copy_project.sh

  for ENV in "${P1_ENVS[@]}"; do
      printf "\nCopy env $ENV"
      steps/copy_environment.sh $ENV

      ENV_CHECK=$(platform project:curl -p $P1_PROJECT_ID /environments/$ENV | jq -r '.status')
      if [ "$ENV_CHECK" = active ]; then
        printf "\nCopy data for env $ENV\n"
        # Wait 1 minute, just to be sure new env is up and running
        sleep 60s
        steps/copy_data.sh $ENV $DATABASE_APP
      else
        printf "\nEnv $ENV is not active, skip copy data\n"
      fi
  done

#  read -p "Would you like to transfer domains now (y/n)?: " choice
#  case "$choice" in
#    y|Y ) steps/project/transfer_domains.sh;;
#  esac
}

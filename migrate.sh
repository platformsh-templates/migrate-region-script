#!/usr/bin/env bash
working_dir=$(pwd)
printf "> Enter project ID to migrate: "
read -r P1_PROJECT_ID

echo "> Select the region where the new project will be hosted
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
printf "Enter region: "
read -r REGION

echo "> On which organization do you want the new project to be? Listing current orgs:"
platform organization:list --columns=name --no-header
printf "Enter organization: "
read -r ORGANIZATION

P1_DEFAULT_BRANCH=$(platform project:info -p "$P1_PROJECT_ID" default_branch)

echo "> From the following, which app contains the database to migrate (ex: app)?"
platform app:list -p "${P1_PROJECT_ID}" -e "${P1_DEFAULT_BRANCH}" --no-header --columns=name
printf "> Enter the app to use: "
read -r DATABASE_APP

printf "> Please provide a valid Github API Token: "
read -r GITHUB_API_TOKEN

# get project P1 name
P1_NAME=$(platform project:info -p "${P1_PROJECT_ID}" title)
printf "Project name is %s\n" "${P1_NAME}"

# get project P1 production env
P1_DEFAULT_BRANCH=$(platform project:info -p "${P1_PROJECT_ID}" default_branch)
printf "Project default branch is %s\n" "${P1_DEFAULT_BRANCH}"

P1_PLAN=$(platform project:info -p "$P1_PROJECT_ID" subscription.plan)
printf "Project plan is %s\n" "${P1_PLAN}"

# create new project P2 with
#   - the same project P1 name on $REGION region
#   - the same env name for production env (default env)
#   - the same plan
P2_PROJECT_ID=$(platform project:create --title="$P1_NAME" --region="$REGION" --default-branch="$P1_DEFAULT_BRANCH" --environments=21 --no-interaction --org="$ORGANIZATION" --plan="$P1_PLAN")
printf "New project ID is %s\n" "${P2_PROJECT_ID}"

##### Clone from P1 to P2
## We need the region of the from project
P1_REGION=$(platform project:info region -p "${P1_PROJECT_ID}");

## Remove git clone directory if it still exists from a previous run
if [ -d "./.local/source_code" ]; then
  printf "Removing previous git clone in ./.local/source_code... "
  rm -rf "./.local/source_code";
  echo "Done."
fi

## Clone P1 from Platform.sh, NOT the integration
printf "Cloning the from project's repository locally... "
git clone --mirror "${P1_PROJECT_ID}@git.${P1_REGION}:${P1_PROJECT_ID}.git" ./.local/source_code
echo "Done."
cd ./.local/source_code
## Get the PLATFORMSH git location for P2
P2_GIT_URL=$(platform project:info -p "${P2_PROJECT_ID}" git)
git remote add p2 "${P2_GIT_URL}"
printf "Pushing the repository to the new project..."
git push p2 --mirror
echo "Done."
cd "${working_dir}"
printf "Removing local temp copy of repository... "
rm -rf ./.local/source_code
echo "Done."

# get P1 project envs
ENV_LIST=$(platform environment:list -p "$P1_PROJECT_ID" --pipe)
P1_ENVS=($ENV_LIST)

steps/set_projects.sh "$P1_PROJECT_ID" "$P2_PROJECT_ID"

[[ $? -ne 0 ]] && exit
steps/copy_project.sh

for ENV in "${P1_ENVS[@]}"; do
    printf "\nCopy env $ENV"
    steps/copy_environment.sh "$ENV"

    ENV_CHECK=$(platform project:curl -p "$P1_PROJECT_ID" /environments/"$ENV" | jq -r '.status')
    if [ "$ENV_CHECK" = active ]; then
      printf "Activating the environment %s in the new project... " "${ENV}"
      platform environment:activate -e "${ENV}" -p "${P2_PROJECT_ID}" --wait --no-interaction
      echo "Done."
      printf "Copying data for env %s\n" "${ENV}"
      # Wait 1 minute, just to be sure new env is up and running
      #sleep 60s
      steps/copy_data.sh "$ENV" "$DATABASE_APP"
    else
      printf "Env %s is not active in original project, skip copy data.\n" "${ENV}"
    fi
done

# get P1 integration repo
P1_INTEGRATION_REPO=$(platform project:curl -p "$P1_PROJECT_ID" /integrations | jq -r '.[]|select(.type | contains("github"))' | jq '.repository'| tr -d '"')
P1_INTEGRATION_ID=$(platform project:curl -p "$P1_PROJECT_ID" /integrations | jq -r '.[]|select(.type | contains("github"))' | jq '.id')
printf "P1 Integration repo is %s and ID is %s\n" "${P1_INTEGRATION_REPO}" "${P1_INTEGRATION_ID}"
printf "P1 integration URL: %s\n" "${P1_INTEGRATION_REPO}"

# remove P1 integration
#TODO uncomment if you need to remove the integration on P1 project
# REMOVE_INTEGRATION=$(platform integration:delete -p $P1_PROJECT_ID --yes $P1_INTEGRATION_ID)

# create integration (github api token) on P2 project and catch errors
(
  set -e
  INTEGRATION=$(platform integration:add --type=github --project="$P2_PROJECT_ID" --repository="$P1_INTEGRATION_REPO" --token="$GITHUB_API_TOKEN" --no-interaction -vvv)
  printf "\nP2 Integration is $INTEGRATION\n"
)
errorCode=$?
if [ $errorCode -ne 0 ]; then
  echo "We have an error"
  printf "\nP2 Integration already exists"
fi

read -p "\nWould you like to transfer domains now (y/n)?: " choice
case "$choice" in
  y|Y ) steps/project/transfer_domains.sh;
esac

./steps/project/update_from_title.sh

printf "New project id %s successfully created.\n" "$P2_PROJECT_ID"
printf "\nhttps://console.platform.sh/${REGION}/${P2_PROJECT_ID}"

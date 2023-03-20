#!/usr/bin/env bash
working_dir=$(pwd)
printf "> Enter project ID from which you want to create a demo project: "
read -r P1_PROJECT_ID

printf "> Enter Title of your demo project: "
read -r PROJECT_TITLE

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
P1_REGION=$(platform project:info region -p "${P1_PROJECT_ID}");

echo "> From the following, which app contains the database to migrate (ex: app)?"
platform app:list -p "${P1_PROJECT_ID}" -e "${P1_DEFAULT_BRANCH}" --no-header --columns=name
printf "> Enter the app to use: "
read -r DATABASE_APP

printf "Project default branch is %s\n" "${P1_DEFAULT_BRANCH}"

# create new project
P2_PROJECT_ID=$(platform project:create --title="$PROJECT_TITLE" --default-branch="$P1_DEFAULT_BRANCH" --region="$REGION" --environments=21 --no-interaction --org="$ORGANIZATION")

if [ "$P2_PROJECT_ID" = "" ]; then
    echo "\n\n[ERROR] An unexpected error occurs during new project creation, please re-execute migration script\n"
    exit
fi

printf "New project ID is ${P2_PROJECT_ID}\n"

ENV_CHECK=$(platform project:curl -p "$P2_PROJECT_ID" /environments/"$ENV" | jq -r '.status')
if [ "$ENV_CHECK" != active ]; then
  printf "Activating environment $P1_DEFAULT_BRANCH\n"
  platform environment:activate -e "${P1_DEFAULT_BRANCH}" -p "${P2_PROJECT_ID}" --wait --no-interaction
  echo "Done."
fi

## Remove git clone directory if it still exists from a previous run
if [ -d "./.local/source_code" ]; then
  printf "Removing previous git clone in ./.local/source_code... "
  rm -rf "./.local/source_code";
  echo "Done."
fi

## Clone template from Platform.sh
printf "Cloning the from template's repository locally... "
git clone --mirror "${P1_PROJECT_ID}@git.${P1_REGION}:${P1_PROJECT_ID}.git" ./.local/source_code
echo "Done."

cd ./.local/source_code
## Get the PLATFORMSH git location for P2
P2_GIT_URL=$(platform project:info -p "${P2_PROJECT_ID}" git)
git remote add demo_project "${P2_GIT_URL}"
printf "Pushing the repository to the new project..."
git push demo_project --mirror
echo "Done."
cd "${working_dir}"
printf "Removing local temp copy of repository... "
rm -rf ./.local/source_code
echo "Done."

steps/set_projects.sh "$P1_PROJECT_ID" "$P2_PROJECT_ID"

printf "Copying data for env %s\n" "${ENV}"
# Wait 1 minute, just to be sure new env is up and running
sleep 60s
steps/copy_data.sh "$P1_DEFAULT_BRANCH" "$DATABASE_APP"

# create Fake users

# create fake envs
printf "Create fake env for project %s\n" "${P2_PROJECT_ID}"


printf "New project id %s successfully created.\n" "$P2_PROJECT_ID"
printf "\nhttps://console.platform.sh/${ORGANIZATION}/${P2_PROJECT_ID}\n"

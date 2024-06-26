#!/bin/bash

# Exit on error, trace all commands, fail on pipeline errors

echo "$GITHUB_TOKEN" | gh auth login --with-token
git config --global --add safe.directory /github/workspace

# set -eo pipefail

echo "Input variables are:"
echo "GITHUB TOKEN: $GITHUB_TOKEN"
echo "BASE BRANCH: $INPUT_BASE_BRANCH"
echo "RELEASE BRANCH: $INPUT_RELEASE_BRANCH"
echo "TEMPLATE: $INPUT_TEMPLATE"
echo "JIRA BASE URL: $INPUT_JIRA_BASE_URL"

# Check if required environment variables are set
if [[ -z "$INPUT_BASE_BRANCH" || -z "$INPUT_RELEASE_BRANCH" || -z "$INPUT_TEMPLATE" ]]; then
  echo "Required environment variables are not set. Exiting..."
  exit 1
fi

if [[ ! -f $INPUT_TEMPLATE ]]; then
  echo "Release template not found. Exiting..."
  exit 1
fi
# Fetch the template from the repository
TEMPLATE=$(cat $INPUT_TEMPLATE)

# Initialize placeholders
FEATURE_TICKETS=""
BUGFIX_TICKETS=""
MAINTENANCE_TICKETS=""
OTHER_TICKETS=""

git fetch --all || { echo 'Failed to fetch repositories'; exit 1; }

# Fetch commit messages
echo $(git log --oneline $INPUT_BASE_BRANCH...$INPUT_RELEASE_BRANCH)
COMMIT_MESSAGES=$(git log --oneline $INPUT_BASE_BRANCH...$INPUT_RELEASE_BRANCH | grep '(\#[0-9]\+)$' | awk '{ $1=""; print substr($0, 2) }')

echo "COMMIT_MESSAGES: $COMMIT_MESSAGES"
echo "INPUT_BASE_BRANCH: $INPUT_BASE_BRANCH"
echo "INPUT_RELEASE_BRANCH: $INPUT_RELEASE_BRANCH"

if [[ -n "$COMMIT_MESSAGES" ]]; then
  while read line; do
    echo "Working on $line"
    TICKET_NUMBER=$(echo $line | grep -oE '[A-Za-z]+-[0-9]+')

    echo "Processing $TICKET_NUMBER"
    COMMIT_MESSAGE=$(echo $line | sed -r 's/AR-[0-9]+: //')
    PR_NUMBER=$(echo $line | grep -oE '#[0-9]+')

    JSON=$(gh pr view $PR_NUMBER --json headRefName --jq '.headRefName')
    echo "JSON: $JSON"

    TYPE=$(echo $JSON | grep -oE '^(feature|bugfix|maintenance)/' | grep -oE '^(feature|bugfix|maintenance)')
    echo "Type: $TYPE"

    CURR_LINE="- [ ] [$line]($INPUT_JIRA_BASE_URL$TICKET_NUMBER)\n"
    echo "CURR_LINE $CURR_LINE"

    if [[ $TYPE == *"feature"* ]]; then
      FEATURE_TICKETS+=$CURR_LINE
    elif [[ $TYPE == *"bugfix"* ]]; then
      BUGFIX_TICKETS+=$CURR_LINE
    elif [[ $TYPE == *"maintenance"* ]]; then
      MAINTENANCE_TICKETS+=$CURR_LINE
    else
      OTHER_TICKETS+=$CURR_LINE
    fi
  done < <(echo "$COMMIT_MESSAGES")
else
  echo "No commit messages found between $INPUT_BASE_BRANCH and $INPUT_RELEASE_BRANCH"
fi

[[ -n "$FEATURE_TICKETS" ]] && FEATURE_TICKETS="### Features:\n$FEATURE_TICKETS"
[[ -n "$BUGFIX_TICKETS" ]] && BUGFIX_TICKETS="### Bugfixes:\n$BUGFIX_TICKETS"
[[ -n "$MAINTENANCE_TICKETS" ]] && MAINTENANCE_TICKETS="### Maintenance:\n$MAINTENANCE_TICKETS"
[[ -n "$OTHER_TICKETS" ]] && OTHER_TICKETS="### Others:\n$OTHER_TICKETS"

echo "FEATURE_TICKETS: $FEATURE_TICKETS"
echo "BUGFIX_TICKETS: $BUGFIX_TICKETS"
echo "MAINTENANCE_TICKETS: $MAINTENANCE_TICKETS"
echo "OTHER_TICKETS: $OTHER_TICKETS"

sed -e "s|{FEATURE_TICKETS}|$FEATURE_TICKETS|" \
    -e "s|{BUGFIX_TICKETS}|$BUGFIX_TICKETS|" \
    -e "s|{MAINTENANCE_TICKETS}|$MAINTENANCE_TICKETS|" \
    -e "s|{OTHER_TICKETS}|$OTHER_TICKETS|" \
    $INPUT_TEMPLATE > temp_release.md

cat temp_release.md
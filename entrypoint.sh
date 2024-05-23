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
COMMIT_MESSAGES=$(git log $INPUT_BASE_BRANCH...$INPUT_RELEASE_BRANCH --oneline | \
awk '{ commit=$1; $1=""; msg=substr($0,2); if (match(msg, /AR-[0-9]+/)) { ticket=substr(msg, RSTART, RLENGTH); if (!seen[ticket]++) print ticket ": " msg } }' | \
sort -u -k1,1)

echo "COMMIT_MESSAGES: $COMMIT_MESSAGES"
echo "INPUT_BASE_BRANCH: $INPUT_BASE_BRANCH"
echo "INPUT_RELEASE_BRANCH: $INPUT_RELEASE_BRANCH"
echo "COMMIT_MESSAGES: $COMMIT_MESSAGES"
if [[ -n "$COMMIT_MESSAGES" ]]; then
  while read line; do
    echo "Working on $line"
    TICKET_NUMBER=$(echo $line | grep -oE 'AR-[0-9]+')

    echo "Processing $TICKET_NUMBER"
    COMMIT_MESSAGE=$(echo $line | sed -r 's/AR-[0-9]+: //')
    PR_NUMBER=$(echo $line | grep -oE '#[0-9]+')

    JSON=$(gh pr view $PR_NUMBER --json headRefName --jq '.headRefName')
    TYPE=$(echo $JSON | grep -oE '^(feature|bugfix|maintenance)')

    echo "Type: $TYPE"
    CURR_LINE="- [ ] [$TICKET_NUMBER - $COMMIT_MESSAGE]($INPUT_JIRA_BASE_URL$TICKET_NUMBER)\n"
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

[[ -z "$FEATURE_TICKETS" ]] && FEATURE_TICKETS="-\n"
[[ -z "$BUGFIX_TICKETS" ]] && BUGFIX_TICKETS="-\n"
[[ -z "$MAINTENANCE_TICKETS" ]] && MAINTENANCE_TICKETS="-\n"
[[ -z "$OTHER_TICKETS" ]] && OTHER_TICKETS="-\n"

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
#!/bin/bash

# Fetch the template from the repository
TEMPLATE=$(cat .github/release.md)

# Initialize placeholders
FEATURE_TICKETS=""
BUGFIX_TICKETS=""
MAINTENANCE_TICKETS=""
OTHER_TICKETS=""

# Fetch commit messages
COMMIT_MESSAGES=$(git log $INPUT_BASE_BRANCH...$INPUT_RELEASE_BRANCH --oneline | awk '{ $1=""; print substr($0,2) }' | grep -E 'AR-[0-9]+' | sort | uniq)

while read line
do
  TICKET_NUMBER=$(echo $line | grep -oE 'AR-[0-9]+')
  COMMIT_MESSAGE=$(echo $line | sed -r 's/AR-[0-9]+: //')
  PR_NUMBER=$(echo $line | grep -oE '#[0-9]+')

  JSON=$(gh pr view $PR_NUMBER --json headRefName --jq '.headRefName')
  TYPE=$(echo $JSON | grep -oE '^(feature|bugfix|maintenance)')

  CURR_LINE="- [ ] [$TICKET_NUMBER - $COMMIT_MESSAGE]($INPUT_JIRA_BASE_URL$TICKET_NUMBER)\n"
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

[[ -z "$FEATURE_TICKETS" ]] && FEATURE_TICKETS="-\n"
[[ -z "$BUGFIX_TICKETS" ]] && BUGFIX_TICKETS="-\n"
[[ -z "$MAINTENANCE_TICKETS" ]] && MAINTENANCE_TICKETS="-\n"
[[ -z "$OTHER_TICKETS" ]] && OTHER_TICKETS="-\n"

sed -e "s|{FEATURE_TICKETS}|$FEATURE_TICKETS|" \
    -e "s|{BUGFIX_TICKETS}|$BUGFIX_TICKETS|" \
    -e "s|{MAINTENANCE_TICKETS}|$MAINTENANCE_TICKETS|" \
    -e "s|{OTHER_TICKETS}|$OTHER_TICKETS|" \
    .github/release.md > temp_release.md
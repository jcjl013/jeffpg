#!/bin/bash

# Color constants
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NO_COLOR='\033[0m'

# Color prefix text for output
ERROR="${RED}----- MPR: ERROR:${NO_COLOR}"
PREFIX="${PURPLE}----- MPR:${NO_COLOR}"
SUCCESS="${GREEN}----- MPR: SUCCESS:${NO_COLOR}"
WARNING="${YELLOW}----- MPR: WARNING:${NO_COLOR}"
INFO="${YELLOW}----- MPR: INFO:${NO_COLOR}"

git_branch() {
  git rev-parse --abbrev-ref HEAD
}

last_commit_message() {
  git log -1 --pretty=%B
}

num_lines_changed() {
  git log --pretty=full --stat --no-merges origin/$BASE..HEAD | awk '{sum += $4 + $6} END {print sum}'
}

# Parse param flags
while getopts :r:m:b:f options
do
  case "${options}"
  in
  b) BASE_RAW=${OPTARG};;
  f) FORCE=true;;
  m) MESSAGE_RAW=${OPTARG};;
  r) REVIEWERS_RAW_STRING=${OPTARG};;
  ?) UNEXPECTED_FLAG=${OPTARG};;
  esac
done

if [ $UNEXPECTED_FLAG ]; then
  case "$UNEXPECTED_FLAG"
  in
  b) echo -e "$ERROR '-b' requires an argument of a base branch that you want to merge into";;
  m) echo -e "$ERROR '-m' requires an argument of a message string for your pull request";;
  r) echo -e "$ERROR '-r' requires an argument of a comma-delimited string of reviewers.
     If you want to assign no reviewers, do not add the '-r' flag";;
  *) echo -e "$ERROR Something went wrong with this flag: -"$UNEXPECTED_FLAG". Exiting".
  esac

  exit 1
fi

# Display the inputs the user has defined during invocation.
if [ ${#options[@]} -gt 0 ]; then
  echo -e "$PREFIX Here's your inputs"
  if [ ! -z "$REVIEWERS_RAW_STRING" ]; then
    echo "Reviewers: $REVIEWERS_RAW_STRING"
  fi
  if [ ! -z "$MESSAGE_RAW" ]; then
    echo "Message: $MESSAGE_RAW"
  fi
  if [ ! -z "$BASE_RAW" ]; then
    echo "Base branch: $BASE_RAW"
  fi
  if [ $FORCE ]; then
    echo "Force push: true"
  fi
fi

# Push from local to remote branch
GIT_BRANCH=$(git_branch)

if [ $GIT_BRANCH == "master" ]; then
  echo -e "$ERROR You're currently on a master branch. MPR will not push to remote master. If you truly want to do this
  then do it manually."
  exit 1
fi

#echo -e "$PREFIX Pushing local branch of '$GIT_BRANCH' to remote"
#if [ $FORCE ]; then
#  echo -e "$INFO Force pushing!"
#  PUSH=$(git push -u origin $GIT_BRANCH -f 2>&1) # Force printing from stderr to stdout
#else
#  PUSH=$(git push -u origin $GIT_BRANCH 2>&1)
#fi
#
#PUSH_STATUS=$?
#PUSH_RESULTS=$PUSH
#
#if [ $PUSH_STATUS -ne 0 ]; then
#  echo "$PUSH_RESULTS"
#  echo -e "$ERROR Failed to push local branch to remote. Check the git output. Exiting."
#  exit 1
#elif [[ $PUSH_RESULTS == *"Everything up-to-date"* && -z "${REVIEWERS_RAW_STRING// }" ]]; then
#  echo -e "$INFO There was no difference between your local and remote branch."
#  exit 1
#fi

# Parse reviewers input so we can derive relevant Github usernames
echo -e "$PREFIX Parsing Github reviewers input"
IFS=',' read -ra REVIEWERS_RAW <<< "$REVIEWERS_RAW_STRING" # Convert string to array
REVIEWERS=""

for REVIEWER in "${REVIEWERS_RAW[@]}"; do
  case "$REVIEWER"
  in
  jeff) REVIEWERS+="jcjl013";;
  *) echo -e "$WARNING '$REVIEWER' is not recognized, but I'll add it anyways as a reviewer";
     REVIEWERS+=$REVIEWER;;
  esac
  REVIEWERS+=","
done

# Remove last comma
REVIEWERS=${REVIEWERS%?}

# Create the Github pull request
echo -e "$PREFIX Opening pull request to Github"
if [ $BASE_RAW ]; then
  BASE=$BASE_RAW
else
  BASE="master"
fi
echo "This pull request will merge from $(git_branch) to $BASE"

echo "Reviewers: " $REVIEWERS

if [[ -z "${MESSAGE_RAW// }" ]]; then
  MESSAGE_RAW=$(last_commit_message)
fi

NEWLINE=$'\n'
IFS=${NEWLINE} read -d '' -r -a MESSAGE_ARRAY <<< "$MESSAGE_RAW"
MESSAGE_ARRAY[0]="${MESSAGE_ARRAY[0]} (±$(num_lines_changed)) ${NEWLINE}"
MESSAGE=$( IFS=${NEWLINE}; echo "${MESSAGE_ARRAY[*]}" )
echo "Message: $MESSAGE"

PR_ARGS=("-m" "$MESSAGE" "-b" "$BASE")
PR=$(hub pull-request "${PR_ARGS[@]}" 2>&1)
PR_STATUS=$?
PR_RESULTS=$PR

if [ $PR_STATUS -ne 0 ]; then
  echo "$PR_RESULTS"
  echo -e "$ERROR Failed to create pull request. Check the output above.
  If you just want to send a patch, do not include reviewers. Exiting."
  exit 1
else
  IFS='/' read -ra GITHUB_PULL_URL_ARRAY <<< "$PR_RESULTS"
  REPO_NAME=${GITHUB_PULL_URL_ARRAY[4]}
  PR_ID=${GITHUB_PULL_URL_ARRAY[6]}
  REVIEWABLE_PREFIX="https://reviewable.io/reviews/medisas"
  echo $REVIEWABLE_PREFIX/$REPO_NAME/$PR_ID
fi

echo -e "$SUCCESS Pull request has been successfully created on Github! :)"

#!/bin/bash

# Purpose: Update members of Slack user-groups with the on-call member(s) of each team
# Written by: Braydon Brinkerhoff
# Date: September 2020


###################################################################################
#################################### Variables ####################################
###################################################################################
# List of (case-sensitive) team names from Opsgenie
# Note: The name of the primary schedule for a team should be formatted as TeamName_schedule
# example -- Team name: 'SysOps' -- The primary schedule should be named: 'SysOps_schedule'
teams=(
  #'CorpIT'
  #'DBOps'
  #'DevOps'
  #'NetOps'
  #'SysOps'
)

# Optional 'Special' teams -- when the team/schedule/handle aren't in the normal format
# Add each team with it's own name, schedule, and handle together:
specialTeams=(
  #'SysOps' 'SysOps_schedule' 'on-call'
  #'SecOps' 'Security_schedule' 'on-call-secops'
)

# Slack User API OAuth token (provided at app installation)
# Note: It must be a user API OAuth token unless your workspace allows all users and guests to update user-groups
slackToken='xoxp-123456790-12345678901234-1234567890123-abcdefghijklmn1234567890'

# Opsgenie API Token to get on-call schedules
ogToken='abcde12345-ab12-cd34-ef56-abcdef1234567'

# Global vars to reduce the amount of http queries needed to update user groups
oncallSchedules=; slackUsers=; slackGroups=;


###################################################################################
#################################### Functions ####################################
###################################################################################
# Join an array into a string using the delimeter passed as $1
joinBy() { local IFS=$1;shift;echo "$*"; }

getJSON() {
  # Query slack and oncall to get json payloads to parse later
  validateJSON() { echo "$@"|jq . >/dev/null 2>&1; return $?; }
  
  getSlackUsers() {
    # Loop and add the next "page" of the Users collection to ensure all users are present when searching
    slackUsers=`curl -ks "https://slack.com/api/users.list?token=$slackToken"`
    local next_cursor=`echo "$slackUsers"|jq '.response_metadata | .next_cursor'|sed 's/"//g'`
    while [[ -n $next_cursor ]];do
      local slackUsersCursor=`curl -ks "https://slack.com/api/users.list?token=$slackToken&cursor=$next_cursor"`
      [[ -n "$slackUsersCursor" ]] && slackUsers+="$slackUsersCursor"
      local next_cursor=`echo "$slackUsersCursor"|jq '.response_metadata | .next_cursor'|sed 's/"//g'`
      local slackUsersCursor=;
    done; }

  if [[ -z "$oncallSchedules" || -z "$slackUsers" || -z "$slackGroups" ]];then
    oncallSchedules=`curl -ks -X GET "https://api.opsgenie.com/v2/schedules/on-calls" --header "Authorization: GenieKey $ogToken"`
    slackGroups=`curl -ks "https://slack.com/api/usergroups.list?token=$slackToken&include_users=true"`
    getSlackUsers
    [[ -n $oncallSchedules && -n $slackUsers && -n slackGroups ]] && \
    validateJSON "$oncallSchedules" "$slackUsers" "$slackGroups"; return $?
  else
    [[ -n $oncallSchedules && -n $slackUsers && -n slackGroups ]] && \
    validateJSON "$oncallSchedules" "$slackUsers" "$slackGroups"; return $?
  fi; }

getUserEmails() {
  # Parse json payload from oncall server to get the email address of the on-call user for the given team
  local schedule=$1
  local jqFilter="'.data[] as \$parent | \$parent[\"_parent\"] | select(.name == \"$schedule\") | \$parent | .onCallParticipants[][\"name\"]'"
  echo "$oncallSchedules"|eval jq $jqFilter|sed 's/"//g'; }

getUserIDs() {
  # Parse json payload from slack to get the encoded ID of the given user
  for user in $@;do
    local jqFilter="'.members[] | select(.name == \"$user\") | .id'"
    echo "$slackUsers"|eval jq $jqFilter|sed 's/"//g'
  done; }

getGroupID() {
  # Parse json payload from slack to get the encoded ID of the user group
  local handle=$1
  local jqFilter="'.usergroups[] | select(.handle == \"$handle\") | .id'"
  echo "$slackGroups"|eval jq $jqFilter|sed 's/"//g'; }

checkGroupMembers(){
  # Check if the oncall user is already the only user in their user group
  local IFS=$'\n'; local groupID=$1; shift; local userIDs=(`sort <<< "$*"`)
  local jqFilter="'.usergroups[] | select(.id == \"$groupID\")|.user_count'"
  local userCount=`echo "$slackGroups"|eval jq $jqFilter`
  if [[ $userCount -gt 0 ]];then
    local jqFilter="'.usergroups[] | select(.id == \"$groupID\")|.users[]'"
    local groupMembers=(`echo "$slackGroups"|eval jq $jqFilter`)
    local groupMembers=(`echo "${groupMembers[*]}"|sort|sed 's/"//g'`)
    [[ ${groupMembers[@]} == ${userIDs[@]} ]]; return $?
  else
    return 1
  fi; }

updateGroupMembers() {
  # Use REST command to update the members of the given slack user group to be only the on-call user for that team
  local groupID=$1; shift; local userIDs=($@); local userString=`joinBy "%" "${userIDs[@]}"|sed 's/%/%2C/g'`; [[ -n $userString && -n $groupID ]] && \
  curl -ks "https://slack.com/api/usergroups.users.update?token=$slackToken&usergroup=$groupID&users=$userString" >/dev/null 2>&1; }

updateOncallGroups(){
  # Loop through every team in the "teams" array and update it's corresponding Slack user group
  if getJSON;then
    for team in "${teams[@]}";do
      local teamLower=`tr [:upper:] [:lower:] <<< "$team"`;
      local handle=`sed 's/_/-/g;s/ /-/g' <<< "oncall-$teamLower"`
      local schedule=$team\_schedule
      local userEmails=(`getUserEmails "$schedule"`)
      local userNames=(`sed 's/@.*//g' <<< "$(joinBy $'\n' ${userEmails[@]})"`)
      local userIDs=(`getUserIDs $groupID ${userNames[@]}`)
      local groupID=`getGroupID "$handle"`
      # The 'checkGroupMembers' function will return true if all the members to be added are already the users in the group
      if ! checkGroupMembers "$groupID" "${userIDs[@]}";then
        updateGroupMembers "$groupID" "${userIDs[@]}"
      fi
    done
  fi; }

updateSpecialGroup() {
  # Separate function to update only the on-call usergroup for because it has a handle that doesn't match the team name
  if getJSON;then
    # Ensure that the amount of items in the 'specialTeams' array is a factor of 3
    if ! (( $# % 3 ));then
      # Every loop will shift 3 places in the 'specialTeams' array to populate the corresponding team, schedule, and handle vars until the array is empty
      while test $# -gt 0;do
        local team="$1"; shift
        local schedule="$1"; shift
        local handle="$1"; shift
        local userEmails=(`getUserEmails "$schedule"`)
        local userNames=(`sed 's/@.*//g' <<< "$(joinBy $'\n' ${userEmails[@]})"`)
        local userIDs=(`getUserIDs $groupID ${userNames[@]}`)
        local groupID=`getGroupID "$handle"`
        if ! checkGroupMembers "$groupID" "${userIDs[@]}";then
          updateGroupMembers "$groupID" "${userIDs[@]}"
        fi
      done
    fi
  fi; }


###################################################################################
################################## Help Function ##################################
###################################################################################
showHELP() {
  echo "${YELLOW}Options:${BLUE}"
  echo "    -h,--help                      Show this help menu."
  echo "    -t,--team                      Update user group members for the specified team."
  echo
  echo "${YELLOW}Usage:${BLUE}"
  echo "    ./opsgenieUserGroups.sh"
  echo "    ./opsgenieUserGroups.sh [-t,--team] [team]"
  echo "${RESET}"; exit 0; }


###################################################################################
################################## Script Flags ###################################
###################################################################################
while test $# -gt 0; do
        case "$1" in
                -h|--help)
                    showHELP
                    ;;
                -t|--team)
                    shift
                    teams=("$1")
                    updateOncallGroups
                    exit 0
                    ;;
                *)
                    echo "${RED} $1 is not a valid option.${RESET}"
                    exit 1
                    ;;
        esac
done

# Run main function to update all teams in the 'teams' var above
updateOncallGroups
# Optional run function to update special teams
updateSpecialGroup "${specialTeams[@]}"

# Opsgenie + Slack group manager
A BASH script that will pull the primary on-call members from one or more Opsgenie teams and populate a corresponding Slack user-group with the on-call members of each team.

## Installation

To set up this script you will need the following:
  - App user API token from Slack
  - Integration API token from Opsgenie
  - Opsgenie schedules following the appropriate naming convention
  - Slack user-groups following the appropriate naming convention

### Acquiring a Slack user API Token

To generate an API key from slack go to the Slack [app portal](https://api.slack.com/apps) and create an app.
 
- Under "**App Features**" go to "**OAuth & Permissions**".
- In the "**Scopes**" section of the page, you will need to add 3 permissions to "**User Token Scopes**":
  - **usergroups:read**
    - Allows the app to read the names and members of the user-groups
  - **usergroups:write**
    - Allows the app to update the names and members of the user-groups
  - **users:read**
    - Allows the app to get a list of all the names and attributes of the Slack users
> **Note**: If your workspace allows "**Everyone except guests**" to **modify/update** user-groups, you can add these permissions to a **Bot API** scope instead.

- After adding the permissions to the scope, you will need to **Install and Authorize** your app to the workspace. This can be found at the top of the "**OAuth & Permissions**" page.
- Once installed, your API token will be under "**OAuth Access Token**". You will need to populate the "**slackToken**" variable in the BASH script with this value.

### Generating an Opsgenie integration API Token

To generate an API key for Opsgenie start by logging into their [web portal](https://app.opsgenie.com) and navigate to the "**Settings**" page.

- On the left side, select "**Integration list**" and then select "**API**".
  - You will be shown an initial settings page for the API integration.
  - You are free to change any of the fields to whatever fits your needs as long as you ensure that the "**Read Access**" permission is **enabled**. 
  - Save the integration when you are finished configuring.

- On the left side, select "**Configured Integrations**" and find your API integration you have just made.

- You will need to populate the "**ogToken**" variable in the BASH script with the value found in the "**API Key**" field of your integration.

### Naming your Opsgenie Teams and Schedules

#### Team names:
Team names should be case-sensitive and use underscores ( _ ) instead of spaces.
> Example: "Sys Ops" should be renamed to "Sys_Ops"

#### Schedule names:
The primary on-call schedule should be named in the format of <TeamName>_schedule.
> Example: The schedule for team "Sys_Ops" should be named "Sys_Ops_schedule"

### Naming your Slack user-groups
Slack user-groups should be created prior to running the script and named in the format of oncall-<TeamName>.
- **Note**: Replace any **underscores** ( **_** ) in your Opsgenie team name with **hyphens** ( **-** )

> Example: The user-group for team "Sys_Ops" should be named "@oncall-sys-ops"



## Populating variables
At the top of the script, you will find a "**Variables**" section. These global variables will be explained below:

### Teams
This variable is an array of **case-sensitive** team names from Opsgenie.
```bash
teams=(
  'CorpIT'
  'DBOps'
  'DevOps'
  'NetOps'
  'SysOps'
  'Sec_DevOps'
)
```

### Special Teams
This variable is an array meant to allow the ability to update Teams/Schdedules/User-Groups that do not fit the naming convention completely. The following fields are required for each team in the array:
- Team name
- Schedule name
- User-Group name
```bash
specialTeams=(
  'SysOps' 'SysOps_schedule' 'on-call'
  'SecOps' 'Security_schedule' 'on-call-secops'
)
```
After generating the Slack and Opsgenie API keys you will need to verify these steps have been completed prior to running:

- In Slack, ensure you have made the usergroups prior with a handle in the format of  oncall-<teamname>. EX: Team is 'SysOps', Handle should be 'oncall-sysops'.
  Note: if your Opsgenie team has an underscore in the name, use a hyphen '-' instead for the handle. EX: Team is 'Sys_Ops', Handle should be 'oncall-sys-ops'.
  
- In Opsgenie, ensure that the primary on-call schedule for each team is named in the format of <teamname>_schedule. EX: Team is 'SysOps', Schedule should be 'SysOps_schedule'.
  
- Populate the 'teams' array variable in the BASH script with a list of (case-sensitive) names of your desired Opsgenie teams.

### slackToken
This is a string that contains the Slack App user (or bot) API token.
```bash
slackToken='xoxp-123456790-12345678901234-1234567890123-abcdefghijklmn1234567890'
``` 

### ogToken
This is a string that contains the API Key for your Opsgenie API Integration.
```bash
ogToken='abcde12345-ab12-cd34-ef56-abcdef1234567'
```

### Place holders
These global variables are meant to be left empty. They are defined as null to document the main variables being used and to define them globally prior to any script run.
```bash
oncallSchedules=; slackUsers=; slackGroups=;
```

## Usage

### Command Line
```bash
 ./opsgenieUserGroups.sh # Default run mode using variables defined in script body
 ./opsgenieUserGroups.sh [-h,--help] # Show help menu and usage
 ./opsgenieUserGroups.sh [-t,--team] [team] # Specify a singular team to run an update for
```

### Cron jobs
This script was written to be run frequently by a cron job so that the Slack user-groups would be updated soon after the Opsgenie on-call schedules changed.
- This script may not be able to run every minute depending on the size of your Slack workspace. If you experience issues, you may be hitting Slack's API rate limit (20 calls/min).
- To remedy any issues with rate limits, it is recommended to lower your crons frequency to once every 2 minutes or longer.

## Notes + Afterthoughts
  - This script ideally works with its own slack user. The reason for this is that "SlackBot" will show the name of the user who installed/authorized the app as the one making the changes to the user-groups.
    - Depending on the permissions of your Slack workspace, you may be able to use a Bot token for your app instead. 
  - This script may only work in SSO setups. The script operates by pulling the user's email from Opsgenie and searches Slack for the user portion of their email (before @..).

## License

Copyright (c) 2020 Braydon Brinkerhoff

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

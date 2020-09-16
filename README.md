# Opsgenie-Slack-group-manager
A BASH script that will pull the primary on-call members from several Opsgenie teams and populate a corresponding Slack user group with the on-call members of each team

To setup this script you will need to aquire an API key from Opsgenie and Slack.

To generate an API key from slack go to https://api.slack.com/apps and create an app.
Under "App Features" go to "OAuth & Permissions".
In the "Scopes" section of the page you need to add 3 permissions to "User Token Scopes":
  - usergroups:read
  - usergroups:write
  - users:read
Note: If your workspace allows "Everyone except guests" to modify/update usergroups, you can add these permissions to a bot scope instead

After adding those permissions, at the top of the page you will need to install and authorize your app.
Once installed, your API token will be under "OAuth Access Token". You will need to populate the "slackToken" variable in the BASH script with this token.


To generate an API key for Opsgenie login to the platform at https://app.opsgenie.com and navigate to the "Settings" page.
Next go to "Integration list" and select "API".
You will be shown an initial settings page for the API integration. You are free to change any of the fields to whatever fits your needs as long as you ensure that the "Read Access" permission is enabled. Save the integration when done.

Under "Configured Integrations" find your API integration and copy the "API Key" field. You will need to populate the "ogToken" variable in the BASH script with this value.


After generating the Slack and Opsgenie API keys you will need to verify these steps have been completed prior to running:

- In Slack, ensure you have made the usergroups prior with a handle in the format of  oncall-<teamname>. EX: Team is 'SysOps', Handle should be 'oncall-sysops'.
  Note: if your Opsgenie team has an underscore in the name, use a hyphen '-' instead for the handle. EX: Team is 'Sys_Ops', Handle should be 'oncall-sys-ops'.
  
- In Opsgenie, ensure that the primary on-call schedule for each team is named in the format of <teamname>_schedule. EX: Team is 'SysOps', Schedule should be 'SysOps_schedule'.
  
- Populate the 'teams' array variable in the BASH script with a list of (case-sensitive) names of your desired Opsgenie teams.


Notes/Warnings: 
  - You should be able to run this script with a cron job as often as every minute but if you experience issues, you may be hitting Slack's rate limit for the API (20 calls/min). You will need to move to every 2 minutes to have the rate limit reset before running again.
  - This script ideally works with it's own slack user, otherwise it will show the user who authorized the app as the one making the changes.
  - This script may only work in SSO setups in Slack as it pulls the user's email from Opsgenie and searches Slack for the user portion of their email (before @..).

# MPCMD - Chat-based Multiplayer Command Line tool for DCS 

## Introduction
MPCMD provides a chat-based interface for authorized users to interact with a DCS multiplayer server. A basic ability to manage user permissions using pre-configured users, or passwords is included.

MPCMD aims to be extensible in the sense that it's relatively simple to add new commands. 

## Installation
Copy the `Mods` and `Scripts` folders into the DCS saved games folder on the target server.

Additional scripts to be included in a mission file using a (`DO SCRIPT FILE` trigger) can be found in `Mods\Services\MPCMD\AddonCommands\MissionEditor`, but these are only needed to use certain commands that require configuration within mission scripts. 

## Usage
Players joining a game on the server will be able to start a MPCMD session by sending `cmd` in chat. They may be prompted to enter a password, depending on the auth config. 

Within a session, type `help` to list commands or `help <command>` to see additional details about the command `<command>`.

### Example 
A player that has not previously authenticated to MPCMD on the server, and has been given passwords for level 1 (`cmd`, `help` etc in this example) and level 2 commands (`msnsw` in this example), can: 
* Send `cmd` to start a session
* Send the level 1 password when prompted. No other players can see this - sending chats to others is disabled until you see a message **ending with** the session start/end marker `||`
* Send `msnsw`
* Send the level 2 password
* A list of missions in the server queue is displayed
* Send the index corresponding to the mission to load
* The server loads the selected mission
* Depending on the server config, the same user doesn't need the password again for level 2 commands and below

![User authenticates and switches mission](Docs/Images/Example%20msnsw.png)

To quit a session, send `q` when not within a command.

## Configuration
Running DCS after installation will create the config file `Logs\MPCMD.lua`. Server admins can use this to set up user permissions and other config.

* Users can be entered directly into the `users` table, if you know their DCS user ID (`12345` in the example below). Omit `LastSeenUsername` if adding the user manually.
* Alternatively, create passwords for accessing commands at different levels. To set or change the password, enter the value against the `password` key, for the appropriate level object. This value will be converted to a passwordHash next time MPCMD loads.
* `passwordScope`:
    *  `1` means the user must re-enter the password for any level above their configured level for each MPCMD session.
    * `2` means that the user is permamnently promoted to the level of the requested command when they enter the correct password.
### Example
```
config = 
{
	["levels"] = 
	{
		[1] = 
		{
			["password"] = "",
			["passwordHash"] = "######################",
			["passwordScope"] = 2,
		}, -- end of [1]
		[2] = 
		{
			["password"] = "",
			["passwordHash"] = "######################",
			["passwordScope"] = 2,
		}, -- end of [2]
	}, -- end of ["levels"]
	["users"] = 
	{
		["12345"] = 
		{
			["LastSeenUsername"] = "MyUser",
			["level"] = 2,
		}, -- end of ["12345"]
	}, -- end of ["users"]
	["options"] = 
	{
		["rateLimitSeconds"] = 60,
		["rateLimitCount"] = 10,
	}, -- end of ["options"]
} -- end of config


```

WIP

## Default commands

TODO

## Creating commands
TODO
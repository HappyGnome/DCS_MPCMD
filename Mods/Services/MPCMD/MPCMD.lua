--[[
   Copyright 2024 HappyGnome (https://github.com/HappyGnome)

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]]

local _MpcmdVersion = "v1.0"

net.log("MPCMD " .. _MpcmdVersion  .. " loading...")

local base = _G

local lfs               = require('lfs')
local socket            = require("socket") 
local net               = require('net')
local DCS               = require("DCS") 
local Skin              = require('Skin')
local U                 = require('me_utilities')
local Gui               = require('dxgui')
local DialogLoader      = require('DialogLoader')
local Static            = require('Static')
local Tools             = require('tools')

package.path = package.path .. [[;]] .. lfs.writedir() .. [[Mods\Services\MPCMD\?.lua;]]

require([[MPCMD_serialization]])
require([[MPCMD_logging]])

MPCMD.Logging.log("MPCMD " .. _MpcmdVersion  .. " loading...")

-----------------------------------------------------------
-- module init and core variables

if MPCMD == nil then
	MPCMD = {}
end

MPCMD.passwordScope =
{
	PER_SESSION = 1
	,PER_USER = 2
}

MPCMD.config = {["users"] = { --[[ [ucid]={level = n, lastSeenUsername = k} ]]},["levels"] = { --[[ [level] = { password = "plaintext", passwordHash = "hashed", passwordScope = n } ]] }, ["options"] = {rateLimitCount = 10, rateLimitSeconds = 60}}
MPCMD.commandFileDirs = {lfs.writedir()..[[Mods\Services\MPCMD\AddonCommands\Def]]}
MPCMD.missionInjectDirs = {[1] = lfs.writedir()..[[Mods\Services\MPCMD\AddonCommands\MissionInject\Common]], [2] = lfs.writedir()..[[Mods\Services\MPCMD\AddonCommands\MissionInject]]}
MPCMD.commands = {}
MPCMD.sessions = {}
MPCMD.playerMap = {} -- key = playerId, value = value of config.users[ucid] for the player's ucid
MPCMD.rateLimit = {} -- key = playerId, value = {count = n, epoch = t}
MPCMD.config_loaded = false

if  MPCMD.Handlers ~= nil then
	for k,v in pairs(MPCMD.Handlers) do -- Set event handlers to nil when re-including
		MPCMD.Handlers[k] = nil
	end
end

MPCMD.scrEnvMission = "mission"
MPCMD.scrEnvServer = "server"


-----------------------------------------------------------
-- CONFIG & UTILITY

MPCMD.loadConfiguration = function()
	if MPCMD.config_loaded then return end

    MPCMD.Logging.log("Config load starting")
	
    local cfg = Tools.safeDoFile(lfs.writedir()..'Config/MPCMD.lua', false)
	
    if (cfg and cfg.config) then
		for k,v in pairs(MPCMD.config) do
			if cfg.config[k] ~= nil then
				MPCMD.config[k] = cfg.config[k]
			end
		end        
    end

	-- hash passwords
	for k,v in pairs(MPCMD.config.levels) do
		if v.password and v.password ~= "" then
			v.passwordHash = net.hash_password(v.password)
		end
		v.password = ""

		MPCMD.config.levels[k] = v
	end
	
	MPCMD.saveConfiguration()

	MPCMD.config_loaded = true
end

MPCMD.saveConfiguration = function()
    U.saveInFile(MPCMD.config, 'config', lfs.writedir()..'Config/MPCMD.lua')
end


--------------------------------------------------------------


--[[
MPCMD.splitToken

Get the first token of a given string (excluding whitespace)

Args:	
	- str - string to parse - (string)
Returns: 
	- First token (string) 
	- Remaining string (string)
]]
MPCMD.splitToken = function(str)
	if not str then return nil end
	local i, j = string.find(str,"[^%s]+")

	local rem = ""
	local match = ""
	
	if i~= nil then
	  match = string.sub(str,i,j)
	  
  	local k = string.len(str)
  
  	if k > j then
  		rem = string.sub(str,j+1,k)
  	end
  	
	end

	return match, rem
end

--[[
MPCMD.splitCommand

Get the first token of a given string (excluding whitespace). If it matches a registered command, return the command

Args:	
	- str - string to parse - (string)
Returns: 
	- command (table / nil)
	- tok (string) command name
	- Remaining (string)
]]
MPCMD.splitCommand = function(str)
	local tok,argMsg = MPCMD.splitToken(str)

	if not tok then return nil, nil end

	tok = string.lower(tok)

	return MPCMD.commands[tok], tok, argMsg
end
--------------------------------------------------------------
-- GENERAL MODULE LOGIC

--[[
MPCMD.getPlayerUcid

Get player UCID for connected player Id

Args:	
	- id - connected player Id (number)
Returns: 
	- ucid (number) or "??" (string)
]]
MPCMD.getPlayerUcid = function(id)
	if DCS.isServer() then 
		local ucid = net.get_player_info(id, 'ucid')
		if not ucid  then ucid  = '??' end
		return ucid
	end
	return "??"	
end

--[[
MPCMD.getPlayerName

Get player name for connected player Id

Args:	
	- id - connected player Id (number)
Returns: 
	- player name (string) or "??" (string)
]]
MPCMD.getPlayerName = function(id)
	local name = net.get_player_info(id, 'name')
	if not name then name = '??' end
	return name
end

--[[ 
MPCMD.setUserConfig 

Set a new user config for the identified player
Adds some additional detail to the config
Saves the config

Args:
	playerId (number)
	userConfig (table / nil)
Returns:
	nil
]]
MPCMD.setUserConfig = function(playerId, userConfig)

	MPCMD.Logging.log("Set user config")
	MPCMD.Logging.log(userConfig)

	local name = MPCMD.getPlayerName(playerId)
	local ucid = tostring(MPCMD.getPlayerUcid(playerId))

	MPCMD.playerMap[playerId] = userConfig

	-- Save username to make config easier to read for the user
	if userConfig then
		userConfig.LastSeenUsername = name
	end

	if ucid ~= nil then
		MPCMD.config.users[ucid] = userConfig 
	end
	MPCMD.saveConfiguration()
end

--[[ 
MPCMD.blockForRate

Tracks the number of requests by a player in a given time. If a limit is exceeded, displayes a message to the player.

Args:
	playerId (number)
Returns:
	isBlocked (boolean)
]]
MPCMD.blockForRate = function(playerId)
	local now =  os.clock()
	if MPCMD.rateLimit[playerId] == nil or MPCMD.rateLimit[playerId].epoch + MPCMD.config.options.rateLimitSeconds <= now then
		MPCMD.rateLimit[playerId] = {count = 1, epoch = now}
	else 
		MPCMD.rateLimit[playerId].count = MPCMD.rateLimit[playerId].count + 1
	end

	if MPCMD.rateLimit[playerId].count > MPCMD.config.options.rateLimitCount then
		net.send_chat_to("Too many requests. Please wait and try again.",playerId)
		return true
	end

	return false
end

--[[ 
MPCMD.startSession

Starts a cmd session for a single player. The session auth level is the player's configured level, if specified.
A handler for the next chat message by the player can be set, otherwise the default session handler will be used.

Args:
	playerId (number)
	chatHandlerOverride (nil / function - "handler" shape)
Returns:
	nil
]]
MPCMD.startSession = function(playerId, chatHandlerOverride)
	local level

	if MPCMD.playerMap ~= nil and MPCMD.playerMap[playerId] ~= nil then
		level = MPCMD.playerMap[playerId].level
	end

	MPCMD.sessions[playerId] = {sessionStart = os.date("%H:%M:%S"), level = level, handler = chatHandlerOverride}
end

--[[ 
MPCMD.stopSession 

End a cmd session for a single player.

Args:
	playerId (number)
Returns:
	nil
]]
MPCMD.stopSession = function(playerId)
	MPCMD.sessions[playerId] = nil
end

--[[ 
MPCMD.setSessionNextHandler

Override chat message handler for next message from a player.

Args:
	playerId (number)
	chatHandlerOverride (nil / function)
Returns:
	nil
]]
MPCMD.setSessionNextHandler = function(playerId, chatHandlerOverride)

	if type( chatHandlerOverride) ~= "function" then
		chatHandlerOverride = nil
	end

	if MPCMD.sessions[playerId] then
		MPCMD.sessions[playerId].handler = chatHandlerOverride
	end
end

--[[ 
MPCMD.promotePlayer

Set player permission level to max of the current level and the specified level.
If permission scope is PER_USER, then the increased level is saved in the player's config.

Args:
	playerId (number)
	newLevel (number)
	scope (number - see MPCMD.passwordScope)
Returns:
	nil
]]
MPCMD.promotePlayer = function (playerId, newLevel, scope)
	
	if MPCMD.getCurrentPlayerLevel(playerId) > newLevel then return end

	if scope == MPCMD.passwordScope.PER_SESSION and MPCMD.sessions[playerId] then

		MPCMD.Logging.log("Promoting session for player "..playerId.." to level "..newLevel)

		MPCMD.sessions[playerId].level = newLevel

	elseif scope == MPCMD.passwordScope.PER_USER then

		local userConfig = MPCMD.playerMap[playerId]

		if not userConfig then
			userConfig = {}
		end

		userConfig.level = newLevel

		MPCMD.Logging.log("Promoting player "..playerId.." to level "..newLevel)

		-- Complete user config and save
		MPCMD.setUserConfig(playerId, userConfig)

		if MPCMD.sessions[playerId] then -- Promote player for current session too
			MPCMD.sessions[playerId].level = newLevel
		end

	end

end

--[[ 
MPCMD.getCurrentPlayerLevel

Get effective player permission level.

Args:
	playerId (number)
Returns:
	level (number)
]]
MPCMD.getCurrentPlayerLevel = function(playerId)
	
	local session = MPCMD.sessions[playerId] 
	local userConfig = MPCMD.playerMap[playerId]
	local userLevel 

	if session then 
		userLevel = session.level
	elseif userConfig  then	
		userLevel = userConfig.level
	end

	if type(userLevel) ~= "number" then
		return 0
	end

	return userLevel
end

--[[ 
MPCMD.execCommand

Return command.exec(playerId,argMsg), sending any error message back to the user in chat, and also logging it

Args:
	playerId (number)
	argMsg (string)
	command (function(number,string,table) or table with "exec" )
Returns:
	custom handler for next chat input, or nil, as returned by command.exec
]]
MPCMD.execCommand = function(playerId, argMsg, command)

	local reply ={}

	local result 
	
	if type(command) == "table" and command.exec then
		if command.cmd then
			local cmdStartMsg = "<< " .. command.cmd

			net.send_chat_to(cmdStartMsg,playerId)
		end

		result  = command.exec(playerId,argMsg,reply)
	else
		MPCMD.Logging.log("Command object invalid")
		return nil
	end

	if reply.err then
		net.send_chat_to(reply.err,playerId)	
		MPCMD.Logging.log("Command failed: " .. reply.err)
	elseif reply.msg then
		net.send_chat_to(reply.msg,playerId)	
	end

	return result
end

--[[ 
MPCMD.safeDoStringInMission 

Execute a string in the mission environment with basic error handling

Args:
	strLua (string)
Returns:
	nil
]]
MPCMD.safeDoStringInMission = function(strLua)

	local execString = 
		[[a_do_script("if MPCMD and MPCMD.Common then]] ..
						[[ MPCMD.Common.safeDoString(\"]] ..
						  	MPCMD.Serialization.escapeLuaString(strLua,2) ..
      					[[\")]] .. 
					[[ end")]]
	
	MPCMD.Logging.log("Exec: ".. execString)

	net.dostring_in(MPCMD.scrEnvMission, execString)
end
--------------------------------------------------------------
-- CMD SESSION HANDLERS


--[[ 
MPCMD.defaultSessionHandler

Handle a chat message sent by a player during a cmd session.

Args:
	playerId (number)
	message - raw chat message - (string)
Returns:
	modified chat message to send (string)
	handler override for next chat from player (function - same spec as this)
]]
MPCMD.defaultSessionHandler = function(playerId, message)

	local command, cmd, argMsg = MPCMD.splitCommand(message)

	if (not command) or (command.exec == nil) or (command.nonSession) or (type(command.level) ~= "number") then 
		net.send_chat_to("Command not recognized",playerId)
		return "", nil
	end

	if (not command.noRateLimit) and MPCMD.blockForRate(playerId) then return "", nil end

	local levelConfig = MPCMD.config.levels[command.level]

	if MPCMD.getCurrentPlayerLevel(playerId) >= command.level then

		MPCMD.Logging.log("Player ".. playerId .. " runs command " .. cmd)

		return "", MPCMD.execCommand(playerId, argMsg, command)

	elseif levelConfig and levelConfig.passwordHash then

		local failCmd = function(id,msg)

			net.send_chat_to("Password incorrect",id)

			return nil
		end
		
		return "", MPCMD.makePasswordHandler(playerId, argMsg,  levelConfig, command, failCmd)
	else
		net.send_chat_to("Unauthorized",playerId)
	end

	return "", nil
end

--[[ 
MPCMD.nonSessionHandler

Handle a chat message sent by a player without a cmd session.

Args:
	playerId (number)
	message - raw chat message - (string)
Returns:
	modified chat message to send (string)
	handler override for next chat from player (function - same spec as this)
]]
MPCMD.nonSessionHandler = function(playerId, message)

	local command, _, argMsg = MPCMD.splitCommand(message)

	if (not command) or (command.exec == nil) or (not command.nonSession) or (type(command.level) ~= "number") then 
		return message, nil
	end

	if (not command.noRateLimit) and MPCMD.blockForRate(playerId) then return "", nil end

	local levelConfig = MPCMD.config.levels[command.level]

	if MPCMD.getCurrentPlayerLevel(playerId) >= command.level then

		MPCMD.startSession(playerId)
		
		MPCMD.setSessionNextHandler(playerId, MPCMD.execCommand(playerId, argMsg, command)) -- Simulate command being executed from within a session (this is what happens if a password is required first)

	elseif levelConfig and levelConfig.passwordHash then

		local failCmd = function(id,msg)
			MPCMD.stopSession(id)

			net.send_chat_to("Password incorrect",id)

			return nil -- TODO: add something here to allow repeated attempts (prevent accidentally retrying and sending the pwd in chat)
		end
		
		MPCMD.startSession(playerId, MPCMD.makePasswordHandler(playerId, argMsg,  levelConfig, command, failCmd))
	else
		net.send_chat_to("Unauthorized",playerId)
	end

	return "", nil
end

--[[ 
MPCMD.makePasswordHandler

Handle a chat message sent by a player without a cmd session.

Args:
	playerId (number)
	argMsg - chat message without command token - (string)
	levelConfig - data for the permission level required to exec the command (from MPCMD.config.levels) - (table)
	command - command data (from MPCMD.commands) - (table)
	failCmd- cmd function to execute on incorrect password (see spec of MPCMD.cmdSessionStarted) - (function / nil)
Returns:
	handler function (function - same spec as MPCMD.nonSessionHandler)
]]
MPCMD.makePasswordHandler = function(playerId, argMsg, levelConfig, command, failCmd)
	net.send_chat_to("Enter password >> ",playerId)

	local inputHandler = function(inPlayerId, message)
		if net.check_password(message, levelConfig.passwordHash) then

			local passwordScope = MPCMD.passwordScope.PER_SESSION

			if levelConfig.passwordScope then
				passwordScope = levelConfig.passwordScope
			end

			MPCMD.promotePlayer(inPlayerId, command.level, passwordScope)
				
			return "", MPCMD.execCommand(inPlayerId, argMsg, command)

		else
			if failCmd then
				return "", MPCMD.execCommand(inPlayerId, argMsg, {exec = failCmd})
			end
		end
		return "", nil
	end

	return inputHandler
end

---------------------------------------------------------------------
-- COMMAND LOADING

--[[ 
MPCMD.execOnFiles

Execute a function on each file in a folder

Args:
	path (string)
Returns:
	nil
]]
MPCMD.execOnFiles = function(path, func)
	for relpath in lfs.dir(path) do
		if relpath ~= "." and relpath ~= ".." then

			local fullpath = path .. "/" .. relpath

			local attr = lfs.attributes(fullpath)

			if type(attr) == "table" and attr.mode == "file" then
				MPCMD.safeCall(func, fullpath)
			end
		end
	end

end

--[[ 
MPCMD.loadCommandFolder

Load commands from all files in a specified directory

Args:
	path (string)
Returns:
	nil
]]
MPCMD.loadCommandFolder = function(path)

	MPCMD.execOnFiles(path, MPCMD.loadCommandFile)
end

--[[ 
MPCMD.loadCommandFile

Load command from a single file

Args:
	path (string)
Returns:
	nil
]]
MPCMD.loadCommandFile = function(path)
	MPCMD.Logging.log("Loading command file "..path)

	MPCMD.cmd = nil

	MPCMD.safeCall(function() return dofile(path) end)

	local obj = MPCMD.cmd
	-- validation

	if not obj then 
		MPCMD.Logging.log("Failed to load command file "..path)
		return
	end

	if type(obj) ~= "table" or type(obj.cmd) ~= "string" or type(obj.exec) ~= "function" or type(obj.level) ~= "number"  then
		MPCMD.Logging.log("Command file return invalid: "..path .. " returned " ..   MPCMD.Serialization.obj2str(obj))
		return
	end

	-- sanitize cmd
	obj.cmd = string.lower(string.gsub(obj.cmd,"%s",""))

	if MPCMD.commands[obj.cmd]  then
		MPCMD.Logging.log("Command ".. obj.cmd .. " already registered.")
		return
	end

	MPCMD.commands[obj.cmd] = {level = obj.level, exec = obj.exec, cmd = obj.cmd, help = obj.help, help2 = obj.help2}
end

--[[ 
MPCMD.loadMissionInjectFolder

Load scripts to inject from all files in a specified directory

Args:
	path (string)
Returns:
	nil
]]
MPCMD.loadMissionInjectFolder = function(path)
	MPCMD.execOnFiles(path, MPCMD.injectMissionScript)
end

--[[ 
MPCMD.injectMissionScript

Load content of specified file and execute it in the mission environment

Args:
	filepath (string)
Returns:
	nil
]]
MPCMD.injectMissionScript = function(filepath)
	
	local file = assert(io.open(filepath, "r"))
	local injectContent = file:read("*all")
    file:close()

	local execString = 
	[[
		a_do_script("]] .. MPCMD.Serialization.escapeLuaString(injectContent) .. [[")
	]]

	net.dostring_in(MPCMD.scrEnvMission, execString)


end

--------------------------------------------------------------
-- CALLBACK EXECUTABLES

MPCMD.doOnMissionLoadEnd = function()
	MPCMD.Logging.log("Mission "..DCS.getMissionName().." loaded")

	MPCMD.loadConfiguration()

	for _,v in ipairs(MPCMD.commandFileDirs) do
		MPCMD.loadCommandFolder(v)
	end

	for _,v in ipairs(MPCMD.missionInjectDirs) do
		MPCMD.loadMissionInjectFolder(v)
	end

	MPCMD.sessions = {} -- Don't carry sessions between missions

end

MPCMD.doOnPlayerConnect = function(id)

	--MPCMD.loadConfiguration()

	local name = MPCMD.getPlayerName(id)
	local ucid = tostring(MPCMD.getPlayerUcid(id))

	-- Adds username to user config and re-syncs to config file
	MPCMD.setUserConfig(id, MPCMD.config.users[ucid])
	
	MPCMD.Logging.log({["Player connected"] = name, ["Player ID"]=id, ["UCID"]=ucid})

	net.send_chat_to("MPCMD " .. _MpcmdVersion .. " running on this server. Type \"cmd\" in chat to start a session. Chat \"help\" during a session to list commands available to you.",id)
end

MPCMD.doOnPlayerDisconnect = function(id)
	
	MPCMD.Logging.log("Player disconnected. Player ID: ".. id)

	MPCMD.playerMap[id] = nil
	MPCMD.sessions[id] = nil
end

MPCMD.doOnPlayerTrySendChat = function(playerId, message)

	local session = MPCMD.sessions[playerId] 

	local result

	--if session then result = "" end -- consume chat messages during a session (even invalid commands)
	----------------------------------------------

	if session then
		local newHandler

		if session.handler then
			result, newHandler = MPCMD.safeCall(session.handler, playerId, message)
		else
			result, newHandler = MPCMD.safeCall(MPCMD.defaultSessionHandler, playerId, message)
		end

		if (not newHandler) and MPCMD.sessions[playerId] then -- When a command completes (but still within a session)
			net.send_chat_to(">>",playerId)
		end

		MPCMD.setSessionNextHandler(playerId, newHandler)
	else
		result, _ = MPCMD.safeCall(MPCMD.nonSessionHandler, playerId, message)
	end

	if type(result) ~= "string" then result = "" end
	
	return result
end

--------------------------------------------------------------
-- CALLBACKS

MPCMD.Handlers = {

	handlingPlayerTrySendChat = false -- semaphore to prevent recursive calls to onPlayerTrySendChat
}

MPCMD.Handlers.onMissionLoadEnd = function()
	if not DCS.isServer() or not DCS.isMultiplayer() then return end
	MPCMD.safeCall(MPCMD.doOnMissionLoadEnd)
end
 
MPCMD.Handlers.onPlayerConnect = function(id)
	if not DCS.isServer() or not DCS.isMultiplayer() then return end
	MPCMD.safeCall(MPCMD.doOnPlayerConnect,id)
end

MPCMD.Handlers.onPlayerDisconnect = function(id)
	if not DCS.isServer() or not DCS.isMultiplayer() then return end
	MPCMD.safeCall(MPCMD.doOnPlayerDisconnect,id)
end

MPCMD.Handlers.onPlayerTrySendChat = function(playerId, message)
	if not DCS.isServer() or not DCS.isMultiplayer() then return message end

	local result = message
	if not MPCMD.Handlers.handlingPlayerTrySendChat then -- prevent recursive calls
		MPCMD.Handlers.handlingPlayerTrySendChat = true

		result = MPCMD.safeCall(MPCMD.doOnPlayerTrySendChat, playerId, message)

		MPCMD.Handlers.handlingPlayerTrySendChat = false
	end

	return result 
end

--------------------------------------------------------------
-- Create default commands

--[[ 
MPCMD.cmdSessionStarted

Command function executed at cmd session start. Note that session creation is automatic, so this method just informs the player of session start and does logging.

Args:
	playerId (number)
Returns:
	nil
]]
MPCMD.cmdSessionStarted = function(playerId)

	net.send_chat_to("|| MPCMD session start >>",playerId)

	MPCMD.Logging.log("Start cmd session for player " .. playerId)

	return nil

end

--[[ 
MPCMD.cmdEndSession

Command function to end a cmd session for a single player.

Args:
	playerId (number)
Returns:
	nil
]]
MPCMD.cmdEndSession = function(playerId)

	MPCMD.stopSession(playerId)

	net.send_chat_to("<< MPCMD session end ||",playerId)

	MPCMD.Logging.log("End cmd session for player " .. playerId)

	return nil
end

--[[ 
MPCMD.cmdHelp

Command function to ist registered commands to a player.

Args:
	playerId (number)
Returns:
	nil
]]
MPCMD.cmdHelp = function(playerId, argMsg)

	local command, cmd

	if argMsg then
		command, cmd, _ = MPCMD.splitCommand (argMsg)
	end

	local helpStr 

	if command then
		helpStr = cmd .. " : "

		if command.help then
			helpStr = helpStr .. command.help .. " : "
		end

		if command.help2 then
			helpStr = helpStr .. command.help2
		end

		net.send_chat_to(helpStr,playerId)
	else
		for k,v in pairs(MPCMD.commands) do

			if type(k) == "string" then 
				helpStr = k
				if type(v.help) == "string" then
					helpStr = helpStr .. " : " .. v.help
				end

				net.send_chat_to(helpStr,playerId)
			end

		end
	end

	return nil

end

--------------------------------------------------------------
-- REGISTER DEFAULT COMMANDS

MPCMD.commands = {
	["cmd"] = {level = 1, exec = MPCMD.cmdSessionStarted, help = "Start mpcmd session.", nonSession = true} -- TODO: make the levels for these commands configurable
	, ["q"] = {level = 0, exec = MPCMD.cmdEndSession, help = "Quit mpcmd session.", noRateLimit = true}
	, ["help"] = {level = 1,exec = MPCMD.cmdHelp, help = "Show command reference. Use help <command> for details on a single command.", help2 = " Args: <command> (optional) \n Example: help flagl \n List commands or give details on a single command."}
}

--------------------------------------------------------------
-- START EVENT HANDLERS
 
MPCMD.loadConfiguration() -- Load config before any handler may be called

DCS.setUserCallbacks(MPCMD.Handlers)

--------------------------------------------------------------
-- END MODULE LOAD
net.log("MPCMD " .. _MpcmdVersion  .. " loaded")
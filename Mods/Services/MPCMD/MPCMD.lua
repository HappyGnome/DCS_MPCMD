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

--TODO: example of password hashing

hash = net.hash_password("Pass")
MPCMD.Logging.log(hash)
if net.check_password("Pass",hash) then
	MPCMD.Logging.log("match")
else
	MPCMD.Logging.log("no match")
end

if net.check_password("Fail",hash) then
	MPCMD.Logging.log("match")
else
	MPCMD.Logging.log("no match")
end
--------------------------------
package.path = package.path .. [[;]] .. lfs.writedir() .. [[Mods\Services\MPCMD\?.lua;]]

require([[MPCMD_serialization]])
require([[MPCMD_logging]])

MPCMD.Logging.log("MPCMD " .. _MpcmdVersion  .. " loading...")

if MPCMD == nil then
	MPCMD = {}
end

MPCMD.passwordScope =
{
	PER_SESSION = 1
	,PER_USER = 2
}

MPCMD.config = {["users"] = { --[[ [ucid]={level = n, lastSeenUsername = k} ]]},["levels"] = { --[[ [level] = { password = "plaintext", passwordHash = "hashed", passwordScope = n } ]] }}
MPCMD.commandFileDirs = {lfs.writedir()..[[Mods\Services\MPCMD\CoreCommands]] , lfs.writedir()..[[Mods\Services\MPCMD\AddonCommands]]}
MPCMD.commands = {}
MPCMD.sessions = {}
MPCMD.playerMap = {} -- key = playerId, value = value of config.users[ucid] for the player's ucid
MPCMD.config_loaded = false

if  MPCMD.Handlers ~= nil then
	for k,v in pairs(MPCMD.Handlers) do -- Set event handlers to nil when re-including
		MPCMD.Handlers[k] = nil
	end
end


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
	
	MPCMD.saveConfiguration()

	MPCMD.config_loaded = true
end

MPCMD.saveConfiguration = function()
    U.saveInFile(MPCMD.config, 'config', lfs.writedir()..'Config/MPCMD.lua')
end


--------------------------------------------------------------

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

MPCMD.splitCommand = function(str)
	local tok,argMsg = MPCMD.splitToken(str)

	if not tok then return nil, nil end

	tok = string.upper(tok)

	return MPCMD.commands[tok], argMsg
end
--------------------------------------------------------------
MPCMD.getPlayerUcid = function(id)
	if DCS.isServer() then 
		local ucid = net.get_player_info(id, 'ucid')
		if not ucid  then ucid  = '??' end
		return ucid
	end
	return "??"	
end

MPCMD.getPlayerName = function(id)
	local name = net.get_player_info(id, 'name')
	if not name then name = '??' end
	return name
end

-- Set a new user config for the identified player
-- Adds some additional detail to the config
-- Saves the config
MPCMD.setUserConfig = function(playerId, userConfig)

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

--------------------------------------------------------------
-- CMD session handler

-- result, session.handler = session.handler(playerId, message)
MPCMD.defaultSessionHandler = function(playerId, message)
	-- local tok,argMsg = MPCMD.splitToken(message)

	-- if not tok then return result end

	-- tok = string.upper(tok)

	-- local command = MPCMD.commands[tok]
	-- if (not command) or (command.exec == nil) then 

	-- 	if session then
	-- 		net.send_chat_to("Command not recognized.",playerId)
	-- 	end
	-- 	return result 
	-- end

	-- -- Check session vs non session for the right place to exec this command
	-- -- In either case get user permissions

	-- if command.nonSession then

	-- 	if session then
	-- 		net.send_chat_to("Command not valid here.",playerId)
	-- 		return result 
	-- 	end
		
	-- elseif not session then 
	-- 	return result 
	-- end

	-- -- message is confirmed a command in this context - suppress sending to others
	-- result = ""

	-- -- MPCMD.Logging.log(permissions)

	-- if not MPCMD.AllowCommand(command, playerId) then
	-- 	net.send_chat_to("You do not have permission to use this command.",playerId)
	-- 	return result 
	-- end
	
	-- if command.exec(playerId, argMsg) then
	-- 	net.send_chat_to(">>",playerId)
	-- end

	-- return result
end

MPCMD.nonSessionHandler = function(playerId, message)

	local command, argMsg = MPCMD.splitCommand(message)

	if (not command) or (command.exec == nil) or (not command.nonSession) then 
		return message, nil
	end
	
	command.exec(playerId, argMsg) -- TODO add option to change a handler (or just make CMD a command for all > starts a session > prompt for auth - exit session on auth fail)

	return "", nil
end
--------------------------------------------------------------
-- CALLBACK EXECUTABLES

-- MPCMD.doOnMissionLoadBegin = function()
-- 	MPCMD.loadConfiguration()

-- 	MPCMD.Logging.log("Mission "..DCS.getMissionName().." loading")
-- end

MPCMD.doOnMissionLoadEnd = function()
	MPCMD.Logging.log("Mission "..DCS.getMissionName().." loaded")

	MPCMD.loadConfiguration()

	for _,v in ipairs(MPCMD.commandFileDirs) do
		MPCMD.loadCommandFolder(v)
	end

	-- if MPCMD.config.restarts then

	-- 	local secondsInWeek = os.time()%604800;
	-- 	MPCMD.nextRestart = nil

	-- 	--config.restarts = [{weekday = n,hour = m, minute = 0},...]
	-- 	-- weekday = 1 for Sunday
	-- 	for k,v in pairs(MPCMD.config.restarts) do
	-- 		local secondsInWeekRestart = ((v.weekday + 2)%7) * 86400 -- Epoch was a Thursday, v.weekday = 5 for Thursday
	-- 		if v.hour then
	-- 			secondsInWeekRestart = secondsInWeekRestart + (v.hour%24)*3600
	-- 			if v.minute then
	-- 				secondsInWeekRestart = secondsInWeekRestart + (v.minute%60) * 60
	-- 			end
	-- 		end
	-- 		if secondsInWeekRestart<secondsInWeek then secondsInWeekRestart = secondsInWeekRestart + 604800 end
	-- 		if MPCMD.nextRestart == nil or secondsInWeekRestart < MPCMD.nextRestart then
	-- 			MPCMD.nextRestart = secondsInWeekRestart
	-- 		end
	-- 	end	
	-- 	-- MPCMD.nextRestart is now correct relative to week start
	-- 	if MPCMD.nextRestart then
	-- 		MPCMD.nextRestart = MPCMD.nextRestart + os.time() - secondsInWeek
	-- 		net.dostring_in('server','trigger.action.outText(\"Mission scheduled to run until '.. os.date('%c',MPCMD.nextRestart) ..'\",10)')
	-- 	end
	-- end
end


MPCMD.loadCommandFolder = function(path)
	for relpath in lfs.dir(path) do
		if relpath ~= "." and relpath ~= ".." then

			local fullpath = path .. "/" .. relpath

			local attr = lfs.attributes(fullpath)

			if type(attr) == "table" and attr.mode == "file" then
				MPCMD.safeCall(MPCMD.loadCommandFile, fullpath)
			end
		end
	end
end

MPCMD.loadCommandFile= function(path)
	MPCMD.Logging.log("Loading command file "..path)

	local obj = dofile(path)

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
	obj.cmd = string.upper(string.gsub(obj.cmd,"%s",""))

	if MPCMD.commands[obj.cmd]  then
		MPCMD.Logging.log("Command ".. obj.cmd .. " already registered.")
		return
	end

	MPCMD.commands[obj.cmd] = {level = obj.level, exec = obj.exec}
end

MPCMD.doOnPlayerConnect = function(id)

	--MPCMD.loadConfiguration()

	-- Adds username to user config and re-syncs to config file
	MPCMD.setUserConfig( MPCMD.config.users[ucid], id)

	local name = MPCMD.getPlayerName(id)
	local ucid = tostring(MPCMD.getPlayerUcid(id))
	
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
		if session.handler then
			result, session.handler = session.handler(playerId, message)
		else
			result, session.handler = MPCMD.defaultSessionHandler(playerId, message) -- TODO
		end
	else
		result, session.handler = MPCMD.nonSessionHandler(playerId, message) -- TODO
	end

	return result
end

MPCMD.AllowCommand = function(command,playerId)

	if (not command) or (not command.level) then return false end

	local requiredLevel = command.level

	local userLevel
	local session = MPCMD.sessions[playerId] 
	local userConfig = MPCMD.playerMap[playerId]

	if session then 
		userLevel = session.level
	elseif userConfig  then	
		userLevel = userConfig.level
	end

	if type(userLevel) ~= "number" then
		userLevel = 0
	end
		
	if requiredLevel <= userLevel then return true end

	-- Check whether user can escalate with a password
	local levelPassword = MPCMD.levels[requiredLevel]

	if levelPassword and MPCMD.PromptPassword(playerId, levelPassword.passwordHash) then

		if levelPassword.passwordScope == MPCMD.passwordScope.PER_SESSION then

			session.level = requiredLevel

		elseif levelPassword.passwordScope == MPCMD.passwordScope.PER_USER then

			if not userConfig then
				userConfig = {}
			end

			userConfig.level = requiredLevel

			-- Complete user config and save
			MPCMD.setUserConfig(playerId, userConfig)
		end

		return true
	end

	return false
end

MPCMD.PromptPassword = function(playerId, hashedPassword)
	net.send_chat_to("Enter password >>",playerId)
end

--------------------------------------------------------------
-- CALLBACKS

MPCMD.Handlers = {

	handlingPlayerTrySendChat = false -- semaphore to prevent recursive calls to onPlayerTrySendChat
}

-- MPCMD.Handlers.onMissionLoadBegin = function()
-- 	if not DCS.isServer() or not DCS.isMultiplayer() then return end
-- 	MPCMD.safeCall(MPCMD.doOnMissionLoadBegin)
-- end

MPCMD.Handlers.onMissionLoadEnd = function()
	if not DCS.isServer() or not DCS.isMultiplayer() then return end
	MPCMD.safeCall(MPCMD.doOnMissionLoadEnd)
end

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
DCS.setUserCallbacks(MPCMD.Handlers)


--------------------------------------------------------------
-- Create default commands

--[[
Return true to halt chat message processing.
]]
MPCMD.cmdStartSession = function(playerId)
	local level

	if MPCMD.playerMap ~= nil and MPCMD.playerMap[playerId] ~= nil then
		level = MPCMD.playerMap[playerId].level
	end

	MPCMD.sessions[playerId] = {sessionStart = os.date("%H:%M:%S"), level = level}
	net.send_chat_to("<< MPCMD session start >>",playerId)

	MPCMD.Logging.log("Start cmd session for player " .. playerId)

	return true

end

-- MPCMD.cmdEndSession
MPCMD.cmdEndSession = function(playerId)

	MPCMD.sessions[playerId] = nil

	net.send_chat_to("<< MPCMD session end >>",playerId)

	MPCMD.Logging.log("End cmd session for player " .. playerId)

	return false
end

-- MPCMD.cmdHelp
MPCMD.cmdHelp = function(playerId)

	for k,v in pairs(MPCMD.commands) do
		if  MPCMD.AllowCommand(v, playerId) then

			if type(k) == "string" then 
				local helpStr = k
				if type(v.help) == "string" then
					helpStr = helpStr .. " : " .. v.help
				end

				net.send_chat_to(helpStr,playerId)
			end
		end
	end

	return true

end

MPCMD.commands = {
	["CMD"] = {level = 1, exec = MPCMD.cmdStartSession, help = "Start mpcmd session.", nonSession = true}
	, ["X"] = {level = 1,exec = MPCMD.cmdEndSession, help = "Quit mpcmd session."}
	, ["HELP"] = {level = 1,exec = MPCMD.cmdHelp, help = "Show command reference."}
}

net.log("MPCMD " .. _MpcmdVersion  .. " loaded")
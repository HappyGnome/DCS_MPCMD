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

if MPCMD == nil then
	MPCMD = {}
end

MPCMD.passwordScope =
{
	PER_SESSION = 1
	,PER_USER = 2
}

MPCMD.config = {["users"] = { --[[ [ucid]={level = n, lastSeenUsername = k} ]]},["levels"] = { --[[ [level] = { password = "plaintext", passwordHash = "hashed", passwordScope = n } ]] }, ["options"] = {rateLimitCount = 10, rateLimitSeconds = 60}}
MPCMD.commandFileDirs = {lfs.writedir()..[[Mods\Services\MPCMD\CoreCommands]] , lfs.writedir()..[[Mods\Services\MPCMD\AddonCommands]]}
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


-----------------------------------------------------------
-- CONFIG & UTILITY

 -- TODO fix issue with forgetting user permissions between games.
 -- TODO dofile not working

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
		if v.password then
			v.passwordHash = net.hash_password(v.password)
		end
		v.password = nil

		MPCMD.config.levels[k] = v
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

	tok = string.lower(tok)

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
--------------------------------------------------------------
-- CMD session handler

-- result, session.handler = session.handler(playerId, message)
MPCMD.defaultSessionHandler = function(playerId, message)

	local command, argMsg = MPCMD.splitCommand(message)

	if (not command) or (command.exec == nil) or (command.nonSession) or (type(command.level) ~= "number") then 
		net.send_chat_to("Command not recognized",playerId)
		return "", nil
	end

	if (not command.noRateLimit) and MPCMD.blockForRate(playerId) then return "", nil end

	local levelConfig = MPCMD.config.levels[command.level]

	if MPCMD.getCurrentPlayerLevel(playerId) >= command.level then

		return "", command.exec(playerId, argMsg)

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

MPCMD.startSession = function(playerId, chatHandlerOverride)
	local level

	if MPCMD.playerMap ~= nil and MPCMD.playerMap[playerId] ~= nil then
		level = MPCMD.playerMap[playerId].level
	end

	MPCMD.sessions[playerId] = {sessionStart = os.date("%H:%M:%S"), level = level, handler = chatHandlerOverride}
end

MPCMD.stopSession = function(playerId)
	MPCMD.sessions[playerId] = nil
end

MPCMD.setSessionNextHandler = function(playerId, chatHandlerOverride)

	if type( chatHandlerOverride) ~= "function" then
		chatHandlerOverride = nil
	end

	if MPCMD.sessions[playerId] then
		MPCMD.sessions[playerId].handler = chatHandlerOverride
	end
end

MPCMD.nonSessionHandler = function(playerId, message)

	local command, argMsg = MPCMD.splitCommand(message)

	if (not command) or (command.exec == nil) or (not command.nonSession) or (type(command.level) ~= "number") then 
		return message, nil
	end

	if (not command.noRateLimit) and MPCMD.blockForRate(playerId) then return "", nil end

	local levelConfig = MPCMD.config.levels[command.level]

	if MPCMD.getCurrentPlayerLevel(playerId) >= command.level then

		MPCMD.startSession(playerId)
		
		MPCMD.setSessionNextHandler(playerId, command.exec(playerId, argMsg)) -- Simulate command being executed from within a session (this is what happens if a password is required first)

	elseif levelConfig and levelConfig.passwordHash then

		local failCmd = function(id,msg)
			MPCMD.stopSession(id)

			net.send_chat_to("Password incorrect",id)

			return nil
		end
		
		MPCMD.startSession(playerId, MPCMD.makePasswordHandler(playerId, argMsg,  levelConfig, command, failCmd))
	else
		net.send_chat_to("Unauthorized",playerId)
	end

	return "", nil
end

MPCMD.makePasswordHandler = function(playerId, argMsg, levelConfig, command, failCmd)
	net.send_chat_to("Enter password >> ",playerId)

	local inputHandler = function(inPlayerId, message)
		if net.check_password(message, levelConfig.passwordHash) then

			local passwordScope = MPCMD.passwordScope.PER_SESSION

			if levelConfig.passwordScope then
				passwordScope = levelConfig.passwordScope
			end

			MPCMD.promotePlayer(playerId, command.level, passwordScope)

			if command.exec then
				return command.exec(inPlayerId, argMsg)
			end

		else
			if failCmd then
				return failCmd(inPlayerId, argMsg)
			end
		end
		return "", nil
	end

	return inputHandler
end

MPCMD.promotePlayer = function (playerId, newLevel, scope)
	
	if MPCMD.getCurrentPlayerLevel(playerId) > newLevel then return end

	if scope == MPCMD.passwordScope.PER_SESSION and MPCMD.sessions[playerId] then

		MPCMD.sessions[playerId].level = newLevel

	elseif scope == MPCMD.passwordScope.PER_USER then

		local userConfig = MPCMD.playerMap[playerId]

		if not userConfig then
			userConfig = {}
		end

		userConfig.level = newLevel

		-- Complete user config and save
		MPCMD.setUserConfig(playerId, userConfig)
	end

end

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
---------------------------------------------------------------------
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

	MPCMD.commands[obj.cmd] = {level = obj.level, exec = obj.exec}
end

--------------------------------------------------------------
-- CALLBACK EXECUTABLES

MPCMD.doOnMissionLoadEnd = function()
	MPCMD.Logging.log("Mission "..DCS.getMissionName().." loaded")

	MPCMD.loadConfiguration()

	for _,v in ipairs(MPCMD.commandFileDirs) do
		MPCMD.loadCommandFolder(v)
	end

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

		if newHandler then -- TODO
			MPCMD.Logging.log("handler set")
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

-- MPCMD.Handlers.onMissionLoadBegin = function()
-- 	if not DCS.isServer() or not DCS.isMultiplayer() then return end
-- 	MPCMD.safeCall(MPCMD.doOnMissionLoadBegin)
-- end

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
MPCMD.loadConfiguration()

DCS.setUserCallbacks(MPCMD.Handlers)


--------------------------------------------------------------
-- Create default commands

--[[
Return true to halt chat message processing.
]]
MPCMD.cmdSessionStarted = function(playerId)

	net.send_chat_to("<< MPCMD session start >>",playerId)

	MPCMD.Logging.log("Start cmd session for player " .. playerId)

	return nil

end

-- MPCMD.cmdEndSession
MPCMD.cmdEndSession = function(playerId)

	MPCMD.stopSession(playerId)

	net.send_chat_to("<< MPCMD session end >>",playerId)

	MPCMD.Logging.log("End cmd session for player " .. playerId)

	return nil
end

-- MPCMD.cmdHelp
MPCMD.cmdHelp = function(playerId)

	for k,v in pairs(MPCMD.commands) do

		if type(k) == "string" then 
			local helpStr = k
			if type(v.help) == "string" then
				helpStr = helpStr .. " : " .. v.help
			end

			net.send_chat_to(helpStr,playerId)
		end

	end

	return nil

end

MPCMD.commands = {
	["cmd"] = {level = 1, exec = MPCMD.cmdSessionStarted, help = "Start mpcmd session.", nonSession = true}
	, ["x"] = {level = 0, exec = MPCMD.cmdEndSession, help = "Quit mpcmd session.", noRateLimit = true}
	, ["help"] = {level = 1,exec = MPCMD.cmdHelp, help = "Show command reference."}
}

net.log("MPCMD " .. _MpcmdVersion  .. " loaded")
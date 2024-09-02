-- To be injected into the mission scripting environment from the server by MPCMD
-- Defines functions to print MPCMD-registered flags to one player (assuming they occupy a unit)
-- Required for cmdPrintFlags and cmdSetFlag

if not MPCMD then
    MPCMD = {}
end

if not MPCMD.Common then
    env.error("MPCMD FlagTools: MPCMD.common required",false)
    return
end

if not MPCMD.Flags then
    MPCMD.Flags = {}
end


--------------------------------------------------------------
-- Callbacks for MPCMD commands

--[[
MPCMD.cmdFlagList

Display list of registered flags to the named player (if they are in a unit)

Args:	
	- playername - string 
Returns: 
    nil
]]
MPCMD.cmdFlagList = function(playerName)

    local message = {[1] = "MPCMD flags:"}

    for k,v in pairs(MPCMD.Flags) do
        local description = v.description
        if not description then
            description = ""
        end
        local currentValue = trigger.misc.getUserFlag(v.flag)
        if currentValue ~= nil then
            description = "(" .. currentValue .. ") - " .. description
        end
        message[#message + 1] =  k .. " - " .. description
    end
    MPCMD.Common.outTextForPlayer (playerName, message)
end

--[[
MPCMD.cmdSetFlag

Update value of a registered flag

Args:	
	- playerName - string
    - flagAlias - string or int 
    - newValue - number
Returns: 
    nil
]]
MPCMD.cmdSetFlag = function(playerName, flagAlias, newValue)

    if not flagAlias then
        return
    end

    local flagData = MPCMD.Flags[flagAlias]
    local err 

    if not flagData then
        err = "Flag " .. flagAlias .. " not found or not registered."
        env.error("MPCMD.cmdSetFlag: " .. err,false)

        MPCMD.Common.outTextForPlayer (playerName, err)
        return
    end
    
    if type(newValue) ~= "number" then
        err = "Flag value must be a number"
        env.error("MPCMD.cmdSetFlag: " .. err,false)

        MPCMD.Common.outTextForPlayer (playerName, err)
        return
    end

    trigger.action.setUserFlag(flagData.flag , newValue)

    MPCMD.Common.outTextForPlayer (playerName, "Flag " .. flagAlias .. " set to " .. newValue)

end

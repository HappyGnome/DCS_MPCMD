-- To be injected into the mission scripting environment from the server by MPCMD
-- Defines functions to print MPCMD-registered flags to one player (assuming they occupy a unit)
-- Required for cmdPrintFlags and cmdSetFlag

if not MPCMD then
    MPCMD = {}
end

if not MPCMD.flags then
    MPCMD.flags = {}
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

    local unitID = MPCMD.getPlayerUnitID(playerName)

    if not unitID then
        env.error("MPCMD.cmdFlagList: Player unit not found",false)
        return
    end
    local displaySeconds = 10

    trigger.action.outTextForUnit(unitID, "MPCMD flags:",displaySeconds,true)

    for k,v in pairs(MPCMD.flags) do
        local description = v.description
        if not description then
            description = ""
        end
        local currentValue = trigger.misc.getUserFlag(v.flag)
        if currentValue ~= nil then
            description = "(" .. currentValue .. ") " .. description
        end

        trigger.action.outTextForUnit(unitID, k .. " - " .. description,displaySeconds,false)
    end
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

    local flagData = MPCMD.flags[flagAlias]

    if not flagData then
        env.error("MPCMD.cmdSetFlag: Flag " .. flagAlias .. " not found or not registered.",false)
        return
    end
    
    if type(newValue) ~= "number" then
        env.error("MPCMD.cmdSetFlag: New value must be a number",false)
        return
    end

    trigger.action.setUserFlag(flagData.flag , newValue)

    local unitID = MPCMD.getPlayerUnitID(playerName)

    if not unitID then
        return
    end

    trigger.action.outTextForUnit(unitID, "Flag " .. flagAlias .. " set to " .. newValue,10,false)

end

--------------------------------------------------------------
-- Common methods

--[[
MPCMD.cmdShowFlagtoUnit

Get unit ID occupied by a given player

Args:	
	- playername - string 
Returns: 
    nil
]]
MPCMD.getPlayerUnitID = function(playerName)

    if not playerName then
        env.error("MPCMD.getPlayerUnitID: Invalid player name",false)
        return nil
    end

    local units = {}

    for _,coa in pairs(coalition.side) do
        units = coalition.getPlayers(coa) 

        for k, v in pairs(units) do
            if v:getPlayerName() == playerName then      
                return v:getID()
            end
        end 
    end

    return nil
end
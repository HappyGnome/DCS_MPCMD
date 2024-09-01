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
-- Flag registration API


--[[
MPCMD.registerFlag

Add a mission scripting flag that can be set via MPCMD

Args:	
	- flagname - (string or int) - matches the identity of the flag in mission scripting
    - description - string - shown to the MPCMD user when listing flags
    - alias - string (optional) - this is the value entered into MPCMD to interact with the flag
Returns: 
    nil
]]
MPCMD.registerFlag = function(flagname, description, alias)

    if not flagname then
        env.error("MPCMD.registerFlag: Invalid flag name",false)
        return
    end

    if not alias then
        alias = flagname
    end

    if MPCMD.flags[alias] and MPCMD.flags[alias] ~= flagname then
        env.error("MPCMD.registerFlag: Changing flag name for an alias is not permitted",false)
        return
    end
    
    MPCMD.flags[alias] = {flag = flagname, description = description}
end

--------------------------------------------------------------
-- Callbacks for MPCMD commands

--[[
MPCMD.cmdShowflags

Display list of registered flags to the named player (if they are in a unit)

Args:	
	- playername - string 
Returns: 
    nil
]]
MPCMD.cmdShowflags = function(playerName)

    local unitID = MPCMD.getPlayerUnitID(playerName)

    if not unitID then
        env.error("MPCMD.cmdShowflags: Player unit not found",false)
        return
    end
    local displaySeconds = 10

    trigger.action.outTextForUnit(unitID, "MPCMD flags:",displaySeconds,true)

    for k,v in pairs(MPCMD.flags) do
        local description = v.description
        if not description then
            description = ""
        end
        trigger.action.outTextForUnit(unitID, k .. " - " .. description,displaySeconds,false)
    end
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


    --env.error("Player name " .. playerName ,false)       -- TODO 
    if not playerName then
        env.error("MPCMD.getPlayerUnitID: Invalid player name",false)
        return nil
    end

    local units = {}

    --env.error("Coa.BLUE: " .. coalition.side.BLUE ,false)       -- TODO 

    for _,coa in pairs(coalition.side) do
        units = coalition.getPlayers(coa)
        --env.error("Coa: " .. coa ,false)       -- TODO     

        for k, v in pairs(units) do
            if v:getPlayerName() == playerName then   
                --env.error(v:getID(),false)       -- TODO      
                return v:getID()
            end
        end 
    end

    return nil
end
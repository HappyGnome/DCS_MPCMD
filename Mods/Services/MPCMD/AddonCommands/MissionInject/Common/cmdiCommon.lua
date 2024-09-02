-- To be injected into the mission scripting environment from the server by MPCMD
-- Defines functions common functionality to inject

if not MPCMD then
    MPCMD = {}
end

if not MPCMD.Common then
    MPCMD.Common = {}
end

--------------------------------------------------------------
-- Common methods

--[[
MPCMD.Common.safeDoString

Get unit ID occupied by a given player

Args:	
	- playername - string 
Returns: 
    nil
]]
MPCMD.Common.safeDoString = function(strLua)
    
    local catchError=function(err)
        env.error("MPCMD.Common.safeDoString" .. err,false)
    end 

    local func = function()
        local chunk = assert(loadstring(strLua))
        return chunk()
    end

    xpcall(func, catchError)
end

--[[
MPCMD.Common.getPlayerUnitID

Get unit ID occupied by a given player

Args:	
	- playername - string 
Returns: 
    nil
]]
MPCMD.Common.getPlayerUnitID = function(playerName)

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

--[[
MPCMD.Common.outTextForPlayer

Attempt to print a message to a player, assuming the player is in a unit

Args:	
	- playerName - string 
    - message - string
Returns: 
    nil
]]
MPCMD.Common.outTextForPlayer = function(playerName, message)

    local unitID = MPCMD.Common.getPlayerUnitID(playerName)

    if not unitID then
        env.error("MPCMD.outTextForPlayer: Player unit not found",false)
        return
    end

    if type(message) =="string" then
        trigger.action.outTextForUnit(unitID, message,10,false)
    elseif type(message) == "table" then
        for _,v in ipairs(message) do
            trigger.action.outTextForUnit(unitID, v,10,false)  
        end
    end 

end
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

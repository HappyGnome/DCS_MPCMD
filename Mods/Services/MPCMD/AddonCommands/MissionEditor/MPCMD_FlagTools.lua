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

-- MPCMD_FlagTools.lua

-- To be included into the mission scripting environment by the mission maker, before registering flags for interaction with MPCMD


if not MPCMD then
    MPCMD = {}
end

if not MPCMD.Flags then
    MPCMD.Flags = {}
end

--------------------------------------------------------------
-- Flag registration API


--[[
MPCMD.registerFlag

Add a mission scripting flag that can be viewed and set via MPCMD

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

    local spcAt, _ = string.find(alias,"[%s]")
    if spcAt ~= nil then
        env.error("MPCMD.registerFlag: Alias cannot contain spaces",false)
        return
    end

    if MPCMD.Flags[alias] and MPCMD.Flags[alias] ~= flagname then
        env.error("MPCMD.registerFlag: Changing flag name for an alias is not permitted",false)
        return
    end
    
    MPCMD.Flags[alias] = {flag = flagname, description = description}
end
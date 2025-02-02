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

MPCMD.cmd =
{
    --Requires cmdiFlagTools to be imported into the mission

    cmd = "flagl",

    help = "List flags",

    help2 = "A list of flag aliases to use with flagset appears on screen. Requires user to be in a unit.",

    level = 2,

    exec = function(playerId,argMsg, reply)

        local playerName = MPCMD.getPlayerName(playerId)

        if playerName then
            
            MPCMD.safeDoStringInMission([[MPCMD.cmdFlagList("]] .. MPCMD.Serialization.escapeLuaString(playerName) .. [[")]])

            reply.msg = "List on screen"
        end

        return nil -- no special handler
    end
}

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

    cmd = "flagset",

    help = "Update a registered flag.",

    help2 = " Args: <flag alias>, <new value> | Example: \"flagset f 2\" | See also command flagl",

    level = 2,

    exec = function(playerId,argMsg,reply)

        local playerName = MPCMD.getPlayerName(playerId)

        local tok1
        local tok2
        
        tok1, argMsg = MPCMD.splitToken(argMsg)
        tok2, argMsg = MPCMD.splitToken(argMsg)

        local flagValue = tonumber(tok2)

        if tok1 == nil then
            reply.err = "Flag alias not specified"
            return nil
        end

        if flagValue == nil then
            reply.err = "Flag value not specified"
            return nil
        end

        if playerName then

            playerName = MPCMD.Serialization.escapeLuaString(playerName)

            local tok1AsNum = tonumber(tok1)
            local flagAlias 
            if tok1AsNum  ~= nil then
                flagAlias = tok1AsNum
            else
                flagAlias = [["]] .. MPCMD.Serialization.escapeLuaString(tok1) .. [["]]
            end

            MPCMD.safeDoStringInMission([[MPCMD.cmdSetFlag("]] .. playerName .. [[",]] .. flagAlias .. [[,]] .. flagValue .. [[)]])

        end

        return nil -- no special handler
    end
}

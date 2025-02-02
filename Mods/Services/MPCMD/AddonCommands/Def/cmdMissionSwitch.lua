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
    cmd = "msnsw",

    help = "Switch to another mission in the server's queue",

    level = 2,

    exec = function(playerId,argMsg)
        local net = require('net')        

        local msnlRaw = net.missionlist_get().missionList

        local msnlRev = {}
        
        -- Removes duplicates
        for i,v in ipairs(msnlRaw) do
            if not msnlRev[v] then
                msnlRev[v]=i   
            end
        end

        local stripFileNameBody = function (strPath)
            local _,_, fname = string.find(strPath,"([^\\/:]*)$")
            if fname == nil or fname == "" then
                return 
            end

            if string.find(fname,"%.") then
                _,_,fname = string.find(fname,"(.*)%.[^%.]*$")
            end
            return fname
        end

        local msgStr = "Index : Mission Name"
        net.send_chat_to(msgStr,playerId)

		for k,v in pairs(msnlRev) do

			if type(k) == "string" then 
				msgStr = v .. " : " .. stripFileNameBody(k) 

                net.send_chat_to(msgStr,playerId)
			end

		end

        msgStr = "Select index (or 'q' to quit):"

        net.send_chat_to(msgStr,playerId)

        --[[ 
        Handler for the user's selection

        Args:
            playerId (number)
            message - raw chat message - (string)
        Returns:
            modified chat message to send (string)
            handler override for next chat from player (function - same spec as MPCMD.nonSessionHandler)
        ]]
        local followUpHandler = function(playerId, message)

            local indStr  = MPCMD.splitToken(message)

            if not indStr or indStr == 'q' then 
                return "",nil
            end

            local indSel = tonumber(indStr)

            if not indSel or not msnlRaw[indSel] then
                return "", nil
            end

            net.load_mission(msnlRaw[indSel])

            return "", nil
        end

        return followUpHandler
    end
}

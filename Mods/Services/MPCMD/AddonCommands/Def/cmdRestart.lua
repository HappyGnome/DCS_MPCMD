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
    cmd = "restart",

    help = "Restart the current mission",

    level = 2,

    exec = function(playerId,argMsg)
        local net = require('net')        

        net.load_mission(DCS.getMissionFilename())

        return nil -- no special handler
    end
}

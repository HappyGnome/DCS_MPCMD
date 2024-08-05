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

net.log("MPCMD Loader called")

local socket = require("socket")
local string = require("string")
local ltn12 = require("ltn12")
local tools = require('tools')
local os = require("os")
local U  = require('me_utilities')

local lfs=require('lfs');
package.path = package.path .. [[;]] .. lfs.writedir() .. [[Mods\Services\MPCMD\?.lua;]]

require([[MPCMD_logging]])

MPCMDLoader = {}

--------------------------------------------------------------
-- CALLBACKS

MPCMDLoader.onNetConnect = function()
  net.log("Calling MPCMD")
	MPCMD.safeCall (
    function() 
      local lfs=require('lfs');
      dofile(lfs.writedir()..[[Mods\Services\MPCMD\MPCMD.lua]]); 
    end
  )
end

--------------------------------------------------------------
DCS.setUserCallbacks(MPCMDLoader)


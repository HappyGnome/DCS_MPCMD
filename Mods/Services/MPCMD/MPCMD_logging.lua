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

require("MPCMD_serialization")

local string = require("string")
local os = require("os")
local lfs= require("lfs")

if MPCMD == nil then
    MPCMD = {}
end

MPCMD.Logging =
{
  logFile = io.open(lfs.writedir()..[[Logs\MPCMD.log]], "w")
}

MPCMD.Logging.changeFile = function(newFileName)
  if MPCMD.Logging.logFile then MPCMD.Logging.logFile:close() end
  MPCMD.Logging.logFile = io.open(lfs.writedir()..[[Logs\]]..newFileName, "w")
end

MPCMD.Logging.log = function(str, logFile, prefix)
  if not str and not prefix then 
      return
  end

  if not logFile then
    logFile = MPCMD.Logging.logFile
  end

  if logFile then
  local msg = ''
  if prefix then msg = msg..prefix end
  if str then
    if type(str) == 'table' then
      msg = msg..'{'
      for k,v in pairs(str) do
        local t = type(v)
        msg = msg..k..':'.. MPCMD.Serialization.obj2str(v)..', '
      end
      msg = msg..'}'
    else
      msg = msg..str
    end
  end
  logFile:write("["..os.date("%H:%M:%S").."] "..msg.."\r\n")
  logFile:flush()
  end
end

--error handler for xpcalls
MPCMD.Logging.catchError=function(err)
	MPCMD.Logging.log(err)
end 

MPCMD.safeCall = function(func,...)
	local op
  
	if arg then 
		op = function()
			return {func(unpack(arg))}
		end
  else
    op = function()
			return {func()}
		end
	end

  local err, res = xpcall(op,MPCMD.Logging.catchError)

  if type(res) == 'table' then
	  return unpack(res)
  else
    return nil
  end

end

  --Hook to load MPCMD
 local status, result = pcall(function() local dcsSr=require('lfs');dofile(dcsSr.writedir()..[[Mods\Services\MPCMD\init.lua]]); end,nil) 
 
 if not status then
 	net.log(result)
 end
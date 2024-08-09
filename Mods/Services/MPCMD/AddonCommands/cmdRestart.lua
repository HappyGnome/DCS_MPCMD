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

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

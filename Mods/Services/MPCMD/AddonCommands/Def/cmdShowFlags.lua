MPCMD.cmd =
{
    --Requires cmdiFlagTools to be imported into the mission

    cmd = "flagl",

    help = "List flags - requires user to be in a unit",

    level = 2,

    exec = function(playerId,argMsg)

        local playerName = MPCMD.getPlayerName(playerId)

        if playerName then

            local execString = 
            [[
                a_do_script("MPCMD.cmdFlagList(\"]] .. MPCMD.Serialization.escapeLuaString(playerName,2) .. [[\")")
            ]]
            
            MPCMD.Logging.log("Exec: ".. execString)

            net.dostring_in(MPCMD.scrEnvMission, execString)
        end

        return nil -- no special handler
    end
}

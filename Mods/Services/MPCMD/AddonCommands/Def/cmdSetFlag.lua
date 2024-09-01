MPCMD.cmd =
{
    --Requires cmdiFlagTools to be imported into the mission

    cmd = "flagset",

    help = "Update a registered flag. Args: <flag alias>, <new value> E.g. flagset f 2. See flagl for a list of aliases in the mission.",

    level = 2,

    exec = function(playerId,argMsg)

        local playerName = MPCMD.getPlayerName(playerId)

        local tok1
        local tok2
        
        tok1, argMsg = MPCMD.splitToken(argMsg)
        tok2, argMsg = MPCMD.splitToken(argMsg)

        local flagValue = tonumber(tok2)

        if tok1 == nil then
            MPCMD.Logging.log("flag alias not specified")
            return nil
        end

        if flagValue == nil then
            MPCMD.Logging.log("Flag value not specified")
            return nil
        end

        if playerName then

            playerName = MPCMD.Serialization.escapeLuaString(playerName,2)

            local tok1AsNum = tonumber(tok1)
            local flagAlias 
            if tok1AsNum  ~= nil then
                flagAlias = tok1AsNum
            else
                flagAlias = [[\"]] .. MPCMD.Serialization.escapeLuaString(tok1,2) .. [[\"]]
            end



            local execString = 
            [[
                a_do_script("MPCMD.cmdSetFlag(\"]] .. playerName .. [[\",]] .. flagAlias .. [[,]] .. flagValue .. [[)")
            ]]
            
            MPCMD.Logging.log("Exec: ".. execString)

            net.dostring_in(MPCMD.scrEnvMission, execString)
        end

        return nil -- no special handler
    end
}

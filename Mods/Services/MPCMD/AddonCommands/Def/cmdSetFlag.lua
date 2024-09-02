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

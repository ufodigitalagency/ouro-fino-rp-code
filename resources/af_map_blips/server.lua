local function tell(source,message)
    if source == 0 then
        print("[af_map_blips] "..message)
        return
    end

    TriggerClientEvent("chat:addMessage",source,{
        color = { 255, 215, 0 },
        args = { "Ouro Fino Blips", message }
    })
end

RegisterCommand("ofblipsreload",function(source)
    if source == 0 then
        print("[af_map_blips] Use este comando dentro do jogo para recarregar no client.")
        return
    end

    TriggerClientEvent("af_map_blips:reload",source)
    tell(source,"Recarregando blips no seu mapa.")
end,false)

RegisterCommand("ofblips",function(source)
    if source == 0 then
        print("[af_map_blips] Use este comando dentro do jogo para alternar no client.")
        return
    end

    TriggerClientEvent("af_map_blips:toggle",source)
end,false)

RegisterCommand("ofblipsstatus",function(source)
    if source == 0 then
        print("[af_map_blips] Resource ativo. Status detalhado aparece no client.")
        return
    end

    TriggerClientEvent("af_map_blips:status",source)
end,false)

RegisterCommand("ofgps",function(source,args)
    if source == 0 then
        print("[af_map_blips] Use /ofgps dentro do jogo.")
        return
    end

    TriggerClientEvent("af_map_blips:gps",source,args[1] or "banco")
end,false)

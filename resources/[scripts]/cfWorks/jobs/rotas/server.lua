RegisterServerEvent("cfWorks:routeReward")
AddEventHandler("cfWorks:routeReward",function(jobId)
    local source = source
    local user_id = vRP.getUserId(source)

    if not user_id or not jobId or not Config.RouteJobs or not Config.RouteJobs[jobId] then
        return
    end

    local cfg = Config.RouteJobs[jobId]
    local amount = tonumber(cfg.payment) or 0
    local xp = tonumber(cfg.xp) or 0

    if amount <= 0 then
        return
    end

    if xp > 0 then
        addJobXP(user_id,jobId,xp)
    end

    payment(user_id,jobId,amount)
    TriggerClientEvent("Notify",source,"sucesso","Servico concluido. Recebeu <b>R$"..amount.."</b>.")
end)

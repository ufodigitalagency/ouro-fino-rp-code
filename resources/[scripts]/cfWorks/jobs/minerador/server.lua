RegisterServerEvent("cfWorks:mineradorReward")
AddEventHandler("cfWorks:mineradorReward", function()
    local source = source
    local user_id = vRP.getUserId(source)
    if user_id then
        local cfg = Config.Minerador
        vRP.giveInventoryItem(user_id, cfg.Item, cfg.Qtd, true)
        addJobXP(user_id, "minerador", cfg.XP)
        payment(user_id, "minerador", cfg.Pagamento)
    end
end)

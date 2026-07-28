RegisterServerEvent("cfWorks:eletricistaReward")
AddEventHandler("cfWorks:eletricistaReward", function()
    local source = source
    local user_id = vRP.getUserId(source)
    if user_id then
        local cfg = Config.Eletricista
        vRP.giveInventoryItem(user_id, cfg.Item, 1, true)
        addJobXP(user_id, "eletricista", cfg.XP)
        payment(user_id, "eletricista", cfg.Pagamento)
        TriggerClientEvent("Notify", source, "sucesso", "Reparo concluído! Recebeu <b>R$"..cfg.Pagamento.."</b>")
    end
end)

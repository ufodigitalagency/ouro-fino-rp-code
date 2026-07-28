local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPC = Tunnel.getInterface("vRP")

CfWorks = {}
CfWorksActiveJobs = CfWorksActiveJobs or {}
Tunnel.bindInterface(GetCurrentResourceName(),CfWorks)

exports("IsJobActive",function(source,jobId)
    return CfWorksActiveJobs[source] == jobId
end)

function CfWorks.LixeiroCanSpawn()
    local source = source
    return CfWorksActiveJobs[source] == "lixeiro"
end

vRP._prepare("vRP/get_job_progress", "SELECT job_id, xp, level, earned FROM cfworks WHERE user_id = @user_id")
vRP._prepare("vRP/update_job_progress", "INSERT INTO cfworks(user_id, job_id, xp, level, earned) VALUES(@user_id, @job_id, @xp, @level, @earned) ON DUPLICATE KEY UPDATE xp = @xp, level = @level, earned = @earned")

local function getXPForLevel(level)
    return level * 1000
end

local function getPlayerProgress(user_id)
    local progress = {}
    local rows = vRP.query("vRP/get_job_progress", { user_id = user_id }) or {}

    for _, v in pairs(rows) do
        progress[v.job_id] = {
            xp = v.xp or 0,
            level = v.level or 1,
            earned = v.earned or 0
        }
    end
    return progress
end

RegisterServerEvent("cfWorks:requestData")
AddEventHandler("cfWorks:requestData", function()
local source = source
    local user_id = vRP.getUserId(source)

    if user_id then
        local identity = vRP.userIdentity(user_id)
        local bankMoney = vRP.getBankMoney(user_id) or 0
        local progress = getPlayerProgress(user_id)

        local totalFaturado = 0
        local totalXP = 0
        local jobsData = {}
        local jobsAtivosCount = 0

        for _, job in pairs(Config.Jobs) do
            local userJobData = progress[job.id] or { xp = 0, level = 1, earned = 0 }
            local currentEarned = tonumber(userJobData.earned) or 0
            local currentXP = tonumber(userJobData.xp) or 0

            totalFaturado = totalFaturado + currentEarned
            totalXP = totalXP + currentXP

            if currentEarned > 0 or currentXP > 0 then
                jobsAtivosCount = jobsAtivosCount + 1
            end

            table.insert(jobsData, {
                id = job.id,
                name = job.name,
                description = job.description,
                icon = job.icon,
                payment = job.payment,
                xp = currentXP,
                level = userJobData.level or 1,
                earned = currentEarned,
                maxXp = getXPForLevel(userJobData.level or 1)
            })
        end

        local payload = {
            name = identity.name .. " " .. identity.name2,
            level = 12,
            totalEarned = totalFaturado,
            isActive = true,
            validity = "Vitalícia",
            jobs = jobsData,
            stats = {
                activeJobs = jobsAtivosCount,
                totalJobs = #Config.Jobs,
                totalTasks = 523,
                totalXP = totalXP,
                avgEarnings = jobsAtivosCount > 0 and (totalFaturado / jobsAtivosCount) or 0
            }
        }

        TriggerClientEvent("cfWorks:updateUI", source, payload)
    end
end)

local function SetActiveJob(source,jobId)
    local user_id = vRP.getUserId(source)
    if user_id then
        local previousJob = CfWorksActiveJobs[source]
        CfWorksActiveJobs[source] = jobId
        TriggerEvent("cfWorks:jobChanged", source, jobId)

        if previousJob == "lixeiro" and jobId ~= "lixeiro" then
            TriggerClientEvent("cfWorks:cleanupLixeiro", source)
        end
        if previousJob == "taxista" and jobId ~= "taxista" then
            TriggerClientEvent("taxi:StopShift", source)
        end
        TriggerClientEvent("cfWorks:syncActiveJob",source,jobId)
        TriggerClientEvent("Notify", source, "verde", "Você selecionou o emprego: <b>" .. jobId .. "</b>")
        return true
    end
    return false
end

exports("SetActiveJob",SetActiveJob)

RegisterServerEvent("cfWorks:setJob")
AddEventHandler("cfWorks:setJob", function(jobId)
    SetActiveJob(source,jobId)
end)

RegisterServerEvent("cfWorks:stopJob")
AddEventHandler("cfWorks:stopJob", function()
    if CfWorksActiveJobs[source] == "taxista" then
        TriggerClientEvent("taxi:StopShift", source)
    end
    TriggerEvent("cfWorks:jobChanged", source, nil)
    CfWorksActiveJobs[source] = nil
    TriggerClientEvent("cfWorks:syncActiveJob",source,nil)
end)

AddEventHandler("playerDropped", function()
    TriggerEvent("cfWorks:playerDropped", source)
    CfWorksActiveJobs[source] = nil
end)

function addJobXP(user_id, job_id, amount)
    if not user_id or not job_id or not amount then return end

    local rows = vRP.query("vRP/get_job_progress", { user_id = user_id })
    local xp, level, earned = 0, 1, 0

    if #rows > 0 then
        xp = rows[1].xp or 0
        level = rows[1].level or 1
        earned = rows[1].earned or 0
    end

    xp = xp + amount
    local nextXP = getXPForLevel(level)

    if xp >= nextXP then
        xp = xp - nextXP
        level = level + 1
        local source = vRP.getUserSource(user_id)
        if source then
            TriggerClientEvent("Notify", source, "amarelo", "Você subiu para o <b>Nível "..level.."</b>!")
        end
    end

    vRP.execute("vRP/update_job_progress", {
        user_id = user_id,
        job_id = job_id,
        xp = xp,
        level = level,
        earned = earned
    })
end

function payment(user_id, job_id, amount)
    local rows = vRP.query("vRP/get_job_progress", { user_id = user_id })
    local xp, level, earned = 0, 1, 0

    for _, v in pairs(rows) do
        if v.job_id == job_id then
            xp, level, earned = v.xp, v.level, v.earned
        end
    end

    vRP.giveInventoryItem(user_id, "dollars", amount)
    earned = earned + amount

    vRP.execute("vRP/update_job_progress", {
        user_id = user_id,
        job_id = job_id,
        xp = xp,
        level = level,
        earned = earned
    })
end

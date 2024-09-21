-- Create a table for the preferred playermodels
--
-- Note: in DarkRP before 2024-09, there was a different table called
-- `darkp_playermodels` (note the misspelling of "darkp"). This table was
-- missing the server column, meaning that preferred job models would persist
-- across multiple servers. To make preferred job models store per server, this
-- new table (without the spelling mistake) was created.
--
-- See the original issue to create the player model preference feature:
-- https://github.com/FPtje/DarkRP/issues/979 and the subsequent refactor at
-- https://github.com/FPtje/DarkRP/pull/3266
sql.Query([[CREATE TABLE IF NOT EXISTS darkrp_playermodels(
    server TEXT NOT NULL,
    jobcmd TEXT NOT NULL,
    model TEXT NOT NULL,
    PRIMARY KEY (server, jobcmd)
);]])


local preferredModels = {}


--[[---------------------------------------------------------------------------
Interface functions
---------------------------------------------------------------------------]]
function DarkRP.setPreferredJobModel(teamNr, model)
    local job = RPExtraTeams[teamNr]
    if not job then return end
    preferredModels[job.command] = model
    sql.Query(string.format([[REPLACE INTO darkrp_playermodels(server, jobcmd, model) VALUES(%s, %s, %s);]], sql.SQLStr(game.GetIPAddress()), sql.SQLStr(job.command), sql.SQLStr(model)))

    net.Start("DarkRP_preferredjobmodel")
        net.WriteUInt(teamNr, 8)
        net.WriteString(model)
    net.SendToServer()
end

function DarkRP.getPreferredJobModel(teamNr)
    local job = RPExtraTeams[teamNr]
    if not job then return end
    return preferredModels[job.command]
end

--[[---------------------------------------------------------------------------
Load the preferred models
---------------------------------------------------------------------------]]
local function sendModels()
    net.Start("DarkRP_preferredjobmodels")
        for _, job in pairs(RPExtraTeams) do
            if not preferredModels[job.command] then net.WriteBit(false) continue end

            net.WriteBit(true)
            net.WriteString(preferredModels[job.command])
        end
    net.SendToServer()
end

local function jobHasModel(job, model)
    return istable(job.model) and table.HasValue(job.model, model) or job.model == model
end

timer.Simple(0, function()
    -- run after the jobs have loaded
    local models = sql.Query(string.format([[SELECT jobcmd, model FROM darkrp_playermodels WHERE server = %s;]], sql.SQLStr(game.GetIPAddress())))

    for _, v in ipairs(models or {}) do
        local job = DarkRP.getJobByCommand(v.jobcmd)
        if job == nil or not jobHasModel(job, v.model) then continue end

        preferredModels[v.jobcmd] = v.model
    end

    sendModels()
end)

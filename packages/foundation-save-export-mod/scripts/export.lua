local myMod = ...

local COMP_SAVE_EXPORTER = {
    TypeName = "COMP_SAVE_EXPORTER",
    ParentType = "COMPONENT",
    Properties = {
        {
            Name = "ExportTriggered",
            Type = "boolean",
            Default = false,
        },
        {
            Name = "LastExportDay",
            Type = "integer",
            Default = -1,
        },
        {
            Name = "AutoExportInterval",
            Type = "integer",
            Default = 0,
        },
    },
}

local function tableToJson(val, indent)
    indent = indent or 0
    local indentStr = string.rep("    ", indent)
    local innerIndent = string.rep("    ", indent + 1)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local isArray = true
        local maxKey = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k ~= math.floor(k) or k <= 0 then
                isArray = false
            end
            if type(k) == "number" and k > maxKey then
                maxKey = k
            end
        end
        if isArray and maxKey == #val then
            local parts = {}
            for _, v in ipairs(val) do
                table.insert(parts, tableToJson(v, indent + 1))
            end
            if #parts == 0 then
                return "[]"
            end
            return "[\n" .. innerIndent .. table.concat(parts, ",\n" .. innerIndent) .. "\n" .. indentStr .. "]"
        else
            local parts = {}
            local keys = {}
            for k, _ in pairs(val) do
                table.insert(keys, k)
            end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                local v = val[k]
                local keyStr
                if type(k) == "string" then
                    keyStr = string.format("%q", k)
                else
                    keyStr = tostring(k)
                end
                local valueStr = tableToJson(v, indent + 1)
                table.insert(parts, keyStr .. ": " .. valueStr)
            end
            if #parts == 0 then
                return "{}"
            end
            return "{\n" .. innerIndent .. table.concat(parts, ",\n" .. innerIndent) .. "\n" .. indentStr .. "}"
        end
    else
        return tostring(val)
    end
end

local function collectObjectData(gameObject)
    local data = {
        Id = gameObject:getId(),
        Name = gameObject:getName(),
        Position = { gameObject.Position[1], gameObject.Position[2], gameObject.Position[3] },
        Active = gameObject.Active,
        Components = {},
    }

    gameObject:forEachComponent(function(component)
        local compData = {
            Type = component:getType(),
            Enabled = component:isEnabled(),
        }
        table.insert(data.Components, compData)
        return true
    end)

    return data
end

local function collectGameStats(level)
    local stats = {}
    local game = level:getGame()
    if game then
        if game.Population then
            stats.Population = game.Population
        end
        if game.Treasury then
            stats.Treasury = game.Treasury
        end
        if game.Day then
            stats.Day = game.Day
        end
        if game.Year then
            stats.Year = game.Year
        end
        if game.Monarch then
            stats.Monarch = game.Monarch
        end
        if game.Happiness then
            stats.Happiness = game.Happiness
        end
    end
    return stats
end

local function collectAllObjects(level)
    local objects = {}

    local foundObjects = {}
    level:find("", foundObjects)

    for _, obj in ipairs(foundObjects) do
        table.insert(objects, collectObjectData(obj))
    end

    return objects
end

local function runExport()
    local level = foundation.currentLevel()
    if not level then
        myMod:log("Save Export: No active level found.")
        return
    end

    local timestamp = os.date("%Y%m%d_%H%M%S")
    local outputDir = "output"
    local filename = outputDir .. "/export-" .. timestamp .. ".json"

    if not myMod:directoryExists(outputDir) then
        myMod:createDirectory(outputDir)
    end

    local objects = collectAllObjects(level)
    local stats = collectGameStats(level)

    local exportData = {
        Metadata = {
            ModName = myMod:getModName(),
            ModVersion = myMod:getModVersion(),
            ExportTimestamp = os.date("%Y-%m-%dT%H:%M:%S"),
            GameVersion = foundation.getGameVersion(),
            ObjectCount = #objects,
        },
        Stats = stats,
        Objects = objects,
    }

    local json = tableToJson(exportData)
    local success = myMod:writeFileAsString(filename, json)

    if success then
        myMod:log("Save Export: " .. tostring(#objects) .. " objects exported to " .. filename)
    else
        myMod:log("Save Export: Failed to write " .. filename)
    end
end

function COMP_SAVE_EXPORTER:init()
    myMod:log("COMP_SAVE_EXPORTER initialized. Press F12 to export game state.")
    self.ExportTriggered = false
    self.LastExportDay = -1
end

function COMP_SAVE_EXPORTER:update()
    if foundation.isKeyPressed("f12") and not self.ExportTriggered then
        self.ExportTriggered = true
        myMod:log("Save Export: F12 pressed, starting export...")
        runExport()
    end
    if not foundation.isKeyPressed("f12") then
        self.ExportTriggered = false
    end

    if self.AutoExportInterval > 0 then
        local game = foundation.currentLevel()
        if game then
            local gameObj = game:getGame()
            if gameObj and gameObj.Day then
                local currentDay = gameObj.Day
                if currentDay > 0 and currentDay ~= self.LastExportDay and currentDay % self.AutoExportInterval == 0 then
                    self.LastExportDay = currentDay
                    myMod:log("Save Export: Auto-export triggered on day " .. tostring(currentDay))
                    runExport()
                end
            end
        end
    end
end

function COMP_SAVE_EXPORTER:onEnabled()
    myMod:log("COMP_SAVE_EXPORTER enabled.")
end

function COMP_SAVE_EXPORTER:onDisabled()
    myMod:log("COMP_SAVE_EXPORTER disabled.")
end

myMod:registerClass(COMP_SAVE_EXPORTER)

function myMod:onGameStarted()
    myMod:log("Save Export: Game started. Spawning exporter component.")
    local level = foundation.currentLevel()
    if level then
        level:createObject(function(newObject)
            newObject:addComponent("COMP_SAVE_EXPORTER")
        end)
        myMod:log("Save Export: Exporter component spawned.")
    end
end

myMod:registerEvent(EVENT.GAME_STARTED, "onGameStarted")

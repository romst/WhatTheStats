wts = {}

---@class Addon: AceAddon-3.0
local Addon = LibStub("AceAddon-3.0"):NewAddon("WhatTheStats")
local AceDB = LibStub("AceDB-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local AceConsole = LibStub("AceConsole-3.0")

---@class CommandLine
local CommandLine = {}

---@class UI
local UI = {}

------- UTILS -------

local debug = true -- TODO make setting
function Addon:Debug(...)
    if debug then
        print(...)
    end
end

local function stringStartsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function serializeTable(val, name, skipnewlines, depth, isArray)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)

    if not isArray and name then
        -- if not array: display number as [1]
        if type(name) == "number" then
            tmp = tmp .. "[" .. name .. "] = "
        else
            tmp = tmp .. name .. " = "
        end
    end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            if not (k and stringStartsWith(k, "__")) then
                tmp = tmp ..
                    serializeTable(v, k, skipnewlines, depth + 1, val.__isArray)
                    .. "," .. (not skipnewlines and "\n" or "")
            end
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

---@class SpellEntry
local DefaultSpellEntry = { -- spellId
    maintained = false,

    school = 0,
    spellType = 0,
    unit = "player",

    tooltip = {
        __isArray = true,
        [1] = "ap",
        [2] = "sp",
        [3] = "level",
        [4] = "newLine",
        [5] = "range",
        [6] = "avg",
        [7] = "avgWithMods",
    },

    base = {
        weaponTypeMultiplier = {},
        fromMainhand = 0,
        fromOffhand = 0,
        fromRange = 0,
        fromFlat = {
            min = 0,
            max = 0,
        },

        normalizedWeaponDamage = false,
    },

    scaling = {
        ap = 0,
        sp = 0,
        level = 0,
    },

    mods = {
        {
            [302053] = -0.5, -- Adventure-Mode lvl 1
        }
    },
}

wts.const = {}
wts.token = {}
wts.text = {}

function Addon:LoadFunctions()
    wts.const = self.db.global.functions.const

    wts.token = {}
    for key, value in pairs(self.db.global.functions.token) do
        wts.token[key] = assert(loadstring("return " .. value))()
    end

    wts.text = {}
    for key, value in pairs(self.db.global.functions.text) do
        wts.text[key] = assert(loadstring("return " .. value))()
    end
end

function Addon:OnInitialize()
    -- Code that you want to run when the addon is first loaded goes here.
    self.db = AceDB:New(
        "WhatTheStatsDB",
        {
            global = {
                playerWeapons = {
                    ['*'] = {
                        baseMin = nil,
                        baseMax = nil,
                        baseDps = nil,
                    }
                },
                abilities = {
                    ['*'] = DefaultSpellEntry
                },
                functions = {
                    const = {
                        ---@enum Unit
                        unit = {
                            player = "player",
                            pet = "pet",
                        },
                        ---@enum SpellType
                        spellType = {
                            unknown = 0,
                            damageMelee = 1,
                            damageRange = 2,
                            damageSpell = 3,
                            heal = 4,
                            other = 5,
                        },
                        ---@enum SpellSchool
                        spellSchool = {
                            unknown = 0,
                            physical = 1,
                            holy = 2,
                            fire = 3,
                            nature = 4,
                            frost = 5,
                            shadow = 6,
                            arcane = 7,
                        },
                        ---@enum WeaponType
                        weaponType = {
                            "Bows",
                            "Crossbows",
                            "Daggers",
                            "Guns",
                            "Fishing Poles",
                            "Fist Weapons",
                            "Miscellaneous",
                            "One-Handed Axes",
                            "One-Handed Maces",
                            "One-Handed Swords",
                            "Polearms",
                            "Staves",
                            "Thrown",
                            "Two-Handed Axes",
                            "Two-Handed Maces",
                            "Two-Handed Swords",
                            "Wands",
                        },
                    },
                    token = {
                        slot = [[function (data, slotName)
                            if slotName == "main" then
                                return 16
                            elseif slotName == "off" then
                                return 17
                            elseif slotName == "range" then
                                return 18
                            end

                            -- invalid slot
                            return 0
                        end]],
                        weaponType = [[function(data, slot)
                            local itemId = GetInventoryItemID(data.unit, slot)
                            if not itemId then return 0 end

                            local itemSubType = select(7, GetItemInfo(itemId))

                            if itemSubType == "Daggers" then
                                return 1
                            elseif itemSubType == "Fist Weapons"
                                or itemSubType == "One-Handed Axes"
                                or itemSubType == "One-Handed Maces"
                                or itemSubType == "One-Handed Swords" then
                                return 2
                            elseif itemSubType == "Polearms"
                                or itemSubType == "Staves"
                                or itemSubType == "Two-Handed Axes"
                                or itemSubType == "Two-Handed Maces"
                                or itemSubType == "Two-Handed Swords" then
                                return 3
                            elseif itemSubType == "Bows"
                                or itemSubType == "Crossbows"
                                or itemSubType == "Guns"
                                or itemSubType == "Thrown"
                                or itemSubType == "Wands" then
                                return 4
                            else
                                return 0
                            end
                        end]],
                        weaponTypeNormalizationModifier = [[function(data, slot)
                            local weaponType = wts.token.weaponType(data, slot)

                            if weaponType == 1 then
                                return 1.7
                            elseif weaponType == 2 then
                                return 2.4
                            elseif weaponType == 3 then
                                return 3.3
                            elseif weaponType == 4 then
                                return 2.8
                            else
                                return 1
                            end
                        end]],
                        damageMain = [[function(data)
                            local min, max = UnitDamage(data.unit)
                            return min, max
                        end]],
                        damageOff = [[function(data)
                            local _, _, min, max = UnitDamage(data.unit)
                            return min, max
                        end]],
                        damageRange = [[function(data)
                            local _, min, max = UnitRangedDamage(data.unit)
                            return minMain, maxMain
                        end]],
                        speedMain = [[function(data)
                            local speed = UnitAttackSpeed(data.unit)
                            return speed
                        end]],
                        speedOff = [[function(data)
                            local _, speed = UnitAttackSpeed(data.unit)
                            return speed
                        end]],
                        speedRange = [[function(data)
                            local speed = UnitRangedDamage(data.unit)
                            return speed
                        end]],
                        ap = [[function (data)
                            local ap = UnitAttackPower(data.unit)
                            return ap
                        end]],
                        apDamage = [[function (data)
                            local ap = UnitAttackPower(data.unit)
                            return ap / 14
                        end]],
                        rap = [[function (data)
                            local rap = UnitRangedAttackPower(data.unit)
                            return rap
                        end]],
                        rapDamage = [[function (data)
                            local rap = UnitRangedAttackPower(data.unit)
                            return rap / 14
                        end]],

                        nwd_min = [[function(data)
                            local damage = 0

                            local minMain, maxMain, minOff, _ = UnitDamage(data.unit)
                            local speedMain, speedOff = UnitAttackSpeed(data.unit)
                            local speedRange, minRanged, _ = UnitRangedDamage(data.unit)

                            local apMod = select(1, UnitAttackPower(data.unit)) / 14
                            local rapMod = select(1, UnitRangedAttackPower(data.unit)) / 14

                            if data.base.normalizedWeaponDamage then
                                if data.base.fromMainhand then
                                    local itemId = GetInventoryItemID(data.unit, 16)
                                    if itemId then
                                        local stats = GetItemStats("item:" .. itemId)

                                        local dps = stats["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]

                                        local avgHit = dps * speedMain
                                        local ratio = (maxMain - minMain) / (maxMain + minMain)

                                        local baseMin = avgHit - (ratio * avgHit)
                                        local baseMax = avgHit + (ratio * avgHit)
                                    end


                                    local baseDamage = minMain - (apMod * speedMain)

                                    damage = damage
                                        + (baseDamage + math.floor(apMod / wts.token.weaponTypeNormalizationModifier(data, 16)))
                                        * data.base.fromMainhand
                                        * (data.base.weaponTypeMultiplier[wts.token.weaponType(data, 16)] or 1)
                                end
                                if data.base.fromOffhand then
                                    damage = damage
                                        + (minOff + (apMod / wts.token.weaponTypeNormalizationModifier(data, 17)))
                                        * data.base.fromOffhand
                                        * (data.base.weaponTypeMultiplier[wts.token.weaponType(data, 17)] or 1)
                                end
                                if data.base.fromRange then
                                    damage = damage
                                        + (minRanged
                                            + math.floor((rapMod / wts.token.weaponTypeNormalizationModifier(data, 18))))
                                        * data.base.fromRange
                                        * (data.base.weaponTypeMultiplier[wts.token.weaponType(data, 18)] or 1)
                                end
                            end

                            return math.floor(damage)
                        end]],
                        nwd_max = [[function(data)
                            local damage = 0

                            local _, maxMain, _, maxOff = UnitDamage(data.unit)
                            local _, _, maxRanged = UnitRangedDamage(data.unit)

                            if data.base.normalizedWeaponDamage then
                                if data.base.fromMainhand then
                                    damage = damage
                                        + (maxMain
                                            + math.floor(((select(1, UnitAttackPower(data.unit)) / 14) / wts.token.weaponTypeNormalizationModifier(data, 16))))
                                        * data.base.fromMainhand
                                        * (data.base.weaponTypeMultiplier[wts.token.weaponType(data, 16)] or 1)
                                end
                                if data.base.fromOffhand then
                                    damage = damage
                                        + (maxOff
                                            + math.floor(((select(1, UnitAttackPower(data.unit)) / 14) / wts.token.weaponTypeNormalizationModifier(data, 17))))
                                        * data.base.fromOffhand
                                        * (data.base.weaponTypeMultiplier[wts.token.weaponType(data, 17)] or 1)
                                end
                                if data.base.fromRange then
                                    damage = damage
                                        + (maxRanged
                                            + math.floor(((select(1, UnitRangedAttackPower(data.unit)) / 14) / wts.token.weaponTypeNormalizationModifier(data, 18))))
                                        * data.base.fromRange
                                        * (data.base.weaponTypeMultiplier[wts.token.weaponType(data, 18)] or 1)
                                end
                            end

                            return math.floor(damage)
                        end]],
                        modAP = [[function(data)
                            if (data.spellType == wts.const.spellType.damageRange) then
                                local base, posBuff, negBuff = UnitRangedAttackPower(data.unit)
                                return math.floor(data.scaling.ap * (base + posBuff + negBuff))
                            else
                                -- all other damage types scale with melee?
                                local base, posBuff, negBuff = UnitAttackPower(data.unit)
                                return math.floor(data.scaling.ap * (base + posBuff + negBuff))
                            end
                        end]],
                        modSP = [[function(data)
                            if data.spellType == wts.const.spellType.heal then
                                local bonusHeal = GetSpellBonusHealing();
                                return math.floor(data.scaling.sp * bonusHeal)
                            else
                                if data.school == 0 then
                                    return 0
                                end
                                -- all other damage types scale with bonus damage?
                                local spellDmg = GetSpellBonusDamage(data.school);
                                return math.floor(data.scaling.sp * spellDmg)
                            end
                        end]],
                        modLevel = [[function(data)
                            return math.floor(data.scaling.level * UnitLevel(data.unit))
                        end]],
                        min = [[function(data)
                            return data.base.fromFlat.min
                                + wts.token.nwd_min(data)
                                + wts.token.modAP(data)
                                + wts.token.modSP(data)
                                + wts.token.modLevel(data)
                        end]],
                        max = [[function(data)
                            return data.base.fromFlat.max
                                + wts.token.nwd_max(data)
                                + wts.token.modAP(data)
                                + wts.token.modSP(data)
                                + wts.token.modLevel(data)
                        end]],
                        range = [[function(data)
                            return wts.token.min(data), wts.token.max(data)
                        end]],
                        avg = [[function(data)
                            return (wts.token.min(data) + wts.token.max(data)) / 2
                        end]]
                    },

                    text = {
                        newLine = [[function(data) return " " end]],
                        empty = [[function(data) return "" end]],
                        ap = [[function(data)
                            return "AP", tostring(data.scaling.ap * 100) .. " % (" .. wts.token.modAP(data) .. ")"
                        end]],
                        sp = [[function(data)
                            return "SP", tostring(data.scaling.sp * 100) .. " % (" .. wts.token.modSP(data) .. ")"
                        end]],
                        level = [[function(data)
                            return "Level", tostring(data.scaling.level) .. " pL (" .. wts.token.modLevel(data) .. ")"
                        end]],
                        nwd = [[function(data)
                            return "NWD range", wts.token.nwd_min(data) .. " - " .. wts.token.nwd_max(data)
                        end]],
                        flatRange = [[function(data)
                            return "Flat range", tostring(data.base.fromFlat.min) .. " - " .. tostring(data.base.fromFlat.max)
                        end]],
                        range = [[function(data)
                            return "Range", tostring(wts.token.min(data)) .. " - " .. tostring(wts.token.max(data))
                        end]],
                        avg = [[function(data)
                            return "Avg", tostring(wts.token.avg(data))
                        end]],
                        avgWithMods = [[function(data)
                            local value = wts.token.avg(data)

                            for i, modifierSet in ipairs(data.mods) do
                                local modifier = 1

                                for key, mod in pairs(modifierSet) do
                                    local name, rank = GetSpellInfo(key)

                                    if UnitAura(data.unit, name, rank) then
                                        modifier = modifier + mod
                                    end
                                end

                                value = value * modifier
                            end

                            return "Avg w/ mods", value
                        end]],
                    }
                }
            }
        },
        true)

    self:LoadFunctions()
    CommandLine:Load(self)

    self:Debug("OnInitialize done.")
end

function Addon:OnEnable()
    -- Called when the addon is enabled
    GameTooltip:HookScript("OnTooltipSetSpell", function(self)
        local _, _, id = self:GetSpell()

        if not id then return end

        local spellData = Addon.db.global.abilities[id]

        Addon:Process(self, spellData)
    end)

    --hooksecurefunc(GameTooltip, "SetAction", Addon.onSetAction)
    --hooksecurefunc(GameTooltip, "SetPetAction", Addon.onSetPetAction)

    Addon:Debug("OnEnable done.")
end

function Addon:OnDisable()
    -- Called when the addon is disabled
    Addon:Debug("OnDisable done.")
end

function Addon:Process(tooltip, spellData)
    tooltip:AddLine(" ")
    if spellData and spellData.maintained then
        for _, func in ipairs(spellData.tooltip) do
            local callback = wts.text[func]

            if not callback then
                callback = wts.token[func]
            end

            if not callback then
                callback = wts.text.empty
                print(func, " is not a function")
            end

            local title, value, leftR, leftG, leftB, rightR, rightG, rightB = callback(spellData)

            if value then
                tooltip:AddDoubleLine(tostring(title), tostring(value),
                    leftR, leftG, leftB,
                    rightR, rightG, rightB)
            else
                tooltip:AddLine(tostring(title),
                    leftR, leftG, leftB)
            end
        end
    else
        tooltip:AddLine("spelldata not maintained")
    end
end

function Addon.calculate(value, data)
    return value
        + (value * data.ap)
        + (GetSpellBonusHealing() * data.bh)
        + ((data.school > 0 and GetSpellBonusDamage(data.school) or 0) * data.bd)
        + (UnitLevel("player") * data.level)
end

-------- CommandLine --------

---comment
---@param addon Addon
function CommandLine:Load(addon)
    AceConsole:RegisterChatCommand("wts", self.OpenUI, false)
end

---@param input string anything that follows the slash command
function CommandLine.OpenUI(input)
    local spellIdAsString = AceConsole:GetArgs(input)

    local spellId = tonumber(spellIdAsString)

    if not spellId then
        print("Invalid command. Please enter spellId.")
        return
    end

    if not GetSpellInfo(spellId) then
        print("Invalid command. No spell found with id: " .. spellId .. ".")
        return
    end

    UI:Open(spellId)
end

-------- UI --------

local WTSTabs = {}

-- Callback function for OnGroupSelected
---@param container WidgetContainer
---@param event any
---@param group string
---@param spellId number?
local function SelectGroup(container, event, group, spellId)
    container:ReleaseChildren()
    WTSTabs[group](container, spellId)
end

--- function that draws the widgets for the first tab
---@param container WidgetContainer
---@param spellId number
function WTSTabs.SpelldataTab(container, spellId)
    local spellData = Addon.db.global.abilities[spellId]

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox:SetLabel("Data")
    editbox:SetText(serializeTable(spellData))
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    --editbox:SetNumLines(50)
    editbox:SetCallback("OnEnterPressed", function(_, _, text)
        local newSpellData = assert(loadstring("return " .. text))()
        if not type(newSpellData) == "table" then
            print("Invalid input! Must return lua table.")
            return
        end

        Addon.db.global.abilities[spellId] = newSpellData
    end)
    container:AddChild(editbox)

    --[[
    local desc = AceGUI:Create("Label")
    desc:SetText("This is Tab 1")
    desc:SetFullWidth(true)
    container:AddChild(desc)

    local button = AceGUI:Create("Button")
    button:SetText("Tab 1 Button")
    button:SetWidth(200)
    container:AddChild(button)
    ]]
end

-- function that draws the widgets for the second tab
---@param container any
function WTSTabs.FunctionsTab(container)
    local functions = Addon.db.global.functions

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox:SetLabel("Data")
    editbox:SetText(serializeTable(functions))
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    --editbox:SetNumLines(50)
    editbox:SetCallback("OnEnterPressed", function(_, _, text)
        local newFunctions = assert(loadstring("return " .. text))()
        if not type(newFunctions) == "table" then
            print("Invalid input! Must return lua table.")
            return
        end

        Addon.db.global.functions = newFunctions
        Addon:LoadFunctions()
    end)
    container:AddChild(editbox)

    --[[
    local desc = AceGUI:Create("Label")
    desc:SetText("This is Tab 2")
    desc:SetFullWidth(true)
    container:AddChild(desc)

    local button = AceGUI:Create("Button")
    button:SetText("Tab 2 Button")
    button:SetWidth(200)
    container:AddChild(button)
    ]]
end

---comment
---@param spellId number
function UI:Open(spellId)
    -- Create a container frame
    local frame = AceGUI:Create("Frame")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetTitle("What the Stats")
    frame:SetLayout("Fill")

    local spellName, spellRank = GetSpellInfo(spellId)
    frame:SetStatusText(spellName .. ", " .. spellRank)

    -- Create the TabGroup
    local tab = AceGUI:Create("TabGroup")
    tab:SetLayout("Flow")
    -- Setup which tabs to show
    tab:SetTabs({ { text = "Spelldata", value = "SpelldataTab" }, { text = "Functions", value = "FunctionsTab" } })
    -- Register callback
    tab:SetCallback("OnGroupSelected", function(container, event, group)
        SelectGroup(container, event, group, spellId)
    end)
    -- Set initial Tab (this will fire the OnGroupSelected callback)
    tab:SelectTab("Spelldata")

    -- add to the frame container
    frame:AddChild(tab)
end

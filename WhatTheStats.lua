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

---@enum Unit
Addon._Unit = {
    player = "player",
    pet = "pet",
}

---@enum SpellType
Addon._SpellType = {
    unknown = 0,
    damageMelee = 1,
    damageRange = 2,
    damageSpell = 3,
    heal = 4,
    other = 5,
}

---@enum SpellSchool
Addon._SpellSchool = {
    unknown = 0,
    physical = 1,
    holy = 2,
    fire = 3,
    nature = 4,
    frost = 5,
    shadow = 6,
    arcane = 7,
}

---@enum WeaponType
Addon._WeaponType = {
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
}

---@class SpellEntry
local DefaultSpellEntry = { -- spellId
    maintained = false,

    school = Addon._SpellSchool.unknown,
    spellType = Addon._SpellType.unknown,
    unit = Addon._Unit.player,

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

local defaultDB = {
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
    }
}

---@param unit Unit
---@param slot integer
---@return integer
local function WeaponType(unit, slot)
    local itemId = GetInventoryItemID(unit, slot)
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
end

local function WeaponTypeNormalizationModifier(unit, slot)
    local weaponType = WeaponType(unit, slot)

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
end

local Token = {}

---@param data SpellEntry
---@return integer
Token.nwd_min = function(data)
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

                print(dps, avgHit, ratio, baseMin, baseMax)
            end


            local baseDamage = minMain - (apMod * speedMain)
            --print(minMain, " - (", apMod, " * ", speedMain, ") =", minMain - (apMod * speedMain))

            --[[
            Addon:Debug(
                "minMain: ", minMain,
                ", UnitAttackPower: ", select(1, UnitAttackPower(data.unit)),
                ", WeaponTypeNormalizationModifier: ", WeaponTypeNormalizationModifier(data.unit, 16),
                ", data.base.fromMainhand: ", data.base.fromMainhand,
                ", WeaponType: ", WeaponType(data.unit, 16),
                ", data.base.weaponTypeMultiplier: ", data.base.weaponTypeMultiplier[WeaponType(data.unit, 16)]
            )
            ]]

            damage = damage
                + (baseDamage + math.floor(apMod / WeaponTypeNormalizationModifier(data.unit, 16)))
                * data.base.fromMainhand
                * (data.base.weaponTypeMultiplier[WeaponType(data.unit, 16)] or 1)
        end
        if data.base.fromOffhand then
            damage = damage
                + (minOff + (apMod / WeaponTypeNormalizationModifier(data.unit, 17)))
                * data.base.fromOffhand
                * (data.base.weaponTypeMultiplier[WeaponType(data.unit, 17)] or 1)
        end
        if data.base.fromRange then
            damage = damage
                + (minRanged
                    + math.floor((rapMod / WeaponTypeNormalizationModifier(data.unit, 18))))
                * data.base.fromRange
                * (data.base.weaponTypeMultiplier[WeaponType(data.unit, 18)] or 1)
        end
    end

    return math.floor(damage)
end

---@param data SpellEntry
---@return integer
Token.nwd_max = function(data)
    local damage = 0

    local _, maxMain, _, maxOff = UnitDamage(data.unit)
    local _, _, maxRanged = UnitRangedDamage(data.unit)

    if data.base.normalizedWeaponDamage then
        if data.base.fromMainhand then
            damage = damage
                + (maxMain
                    + math.floor(((select(1, UnitAttackPower(data.unit)) / 14) / WeaponTypeNormalizationModifier(data.unit, 16))))
                * data.base.fromMainhand
                * (data.base.weaponTypeMultiplier[WeaponType(data.unit, 16)] or 1)
        end
        if data.base.fromOffhand then
            damage = damage
                + (maxOff
                    + math.floor(((select(1, UnitAttackPower(data.unit)) / 14) / WeaponTypeNormalizationModifier(data.unit, 17))))
                * data.base.fromOffhand
                * (data.base.weaponTypeMultiplier[WeaponType(data.unit, 17)] or 1)
        end
        if data.base.fromRange then
            damage = damage
                + (maxRanged
                    + math.floor(((select(1, UnitRangedAttackPower(data.unit)) / 14) / WeaponTypeNormalizationModifier(data.unit, 18))))
                * data.base.fromRange
                * (data.base.weaponTypeMultiplier[WeaponType(data.unit, 18)] or 1)
        end
    end

    return math.floor(damage)
end

---@param data SpellEntry
---@return number
Token.modAP = function(data)
    if (data.spellType == Addon._SpellType.damageRange) then
        local base, posBuff, negBuff = UnitRangedAttackPower(data.unit)
        return math.floor(data.scaling.ap * (base + posBuff + negBuff))
    else
        -- all other damage types scale with melee?
        local base, posBuff, negBuff = UnitAttackPower(data.unit)
        return math.floor(data.scaling.ap * (base + posBuff + negBuff))
    end
end
---@param data SpellEntry
---@return number
Token.modSP = function(data)
    if data.spellType == Addon._SpellType.heal then
        local bonusHeal = GetSpellBonusHealing();
        return math.floor(data.scaling.sp * bonusHeal)
    else
        if data.school == Addon._SpellSchool.unknown then
            return 0
        end
        -- all other damage types scale with bonus damage?
        local spellDmg = GetSpellBonusDamage(data.school);
        return math.floor(data.scaling.sp * spellDmg)
    end
end
---@param data SpellEntry
---@return number
Token.modLevel = function(data)
    return math.floor(data.scaling.level * UnitLevel(data.unit))
end


local FunctionMath = {
    ---@param data SpellEntry
    ---@return number
    min = function(data)
        return data.base.fromFlat.min
            + Token.nwd_min(data)
            + Token.modAP(data)
            + Token.modSP(data)
            + Token.modLevel(data)
    end,
    ---@param data SpellEntry
    ---@return number
    max = function(data)
        return data.base.fromFlat.max
            + Token.nwd_max(data)
            + Token.modAP(data)
            + Token.modSP(data)
            + Token.modLevel(data)
    end,
}

---@param data SpellEntry
---@return integer min, integer max
FunctionMath.range = function(data)
    return FunctionMath.min(data), FunctionMath.max(data)
end

---@param data SpellEntry
---@return number
FunctionMath.avg = function(data)
    return (FunctionMath.min(data) + FunctionMath.max(data)) / 2
end

local FunctionText = {
    ---@param data SpellEntry
    ---@return string
    newLine = function(data)
        return " "
    end,
    ---@param data SpellEntry
    ---@return string
    empty = function(data)
        return ""
    end,
    ---@param data SpellEntry
    ---@return string left, string right
    ap = function(data)
        return "AP", tostring(data.scaling.ap * 100) .. " % (" .. Token.modAP(data) .. ")"
    end,
    ---@param data SpellEntry
    ---@return string left, string right
    sp = function(data)
        return "SP", tostring(data.scaling.sp * 100) .. " % (" .. Token.modSP(data) .. ")"
    end,
    ---@param data SpellEntry
    ---@return string left, string right
    level = function(data)
        return "Level", tostring(data.scaling.level) .. " pL (" .. Token.modLevel(data) .. ")"
    end,
    nwd = function(data)
        return "NWD range", Token.nwd_min(data) .. " - " .. Token.nwd_max(data)
    end,
    ---@param data SpellEntry
    ---@return string left, string right
    flatRange = function(data)
        return "Flat range", tostring(data.base.fromFlat.min) .. " - " .. tostring(data.base.fromFlat.max)
    end,
    ---@param data SpellEntry
    ---@return string left, string right
    range = function(data)
        return "Range", tostring(FunctionMath.min(data)) .. " - " .. tostring(FunctionMath.max(data))
    end,
    ---@param data SpellEntry
    ---@return string left, string right
    avg = function(data)
        return "Avg", tostring(FunctionMath.avg(data))
    end,
    ---@param data SpellEntry
    ---@return string left, string right
    avgWithMods = function(data)
        local value = FunctionMath.avg(data)

        for i, modifierSet in ipairs(data.mods) do
            local modifier = 1

            for key, mod in pairs(modifierSet) do
                local name, rank = GetSpellInfo(key)

                if UnitAura(data.unit, name, rank) then
                    Addon:Debug("mod[" .. i .. "].", name, ".", value, " = ", mod)
                    modifier = modifier + mod
                end
            end

            value = value * modifier
        end

        Addon:Debug("Final: " .. value)

        return "Avg w/ mods", value
    end,
}


function Addon:OnInitialize()
    -- Code that you want to run when the addon is first loaded goes here.
    self.db = AceDB:New("WhatTheStatsDB", defaultDB, true)

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
            local callback = FunctionText[func]

            if not callback then
                callback = FunctionText.empty
                print(func, " is not a function")
            end

            local title, value = callback(spellData)

            if value then
                tooltip:AddDoubleLine(title, value)
                --line.leftR, line.leftG, line.leftB,
                --line.rightR, line.rightG, line.rightB)
            else
                tooltip:AddLine(title)
                --line.leftR, line.leftG, line.leftB)
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

---comment
---@param spellId number
function UI:Open(spellId)
    -- Create a container frame
    local f = AceGUI:Create("Frame")
    f:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    f:SetTitle("What the Stats")
    f:SetLayout("Flow")

    local spellName, spellRank = GetSpellInfo(spellId)
    f:SetStatusText(spellName .. ", " .. spellRank)

    local spellData = Addon.db.global.abilities[spellId]

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox:SetLabel("Data")
    editbox:SetText(serializeTable(spellData))
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    --editbox:SetNumLines(50)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text)
        local newSpellData = assert(loadstring("return " .. text))()
        if not type(newSpellData) == "table" then
            print("Invalid input! Must return lua table.")
            return
        end

        Addon.db.global.abilities[spellId] = newSpellData
    end)
    f:AddChild(editbox)
end

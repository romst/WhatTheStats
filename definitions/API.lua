---@meta

---@param unit "player"|"pet"
---@return number base, number posBuff, number negBuff
function UnitAttackPower(unit) end

---@param unit "player"|"pet"
---@return number base, number posBuff, number negBuff
function UnitRangedAttackPower(unit) end

---@return number bonusHeal
function GetSpellBonusHealing() end

---@param spellTreeID SpellSchool
---@return number spellDmg
function GetSpellBonusDamage(spellTreeID) end

---@param unit Unit
---@return number
function UnitLevel(unit) end

---@param spell number|string spellId or spellName or spellLink
---@return string name, string rank, string icon, number cost, string powerType, number castTime, number minRange, number maxRange
function GetSpellInfo(spell) end

---@param unit Unit
---@param name string
---@param rank string
---@return string? name, ...
function UnitAura(unit, name, rank) end

---@enum WeaponSlot
local WeaponSlot = {
    mainhand = 16,
    offhand = 17,
    ranged = 18,
}

---@param unit Unit
---@param invSlot WeaponSlot
---@return number? itemId
function GetInventoryItemID(unit, invSlot) end

---@param itemId number
---@return string itemName, string itemLink, integer itemRarity, integer itemLevel, integer itemMinLevel, string itemType, string itemSubType, integer itemStackCount, string itemEquipLoc, string itemTexture, integer itemSellPrice
function GetItemInfo(itemId) end

---@param unit Unit
---@return number lowDmg, number hiDmg, number offlowDmg, number offhiDmg, number posBuff, number negBuff, number percentmod
function UnitDamage(unit) end

---@param unit Unit
---@return number speed, number lowDmg, number hiDmg, number posBuff, number negBuff, number percent
function UnitRangedDamage(unit) end

---comment
---@param unit Unit
---@return number mainSpeed, number offSpeed
function UnitAttackSpeed(unit) end

---@class GameTooltip
GameTooltip = {}

---@return _,_, number id
function GameTooltip:GetSpell() end

---Appends the new line to the tooltip.
---@param tooltipText string
---@param r number 0..1
---@param g number 0..1
---@param b number 0..1
---@param wrapText boolean
function GameTooltip:AddLine(tooltipText, r, g, b, wrapText) end

---Two column line
---@param textL string
---@param textR string
---@param rL number 0..1
---@param gL number 0..1
---@param bL number 0..1
---@param rR number 0..1
---@param gR number 0..1
---@param bR number 0..1
function GameTooltip:AddDoubleLine(textL, textR, rL, gL, bL, rR, gR, bR) end

---comment
---@param event string
---@param callback fun(self: GameTooltip)
function GameTooltip:HookScript(event, callback) end

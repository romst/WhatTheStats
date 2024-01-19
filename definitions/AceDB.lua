---@meta

---@class AceDB-3.0
local AceDB = {}

---@class DB
---@field char table
---@field realm table
---@field class table
---@field race table
---@field faction table
---@field factionrealm table
---@field locale table
---@field global table
---@field profile table

---comment
---@param name string
---@param defaults? table
---@param defaultProfile? true|string
---@return DB
function AceDB:New(name, defaults, defaultProfile) end

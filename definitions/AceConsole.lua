---@meta

---@class AceConsole-3.0
local AceConsole = {}


---print to console
---@param ... string args
function AceConsole:Print(...) end

---register new chat command
---@param command string command without leading "/"
---@param func function|string
---@param persist boolean? default: true
function AceConsole:RegisterChatCommand(command, func, persist) end

---@param command string
function AceConsole:UnregisterChatCommand(command) end

---Retreive one or more space-separated arguments from a string. Treats quoted strings and itemlinks as non-spaced.
---@param str string every thing after slash command
---@param numargs? 1 default: 1
---@param startpos? number default: 1
---@return string arg, number nextposition
function AceConsole:GetArgs(str, numargs, startpos) end

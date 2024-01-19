---@meta

---@class AceGUI-3.0
local AceGUI = {}

---Create a new Widget of the given type. This function will instantiate a new widget (or use one from the widget pool), and call the OnAcquire function on it, before returning.
---@generic T : Widget
---@param type `T`
---@return T
function AceGUI:Create(type) end

---Releases a widget Object. This function calls OnRelease on the widget and places it back in the widget pool. Any data on the widget is being erased, and the widget will be hidden. If this widget is a Container-Widget, all of its Child-Widgets will be releases as well.
---@param widget Widget
function AceGUI:Release(widget) end

--- Called when something has happened that could cause widgets with focus to drop it e.g. titlebar of a frame being clicked
function AceGUI:ClearFocus() end

------------------ Events ------------------

-- TODO

------------------ Widget ------------------

---@class Widget
local Widget = {}

---@param width number
function Widget:SetWidth(width) end

---@param width number
function Widget:SetHeight(width) end

---@param bool boolean
function Widget:SetFullWidth(bool) end

---@param bool boolean
function Widget:SetFullHeight(bool) end

------------- Frame -------------

---@class Frame:Widget
local Frame = {}

---@param title string
function Frame:SetTitle(title) end

---@param statusText string
function Frame:SetStatusText(statusText) end

---@param layout "Fill"|"List"|"Flow"
function Frame:SetLayout(layout) end

---@param event string
---@param callback function
function Frame:SetCallback(event, callback) end

---@param child Widget
function Frame:AddChild(child) end

------------- Button -------------

---@class Button:Widget
local Button = {}

---@param text string
function Button:SetText(text) end

---@param event string
---@param callback function
function Button:SetCallback(event, callback) end

------------- EditBox -------------

---@class EditBox:Widget
local EditBox = {}

---@param label string
function EditBox:SetLabel(label) end

---@param text string
function EditBox:SetText(text) end

---@param event string
---@param callback function
function EditBox:SetCallback(event, callback) end

------------- MultiLineEditBox -------------

---@class MultiLineEditBox:Widget
local MultiLineEditBox = {}

---@param label string
function MultiLineEditBox:SetLabel(label) end

---@param text string
function MultiLineEditBox:SetText(text) end

---@param lines number
function MultiLineEditBox:SetNumLines(lines) end

---@param event string
---@param callback function
function MultiLineEditBox:SetCallback(event, callback) end

------------- Label -------------

---@class Label:Widget
local Label = {}

---@param text string
function Label:SetText(text) end

---@param width number
function Label:SetWidth(width) end

---@param bool boolean
function Label:SetFullWidth(bool) end

------------- TabGroup -------------

---@class TabGroup:Widget
local TabGroup = {}

---@param layout "Fill"|"List"|"Flow"
function TabGroup:SetLayout(layout) end

---@param event string
---@param callback function
function TabGroup:SetCallback(event, callback) end

---@param tbl {text: string, value: string}[] text: label of tab; value: identifier of tab
function Label:SetTabs(tbl) end

---@param tab string identifier of tab
function Label:SelectTab(tab) end

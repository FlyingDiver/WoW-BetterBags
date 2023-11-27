local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class ColumnFrame: AceModule
local columnFrame = addon:NewModule('ColumnFrame')

---@class Column
---@field frame Frame
---@field cells Cell[]|Item[]|Section[]
---@field minimumWidth number
local columnProto = {}

-- AddCell adds a cell to this column at the given position, or
-- at the end of the column if no position is given.
---@param cell Cell|Item|Section
---@param position? number
function columnProto:AddCell(cell, position)
  cell.frame:SetParent(self.frame)
  if position and position < 1 then
    position = 1
  else
    position = position or #self.cells + 1
  end
  -- cell.position = position not sure if needed yet
  table.insert(self.cells, position, cell)
  cell.frame:Show()
end

-- GetCellPosition returns the cell's position as an integer in this column.
function columnProto:GetCellPosition(cell)
  for i, c in ipairs(self.cells) do
    if cell == c then return i end
  end
end

-- RemoveCell removes a cell from this column.
function columnProto:RemoveCell(cell)
  for i, c in ipairs(self.cells) do
    if cell == c then
      table.remove(self.cells, i)
      return
    end
  end
end

function columnProto:RemoveAll()
  for _, cell in pairs(self.cells) do
    cell.frame:SetParent(nil)
    cell.frame:ClearAllPoints()
  end
  wipe(self.cells)
end

function columnProto:Release()
  columnFrame:Release(self)
end

function columnProto:Wipe()
  self.frame:Hide()
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.minimumWidth = 0
  for _, cell in ipairs(self.cells) do
    cell:Release()
  end
  wipe(self.cells)
end

--TODO(lobato): Figure out if we need to do cell compaction.
-- Draw will full redraw this column and snap all cells into the correct
-- position.
---@param style? GridCompactStyle
function columnProto:Draw(style)
  if not style then style = const.GRID_COMPACT_STYLE.NONE end
  local w = self.minimumWidth
  local h = 0
  ---@type table
  ---@type table<any, number>
  local cellToRow = {}
  ---@type table<number, {count: number}>
  local rows = {}
  ---@type table<number, any>
  local firstCellInRow = {}
  for cellPos, cell in ipairs(self.cells) do
    cell.frame:ClearAllPoints()
    w = math.max(w, cell.frame:GetWidth())
    if cellPos == 1 then
      cell.frame:SetPoint("TOPLEFT", self.frame)
      h = h + cell.frame:GetHeight()
      if style == const.GRID_COMPACT_STYLE.SIMPLE then
        cellToRow[cell] = 1
        rows[1] = {count = #cell.content.cells}
        firstCellInRow[1] = cell
      end
    elseif style == const.GRID_COMPACT_STYLE.NONE then
      cell.frame:SetPoint("TOPLEFT", self.cells[cellPos - 1].frame, "BOTTOMLEFT", 0, -4)
      h = h + cell.frame:GetHeight() + 4
    elseif style == const.GRID_COMPACT_STYLE.SIMPLE then
      local aboveCell = self.cells[cellPos - 1]
      local rowData = rows[cellToRow[aboveCell]]
      if rowData.count + #cell.content.cells <= cell.content.maxCellWidth then
        cell.frame:SetPoint("TOPLEFT", aboveCell.frame, "TOPRIGHT", 0, 0)
        rows[cellToRow[aboveCell]].count = rows[cellToRow[aboveCell]].count + #cell.content.cells
        cellToRow[cell] = cellToRow[aboveCell]
      else
        local first = firstCellInRow[#rows]
        cell.frame:SetPoint("TOPLEFT", first.frame, "BOTTOMLEFT", 0, -4)
        h = h + cell.frame:GetHeight()
        local newRow = #rows + 1
        rows[newRow] = {count = #cell.content.cells}
        cellToRow[cell] = newRow
        firstCellInRow[newRow] = cell
      end
    end
  end
  self.frame:SetSize(w, h)
  self.frame:Show()
  return w, h
end

------
--- Column Frame
------
function columnFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
end

---@return Column
function columnFrame:_DoCreate()
  local column = setmetatable({}, {__index = columnProto})
  ---@class Frame: BackdropTemplate
  local f = CreateFrame('Frame', nil, nil, "BackdropTemplate")
  column.frame = f
  column.minimumWidth = 0
  column.cells = {}
  column.frame:Show()
  return column
end

---@param c Column
function columnFrame:_DoReset(c)
  c:Wipe()
end

---@return Column
function columnFrame:Create()
  return self._pool:Acquire()
end

---@param c Column
function columnFrame:Release(c)
  self._pool:Release(c)
end
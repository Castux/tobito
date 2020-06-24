local js = require "js"

local context

local function get_div_cell(div)
    for i = 0, div.classList.length - 1 do
        local class = div.classList[i]
        local cell_num = class:match "^cell(%d+)$"
        if cell_num then
            return tonumber(cell_num)
        end
    end
end

local function get_pawn_at_cell(cell)

    for _,div in ipairs(context.pawns) do
        local c = get_div_cell(div)
        if c == cell then
            return div
        end
    end
end

local function set_pawn_cell(div, cell)

    local num = get_div_cell(div)
    div.classList:replace("cell" .. num, "cell" .. cell)
end

local function deselect()

    if context.selected then
        context.selected.classList:remove "selected"
        context.selected = nil
    end
end

local function select(div)
    div.classList:add "selected"
    context.selected = div
end

local function on_pawn_clicked(self, e)

    local cell = get_div_cell(self)

    if context.selected == self then
        deselect()
    else
        deselect()
        select(self)
    end
end

local function on_trigger_clicked(self, e)

    local cell = get_div_cell(self)

    if context.selected then

        local previous = get_pawn_at_cell(cell)
        if previous then
            return
        end

        local pawn = context.selected
        deselect()

        pawn.parentElement:appendChild(pawn)

        js.global:setTimeout(function()
            set_pawn_cell(pawn, cell)
        end, 0.01)
    end

end

local function setup()

    local pawn_collection = js.global.document:getElementsByClassName "pawn"
    local pawns = {}

    for i = 0, pawn_collection.length - 1 do
        local p = pawn_collection[i]
        p:addEventListener("click", on_pawn_clicked)
        table.insert(pawns, p)
    end

    local trigger_collection = js.global.document:getElementsByClassName "trigger"
    local triggers = {}

    for i = 0, trigger_collection.length - 1 do
        local t = trigger_collection[i]
        t:addEventListener("click", on_trigger_clicked)
        table.insert(triggers, t)
    end

    context =
    {
        pawns = pawns,
        triggers = triggers
    }
end


setup()

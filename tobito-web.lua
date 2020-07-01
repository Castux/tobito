local js = require "js"
local tobito = require "tobito"

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

local function get_pawn_player(div)

    if div.classList:contains "top" then
        return tobito.Top
    else
        return tobito.Bottom
    end

end

local function set_pawn_cell(div, cell)

    local num = get_div_cell(div)
    div.classList:replace("cell" .. num, "cell" .. cell)
end

local function state_to_int()

    local s = {}
    for i = 0, tobito.MaxCell do
        s[i] = tobito.Empty
    end

    for _,div in ipairs(context.pawns) do
        local player = div.classList:contains "top" and tobito.Top or tobito.Bottom
        local cell = get_div_cell(div)

        s[cell] = player
    end

    s.next_player = context.next_player
    s.start = context.start

    return tobito.state_to_int(s)
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

    if context.pending_relocations then

        if self.classList:contains "toRelocate" then
            select(self)
        end

    else
        local cell = get_div_cell(self)
        local player = get_pawn_player(self)

        local valid = false

        for _,m in ipairs(context.next_moves) do
            if m[1] == cell then
                valid = true
                break
            end
        end

        if not valid then
            return
        end

        if context.selected == self then
            deselect()
        else
            deselect()
            select(self)
        end
    end
end

local function prepare_next_moves()

    local int = state_to_int()
    local s = tobito.int_to_state(int)

    print(tobito.draw_state(s))

    context.next_moves = {}

    for m in tobito.valid_moves(s) do
        print(table.concat(m, ","))
        table.insert(context.next_moves, m)
    end

end

local function get_relocations(from, to)

    local res = {}

    local to_relocate = {}
    local destinations = {}

    for _,m in ipairs(context.next_moves) do
        if m[1] == from and m[2] == to then
            for i = 3,#m,2 do
                to_relocate[m[i]] = true
                destinations[m[i+1]] = true
            end
        end
    end

    return to_relocate, destinations
end

local function end_of_move_admin()
    context.pending_relocations = false
    context.to_relocate = {}
    context.relocate_destinations = {}

    context.next_player = context.next_player == tobito.Top and tobito.Bottom or tobito.Top
    context.start = false

    prepare_next_moves()
end

local function make_move(pawn, dest)

    pawn.parentElement:appendChild(pawn)

    js.global:setTimeout(function()

        local to_relocate,destinations = get_relocations(get_div_cell(pawn), dest)

        context.pending_relocations = false

        for cell,_ in pairs(to_relocate) do
            context.pending_relocations = true
            context.to_relocate = to_relocate
            context.relocate_destinations = destinations

            local p = get_pawn_at_cell(cell)
            p.classList:add "toRelocate"
        end

        set_pawn_cell(pawn, dest)

        -- Move admin

        if not context.pending_relocations then
            end_of_move_admin()
        end
    end, 0.01)

end

local function is_valid_move(from, to)

    for _,m in ipairs(context.next_moves) do
        if m[1] == from and m[2] == to then
            return true
        end
    end

    return false
end

local function on_trigger_clicked(self, e)

    local cell = get_div_cell(self)

    if context.selected and not context.pending_relocations then

        local valid = is_valid_move(get_div_cell(context.selected), cell)
        if not valid then
            return
        end

        local pawn = context.selected
        deselect()

        make_move(pawn, cell)

    elseif context.selected and context.pending_relocations then

        assert(context.selected.classList:contains "toRelocate")
        if context.relocate_destinations[cell] then

            context.to_relocate[get_div_cell(context.selected)] = nil
            context.relocate_destinations[cell] = nil

            set_pawn_cell(context.selected, cell)
            context.selected.classList:remove "toRelocate"
            deselect()

            if not next(context.to_relocate) then
                end_of_move_admin()
            end
        end

    end

end

local function on_start_button_clicked(self, e)

    if self.id == "redStarts" then
        context.next_player = tobito.Top
    else
        context.next_player = tobito.Bottom
    end

    context.start = true

    local overlay = js.global.document:getElementById "startSelector"
    overlay.parentElement:removeChild(overlay)

    prepare_next_moves()
end

local function on_ai_selector_clicked(self, e)

    local player = (self.parentElement.id == "topSelector") and tobito.Top or tobito.Bottom

    local siblings = self.parentElement.children
    for i = 0, siblings.length - 1 do
        siblings[i].classList:remove "aiSelected"
    end

    self.classList:add "aiSelected"

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

    local starter_buttons = js.global.document:getElementsByClassName "starterButton"
    for i = 0, starter_buttons.length - 1 do
        local b = starter_buttons[i]
        b:addEventListener("click", on_start_button_clicked)
    end

    local ai_selectors = js.global.document:getElementsByClassName "aiSelectorButton"
    for i = 0, ai_selectors.length - 1 do
        local b = ai_selectors[i]
        b:addEventListener("click", on_ai_selector_clicked)
    end

    local ai = {[tobito.Top] = "Human", [tobito.Bottom] = "Human"}

    context =
    {
        pawns = pawns,
        triggers = triggers,
        ai = ai
    }
end

setup()

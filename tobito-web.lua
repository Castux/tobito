local js = require "js"
local tobito = require "tobito"
local tobito_ai = require "ai"


local context
local ai_data

local end_of_move_admin

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
    elseif div.classList:contains "bottom" then
        return tobito.Bottom
    else
        return tobito.Neutral
    end

end

local function set_pawn_cell(div, cell)

    local num = get_div_cell(div)
    if num then
        div.classList:replace("cell" .. num, "cell" .. cell)
    else
        div.classList:add("cell" .. cell)
    end
end

local function state_to_int()

    local s = {}
    for i = 0, tobito.MaxCell do
        s[i] = tobito.Empty
    end

    for _,div in ipairs(context.pawns) do
        local player = get_pawn_player(div)
        local cell = get_div_cell(div)
        if cell then
            s[cell] = player
        end
    end

    s.next_player = context.next_player

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

local function load_ai_data()

    context.ai = {[tobito.Top] = "Human", [tobito.Bottom] = "Human"}
    ai_data = {}

    local req = js.new(js.global.XMLHttpRequest)
    req:open('GET', "data.dat")
    req.responseType = "arraybuffer"
    req.onload = function()

        local arr = js.new(js.global.Int32Array, req.response)

        for i = 0, arr.length - 1 do
            local int = arr[i]

            local win = int >> 30
	        local state = int & 0x3fffffff

            ai_data[state] =
                (win == tobito.Top) and 1
                or (win == tobito.Bottom) and -1
                or 0
        end

        local loadingScreen = js.global.document:getElementById "loadingScreen"
        loadingScreen.style.display = "none";
    end

    req:send()
end

local function apply_ai_move(m)

    for i = 1,#m,2 do
        local pawn = get_pawn_at_cell(m[i])
        set_pawn_cell(pawn, m[i+1])
    end

    end_of_move_admin()
end

local function try_ai_move()

    local ai = context.ai[context.next_player]
    if ai == "Human" then
        return
    end

    local exclude
    if not context.repetitions then
        exclude = context.positions_played
    end

    local state_int = state_to_int()

    local strategy
    if ai == "Aggressive AI" then
        strategy = "aggressive"
    elseif ai == "Balanced AI" then
        strategy = "balanced"
    elseif ai == "Prudent AI" then
        strategy = "prudent"
    else
        error "Bad AI button"
    end

    local ai_picks = tobito_ai.decide_state(state_int, ai_data, strategy, exclude)

    if #ai_picks == 0 then
        return
    end

    local ai_pick = ai_picks[math.random(#ai_picks)]

    local ai_move

    for _,move in ipairs(context.next_moves) do

        local state = tobito.int_to_state(state_int)
        tobito.apply_move(state, move)
        local next_state_int = tobito.state_to_int(state)

        if next_state_int == ai_pick then
            ai_move = move
            break
        end
    end

    if ai_move then
        apply_ai_move(ai_move)
    end
end

local function prepare_next_moves()

    local int = state_to_int()
    context.positions_played[int] = true

    local s = tobito.int_to_state(int)

    local exclude
    if not context.repetitions then
        exclude = context.positions_played
    end
    context.next_moves = {}

    for m in tobito.valid_moves(s, exclude) do
        table.insert(context.next_moves, m)
    end

    try_ai_move()
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

end_of_move_admin = function()
    context.pending_relocations = false
    context.to_relocate = {}
    context.relocate_destinations = {}

    context.next_player = context.next_player == tobito.Top and tobito.Bottom or tobito.Top

    js.global:setTimeout(function()
        prepare_next_moves()
    end, 1000)
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

        local pawn = context.selected

        if context.relocate_destinations[cell] then

            context.to_relocate[get_div_cell(pawn)] = nil
            context.relocate_destinations[cell] = nil

            pawn.parentElement:appendChild(pawn)

            js.global:setTimeout(function()

                set_pawn_cell(pawn, cell)
                pawn.classList:remove "toRelocate"
                deselect()

                if not next(context.to_relocate) then
                    end_of_move_admin()
                end
            end, 0.1)

        end

    end

end

local function on_start_button_clicked(self, e)

    if self.id:match "red" then
        context.next_player = tobito.Top
    else
        context.next_player = tobito.Bottom
    end

    local haneto = self.id:match "Haneto"
    for _,div in ipairs(context.pawns) do
        if div.classList:contains "neutral" then

            set_pawn_cell(div, 7)

            if haneto then
                div.style.display = ""
            else
                div.style.display = "none";
                div.classList:remove "cell7"
            end

            break
        end
    end

    context.positions_played = {}
    context.positions_played[state_to_int()] = true

    local overlay = js.global.document:getElementById "startSelector"
    overlay.style.display = "none"

    prepare_next_moves()
end

local function on_ai_selector_clicked(self, e)

    local player = (self.parentElement.id == "topSelector") and tobito.Top or tobito.Bottom

    local siblings = self.parentElement.children
    for i = 0, siblings.length - 1 do
        siblings[i].classList:remove "aiSelected"
    end

    self.classList:add "aiSelected"

    context.ai[player] = self.innerHTML

    if context.next_player then
        try_ai_move()
    end
end

local function reset()

    local top_index = 0
    local bottom_index = 12

    for _,pawn in ipairs(context.pawns) do

        local player = get_pawn_player(pawn)

        if player == tobito.Top then
            set_pawn_cell(pawn, top_index)
            top_index = top_index + 1
        elseif player == tobito.Bottom then
            set_pawn_cell(pawn, bottom_index)
            bottom_index = bottom_index + 1
        else
            pawn.style.display = "none"
        end

    end

    context.next_player = nil
    context.next_moves = {}
    context.positions_played = {}

    local overlay = js.global.document:getElementById "startSelector"
    overlay.style:removeProperty "display"

    overlay.parentElement:appendChild(overlay)

end

local function toggle_repetitions()

    local rep_button = js.global.document:getElementById "repButton"

    context.repetitions = not context.repetitions
    if context.repetitions then
        rep_button.innerHTML = "Repetitions ok"
    else
        rep_button.innerHTML = "No repetitions"
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

    local reset_button = js.global.document:getElementById "resetButton"
    reset_button:addEventListener("click", reset)

    local rep_button = js.global.document:getElementById "repButton"
    rep_button:addEventListener("click", toggle_repetitions)

    context =
    {
        pawns = pawns,
        triggers = triggers,
        repetitions = false
    }

    load_ai_data()
    math.randomseed(os.time())
end

setup()

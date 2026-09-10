-----------------------------------------------------------------------------
-- HGSS Bug-Catching Contest support
-- Reuses the existing target matching, shiny detection, subdue, and battle
-- handling while keeping contest-specific movement/catching isolated.
--
-- In HGSS Bug-Catching Contest battles, selecting BAG does not open the
-- normal Ball pocket. The game converts that input directly into the contest
-- Sport Ball throw command. This mode intentionally relies on that game
-- behavior instead of inventing a Sport Ball inventory pointer.
-----------------------------------------------------------------------------

local catch_pokemon_standard = catch_pokemon

local function in_bug_contest_area()
    return game_state and game_state.in_game and game_state.map_name == "National Park"
end

local function catch_bug_contest_pokemon()
    print("Bug-Catching Contest target found. Throwing Sport Balls...")

    while game_state.in_battle do
        -- Wait until the main battle menu is ready.
        while game_state.in_battle and mbyte(pointers.battle_menu_state) ~= 1 do
            press_sequence("B", 8)
        end

        if not game_state.in_battle then
            break
        end

        wait_frames(20)

        -- HGSS maps BAG input to the contest Sport Ball throw command when
        -- BATTLE_TYPE_BUG_CONTEST is active.
        touch_screen_at(38, 174)

        -- Safety guard: outside the contest this input opens the regular Bag.
        -- Watch a timing window rather than checking one fixed frame so slower
        -- transitions cannot make the bot miss the normal Bag screen.
        for _ = 1, 90 do
            if not game_state.in_battle then
                break
            end

            if get_battle_state() == "Bag" then
                abort("Bug-Catching Contest mode is not active in-game. Enter the contest before starting this bot mode.")
            end

            wait_frames(1)
        end

        -- Wait for either a failed catch (battle menu returns) or for the
        -- battle to end. Avoid A inputs so the post-catch swap UI is not
        -- accidentally accepted.
        while game_state.in_battle and mbyte(pointers.battle_menu_state) ~= 1 do
            press_sequence("B", 8)
            touch_screen_at(0, 0)
        end
    end

    -- The game owns the contest lifecycle after battle: a successful catch
    -- enters the keep/swap flow, and reaching zero Sport Balls transitions to
    -- the built-in judging scripts. Stop here instead of duplicating either.
    abort("Bug-Catching Contest target battle ended. Verify the battle outcome and finish the contest manually.")
end

-- Preserve every existing HGSS catch path. Only the explicit contest mode
-- receives the Sport Ball behavior above.
function catch_pokemon()
    if config.mode == "bug_contest" then
        return catch_bug_contest_pokemon()
    end

    return catch_pokemon_standard()
end

-- Mirrors Falin-Mor's Gen IV random-encounter movement, but adds a National
-- Park boundary check. This is important because the base implementation
-- otherwise waits indefinitely for a battle even after the contest time-up
-- script has moved the player to judging.
local function move_until_bug_contest_encounter()
    local all_dirs = {"Up", "Down", "Left", "Right"}

    if config.move_direction == "spin" then
        local facing_value = mbyte(pointers.facing)
        local facing_dir = all_dirs[facing_value + 1]

        while not game_state.in_battle and in_bug_contest_area() do
            for _, dir in ipairs(all_dirs) do
                if dir ~= facing_dir then
                    press_sequence(dir, 3)

                    if game_state.in_battle or not in_bug_contest_area() then
                        break
                    end
                end
            end
        end
    else
        local dir1, dir2, start_face

        if config.move_direction == "horizontal" then
            dir1 = "Left"
            dir2 = "Right"
            start_face = 0
        else
            dir1 = "Up"
            dir2 = "Down"
            start_face = 2
        end

        if in_bug_contest_area() and mbyte(pointers.facing) ~= start_face then
            press_sequence(dir2, 8)
        end

        if in_bug_contest_area() and not game_state.in_battle then
            hold_button("B")
        end

        while not game_state.in_battle and in_bug_contest_area() do
            hold_button(dir1)
            wait_frames(7)
            release_button(dir1)

            if game_state.in_battle or not in_bug_contest_area() then
                break
            end

            hold_button(dir2)
            wait_frames(7)
            release_button(dir2)
        end
    end

    clear_all_inputs()
end

--- Hunts Bug-Catching Contest encounters. The contest itself must already be
--- active when started. The game remains the source of truth for timer,
--- Sport Ball count, keep/swap, and judging transitions.
function mode_bug_contest()
    if not game_state or not game_state.in_game then
        print("Waiting to reach the overworld...")

        while not game_state or not game_state.in_game do
            process_frame()
        end
    end

    if not in_bug_contest_area() then
        abort("Bug-Catching Contest mode must be started inside National Park after entering the contest.")
    end

    print("Attempting to start a Bug-Catching Contest encounter...")
    wait_frames(30)
    move_until_bug_contest_encounter()

    if not game_state.in_battle then
        abort("Bug-Catching Contest ended or the player left National Park. Stopping safely.")
    end

    process_wild_encounter()
end

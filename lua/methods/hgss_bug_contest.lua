-----------------------------------------------------------------------------
-- HGSS Bug-Catching Contest support
-- Reuses the existing random-encounter, target matching, and subdue logic.
--
-- In HGSS Bug-Catching Contest battles, selecting BAG does not open the
-- normal Ball pocket. The game converts that input directly into the contest
-- Sport Ball throw command. This mode intentionally relies on that game
-- behavior instead of inventing a Sport Ball inventory pointer.
-----------------------------------------------------------------------------

local catch_pokemon_standard = catch_pokemon

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
        wait_frames(30)

        -- Safety guard: outside the contest this input opens the regular Bag.
        -- Stop rather than navigating/using a normal Poke Ball by mistake.
        if game_state.in_battle and get_battle_state() == "Bag" then
            abort("Bug-Catching Contest mode is not active in-game. Enter the contest before starting this bot mode.")
        end

        -- Wait for either a failed catch (battle menu returns) or for the
        -- battle to end. Avoid A inputs so the post-catch swap UI is not
        -- accidentally accepted.
        while game_state.in_battle and mbyte(pointers.battle_menu_state) ~= 1 do
            press_sequence("B", 8)
            touch_screen_at(0, 0)
        end
    end

    -- A successful contest catch opens a separate swap/keep flow after the
    -- battle. Stop here so the user can verify the result and finish the
    -- contest safely. This also handles the out-of-Sport-Balls path without
    -- falsely claiming the target was caught.
    abort("Bug-Catching Contest target battle ended. Verify the caught Pokemon and finish the contest manually.")
end

-- Preserve every existing HGSS catch path. Only the explicit contest mode
-- receives the Sport Ball behavior above.
function catch_pokemon()
    if config.mode == "bug_contest" then
        return catch_bug_contest_pokemon()
    end

    return catch_pokemon_standard()
end

--- Hunts Bug-Catching Contest encounters using the existing Gen IV random
--- encounter engine. The contest itself must already be active when started.
function mode_bug_contest()
    if game_state.in_game and game_state.map_name ~= "National Park" then
        abort("Bug-Catching Contest mode must be started inside National Park after entering the contest.")
    end

    mode_random_encounters()
end

local wezterm = require("wezterm")
local act = wezterm.action
local agent_deck = wezterm.plugin.require("https://github.com/Eric162/wezterm-agent-deck")
local config = wezterm.config_builder()
agent_deck.apply_to_config(config, {
    notifications = { enabled = true, on_waiting = true },
    tab_title = { enabled = false },
})
-- =========================
-- Rename Timestamps (for manual rename vs auto-status priority)
-- =========================
local rename_timestamps = {}
local function prune_rename_timestamps()
    local valid = {}
    local ok, wins = pcall(function() return wezterm.mux.all_windows() end)
    if ok and wins then
        for _, w in ipairs(wins) do
            for _, t in ipairs(w:tabs() or {}) do
                local p = t:active_pane()
                if p then valid[p:pane_id()] = true end
            end
        end
        for pid in pairs(rename_timestamps) do
            if not valid[pid] then rename_timestamps[pid] = nil end
        end
    end
    wezterm.time.call_after(300, prune_rename_timestamps)
end
prune_rename_timestamps()
-- =========================
-- Session Tracking (file-based, instant, no CLI needed)
-- =========================
local SESSIONS_FILE = wezterm.config_dir .. "/sessions.txt"

-- The session we were in before the current one, so Leader+w can bounce back.
-- Set inside switch_to_session (the single switch path) so it's always accurate
-- the instant you switch — no reliance on the status timer.
local prev_workspace = nil

-- Small toast helper: wezterm has no in-terminal "message" action (the old
-- act.ShowMessage this config used does not exist), so use an OS toast.
local function notify(window, msg)
    pcall(function() window:toast_notification("WezTerm", msg, nil, 2500) end)
end

local function read_sessions()
    local sessions = {}
    local f = io.open(SESSIONS_FILE, "r")
    if f then
        for line in f:lines() do
            if line and #line > 0 then sessions[line] = true end
        end
        f:close()
    end
    return sessions
end

local function save_sessions(sessions)
    local f = io.open(SESSIONS_FILE, "w")
    if f then
        for name in pairs(sessions) do f:write(name .. "\n") end
        f:close()
    end
end

local function add_session(name)
    local s = read_sessions(); s[name] = true; save_sessions(s)
end

local function remove_session(name)
    local s = read_sessions(); s[name] = nil; save_sessions(s)
end

-- Every known session = live workspaces UNION names remembered in the file.
local function all_sessions()
    local set = read_sessions()
    local ok, live = pcall(function() return wezterm.mux.get_workspace_names() end)
    if ok and live then
        for _, w in ipairs(live) do set[w] = true end
    end
    local list = {}
    for name in pairs(set) do table.insert(list, name) end
    table.sort(list)
    return list
end

-- Switch to (creating if needed) the named session on the mux domain.
-- No AttachDomain here: the GUI is already attached to mux at startup
-- (see default_gui_startup_args), so SwitchToWorkspace with a mux spawn
-- domain just creates/switches the ONE workspace we want. Calling
-- AttachDomain here is what re-imported every existing mux window and made
-- this look like it launched a second WezTerm.
local function switch_to_session(window, pane, name)
    -- Remember where we're leaving from so Leader+w can bounce back to it.
    local cur = window:active_workspace()
    if cur and cur ~= name then prev_workspace = cur end
    add_session(name)
    window:perform_action(
        act.SwitchToWorkspace {
            name = name,
            spawn = { domain = { DomainName = "mux" } },
        },
        pane
    )
end

-- Close every tab that belongs to a workspace, wherever it lives.
local function close_workspace_tabs(window, name)
    local ok, wins = pcall(function() return wezterm.mux.all_windows() end)
    if ok and wins then
        local panes = {}
        for _, mw in ipairs(wins) do
            if mw:get_workspace() == name then
                for _, tab in ipairs(mw:tabs() or {}) do
                    local p = tab:active_pane()
                    if p then table.insert(panes, p) end
                end
            end
        end
        for _, p in ipairs(panes) do
            window:perform_action(act.CloseCurrentTab { confirm = false }, p)
        end
    end
end

local function kill_session(window, name)
    close_workspace_tabs(window, name)
    remove_session(name)
end

local function bulk_delete_mode(window, pane)
    local marked = {}; local marked_count = 0

    local function show_bulk()
        local choices = {}
        table.insert(choices, { id = "\1del", label = "✓  Delete marked (" .. marked_count .. ")" })
        table.insert(choices, { id = "\1cancel", label = "✗  Cancel" })
        table.insert(choices, { id = "\1sep", label = "─── toggle sessions ───" })

        local current = window:active_workspace()
        for _, name in ipairs(all_sessions()) do
            if name ~= current then
                local marker = marked[name] and "☑  " or "☐  "
                table.insert(choices, { id = name, label = marker .. name })
            end
        end

        window:perform_action(act.InputSelector {
            title = "Bulk delete — select sessions to mark",
            fuzzy = true,
            fuzzy_description = "Mark sessions to delete: ",
            choices = choices,
            action = wezterm.action_callback(function(win, pane, id, _label)
                if not id or id == "\1cancel" then return end
                if id == "\1sep" then show_bulk(); return end
                if id == "\1del" then
                    local names = {}
                    for n in pairs(marked) do table.insert(names, n) end
                    table.sort(names)
                    if #names == 0 then
                        notify(win, "No sessions marked for deletion.")
                        show_bulk()
                        return
                    end
                    win:perform_action(act.InputSelector {
                        title = "Delete " .. #names .. " sessions?",
                        choices = {
                            { id = "yes", label = "󰄬  Yes, delete " .. #names .. " sessions" },
                            { id = "no",  label = "󰅖  Cancel" },
                        },
                        action = wezterm.action_callback(function(win, pane, id2)
                            if id2 == "yes" then
                                for _, n in ipairs(names) do
                                    kill_session(win, n)
                                end
                                notify(win, "Deleted " .. #names .. " sessions.")
                            end
                        end),
                    }, pane)
                    return
                end
                -- Toggle session
                if marked[id] then marked[id] = nil; marked_count = marked_count - 1 else marked[id] = true; marked_count = marked_count + 1 end
                show_bulk()
            end),
        }, pane)
    end

    show_bulk()
end

-- =========================
-- Performance & Memory
-- =========================
config.front_end = "OpenGL"
config.max_fps = 60
config.animation_fps = 60
config.cursor_blink_rate = 500
config.scrollback_lines = 1000
config.enable_scroll_bar = false
config.check_for_updates = false
config.status_update_interval = 5000
config.unicode_version = 14
config.tab_max_width = 48
config.clean_exit_codes = {}
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"
--ssh alltop wezterm multiplexing
config.ssh_domains = {
  {
    name = 'cpanel-alltop',
    remote_address = 'node2.webhostnepal.net',
    username = 'alltopgr',
    -- WezTerm will pick up your existing ~/.ssh/config automatically
  },
}
config.unix_domains = {
  {
    name = 'mux',
  },
}

-- Auto-connect the GUI to the background mux server on every launch.
-- Connecting to a unix domain auto-starts wezterm-mux-server if it isn't
-- already running, so there is NO manual `wezterm-mux-server --daemonize`
-- step any more. On relaunch this REATTACHES to the existing mux windows
-- (it imports them, it does not duplicate them), which is why every
-- workspace you create now lives on mux and is persistent by default.
-- Because the whole GUI is already attached to mux at startup, none of the
-- keybindings below need AttachDomain — that action is what used to
-- re-import every window and make Leader+a look like it "spawned another
-- WezTerm". It's gone now.
config.default_gui_startup_args = { 'connect', 'mux' }

-- Session / workspace model (UNIFIED — everything lives on the mux server):
--   There is only one primitive: the workspace. Because the GUI attaches to
--   the `mux` domain at startup, EVERY workspace/tab you open runs on the
--   background mux server and survives a full GUI close. "Session" and
--   "workspace" are now the same thing — a named, persistent workspace.
--   Leader+a       = create/switch to a named session (blank = "default")
--   Leader+w       = toggle back to your previous session (bounce between two)
--   Leader+'       = session hub: pick to switch instantly; create + manage
--                    (rename/delete) behind their own entries
--   Leader+d       = close current tab (its workspace stays on the server)
--   Leader+g       = delete a tracked session
--   To step away:   just close the GUI window — the mux server keeps every
--                   pane alive; relaunching WezTerm reattaches them.
-- =========================
-- Window & Appearance
-- =========================
config.window_decorations = "RESIZE"
config.default_prog = { "nu" }
config.text_background_opacity = 1.0
-- = :Curated Font List (Comment/Uncomment the ones you like):
-- [MODERN/SLIM]    : "0xProto Nerd Font Mono", "JetBrainsMono NF", "Iosevka Nerd Font"
-- [HANDWRITTEN]   : "VictorMono Nerd Font", "FantasqueSansM Nerd Font", "MonaspiceRn Nerd Font"
-- [UNIQUE/PIXEL]   : "Monoid Nerd Font", "Agave Nerd Font", "DaddyTimeMono Nerd Font"
-- [FUNKY/CARTOON]  : "ComicShannsMono Nerd Font", "Comic Sans MS"
config.font = wezterm.font_with_fallback({
    "Monoid Nerd Font",
    "JetBrainsMono NF",
})
config.font_size = 12
-- config.font_size = 15
-- = :Standard Verified Themes:
-- "Dracula", "Tokyo Night", "Kanagawa", "Nord", "One Dark (Gogh)"
-- "Catppuccin Mocha", "Catppuccin Macchiato", "Rosé Pine", "Rosé Pine Moon"
-- "Gruvbox Dark (Gogh)", "Monokai Pro", "Cyberpunk (Gogh)"
-- = :Funky / Anime / Neon Themes:
-- "Aura", "Synthwave (Gogh)", "Outrun Dark", "Nightfly"
-- "Yorumi", "Miku (Gogh)", "Evangelion-01 (Gogh)", "Neon (Gogh)"
-- Full Gallery: https://wezfurlong.org/wezterm/colorschemes/index.html
-- rose-pine-moon // this one is also beautiful
config.color_scheme = "rose-pine-moon"
config.window_padding = {
    left = 8,
    right = 8,
    top = 8,
    bottom = 8,
}
config.window_frame = {
    border_left_width = "0",
    border_right_width = "0",
    border_bottom_height = "0",
    border_top_height = "0",
    inactive_titlebar_bg = "#1e1e2e",
    active_titlebar_bg = "#1e1e2e",
    inactive_titlebar_fg = "#cdd6f4",
    active_titlebar_fg = "#cdd6f4",
}
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
-- =========================
-- Background
-- =========================
-- Uncomment one background image if desired:
-- config.background = {
--     {
--         source = {
--             File = "C:/Users/kshit/.config/wezterm/background/manAuraRed.jpg" },
--         width = "100%",
--         height = "100%",
--         repeat_x = "NoRepeat",
--         repeat_y = "NoRepeat",
--         hsb = {
--             brightness = 0.7,
--             hue = 1.0,
--             saturation = 1.0,
--         },
--         attachment = "Fixed",
--     },
-- }

-- =========================
-- Cursor
-- =========================
-- cursor_blink_rate already set in Performance section above
config.default_cursor_style = "SteadyBar"
config.force_reverse_video_cursor = true
-- =========================
-- Tab Bar Colors
-- =========================
config.colors = {
    tab_bar = {
        background = "#1e1e2e",
        active_tab = {
            bg_color = "#cba6f7",
            fg_color = "#1e1e2e",
        },
        inactive_tab = {
            bg_color = "#585b70",
            fg_color = "#cdd6f4",
        },
        inactive_tab_hover = {
            bg_color = "#6c7086",
            fg_color = "#cdd6f4",
        },
    },
}
-- =========================
-- Leader Key
-- =========================
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }
-- =========================
-- Keybindings
-- =========================
config.keys = {
    { mods = "LEADER",       key = "s", action = act.PaneSelect { mode = "SwapWithActive" } },
    { mods = "LEADER",       key = "c", action = act.SpawnTab("CurrentPaneDomain") },
    { mods = "LEADER",       key = "x", action = act.CloseCurrentPane { confirm = true } },
    { mods = "LEADER",       key = "b", action = act.ActivateTabRelative(-1) },
    { mods = "LEADER",       key = "n", action = act.ActivateTabRelative(1) },
    -- Toggle back to your previous session (bounce between the two you use).
    { mods = "LEADER", key = "w", action = wezterm.action_callback(function(window, pane)
        local cur = window:active_workspace()
        if prev_workspace and prev_workspace ~= cur then
            switch_to_session(window, pane, prev_workspace)
        else
            -- No previous session yet — show the switcher so the key is never dead.
            window:perform_action(act.ShowLauncherArgs { flags = "WORKSPACES" }, pane)
        end
    end)},
    -- Close all tabs in CURRENT workspace (with prompt)
    { mods = "LEADER",       key = "t", action = act.ShowTabNavigator },
    { mods = "LEADER",       key = "p", action = act.ActivateCommandPalette },
    { mods = "LEADER",       key = "\\", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { mods = "LEADER",       key = "-",  action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { mods = "LEADER",       key = "h", action = act.ActivatePaneDirection("Left") },
    { mods = "LEADER",       key = "j", action = act.ActivatePaneDirection("Down") },
    { mods = "LEADER",       key = "k", action = act.ActivatePaneDirection("Up") },
    { mods = "LEADER",       key = "l", action = act.ActivatePaneDirection("Right") },
    { mods = "LEADER|SHIFT", key = "h", action = act.AdjustPaneSize({ "Left", 22 }) },
    { mods = "LEADER|SHIFT", key = "l", action = act.AdjustPaneSize({ "Right", 22 }) },
    { mods = "LEADER|SHIFT", key = "j", action = act.AdjustPaneSize({ "Down", 22 }) },
    { mods = "LEADER|SHIFT", key = "k", action = act.AdjustPaneSize({ "Up", 22 }) },
    { mods = "CTRL|SHIFT",   key = "R", action = act.ReloadConfiguration },
    { mods = "CTRL|SHIFT",   key = "C", action = act.CopyTo("Clipboard") },
    { mods = "CTRL|SHIFT",   key = "V", action = act.PasteFrom("Clipboard") },
    -- Theme picker
    { mods = "LEADER", key = "T", action = act.InputSelector {
        title = "Theme Picker",
        alphabet = "abcdefghijklmnopqrstuvwxyz",
        choices = {
            { label = "rose-pine-moon" },
            { label = "Catppuccin Mocha" },
            { label = "Catppuccin Macchiato" },
            { label = "Tokyo Night" },
            { label = "Dracula" },
            { label = "Kanagawa" },
            { label = "Nord" },
            { label = "One Dark (Gogh)" },
            { label = "Gruvbox Dark (Gogh)" },
            { label = "Monokai Pro" },
            { label = "Ayu Dark" },
            { label = "Palenight (Gogh)" },
            { label = "Espresso (Gogh)" },
            { label = "Andromeda" },
            { label = "Rosé Pine" },
            { label = "Solarized Dark (Gogh)" },
            { label = "MaterialDark" },
        },
        action = wezterm.action_callback(function(window, pane, id, label)
            if label then
                local overrides = window:get_config_overrides() or {}
                overrides.color_scheme = label
                window:set_config_overrides(overrides)
            end
        end),
    }},
    -- Rename tab
    { mods = "LEADER", key = "r", action = act.PromptInputLine {
        description = "Rename tab",
        action = wezterm.action_callback(function(window, pane, line)
            if line then
                window:active_tab():set_title(line)
                rename_timestamps[pane:pane_id()] = os.time()
            end
        end),
    }},
    -- Close ALL tabs in ALL windows — exits WezTerm entirely (with prompt)
    { mods = "LEADER|SHIFT", key = "q", action = act.PromptInputLine {
        description = "Quit WezTerm entirely? (y/n)",
        action = wezterm.action_callback(function(window, pane, line)
            if line and line:lower() == "y" then
                window:perform_action(act.QuitApplication, pane)
            end
        end),
    }},
    -- Create / switch to a named session (tmux: new -A -s <name>)
    { mods = "LEADER", key = "a", action = act.PromptInputLine {
        description = "Session name (blank = default mux session):",
        action = wezterm.action_callback(function(window, pane, line)
            if line and #line > 0 then
                switch_to_session(window, pane, line)
            else
                switch_to_session(window, pane, "default")
            end
        end),
    }},
    -- Detach: close tab, session stays alive on mux server
    { mods = "LEADER", key = "d", action = wezterm.action_callback(function(window, pane)
        local tab_count = #window:mux_window():tabs()
        if tab_count <= 1 then
            window:perform_action(act.SpawnTab("DefaultDomain"), pane)
        end
        window:perform_action(act.CloseCurrentTab { confirm = false }, pane)
    end)},
    -- Delete a tracked session
    { mods = "LEADER", key = "g", action = wezterm.action_callback(function(window, pane)
        local choices = {}
        for _, name in ipairs(all_sessions()) do
            table.insert(choices, { id = name, label = name })
        end
        if #choices > 0 then
            window:perform_action(
                act.InputSelector {
                    title = "Delete Session",
                    choices = choices,
                    action = wezterm.action_callback(function(_, _, id)
                        if id then kill_session(window, id) end
                    end),
                },
                pane
            )
        end
    end)},
}
-- Tabs 1-9
for i = 1, 9 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = act.ActivateTab(i - 1),
    })
end
-- =========================
-- Initial Window Size
-- =========================
config.initial_cols = 140
config.initial_rows = 40
-- =========================
-- Visual Bell (flash instead of beep)
-- =========================
config.audible_bell = "Disabled"
config.visual_bell = {
    fade_in_duration_ms = 100,
    fade_out_duration_ms = 100,
    target = "BackgroundColor",
}
-- =========================
-- Font Ligatures
-- =========================
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
-- =========================
-- Hyperlink Rules (clickable paths/URLs)
-- =========================
config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
    regex = "\\bhttps?://(?:localhost|127\\.0\\.0\\.1)(?::\\d+)?\\S*\\b",
    format = "$0",
})
-- =========================
-- Quick Select Patterns
-- =========================
config.quick_select_patterns = {
    "[a-z]+(?:-[a-z0-9]+)+-[a-z0-9]+",  -- kebab-case identifiers
    "[A-Z][a-z]+(?:[A-Z][a-z]+)+",       -- PascalCase identifiers
    "[a-z]+(?:_[a-z0-9]+)+",             -- snake_case identifiers
}
-- =========================
-- Window Close Confirmation
-- =========================
config.window_close_confirmation = "AlwaysPrompt"
config.skip_close_confirmation_for_processes_named = {} -- empty = always confirm
-- =========================
-- Alt as Meta (better vim/terminal compatibility)
-- =========================
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false
-- =========================
-- Right Status Bar (date/time + hostname)
-- =========================
wezterm.on("update-right-status", function(window, pane)
    local date = wezterm.strftime("%Y-%m-%d %H:%M")
    local hostname = wezterm.hostname()
    local workspace = window:active_workspace()
    local status = ""
    if workspace and #workspace > 0 then
        status = workspace .. " | "
    end
    window:set_right_status(wezterm.format({
        { Text = status .. hostname .. " | " .. date },
    }))
end)
-- =========================
-- Tab Title Formatting (agent-deck dots + OpenCode status + fallback)
-- =========================
-- Cache the OpenCode attention file reads so format-tab-title doesn't hit
-- disk + parse JSON on every frame for every tab. Re-read at most once per
-- second per pane; the attention file changes rarely so this is invisible.
local custom_status_cache = {}
local custom_status_cache_ts = {}

local function read_custom_status(pane_id)
    local now = os.time()
    local entry = custom_status_cache[pane_id]
    local last = custom_status_cache_ts[pane_id]
    if entry and last and (now - last) < 1 then
        return entry.text, entry.ts
    end
    local path = wezterm.home_dir .. '/.local/state/wezterm-attention/' .. tostring(pane_id)
    local f = io.open(path, 'r')
    if not f then
        custom_status_cache[pane_id] = { text = nil, ts = nil }
        custom_status_cache_ts[pane_id] = now
        return nil, nil
    end
    local content = f:read('*a')
    f:close()
    local ok, decoded = pcall(wezterm.json_parse, content)
    local text, ts
    if ok and decoded and decoded.text then
        text, ts = decoded.text, (decoded.timestamp or 0) / 1000
    end
    custom_status_cache[pane_id] = { text = text, ts = ts }
    custom_status_cache_ts[pane_id] = now
    return text, ts
end

-- Basename of a pane's working directory (e.g. the repo/service folder).
-- Handy fallback title when no agent is running: tells you *where* the tab is
-- sitting instead of showing raw shell/command noise. Requires OSC 7 (shell
-- integration) to report the cwd; returns nil if unavailable.
local function cwd_basename(pane)
    local cwd = pane.current_working_dir
    if not cwd then return nil end
    local path
    local ok = pcall(function() path = cwd.file_path end)  -- newer wezterm: Url object
    if not ok or not path or #path == 0 then
        path = tostring(cwd):gsub("^file://[^/]*", "")     -- fallback: file://host/path
    end
    path = path
        :gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)  -- url-decode
        :gsub("[/\\]+$", "")                                                    -- trim trailing slash
    local base = path:match("([^/\\]+)$")
    if base and #base > 0 then return base end
    return nil
end

-- Nerd Font git-branch glyph (U+E0A0). Shown next to the repo folder in idle
-- tabs; the branch value comes from the `git_branch` user var that nushell
-- publishes via OSC 1337 SetUserVar on each prompt.
local BRANCH_ICON = utf8.char(0xE0A0)

-- Tab palette. Inactive tabs get a bg raised off the tab-bar background so they
-- read as distinct blocks (before, inactive == bar bg, so tabs blurred into one
-- another). A thin powerline divider between tabs guarantees separation even
-- when two neighbours share the same state/colour.
local ACTIVE_BG   = "#4b3f6e"   -- brightest: the focused tab
local ACTIVE_FG   = "#ffffff"
local INACTIVE_BG = "#2c2a40"   -- raised off the bar, dimmer than active
local INACTIVE_FG = "#a6accd"
local TABBAR_BG   = "#1e1e2e"   -- matches config.colors.tab_bar.background
-- Divider between tabs. Bright gold so each tab boundary is obvious at a
-- glance. Swap SEP_ICON for a different shape if you like:
--   0xE0B1 ""  thin chevron (current)   0xE0B0 ""  solid arrow (bold)
--   0x2503 "┃"  heavy bar               0x2502 "│"  light bar
local SEP_ICON    = utf8.char(0xE0B1)  --  thin right divider
local SEP_FG      = "#f6c177"           -- gold — high contrast vs the dark tab bar

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
    local pane = tab.active_pane
    if not pane then return {} end
    local state = agent_deck.get_agent_state(pane.pane_id)

    local bg = tab.is_active and ACTIVE_BG or INACTIVE_BG
    local fg = tab.is_active and ACTIVE_FG or INACTIVE_FG

    local elements = {}
    local reserved = 0

    -- OpenCode is considered active if agent_deck detects it OR the attention
    -- file was written recently by wezterm-title.js (proves OpenCode is alive
    -- in this pane even if agent_deck misses the process on Windows).
    local custom_text, custom_ts = read_custom_status(pane.pane_id)
    local opencode_active = (state ~= nil and state.agent_type == "opencode")
       or (custom_ts ~= nil and (os.time() - custom_ts) < 15)
    if not opencode_active then
        custom_text, custom_ts = nil, nil
    end

    -- "opencode: idle" / "opencode: starting" aren't useful as a tab title;
    -- fall back to directory+branch in those cases.
    if custom_text == "opencode: idle" or custom_text == "opencode: starting" then
        custom_text = nil
    end

    -- Synthesize an agent state for the icon when agent_deck missed detection
    -- but we know OpenCode is active via the fresh attention file. This ensures
    -- the agent_deck ●/◔/○ icon always renders for OpenCode panes.
    local effective_state = state
    if not effective_state and opencode_active then
        local st = custom_text and "working" or "idle"
        effective_state = { agent_type = "opencode", status = st }
    end

    if effective_state then
        table.insert(elements, { Background = { Color = bg } })
        table.insert(elements, { Foreground = { Color = agent_deck.get_status_color(effective_state.status) } })
        table.insert(elements, { Text = agent_deck.get_status_icon(effective_state.status) .. " " })
        reserved = 2
    end

    -- Width budget for the title text, measured in display *cells* (not bytes).
    -- -3 covers the two padding spaces and the trailing divider added below.
    local avail = math.max(max_width - reserved - 3, 6)

    local title
    if custom_text then
        title = custom_text:gsub("^opencode: ", "")
    elseif tab.tab_title and #tab.tab_title > 0 then
        title = tab.tab_title
    else
        local dir = cwd_basename(pane)
        if dir then
            local branch = pane.user_vars and pane.user_vars.git_branch
            if branch and #branch > 0 then
                -- Keep the branch readable: when folder + branch is wider than
                -- the tab, trim the *folder* (left) and leave the branch intact,
                -- instead of letting the branch fall off the right edge.
                local suffix = " " .. BRANCH_ICON .. " " .. branch
                local dir_budget = math.max(avail - wezterm.column_width(suffix), 3)
                if wezterm.column_width(dir) > dir_budget then
                    dir = wezterm.truncate_right(dir, dir_budget - 1) .. "…"
                end
                title = dir .. suffix
            else
                title = dir
            end
        else
            title = pane.title
            if not title or #title == 0 then
                title = pane.foreground_process_name:match("([^/\\]+)$") or "shell"
            end
        end
    end

    -- Final safety net for every other title source (renames, agent/OpenCode
    -- status, process names). Truncate by display width on a codepoint boundary
    -- so multi-byte glyphs (branch icon, box-drawing) are never sliced
    -- mid-character — a byte-wise cut renders as a broken box and looks clipped.
    if wezterm.column_width(title) > avail then
        title = wezterm.truncate_right(title, avail - 1) .. "…"
    end

    table.insert(elements, { Background = { Color = bg } })
    table.insert(elements, { Foreground = { Color = fg } })
    table.insert(elements, { Text = " " .. title .. " " })

    -- Thin divider between this tab and the next, so two tabs never look like
    -- one. Painted with the *next* tab's bg so it sits flush against it.
    local next_bg = TABBAR_BG
    for i, t in ipairs(tabs) do
        if t.tab_index == tab.tab_index then
            local nt = tabs[i + 1]
            if nt then next_bg = nt.is_active and ACTIVE_BG or INACTIVE_BG end
            break
        end
    end
    table.insert(elements, { Background = { Color = next_bg } })
    table.insert(elements, { Foreground = { Color = SEP_FG } })
    table.insert(elements, { Text = SEP_ICON })

    return elements
end)
return config

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- Theme persistence: save/restore across restarts
local THEME_FILE = wezterm.config_dir .. "/theme.txt"
local function read_saved_theme()
    local f = io.open(THEME_FILE, "r")
    if f then
        local theme = f:read("*a")
        if theme then theme = theme:gsub("%s+$", "") end
        f:close()
        if theme and #theme > 0 then return theme end
    end
    return nil
end
local function save_theme(name)
    local f = io.open(THEME_FILE, "w")
    if f then f:write(name); f:close() end
end

-- Apply saved theme on startup
local saved_theme = read_saved_theme()
if saved_theme then
    config.color_scheme = saved_theme
end

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

-- =========================
-- Performance & Memory
-- =========================
config.front_end = "OpenGL"
config.max_fps = 60
config.animation_fps = 60
config.cursor_blink_rate = 0
config.scrollback_lines = 5000
config.enable_scroll_bar = false
config.check_for_updates = false
config.status_update_interval = 30000

config.tab_max_width = 48

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
config.font = wezterm.font_with_fallback({
    "Monoid Nerd Font",
    "JetBrainsMono NF",
})
config.font_size = 12
if not saved_theme then config.color_scheme = "rose-pine-moon" end
config.window_padding = {
    left = 8,
    right = 8,
    top = 8,
    bottom = 8,
}
config.window_frame = {
    inactive_titlebar_bg = "#1e1e2e",
    active_titlebar_bg = "#1e1e2e",
    inactive_titlebar_fg = "#cdd6f4",
    active_titlebar_fg = "#cdd6f4",
}
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
-- =========================
-- Cursor
-- =========================
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
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 500 }
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
        title = "Theme Picker (Light + Dark)",
        alphabet = "abcdefghijklmnopqrstuvwxyz",
        choices = {
            -- ═══════════════ LIGHT THEMES ═══════════════
            { label = "──── Light ────" },
            { label = "Catppuccin Latte" },
            { label = "Catppuccin Latte (Gogh)" },
            { label = "Solarized Light (Gogh)" },
            { label = "Gruvbox light, medium (base16)" },
            { label = "Gruvbox light, soft (base16)" },
            { label = "Gruvbox light, hard (base16)" },
            { label = "One Light (Gogh)" },
            { label = "One Light (base16)" },
            { label = "Github (Gogh)" },
            { label = "Tokyo Night Light (Gogh)" },
            { label = "Rosé Pine Dawn (Gogh)" },
            { label = "Everforest Light (Gogh)" },
            { label = "Everforest Light Medium (Gogh)" },
            { label = "Everforest Light Soft (Gogh)" },
            { label = "flexoki-light" },
            { label = "Apple System Colors" },
            { label = "AtomOneLight" },
            { label = "Ayu Light (Gogh)" },
            { label = "iceberg-light" },
            -- ═══════════════ DARK THEMES ═══════════════
            { label = "──── Dark ────" },
            -- Catppuccin
            { label = "Catppuccin Mocha" },
            { label = "Catppuccin Macchiato" },
            { label = "Catppuccin Frappe" },
            -- Tokyo Night
            { label = "Tokyo Night" },
            { label = "Tokyo Night Storm" },
            -- Retro / Synthwave
            { label = "Dracula" },
            { label = "Dracula (Gogh)" },
            { label = "Cyberpunk (Gogh)" },
            -- Earthy / Warm
            { label = "Gruvbox Dark (Gogh)" },
            { label = "Kanagawa" },
            { label = "Monokai Pro" },
            -- Cool / Blue
            { label = "Nord" },
            { label = "One Dark (Gogh)" },
            { label = "Night Owl" },
            { label = "One Half Dark" },
            -- Pine / Green
            { label = "rose-pine-moon" },
            { label = "Vesper" },
            { label = "Miku (Gogh)" },
            -- Minimal / Clean
            { label = "Palenight (Gogh)" },
            { label = "Espresso (Gogh)" },
            { label = "Ayu Mirage (Gogh)" },
            { label = "Horizon Night" },
            -- Solarized
            { label = "Solarized Dark (Gogh)" },
            -- Fun / Unique
            { label = "Snazzy" },
            { label = "Soft Era" },
            { label = "Material Palenight" },
        },
        action = wezterm.action_callback(function(window, pane, id, label)
            if label then
                local overrides = window:get_config_overrides() or {}
                overrides.color_scheme = label
                window:set_config_overrides(overrides)
                save_theme(label)
            end
        end),
    }},
    -- Rename tab
    { mods = "LEADER", key = "r", action = act.PromptInputLine {
        description = "Rename tab",
        action = wezterm.action_callback(function(window, pane, line)
            if line then
                window:active_tab():set_title(line)
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
config.audible_bell = "Disabled"
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
config.window_close_confirmation = "SmartPrompt"
-- =========================
-- Alt as Meta (better vim/terminal compatibility)
-- =========================
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false
config.allow_win32_input_mode = true
config.enable_osc52 = true
-- =========================
-- Right Status Bar (date/time + hostname)
-- =========================
wezterm.on("update-right-status", function(window, pane)
    local time = wezterm.strftime("%H:%M")
    window:set_right_status(wezterm.format({
        { Foreground = { Color = "#6c7086" } },
        { Text = " " .. time .. " " },
    }))
end)
return config

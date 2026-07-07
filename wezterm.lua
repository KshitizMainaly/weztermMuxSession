local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()
-- =========================
-- Session Tracking (file-based, instant, no CLI needed)
-- =========================
local SESSIONS_FILE = wezterm.config_dir .. "/sessions.txt"

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

local function get_session_list()
    local list = {}
    for name in pairs(read_sessions()) do table.insert(list, { label = name }) end
    return list
end
-- =========================
-- Performance & Memory
-- =========================
config.front_end = "OpenGL"                    -- stable for TUI apps (Helix, etc.)
config.webgpu_power_preference = "HighPerformance" -- dedicated GTX 1650
config.max_fps = 120                          -- buttery smooth (matches high refresh monitors)
config.animation_fps = 30                     -- smooth but stable for TUI redraws
config.cursor_blink_rate = 500                -- 500ms blink interval (standard smooth blink)
config.scrollback_lines = 2000               -- cap scrollback buffer (default 3500)
config.enable_scroll_bar = false             -- no scroll bar widget
config.check_for_updates = false             -- no background update checks
config.status_update_interval = 1000         -- status bar update every second (for clock)
config.unicode_version = 14                  -- avoid expensive unicode lookups
config.clean_exit_codes = { 130 }            -- clean exit on Ctrl+C
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
    name = 'mux',  -- renamed from 'local'
  },
}

-- Silently connect to mux daemon at startup so Leader+w can list sessions
-- and Leader+a can detect existing workspaces (prevents extra tab on re-attach)
wezterm.on("gui-startup", function(cmd)
    local mux = wezterm.mux
    local ok, domain = pcall(function()
        return mux.get_domain("mux")
    end)
    if ok and domain then
        domain:attach()
    end
end)

-- Leader+a = attach/create named persistent session (tmux "new -A -s")
-- Leader+d = detach (tmux "detach")
-- Leader+w = list/switch sessions (tmux "ls")
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
    -- "DaddyTimeMono Nerd Font",
--    "ComicShannsMono Nerd Font",
"Monoid Nerd Font",
"ComicShannsMono Nerd Font",
    "JetBrainsMono NF",
    "Iosevka Nerd Font",
})
config.font_size = 11
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
config.color_scheme = "rose-pine-moon" -- Dracula is robust. Try "Tokyo Night" or "Aura" for a different feel.
config.window_padding = {
    left = 25,
    right = 25,
    top = 25,
    bottom = 25,
}
config.window_frame = {
    border_left_width = "0.4cell",
    border_right_width = "0.4cell",
    border_bottom_height = "0.15cell",
    border_top_height = "0.15cell",
    inactive_titlebar_bg = "#1e1e2e",
    active_titlebar_bg = "#1e1e2e",
    inactive_titlebar_fg = "#cdd6f4",
    active_titlebar_fg = "#cdd6f4",
}
config.hide_tab_bar_if_only_one_tab = true
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
    -- List/switch mux sessions (like tmux ls)
    { mods = "LEADER", key = "w", action = wezterm.action_callback(function(window, pane)
        local choices = get_session_list()
        if #choices > 0 then
            window:perform_action(
                act.InputSelector {
                    title = "Mux Sessions",
                    alphabet = "abcdefghijklmnopqrstuvwxyz",
                    choices = choices,
                    action = wezterm.action_callback(function(window, pane, id, label)
                        if label then
                            add_session(label)
                            window:perform_action(
                                act.SwitchToWorkspace { name = label },
                                pane
                            )
                        end
                    end),
                },
                pane
            )
        else
            window:perform_action(
                act.ShowLauncherArgs { flags = "WORKSPACES" },
                pane
            )
        end
    end)},
    -- Close all tabs in CURRENT workspace (with prompt)
    { mods = "LEADER", key = "q", action = act.PromptInputLine {
        description = "Close all tabs in this workspace? (y/n)",
        action = wezterm.action_callback(function(window, pane, line)
            if line and line:lower() == "y" then
                local tabs = window:mux_window():tabs()
                for _ = 1, #tabs do
                    window:perform_action(act.CloseCurrentTab { confirm = false }, window:active_pane())
                end
            end
        end),
    }},
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
    -- Attach / create named persistent session (tmux: new -A -s <name>)
    { mods = "LEADER", key = "a", action = act.PromptInputLine {
        description = "Session name (blank = default mux session):",
        action = wezterm.action_callback(function(window, pane, line)
            if line and #line > 0 then
                local sessions = read_sessions()
                local exists = sessions[line]
                add_session(line)
                if exists then
                    window:perform_action(
                        act.SwitchToWorkspace { name = line },
                        pane
                    )
                else
                    window:perform_action(
                        act.SwitchToWorkspace {
                            name = line,
                            spawn = {
                                domain = { DomainName = "mux" },
                            },
                        },
                        pane
                    )
                end
            else
                window:perform_action(act.AttachDomain 'mux', pane)
            end
        end),
    }},
    -- Kill/delete a mux session by selecting from list
    { mods = "LEADER", key = "g", action = wezterm.action_callback(function(window, pane)
        local choices = get_session_list()
        if #choices > 0 then
            window:perform_action(
                act.InputSelector {
                    title = "Remove Session",
                    alphabet = "abcdefghijklmnopqrstuvwxyz",
                    choices = choices,
                    action = wezterm.action_callback(function(window, pane, id, label)
                        if label then
                            remove_session(label)
                        end
                    end),
                },
                pane
            )
        end
    end)},
    -- Detach from mux session (tmux: detach)
    { mods = "LEADER", key = "d", action = act.DetachDomain { DomainName = "mux" } },
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
config.hyperlink_rules = {
    { regex = "\\b\\w+://[\\w.-]+\\.[a-z]{2,15}\\S*\\b", format = "$0" },
    { regex = "\\b[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+\\b", format = "mailto:$0" },
    { regex = "\\b(/[\\w.-]+)+/?\\b", format = "file://$0" },
    { regex = "\\bhttps?://localhost(:\\d+)?\\S*\\b", format = "$0" },
    { regex = "\\bhttps?://127\\.0\\.0\\.1(:\\d+)?\\S*\\b", format = "$0" },
}
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
config.status_update_interval = 1000
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
-- Tab Title Formatting (process + cwd)
-- =========================
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local pane = tab.active_pane
    local title = pane.title
    if title and #title > 0 then
        title = title
    else
        title = pane.foreground_process_name
        -- Extract just the filename from the path
        title = title:match("([^/\\]+)$") or title
    end
    -- Truncate if too long
    if #title > 20 then
        title = title:sub(1, 18) .. ".."
    end
    return " " .. title .. " "
end)
return config

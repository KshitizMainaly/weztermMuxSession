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
    wezterm.time.call_after(120, prune_rename_timestamps)
end
prune_rename_timestamps()
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
local function switch_to_session(window, pane, name)
    add_session(name)
    window:perform_action(act.AttachDomain("mux"), pane)
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
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance" -- dedicated GTX 1650
config.max_fps = 120                          -- buttery smooth (matches high refresh monitors)
config.animation_fps = 30                     -- smooth but stable for TUI redraws
config.cursor_blink_rate = 500                -- 500ms blink interval (standard smooth blink)
config.scrollback_lines = 2000               -- cap scrollback buffer (default 3500)
config.enable_scroll_bar = false             -- no scroll bar widget
config.check_for_updates = false             -- no background update checks
config.status_update_interval = 1000         -- status bar update every second (for clock)
config.unicode_version = 14                  -- avoid expensive unicode lookups
config.tab_max_width = 48                    -- room for agent status + repo  branch
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
    name = 'mux',
  },
}

-- Session / workspace model:
--   A "session" is a tracked workspace on the mux domain, surviving detach.
--   Leader+a       = create/switch to a named session
--   Leader+w       = workspace launcher (create/switch any)
--   Leader+'       = Session Manager: list, create, switch to, delete
--   Leader+d       = detach: close tab, session stays on mux server
--   Leader+g       = delete a tracked session
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
    -- Workspace switcher (shows ALL workspaces, create new by typing name)
    { mods = "LEADER", key = "w", action = act.ShowLauncherArgs { flags = "WORKSPACES" } },
    -- Close all tabs in CURRENT workspace (with prompt)
    { mods = "LEADER", key = "q", action = wezterm.action_callback(function(window, pane)
        local ws = window:active_workspace()
        window:perform_action(act.InputSelector {
            title = "Close workspace: " .. ws,
            choices = {
                { id = "yes", label = "󰄬  Yes, close all tabs in " .. ws },
                { id = "no",  label = "󰅖  Cancel" },
            },
            action = wezterm.action_callback(function(_, _, id)
                if id == "yes" then close_workspace_tabs(window, ws) end
            end),
        }, pane)
    end)},
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
                window:perform_action(act.AttachDomain 'mux', pane)
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
    -- Session Manager: list, create, switch to, rename, delete
    { mods = "LEADER", key = "'", action = wezterm.action_callback(function(window, pane)
        local current = window:active_workspace()
        local choices = { { id = "\1new", label = "＋  Create new session…" } }
        for _, name in ipairs(all_sessions()) do
            local marker = (name == current) and "●  " or "   "
            table.insert(choices, { id = name, label = marker .. name })
        end
        window:perform_action(
            act.InputSelector {
                title = "Session Manager",
                fuzzy = true,
                fuzzy_description = "Session (type to filter): ",
                choices = choices,
                action = wezterm.action_callback(function(window, pane, id, _label)
                    if not id then return end
                    if id == "\1new" then
                        window:perform_action(act.PromptInputLine {
                            description = "New session name:",
                            action = wezterm.action_callback(function(window, pane, line)
                                if line and #line > 0 then switch_to_session(window, pane, line) end
                            end),
                        }, pane)
                        return
                    end
                    local name = id
                    window:perform_action(act.InputSelector {
                        title = "Session: " .. name,
                        choices = {
                            { id = "switch", label = "󰁔  Switch to  " .. name },
                            { id = "rename", label = "󰑕  Rename     " .. name },
                            { id = "delete", label = "󰆴  Delete     " .. name },
                            { id = "cancel", label = "󰅖  Cancel" },
                        },
                        action = wezterm.action_callback(function(window, pane, act_id, _l)
                            if not act_id or act_id == "cancel" then return end
                            if act_id == "switch" then
                                switch_to_session(window, pane, name)
                            elseif act_id == "rename" then
                                window:perform_action(act.PromptInputLine {
                                    description = "Rename '" .. name .. "' to:",
                                    action = wezterm.action_callback(function(window, pane, line)
                                        if not line or #line == 0 or line == name then return end
                                        pcall(function() wezterm.mux.rename_workspace(name, line) end)
                                        remove_session(name)
                                        add_session(line)
                                        window:perform_action(act.ShowMessage { message = "Renamed to: " .. line }, pane)
                                    end),
                                }, pane)
                            elseif act_id == "delete" then
                                if name == current then
                                    window:perform_action(act.ShowMessage {
                                        message = "Can't delete the session you're in — switch away first.",
                                    }, pane)
                                    return
                                end
                                kill_session(window, name)
                                window:perform_action(act.ShowMessage { message = "Deleted session: " .. name }, pane)
                            end
                        end),
                    }, pane)
                end),
            },
            pane
        )
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
local function read_custom_status(pane_id)
    local path = wezterm.home_dir .. '/.local/state/wezterm-attention/' .. tostring(pane_id)
    local f = io.open(path, 'r')
    if not f then return nil, nil end
    local content = f:read('*a')
    f:close()
    local ok, decoded = pcall(wezterm.json_parse, content)
    if ok and decoded and decoded.text then
        return decoded.text, (decoded.timestamp or 0) / 1000
    end
    return nil, nil
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
local SEP_ICON    = utf8.char(0xE0B1)  --  thin right divider
local SEP_FG      = "#6c7086"

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
    local pane = tab.active_pane
    if not pane then return {} end
    local state = agent_deck.get_agent_state(pane.pane_id)

    local bg = tab.is_active and ACTIVE_BG or INACTIVE_BG
    local fg = tab.is_active and ACTIVE_FG or INACTIVE_FG

    local elements = {}
    local reserved = 0

    if state then
        table.insert(elements, { Background = { Color = bg } })
        table.insert(elements, { Foreground = { Color = agent_deck.get_status_color(state.status) } })
        table.insert(elements, { Text = agent_deck.get_status_icon(state.status) .. " " })
        reserved = 2
    end

    local custom_text, custom_ts = read_custom_status(pane.pane_id)
    local rename_ts = rename_timestamps[pane.pane_id] or 0

    -- Only trust the file-based OpenCode status while OpenCode is actually
    -- running in this pane. agent-deck detects the process (and clears `state`
    -- after it exits), so this mirrors how Claude's tab reacts to its process.
    -- Once OpenCode quits, we drop the stale status file and fall back to the
    -- normal pane title instead of freezing on the last "opencode: …" text.
    local opencode_active = state ~= nil and state.agent_type == "opencode"
    if not opencode_active then
        custom_text, custom_ts = nil, nil
    end

    -- Width budget for the title text, measured in display *cells* (not bytes).
    -- -3 covers the two padding spaces and the trailing divider added below.
    local avail = math.max(max_width - reserved - 3, 6)

    local title
    if tab.tab_title and #tab.tab_title > 0 and rename_ts >= (custom_ts or 0) then
        title = tab.tab_title
    elseif custom_text then
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
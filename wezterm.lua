local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- =========================
-- Theme persistence (minimal — one file read at startup)
-- =========================
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
local saved_theme = read_saved_theme()

-- =========================
-- Performance & Rendering (tuned for Neovim)
-- =========================
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.max_fps = 120
config.animation_fps = 1                -- kill all animations (tab transitions, cursor fade, etc.)
config.cursor_blink_rate = 0             -- no blink timer
config.scrollback_lines = 3500          -- neovim manages its own buffer; keep this lean
config.enable_scroll_bar = false
config.check_for_updates = false
config.status_update_interval = 60000   -- status bar callback fires once/min instead of default 1s

-- Text rendering: fastest path
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }  -- no ligature shaping
config.freetype_load_target = "Normal"   -- Normal is fastest; Light/HorizontalLcd do extra work
config.freetype_render_target = "Normal"

-- Input: zero overhead
config.use_dead_keys = false
config.allow_win32_input_mode = true
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- Disable hyperlink scanning (regex runs on EVERY line of terminal output)
config.hyperlink_rules = {}

-- =========================
-- Window & Appearance
-- =========================
config.window_decorations = "RESIZE"
config.default_prog = { "nu" }
config.font = wezterm.font("Monoid Nerd Font")   -- single font = no fallback chain lookup
config.font_size = 12
config.color_scheme = saved_theme or "rose-pine-moon"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.window_frame = {
    inactive_titlebar_bg = "#1e1e2e",
    active_titlebar_bg = "#1e1e2e",
    inactive_titlebar_fg = "#cdd6f4",
    active_titlebar_fg = "#cdd6f4",
}
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_max_width = 48

-- SSH domain (kept — zero cost unless you actually connect)
config.ssh_domains = {
    {
        name = 'cpanel-alltop',
        remote_address = 'node2.webhostnepal.net',
        username = 'alltopgr',
    },
}

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
        active_tab = { bg_color = "#cba6f7", fg_color = "#1e1e2e" },
        inactive_tab = { bg_color = "#585b70", fg_color = "#cdd6f4" },
        inactive_tab_hover = { bg_color = "#6c7086", fg_color = "#cdd6f4" },
    },
}

-- =========================
-- Leader Key
-- =========================
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 500 }

-- =========================
-- Keybindings (lean — no session/mux callbacks)
-- =========================
config.keys = {
    -- Panes
    { mods = "LEADER",       key = "s",  action = act.PaneSelect { mode = "SwapWithActive" } },
    { mods = "LEADER",       key = "x",  action = act.CloseCurrentPane { confirm = false } },
    { mods = "LEADER",       key = "\\", action = act.SplitHorizontal { domain = "DefaultDomain" } },
    { mods = "LEADER",       key = "-",  action = act.SplitVertical { domain = "DefaultDomain" } },
    { mods = "LEADER",       key = "h",  action = act.ActivatePaneDirection("Left") },
    { mods = "LEADER",       key = "j",  action = act.ActivatePaneDirection("Down") },
    { mods = "LEADER",       key = "k",  action = act.ActivatePaneDirection("Up") },
    { mods = "LEADER",       key = "l",  action = act.ActivatePaneDirection("Right") },
    { mods = "LEADER|SHIFT", key = "h",  action = act.AdjustPaneSize { "Left", 22 } },
    { mods = "LEADER|SHIFT", key = "l",  action = act.AdjustPaneSize { "Right", 22 } },
    { mods = "LEADER|SHIFT", key = "j",  action = act.AdjustPaneSize { "Down", 22 } },
    { mods = "LEADER|SHIFT", key = "k",  action = act.AdjustPaneSize { "Up", 22 } },
    -- Tabs
    { mods = "LEADER",       key = "c",  action = act.SpawnTab("DefaultDomain") },
    { mods = "LEADER",       key = "b",  action = act.ActivateTabRelative(-1) },
    { mods = "LEADER",       key = "n",  action = act.ActivateTabRelative(1) },
    { mods = "LEADER",       key = "t",  action = act.ShowTabNavigator },
    -- Workspaces (built-in, no mux overhead)
    { mods = "LEADER",       key = "a",  action = act.PromptInputLine {
        description = "Workspace name:",
        action = wezterm.action_callback(function(window, pane, line)
            if line and #line > 0 then
                window:perform_action(act.SwitchToWorkspace { name = line }, pane)
            end
        end),
    }},
    { mods = "LEADER",       key = "w",  action = act.ShowLauncherArgs { flags = "WORKSPACES" } },
    -- Clipboard
    { mods = "CTRL|SHIFT",   key = "C",  action = act.CopyTo("Clipboard") },
    { mods = "CTRL|SHIFT",   key = "V",  action = act.PasteFrom("Clipboard") },
    -- Misc
    { mods = "LEADER",       key = "p",  action = act.ActivateCommandPalette },
    { mods = "CTRL|SHIFT",   key = "R",  action = act.ReloadConfiguration },
    { mods = "LEADER|SHIFT", key = "q",  action = act.QuitApplication },
    -- Rename tab
    { mods = "LEADER", key = "r", action = act.PromptInputLine {
        description = "Rename tab",
        action = wezterm.action_callback(function(window, pane, line)
            if line then window:active_tab():set_title(line) end
        end),
    }},
    -- Theme picker
    { mods = "LEADER", key = "T", action = act.InputSelector {
        title = "Theme Picker",
        choices = {
            { label = "─── Light ───", id = "__sep__" },
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
            { label = "─── Dark ───", id = "__sep__" },
            { label = "Catppuccin Mocha" },
            { label = "Catppuccin Macchiato" },
            { label = "Catppuccin Frappe" },
            { label = "Tokyo Night" },
            { label = "Tokyo Night Storm" },
            { label = "Dracula" },
            { label = "Dracula (Gogh)" },
            { label = "Gruvbox Dark (Gogh)" },
            { label = "Kanagawa (Gogh)" },
            { label = "Nord (Gogh)" },
            { label = "One Dark (Gogh)" },
            { label = "Night Owl (Gogh)" },
            { label = "rose-pine-moon" },
            { label = "Espresso (Gogh)" },
            { label = "Ayu Mirage (Gogh)" },
            { label = "Solarized Dark (Gogh)" },
            { label = "Snazzy" },
        },
        action = wezterm.action_callback(function(window, pane, id, label)
            if not label or id == "__sep__" then return end
            local overrides = window:get_config_overrides() or {}
            overrides.color_scheme = label
            window:set_config_overrides(overrides)
            save_theme(label)
        end),
    }},
}
-- Tabs 1-9
for i = 1, 9 do
    table.insert(config.keys, {
        key = tostring(i), mods = "LEADER", action = act.ActivateTab(i - 1),
    })
end

-- =========================
-- Misc
-- =========================
config.initial_cols = 140
config.initial_rows = 40
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"

return config

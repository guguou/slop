# Yosemite UI

A macOS 10.10 Yosemite–styled UI library for Roblox. It has a Finder-style sidebar and toolbar, light/dark themes, translucent ("vibrant") surfaces, popovers, a color picker, configs, a key system, keyboard navigation and a Spotlight-style command bar.

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/guguou/slop/refs/heads/main/slop.lua"))()
```

---

## Contents

1. [Quick start](#quick-start)
2. [Library options](#library-options)
3. [Key system](#key-system)
4. [Window](#window)
5. [Sidebar: categories and tabs](#sidebar-categories-and-tabs)
6. [Toolbar](#toolbar)
7. [Sections and controls](#sections-and-controls)
8. [Common control methods](#common-control-methods)
9. [Popovers](#popovers)
10. [Tables](#tables)
11. [Alerts and notifications](#alerts-and-notifications)
12. [Configs](#configs)
13. [Settings sheet](#settings-sheet)
14. [Keyboard and command bar](#keyboard-and-command-bar)
15. [Themes, accents, vibrancy](#themes-accents-vibrancy)
16. [Icons](#icons)
17. [Executor requirements](#executor-requirements)
18. [Full example](#full-example)

---

## Quick start

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/guguou/slop/refs/heads/main/slop.lua"))()

local w = UI:Window({ Title = "My Hub", Icon = "compass" })
local main = w:Category("Favorites"):Tab("Main", "house")
local sec = main:Section("Player")

sec:Checkbox({ Text = "Infinite jump", Callback = function(on) print(on) end })
sec:Slider({ Text = "Walk speed", Min = 16, Max = 200, Default = 16, Callback = function(v)
	game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v
end })
sec:Button({ Text = "Hello", Default = true, Callback = function()
	UI:Notify({ Title = "Hi!", Text = "It works.", Icon = "party-popper" })
end })
```

---

## Library options

Set these **before** creating a window.

| Field | Default | What it does |
|---|---|---|
| `UI.Lucide` | auto | `false` turns icons off (plain text glyphs are used instead). Pass a module you already loaded to use that one. |
| `UI.BlurSize` | `14` | Strength of the background blur used for vibrancy. |

Library functions:

| Function | What it does |
|---|---|
| `UI:Toggle([bool])` | Shows or hides every window. With no argument it flips the current state. |
| `UI:SetTheme("Light" \| "Dark")` | Switches the theme with a color fade. Saved. |
| `UI:SetAccent("Blue" \| "Graphite")` | Switches the accent color. Saved. |
| `UI:SetVibrancy(bool)` | Turns translucent surfaces and the background blur on or off. Saved. |
| `UI:SetReduceMotion(bool)` | Turns animations off. Saved. |
| `UI:SetToggleKey(Enum.KeyCode)` | Sets the key that shows/hides the UI. Default is `RightShift`. Saved. |
| `UI:SetMobileButton(bool)` | Shows or hides the floating, draggable toggle button. It's on by default on touch devices. |
| `UI:Notify({...})` | Shows a notification banner. See [Alerts and notifications](#alerts-and-notifications). |
| `UI:KeySystem({...})` | Shows a key prompt. See [Key system](#key-system). |

UI preferences are saved to `Yosemite/ui.json`. Your script's configs are saved separately; see [Configs](#configs).

---

## Key system

Call it before creating your window. It **waits** until the user is done, then returns `true` if the key was valid or `false` if they cancelled.

```lua
if not UI:KeySystem({
	Title = "My Hub",
	Subtitle = "Enter your key to continue.",   -- optional
	Note = "Keys reset every 24 hours.",          -- optional, smaller gray text
	Keys = { "abc123", "vip-key" },              -- a fixed list of valid keys...
	-- Validate = function(key) return true end, -- ...or your own check (may yield, e.g. an HTTP request)
	Link = "https://your.site/get-key",         -- adds a "Get Key" button that copies this link
	FileName = "MyHub/key.txt",                 -- where a valid key is remembered
	SaveKey = true,                             -- false = ask every time
	Invalid = "That key isn't valid.",          -- optional error text
}) then return end
```

- A wrong key turns the field red and shakes the dialog.
- A saved key is checked again on every launch, so an expired key still gets rejected.

---

## Window

```lua
local w = UI:Window({
	Title = "My Hub",
	Icon = "compass",                         -- optional Lucide icon next to the title
	Size = UDim2.fromOffset(720, 460),
	SidebarWidth = 170,
	Thin = false,                             -- thin titlebar (default comes from the user's setting)
	MobileButton = false,                     -- force the floating toggle button on
	Config = {
		Folder = "MyHub/Configs",
		Format = "{place}/{name}.json",       -- see Configs
		AutoLoad = true,
	},
})
```

| Method | What it does |
|---|---|
| `w:SetTitle(text)` | Changes the title. |
| `w:SetThin(bool)` | Thin titlebar: 22px, or one 38px row when there's a toolbar. |
| `w:Minimize()` / `w:Restore()` | Sends the window to the Dock at the bottom of the screen, or brings it back. The yellow light minimizes. Click the Dock tile to restore. |
| `w:OpenSettings()` | Opens the settings sheet (same as the gear in the bottom-left corner). |
| `w:OpenCommandBar()` | Opens the command bar (same as Ctrl+K). |
| `w:Alert({...})` | Shows an alert sheet. |
| `w:Popover(anchor, {...})` | Attaches a popover to any GuiObject. See [Popovers](#popovers). |
| `w.Gui` | The window's ScreenGui. Call `w.Gui:Destroy()` to remove it. |
| `w.Flags` | Every control that has a flag, keyed by flag name. |

The traffic lights close (red), minimize to the Dock (yellow) and zoom (green). Drag the window by its titlebar.

---

## Sidebar: categories and tabs

```lua
local fav = w:Category("Favorites")            -- collapsible: hover the header, click Hide/Show
local main = fav:Tab("Main", "house")          -- name, optional icon
local misc = w:Category("More", { Collapsible = false }):Tab("Misc", "wrench")
local loose = w:Tab("Loose tab")               -- a tab with no category
```

`w:Header(name)` is the same as `w:Category(name, { Collapsible = false })`.

---

## Toolbar

```lua
local tb = w:Toolbar({ Labels = true })   -- Labels = Finder-style captions under each item

tb:Button({ Icon = "refresh-cw", Label = "Refresh", Callback = fn })
tb:Button({ Text = "Save", Default = true, Callback = fn })
tb:Segmented({ Items = { "list", "layout-grid" }, Icons = true, Default = "list", Label = "View", Callback = fn })
tb:Menu({ Icon = "settings", Items = { "One", "Two" }, Label = "Action", Callback = function(item) end })
tb:Popover({ Icon = "sliders-horizontal", Label = "Quick", Title = "Quick settings", Build = function(p) ... end })
tb:Space(12)
tb:Search({ Placeholder = "Search", Width = 200, Label = "Search" })
```

- Every item accepts `Side = "Right"`. Search goes on the right by default.
- **Search** filters the current tab as you type, matching control names, section names and table rows. Set `Filter = false` to only get `Callback(text)`.

---

## Sections and controls

```lua
local s = tab:Section("Name")
```

Every **value** control:
- takes `Text`, `Default`, `Callback` and an optional `Flag` (see [Configs](#configs)),
- returns an object with `:Get()` and `:Set(value, silent)`. `silent = true` skips the callback,
- also has the [common methods](#common-control-methods).

### Button
```lua
local b = s:Button({ Text = "Run", Label = "Optional row label", Default = true, Icon = "play", Callback = fn })
b:Fire()                 -- click it from code
b.Button                 -- the underlying TextButton
```
`Default = true` gives the blue button.

### ButtonRow
```lua
s:ButtonRow({ { Text = "Save", Callback = a }, { Text = "Load", Callback = b }, { Text = "Delete", Callback = c } })
```

### Checkbox
```lua
local c = s:Checkbox({ Text = "Enabled", Default = false, Callback = function(on) end })
```

### Slider
```lua
s:Slider({ Text = "FOV", Min = 10, Max = 360, Step = 1, Default = 90, Suffix = "°", KeyStep = 5, Callback = function(v) end })
```
`KeyStep` is how much each arrow-key press moves it. It's worked out automatically if you leave it out.

### Stepper
```lua
s:Stepper({ Text = "Smoothing", Min = 0, Max = 1, Step = .05, Default = .3, Suffix = "", Width = 56, Callback = fn })
```

### Segmented
```lua
s:Segmented({ Text = "Mode", Items = { "Hold", "Toggle", "Always" }, Default = "Hold", Callback = function(item) end })
```

### Radio
```lua
s:Radio({ Text = "Priority", Items = { "Distance", "Health" }, Default = "Distance", Callback = fn })
```

### Popup (dropdown)
```lua
local p = s:Popup({ Text = "Target", Items = { "Head", "Torso" }, Default = "Head", Width = 140, Callback = fn })
p:SetItems({ "A", "B", "C" })
```

### TextField
```lua
local t = s:TextField({ Text = "Name", Placeholder = "type here", Default = "", Width = 160,
	Callback = function(text, pressedEnter) end })
t.Box   -- the underlying TextBox
```

### Keybind
```lua
s:Keybind({ Text = "Aim key", Default = Enum.KeyCode.E,
	Callback = function(key) end,       -- fires when the bind changes (nil = cleared)
	OnPress = function() end })         -- fires when the bound key is pressed
```
Click the button, then press a key. **Esc** or **Backspace** clears the bind.

### ColorPicker
```lua
s:ColorPicker({ Text = "ESP color", Default = Color3.fromRGB(255, 59, 48), Callback = function(color) end })
```
This opens the Colors panel. It has three modes (Picker, Sliders, Palette) and a hex field, and it updates the color live.

### Progress
```lua
local bar = s:Progress({ Text = "Loading", Default = 0 })
bar:Set(.6)   -- 0..1
```

### Label and Separator
```lua
local l = s:Label("Some help text that wraps.")
l:SetText("New text")
s:Separator()
```

### Popover button
See [Popovers](#popovers).

---

## Common control methods

Every control returns an object with these methods:

| Method | What it does |
|---|---|
| `:SetVisible(bool)` | Shows or hides the row. |
| `:SetDisabled(bool)` | Grays the row out and blocks clicks. Keyboard navigation skips it. |
| `:SetText(text)` | Changes the label. On a Button, it changes the button's text. |
| `.Row` | The row Frame. |

---

## Popovers

```lua
-- inside a section: a row with a button that opens it
local pv = s:Popover({ Label = "Advanced", Text = "Options", Title = "Advanced options", Width = 260,
	Build = function(p)
		p:Checkbox({ Text = "Silent", Callback = fn })
		p:Slider({ Text = "Range", Min = 0, Max = 100 })
	end })

-- in the toolbar
tb:Popover({ Icon = "zap", Label = "Quick", Build = function(p) ... end })

-- attached to anything
local pv2 = w:Popover(someGuiObject, { Title = "Hi", Build = function(p) ... end })
pv2.Open(); pv2.Close(); pv2.Toggle()
```

- `p` works like a section, so any control can go inside.
- Controls inside a popover save to configs like any other. Their flag names start with the popover's `Title` (or its `Label`).
- A popover closes when you click outside it or press Esc.

---

## Tables

```lua
local t = tab:Table({
	Fill = true,                    -- fill the whole tab (Finder list view); otherwise use Height = 220
	SortColumn = 1,
	Columns = {
		{ Name = "Name", Width = 3 },
		{ Name = "Size", Width = 1, Align = "Right", Sort = function(a, b) return a < b end },
	},
	Rows = {
		{ Icon = "file-text", "Notes.txt", "4 KB" },
		{ Icon = "image", "Photo.png", "1.2 MB", Player = somePlayer },   -- extra keys are kept for your own use
	},
	Callback = function(row) end,   -- selection changed
	Activate = function(row) end,   -- double-click or Enter
})
t:SetRows(rows); t:Add(row); t:Remove(row); t:Clear()
t:GetSelected(); t:Select(row); t:Refresh()
```

- Click a column header to sort by it. Click again to reverse the order.
- The toolbar search filters the table's rows.
- With a row selected, ↑ and ↓ move the selection.

---

## Alerts and notifications

```lua
w:Alert({
	Title = "Delete config?",
	Text = "This can't be undone.",
	Buttons = { "Cancel", "Delete" },   -- the last button is the blue default
	Callback = function(button) end,
})
```
Enter presses the last button. Esc presses the first.

```lua
local n = UI:Notify({
	Title = "Saved",
	Text = "Config “main” saved.",
	Icon = "save",
	Duration = 5,                       -- 0 = stays until dismissed
	Buttons = { "Close", "Undo" },      -- optional action buttons
	Callback = function(button) end,
	OnClick = function() end,           -- clicking the banner itself
})
n.Dismiss()
```
Hovering a notification pauses its timer.

---

## Configs

Every value control is saved under a **flag**:
- If you don't set one, the flag is `"<Section name>/<Text>"` (for example `"Aim/Enabled"`).
- `Flag = "myFlag"` sets your own.
- `Flag = false` leaves the control out of configs.

```lua
Config = { Folder = "MyHub/Configs", Format = "{place}/{name}.json", AutoLoad = true }
```

Tokens you can use in `Format`:

| Token | Becomes |
|---|---|
| `{name}` | The config's name |
| `{place}` | `game.PlaceId` |
| `{game}` | `game.GameId` |
| `{user}` | The local player's name |

Functions:

| Function | What it does |
|---|---|
| `w:SaveConfig(name)` | Saves all flags. Returns `true` on success. |
| `w:LoadConfig(name)` | Loads a config and runs every control's callback. Returns `true` on success. |
| `w:ListConfigs()` | Returns a sorted list of saved config names. |
| `w:DeleteConfig(name)` | Deletes a config. |
| `w:SetAutoload(name or nil)` / `w:GetAutoload()` | Sets or reads which config loads on start. |
| `w:LoadAutoload()` | Loads the autoload config. This runs on its own 0.5s after the window opens. If your script waits (yields) while building its controls, call it yourself once everything exists. |

Users can do all of this from **Settings (gear) → Configs**.

Values that can be saved: booleans, numbers, strings, `EnumItem`s (keybinds) and `Color3`s.

---

## Settings sheet

The gear in the sidebar's bottom-left corner opens a sheet with two pages:

- **General:**
  - Appearance (Light/Dark), Accent (Blue/Graphite) and Titlebar (Normal/Thin).
  - Vibrancy and Reduce motion.
  - The Toggle UI key and the floating toggle button.
- **Configs:** name, a list of saved configs, Save / Load / Delete, and Load on start.

You can add your own sections to the General page:

```lua
local mine = w.Settings:Section("My script")
mine:Checkbox({ Text = "Debug logging", Flag = "debug" })
```

The sheet scrolls when its content is taller than the window.

---

## Keyboard and command bar

| Key | What it does |
|---|---|
| Tab / Shift+Tab | Moves focus to the next / previous control. The focused control gets a blue ring. |
| ↑ / ↓ | Moves focus (in a table, moves the selection) |
| ← / → | Adjusts a slider, stepper, segmented control, radio or popup |
| Enter / Space | Activates the focused control |
| Enter (nothing focused) | Presses the open sheet's default button |
| Esc | Closes the color panel, then a popover, then a sheet. Otherwise clears focus. |
| Ctrl+K | Opens the command bar: type to find any tab or control and jump to it |
| RightShift (default) | Shows / hides the UI |

Keys only act on the window you clicked last, and do nothing while you're typing in a text box. Space and the arrow keys also reach the game (jumping, moving), so Enter is the safer key to activate controls.

---

## Themes, accents, vibrancy

- **Themes:** `Light` and `Dark`. You can add your own by copying `UI.Themes.Light` into `UI.Themes.MyTheme`, changing the colors, then calling `UI:SetTheme("MyTheme")`.
- **Accents:** `Blue` and `Graphite`. You can add more to `UI.Accents` the same way. An accent needs the fields `Top`, `Bot`, `Border`, `Solid` and `Focus`.
- **Vibrancy:** makes the sidebar, titlebar, popovers, menus and Dock translucent, with a `BlurEffect` on the camera behind them. That blur covers the whole game view while the UI is visible. It's removed when the UI is hidden or vibrancy is turned off.

---

## Icons

Icons come from [Lucide](https://lucide.dev) through `latte-soft/lucide-roblox` spritesheets. Use any Lucide icon name (`"house"`, `"settings"`, `"map-pin"`…). If an icon can't be loaded, a text fallback is shown instead. You can also pass a plain glyph like `"◎"` instead of a name.

---

## Executor requirements

| Feature | Needs |
|---|---|
| Loading the library | `loadstring`, `game:HttpGet` |
| Configs, saved UI settings, saved keys | `writefile`, `readfile`, `isfile`, `makefolder`, `listfiles`, `delfile` (each one is optional; that feature just won't save) |
| Get Key / Copy buttons | `setclipboard` (optional) |
| Drawing on top of other UI | `gethui` if available, then `CoreGui`, then `PlayerGui` |

---

## Full example

See `yosemite_example.lua`. It shows the key system, movement and fly, ESP with color pickers and a popover, fullbright and FOV, a player list table with teleport and spectate toolbar buttons, anti-AFK, rejoin, unload, and a custom settings section.

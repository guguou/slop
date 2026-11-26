-- Yosemite UI: example script (movement, fly, ESP, world, player list, misc)
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/guguou/slop/refs/heads/main/slop.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local conns = {}
local function on(sig, fn) local c = sig:Connect(fn); table.insert(conns, c); return c end
local function char() return LP.Character end
local function hum() local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function root() local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function notify(title, text, icon) UI:Notify({ Title = title, Text = text, Icon = icon or "info", Duration = 3 }) end

local state = {
	speedOn = false, speed = 32, jumpOn = false, jump = 75,
	infJump = false, noclip = false, fly = false, flySpeed = 60,
	esp = false, names = false, teamCheck = true, fill = Color3.fromRGB(255, 59, 48), outline = Color3.fromRGB(255, 255, 255), fillT = .6,
	fullbright = false, fov = 70, fovOn = false,
}

------------------------------------------------------------------------- key system
-- demo key is "yosemite"; swap Keys for Validate = function(key) ... return true/false end to check a server
if not UI:KeySystem({
	Title = "Yosemite Demo",
	Note = "The demo key is “yosemite”. A valid key is remembered, so you only enter it once.",
	Keys = { "yosemite" },
	Link = "https://example.com/get-key",
	FileName = "YosemiteDemo/key.txt",
}) then return end

------------------------------------------------------------------------- window
local w = UI:Window({
	Title = "Yosemite Demo", Icon = "compass", Size = UDim2.fromOffset(720, 470),
	Config = { Folder = "YosemiteDemo/Configs", Format = "{place}/{name}.json" },
})

local fav = w:Category("Favorites")
local playerTab = fav:Tab("Player", "user")
local visualsTab = fav:Tab("Visuals", "eye")
local listTab = fav:Tab("Players", "users")
local more = w:Category("More")
local miscTab = more:Tab("Misc", "wrench")

------------------------------------------------------------------------- player: movement
local move = playerTab:Section("Movement")
move:Checkbox({ Text = "Override walk speed", Callback = function(v) state.speedOn = v end })
local speedSlider = move:Slider({ Text = "Walk speed", Min = 16, Max = 200, Default = state.speed, Callback = function(v) state.speed = v end })
move:Checkbox({ Text = "Override jump power", Callback = function(v) state.jumpOn = v end })
move:Slider({ Text = "Jump power", Min = 50, Max = 300, Default = state.jump, Callback = function(v) state.jump = v end })
move:Separator()
move:Checkbox({ Text = "Infinite jump", Callback = function(v) state.infJump = v end })
move:Checkbox({ Text = "Noclip", Callback = function(v) state.noclip = v end })
move:Popover({ Label = "Presets", Text = "Choose", Title = "Speed presets", Width = 220, Build = function(p)
	p:ButtonRow({
		{ Text = "Walk", Callback = function() speedSlider:Set(16) end },
		{ Text = "Run", Callback = function() speedSlider:Set(50) end },
		{ Text = "Zoom", Callback = function() speedSlider:Set(150) end },
	})
	p:Label("Presets only change the slider; turn on Override walk speed to apply.")
end })

on(RunService.Heartbeat, function()
	local h = hum()
	if not h then return end
	if state.speedOn and h.WalkSpeed ~= state.speed then h.WalkSpeed = state.speed end
	if state.jumpOn then
		h.UseJumpPower = true
		if h.JumpPower ~= state.jump then h.JumpPower = state.jump end
	end
end)
on(UIS.JumpRequest, function()
	local h = hum()
	if state.infJump and h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
on(RunService.Stepped, function()
	if not state.noclip and not state.fly then return end
	local c = char()
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
	end
end)

------------------------------------------------------------------------- player: fly
local flySec = playerTab:Section("Fly")
local flyBox = flySec:Checkbox({ Text = "Fly", Callback = function(v)
	state.fly = v
	local h = hum()
	if h then h.PlatformStand = v end
	if not v then local r = root(); if r then r.AssemblyLinearVelocity = Vector3.zero end end
end })
flySec:Slider({ Text = "Fly speed", Min = 10, Max = 300, Default = state.flySpeed, Callback = function(v) state.flySpeed = v end })
flySec:Keybind({ Text = "Toggle fly", Default = Enum.KeyCode.F, OnPress = function() flyBox:Set(not flyBox:Get()) end })
flySec:Label("WASD to move, Space to rise, Left Ctrl to sink.")

on(RunService.Heartbeat, function()
	if not state.fly then return end
	local r, h = root(), hum()
	if not r or not h then return end
	h.PlatformStand = true
	local cf = Camera.CFrame
	local dir = Vector3.zero
	if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
	if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
	if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
	if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
	if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
	if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
	if dir.Magnitude == 0 and h.MoveDirection.Magnitude > 0 then dir = h.MoveDirection end -- mobile thumbstick
	r.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * state.flySpeed or Vector3.zero
end)

on(LP.CharacterAdded, function()
	if state.fly then flyBox:Set(false) end
end)

------------------------------------------------------------------------- visuals: ESP
local espFolder = Instance.new("Folder")
espFolder.Name = "YosemiteDemoESP"
pcall(function() espFolder.Parent = gethui and gethui() or game:GetService("CoreGui") end)
if not espFolder.Parent then espFolder.Parent = LP:WaitForChild("PlayerGui") end

local espObjs = {} -- [player] = { hl, bb, label }
local function clearEsp(p)
	local o = espObjs[p]
	if o then
		if o.hl then o.hl:Destroy() end
		if o.bb then o.bb:Destroy() end
		espObjs[p] = nil
	end
end
local function shouldShow(p)
	if p == LP or not p.Character then return false end
	if state.teamCheck and LP.Team and p.Team == LP.Team then return false end
	return true
end
local function updateEsp(p)
	if not state.esp or not shouldShow(p) then clearEsp(p) return end
	local c = p.Character
	local o = espObjs[p] or {}
	espObjs[p] = o
	if not o.hl or o.hl.Adornee ~= c then
		if o.hl then o.hl:Destroy() end
		o.hl = Instance.new("Highlight")
		o.hl.Adornee = c
		o.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		o.hl.Parent = espFolder
	end
	o.hl.FillColor, o.hl.OutlineColor, o.hl.FillTransparency = state.fill, state.outline, state.fillT
	local head = c:FindFirstChild("Head")
	if state.names and head then
		if not o.bb or o.bb.Adornee ~= head then
			if o.bb then o.bb:Destroy() end
			o.bb = Instance.new("BillboardGui")
			o.bb.Size, o.bb.StudsOffset, o.bb.AlwaysOnTop, o.bb.Adornee = UDim2.fromOffset(200, 20), Vector3.new(0, 2.5, 0), true, head
			o.label = Instance.new("TextLabel")
			o.label.BackgroundTransparency, o.label.Size, o.label.Font, o.label.TextSize = 1, UDim2.fromScale(1, 1), Enum.Font.ArialBold, 13
			o.label.TextStrokeTransparency = .5
			o.label.Parent = o.bb
			o.bb.Parent = espFolder
		end
		o.label.Text, o.label.TextColor3 = p.DisplayName, state.outline
	elseif o.bb then
		o.bb:Destroy(); o.bb = nil
	end
end
local function refreshEsp() for _, p in ipairs(Players:GetPlayers()) do updateEsp(p) end end
on(Players.PlayerRemoving, clearEsp)
task.spawn(function()
	while espFolder.Parent do
		if state.esp then refreshEsp() end
		task.wait(state.espRate or .5)
	end
end)

local esp = visualsTab:Section("ESP")
esp:Checkbox({ Text = "Highlight players", Callback = function(v) state.esp = v; refreshEsp() end })
esp:ColorPicker({ Text = "Fill color", Default = state.fill, Callback = function(c) state.fill = c; refreshEsp() end })
esp:ColorPicker({ Text = "Outline / name color", Default = state.outline, Callback = function(c) state.outline = c; refreshEsp() end })
esp:Popover({ Label = "Options", Text = "Edit", Title = "ESP options", Build = function(p)
	p:Checkbox({ Text = "Show names", Callback = function(v) state.names = v; refreshEsp() end })
	p:Checkbox({ Text = "Hide teammates", Default = true, Callback = function(v) state.teamCheck = v; refreshEsp() end })
	p:Slider({ Text = "Fill", Min = 0, Max = 100, Default = 40, Suffix = "%", Callback = function(v) state.fillT = 1 - v / 100; refreshEsp() end })
end })

------------------------------------------------------------------------- visuals: world
local saved = {}
local function setFullbright(v)
	state.fullbright = v
	if v then
		saved = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
			GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient }
	elseif saved.Brightness then
		for k, val in pairs(saved) do Lighting[k] = val end
	end
end
on(RunService.RenderStepped, function()
	if state.fullbright then
		Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = 2, 14, 1e5
		Lighting.GlobalShadows, Lighting.Ambient = false, Color3.fromRGB(178, 178, 178)
	end
	if state.fovOn then Camera.FieldOfView = state.fov end
end)

local world = visualsTab:Section("World")
world:Checkbox({ Text = "Fullbright", Callback = setFullbright })
world:Checkbox({ Text = "Override field of view", Callback = function(v) state.fovOn = v; if not v then Camera.FieldOfView = 70 end end })
world:Slider({ Text = "Field of view", Min = 40, Max = 120, Default = state.fov, Suffix = "°", Callback = function(v) state.fov = v end })

------------------------------------------------------------------------- players list
local function rows()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			table.insert(out, { Icon = "user", Player = p, p.Name, p.DisplayName, p.Team and p.Team.Name or "—", p.AccountAge })
		end
	end
	return out
end
local list = listTab:Table({
	Fill = true, SortColumn = 1, Name = "Players",
	Columns = { { Name = "Name", Width = 2 }, { Name = "Display Name", Width = 2 }, { Name = "Team", Width = 1.4 }, { Name = "Age (days)", Width = 1, Align = "Right" } },
	Rows = rows(),
	Activate = function(r) -- double-click / Enter
		local mine, theirs = root(), r.Player.Character and r.Player.Character:FindFirstChild("HumanoidRootPart")
		if mine and theirs then mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 3); notify("Teleported", "to " .. r.Player.DisplayName, "map-pin") end
	end,
})
on(Players.PlayerAdded, function() list:SetRows(rows()) end)
on(Players.PlayerRemoving, function() task.defer(function() list:SetRows(rows()) end) end)

local spectating
local function spectate(p)
	local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if h and spectating ~= p then
		spectating = p
		Camera.CameraSubject = h
		notify("Spectating", p.DisplayName, "eye")
	else
		spectating = nil
		Camera.CameraSubject = hum()
	end
end

------------------------------------------------------------------------- toolbar
local tb = w:Toolbar({ Labels = true })
tb:Button({ Icon = "refresh-cw", Label = "Refresh", Callback = function() list:SetRows(rows()) end })
tb:Button({ Icon = "map-pin", Label = "Teleport", Callback = function()
	local r = list:GetSelected()
	if not r then notify("No player selected", "Pick someone in the Players tab first.", "triangle-alert") return end
	local mine, theirs = root(), r.Player.Character and r.Player.Character:FindFirstChild("HumanoidRootPart")
	if mine and theirs then mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 3) end
end })
tb:Button({ Icon = "eye", Label = "Spectate", Callback = function()
	local r = list:GetSelected()
	spectate(r and r.Player)
end })
tb:Popover({ Icon = "zap", Label = "Quick", Title = "Quick toggles", Width = 220, Build = function(p)
	p:Button({ Text = "Toggle fly", Callback = function() flyBox:Set(not flyBox:Get()) end })
	p:Button({ Text = "Reset character", Callback = function() local h = hum(); if h then h.Health = 0 end end })
end })
tb:Search({ Label = "Search" })

------------------------------------------------------------------------- misc
local misc = miscTab:Section("Session")
local afkConn
misc:Checkbox({ Text = "Anti-AFK", Callback = function(v)
	if afkConn then afkConn:Disconnect(); afkConn = nil end
	if v then
		afkConn = on(LP.Idled, function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end })
misc:Button({ Label = "Server", Text = "Rejoin", Callback = function()
	w:Alert({ Title = "Rejoin this server?", Text = "You'll be teleported back into the same server.", Buttons = { "Cancel", "Rejoin" },
		Callback = function(b) if b == "Rejoin" then TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end end })
end })
misc:Button({ Label = "Job ID", Text = "Copy", Callback = function()
	if setclipboard then setclipboard(game.JobId); notify("Copied", game.JobId, "clipboard") else notify("Not supported", "This executor has no setclipboard.", "triangle-alert") end
end })
misc:Label("Place " .. game.PlaceId .. " · " .. #Players:GetPlayers() .. " players at load")

local danger = miscTab:Section("Script")
danger:Button({ Label = "Unload everything", Text = "Unload", Callback = function()
	w:Alert({ Title = "Unload the script?", Text = "Turns every feature off and closes the window.", Buttons = { "Cancel", "Unload" }, Callback = function(b)
		if b ~= "Unload" then return end
		state.speedOn, state.jumpOn, state.infJump, state.noclip, state.esp, state.fovOn = false, false, false, false, false, false
		flyBox:Set(false)
		setFullbright(false)
		spectate(nil)
		for _, c in ipairs(conns) do c:Disconnect() end
		espFolder:Destroy()
		local h = hum(); if h then h.WalkSpeed = 16 end
		local blur = workspace.CurrentCamera:FindFirstChild("YosemiteVibrancy"); if blur then blur:Destroy() end
		w.Gui:Destroy()
	end })
end })

-- a setting of our own inside the gear sheet (saved with configs too)
w.Settings:Section("Demo"):Slider({ Text = "ESP refresh (ms)", Min = 100, Max = 2000, Step = 100, Default = 500, Flag = "demo/espRate",
	Callback = function(v) state.espRate = v / 1000 end })

notify("Yosemite Demo loaded", "Ctrl+K to search · " .. (UI.ToggleKey and UI.ToggleKey.Name or "RightShift") .. " to hide", "sparkles")

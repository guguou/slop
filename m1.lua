--[[
	Material1 — Material Design 1 (2014 / Lollipop) UI library for Roblox
	standalone · draggable · keybinds · flags + config

	local M   = loadstring(game:HttpGet(URL))()
	local win = M:Window({ Title = "Hub", Primary = "Indigo", Accent = "Pink",
	                       Dark = false, Size = Vector2.new(560, 420),
	                       ToggleKey = Enum.KeyCode.RightShift })
	local tab = win:Tab("Main")
	local sec = tab:Section("Combat")          -- card w/ subheader
	sec:Switch({ Text = "ESP", Flag = "esp", Callback = function(v) end })
	tab:Button({ Text = "Run" })               -- direct calls go to an untitled card

	Components : Label Subheader Divider Button Switch/Toggle Checkbox Radio
	             Slider TextField/Input Dropdown Keybind
	Window     : Tab SelectTab Snackbar/Notify Dialog FAB Toggle Minimize
	             SetToggleKey Destroy
	Lib        : M.Flags  M:SaveConfig(name)  M:LoadConfig(name)  M:ListConfigs()
	Callbacks don't fire on creation (Default is applied silently).
]]

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local CoreGui      = game:GetService("CoreGui")
local LP           = Players.LocalPlayer

local Material = { Flags = {}, _setters = {}, _binding = false, Version = "0.1.0" }

---------------------------------------------------------------- palette (MD 2014)
local function hex(s) return Color3.fromHex(s) end
local P = {}
local function sw(name, c100, c500, c700, a200)
	P[name] = { [100] = hex(c100), [500] = hex(c500), [700] = hex(c700), A200 = a200 and hex(a200) or nil }
end
sw("Red",        "FFCDD2", "F44336", "D32F2F", "FF5252")
sw("Pink",       "F8BBD0", "E91E63", "C2185B", "FF4081")
sw("Purple",     "E1BEE7", "9C27B0", "7B1FA2", "E040FB")
sw("DeepPurple", "D1C4E9", "673AB7", "512DA8", "7C4DFF")
sw("Indigo",     "C5CAE9", "3F51B5", "303F9F", "536DFE")
sw("Blue",       "BBDEFB", "2196F3", "1976D2", "448AFF")
sw("LightBlue",  "B3E5FC", "03A9F4", "0288D1", "40C4FF")
sw("Cyan",       "B2EBF2", "00BCD4", "0097A7", "18FFFF")
sw("Teal",       "B2DFDB", "009688", "00796B", "64FFDA")
sw("Green",      "C8E6C9", "4CAF50", "388E3C", "69F0AE")
sw("LightGreen", "DCEDC8", "8BC34A", "689F38", "B2FF59")
sw("Lime",       "F0F4C3", "CDDC39", "AFB42B", "EEFF41")
sw("Yellow",     "FFF9C4", "FFEB3B", "FBC02D", "FFFF00")
sw("Amber",      "FFECB3", "FFC107", "FFA000", "FFD740")
sw("Orange",     "FFE0B2", "FF9800", "F57C00", "FFAB40")
sw("DeepOrange", "FFCCBC", "FF5722", "E64A19", "FF6E40")
sw("Brown",      "D7CCC8", "795548", "5D4037")
sw("Grey",       "F5F5F5", "9E9E9E", "616161")
sw("BlueGrey",   "CFD8DC", "607D8B", "455A64")
Material.Palette = P

---------------------------------------------------------------- type
local ROBOTO = "rbxasset://fonts/families/Roboto.json"
local W = { R = Enum.FontWeight.Regular, M = Enum.FontWeight.Medium, B = Enum.FontWeight.Bold }
local function F(weight) return Font.new(ROBOTO, weight or W.R, Enum.FontStyle.Normal) end

---------------------------------------------------------------- utils
local function new(class, props, kids)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	if kids then for _, c in ipairs(kids) do c.Parent = o end end
	if parent then o.Parent = parent end
	return o
end

local function corner(r)
	return new("UICorner", { CornerRadius = (r == "full") and UDim.new(1, 0) or UDim.new(0, r or 2) })
end

local function pad(l, r, t, b, parent)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), Parent = parent })
end

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function fire(cb, ...) if type(cb) == "function" then task.spawn(cb, ...) end end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function lum(c) return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B end

local function toKey(k)
	if typeof(k) == "EnumItem" then return k end
	if type(k) ~= "string" or k == "None" or k == "" then return nil end
	local ok, v = pcall(function() return Enum.KeyCode[k] end)
	if ok and v then return v end
	ok, v = pcall(function() return Enum.UserInputType[k] end)
	if ok and v then return v end
	return nil
end

local function keyName(k)
	if not k then return "None" end
	if k.EnumType == Enum.UserInputType then
		return ({ MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3" })[k.Name] or k.Name
	end
	return k.Name
end

local function mountGui(gui)
	local prot = (syn and syn.protect_gui) or protect_gui
	if prot then pcall(prot, gui) end
	local ok, hui = pcall(function() return gethui() end)
	if ok and typeof(hui) == "Instance" then gui.Parent = hui return end
	if not pcall(function() gui.Parent = CoreGui end) then
		gui.Parent = LP:WaitForChild("PlayerGui")
	end
end

---------------------------------------------------------------- z-depth shadow (fake, layered)
-- holder = transparent frame; shadow goes in at ZIndex 0, surface at ZIndex 1
local function shadow(holder, elev, radius)
	local box = new("Frame", { Name = "Shadow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = holder })
	local layers = {}
	for i = 1, 3 do
		layers[i] = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 0, Parent = box },
			{ corner(radius == "full" and "full" or (radius or 2) + i * 2) })
	end
	local function set(e, anim)
		for i, l in ipairs(layers) do
			local spread = math.floor(e * 0.25 * i + 0.5)
			local drop = math.floor(e * 0.35 + 0.5)
			local props = {
				Size = UDim2.new(1, spread * 2, 1, spread * 2),
				Position = UDim2.fromOffset(-spread, -spread + drop),
				BackgroundTransparency = (e <= 0) and 1 or (0.8 + i * 0.05),
			}
			if anim then tw(l, 0.25, props) else for k, v in pairs(props) do l[k] = v end end
		end
	end
	set(elev or 2)
	return set
end

---------------------------------------------------------------- ink ripple
-- surface must have ClipsDescendants; x/y nil = centered (icon buttons, FAB)
local function ripple(surface, color, x, y, alpha)
	local ap, as = surface.AbsolutePosition, surface.AbsoluteSize
	local px, py, d
	if x then
		px, py = x - ap.X, y - ap.Y
		local fx, fy = math.max(px, as.X - px), math.max(py, as.Y - py)
		d = math.sqrt(fx * fx + fy * fy) * 2
	else
		px, py = as.X / 2, as.Y / 2
		d = math.max(as.X, as.Y)
	end
	local c = new("Frame", { Name = "Ripple", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px, py),
		Size = UDim2.fromOffset(0, 0), BackgroundColor3 = color, BackgroundTransparency = alpha or 0.82,
		BorderSizePixel = 0, ZIndex = 50, Parent = surface }, { corner("full") })
	tw(c, 0.5, { Size = UDim2.fromOffset(d, d) }, Enum.EasingStyle.Quad)
	task.delay(0.3, function()
		tw(c, 0.4, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		task.wait(0.4)
		c:Destroy()
	end)
end

local function ink(b, color, alpha, centered)
	b.InputBegan:Connect(function(i)
		if isPress(i) then
			if centered then ripple(b, color, nil, nil, alpha) else ripple(b, color, i.Position.X, i.Position.Y, alpha) end
		end
	end)
end

local function hover(b, alpha)
	b.MouseEnter:Connect(function() tw(b, 0.15, { BackgroundTransparency = alpha or 0.96 }) end)
	b.MouseLeave:Connect(function() tw(b, 0.15, { BackgroundTransparency = 1 }) end)
end

---------------------------------------------------------------- theme
local function shades(v, fallback)
	if typeof(v) == "Color3" then
		return { [100] = v:Lerp(Color3.new(1, 1, 1), 0.7), [500] = v, [700] = v:Lerp(Color3.new(0, 0, 0), 0.2), A200 = v }
	end
	return P[v] or P[fallback]
end

local function theme(o)
	local p, a = shades(o.Primary, "Indigo"), shades(o.Accent, "Pink")
	local dark = o.Dark == true
	local T = {
		Dark = dark,
		Primary = p[500], PrimaryDark = p[700], PrimaryLight = p[100],
		Accent = a.A200 or a[500],
		Bg   = dark and hex("303030") or hex("FAFAFA"),
		Card = dark and hex("424242") or hex("FFFFFF"),
		Fg   = dark and Color3.new(1, 1, 1) or Color3.new(0, 0, 0),
		-- text opacities: primary / secondary / hint / divider
		T1 = dark and 0 or 0.13, T2 = dark and 0.3 or 0.46, T3 = dark and 0.5 or 0.62, TD = 0.88,
	}
	T.OnPrimary = lum(T.Primary) > 0.6 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
	T.OnAccent  = lum(T.Accent)  > 0.6 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
	T.Ink = dark and T.Accent or T.Primary
	return T
end

local function label(T, props)
	local base = { BackgroundTransparency = 1, FontFace = F(W.R), TextSize = 16, TextColor3 = T.Fg,
		TextTransparency = T.T1, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd }
	for k, v in pairs(props) do base[k] = v end
	return new("TextLabel", base)
end

-- flat button w/ min width 64, used by dialogs + snackbar
local function flatButton(T, parent, text, color, order)
	local b = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.Fg, BackgroundTransparency = 1,
		BorderSizePixel = 0, ClipsDescendants = true, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(64, 36), LayoutOrder = order or 0, Parent = parent }, { corner(2) })
	local l = new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 64, 1, 0),
		Text = string.upper(text), FontFace = F(W.M), TextSize = 14, TextColor3 = color or T.Ink, Parent = b })
	pad(8, 8, 0, 0, l)
	hover(b, 0.92)
	ink(b, T.Fg, 0.85)
	return b
end

local function flag(o, obj, value)
	if o.Flag then
		Material.Flags[o.Flag] = value
		Material._setters[o.Flag] = obj
	end
end

---------------------------------------------------------------- Container (cards)
local Container = {}
Container.__index = Container

function Container:_o()
	self._n = self._n + 1
	return self._n
end

function Container:_row(text, h, rightW)
	local T = self.T
	local row = new("TextButton", { Name = text or "Row", AutoButtonColor = false, Text = "", BackgroundColor3 = T.Fg,
		BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, h or 48), LayoutOrder = self:_o(), Parent = self.list })
	local lbl = label(T, { Text = text or "", Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -(16 + (rightW or 16)), 1, 0), Parent = row })
	hover(row)
	ink(row, T.Fg, 0.9)
	return row, lbl
end

function Container:Label(o)
	if type(o) == "string" then o = { Text = o } end
	o = o or {}
	local T = self.T
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_o(), Parent = self.list })
	pad(16, 16, 10, 10, row)
	local l = label(T, { Text = o.Text or "", TextSize = o.Size or 14, TextTransparency = (o.Secondary == false) and T.T1 or T.T2,
		TextWrapped = true, TextTruncate = Enum.TextTruncate.None, RichText = true,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
	return { Instance = row, SetText = function(_, s) l.Text = s end }
end

function Container:Subheader(text)
	local T = self.T
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = self:_o(), Parent = self.list })
	label(T, { Text = text or "", FontFace = F(W.M), TextSize = 14, TextColor3 = T.Ink, TextTransparency = 0,
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), Parent = row })
	return { Instance = row }
end

function Container:Divider()
	local d = new("Frame", { BackgroundColor3 = self.T.Fg, BackgroundTransparency = self.T.TD, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1), LayoutOrder = self:_o(), Parent = self.list })
	return { Instance = d }
end

-- Raised (default) or flat (Raised=false)
function Container:Button(o)
	o = o or {}
	local T = self.T
	local raised = o.Raised ~= false
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = self:_o(), Parent = self.list })
	local holder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 36), Parent = row })
	local setShadow = raised and shadow(holder, 2) or nil
	local btn = new("TextButton", { AutoButtonColor = false, Text = string.upper(o.Text or "Button"), FontFace = F(W.M), TextSize = 14,
		TextColor3 = raised and T.OnPrimary or T.Ink, BackgroundColor3 = raised and T.Primary or T.Fg,
		BackgroundTransparency = raised and 0 or 1, BorderSizePixel = 0, ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = holder }, { corner(2) })
	ink(btn, raised and T.OnPrimary or T.Fg, raised and 0.75 or 0.85)
	if raised then
		btn.InputBegan:Connect(function(i) if isPress(i) then setShadow(8, true) end end)
		btn.InputEnded:Connect(function(i) if isPress(i) then setShadow(2, true) end end)
	else
		hover(btn, 0.94)
	end
	btn.MouseButton1Click:Connect(function() fire(o.Callback) end)
	return {
		Instance = row,
		SetText = function(_, s) btn.Text = string.upper(s) end,
		Fire = function() fire(o.Callback) end,
	}
end

function Container:Switch(o)
	o = o or {}
	local T = self.T
	local row = self:_row(o.Text, 48, 72)
	local track = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(34, 14), BorderSizePixel = 0, Parent = row }, { corner("full") })
	local th = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -43, 0.5, 0), Size = UDim2.fromOffset(20, 20), Parent = row })
	shadow(th, 1, "full")
	local thumb = new("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = th }, { corner("full") })
	local offThumb = T.Dark and hex("BDBDBD") or hex("FAFAFA")

	local obj = { Value = false, Instance = row }
	function obj:Set(v, silent)
		v = v and true or false
		self.Value = v
		tw(th, 0.2, { Position = UDim2.new(1, v and -23 or -43, 0.5, 0) })
		tw(thumb, 0.2, { BackgroundColor3 = v and T.Accent or offThumb })
		tw(track, 0.2, { BackgroundColor3 = v and T.Accent or T.Fg, BackgroundTransparency = v and 0.5 or (T.Dark and 0.7 or 0.74) })
		if o.Flag then Material.Flags[o.Flag] = v end
		if not silent then fire(o.Callback, v) end
	end
	function obj:Get() return self.Value end
	row.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
	flag(o, obj, false)
	obj:Set(o.Default == true, true)
	return obj
end

function Container:Checkbox(o)
	o = o or {}
	local T = self.T
	local row = self:_row(o.Text, 48, 56)
	local box = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -19, 0.5, 0), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = row }, { corner(2) })
	local stroke = new("UIStroke", { Thickness = 2, Color = T.Fg, Transparency = T.T2, Parent = box })
	-- check mark from two rotated bars
	local legA = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 10), Size = UDim2.fromOffset(6, 2),
		Rotation = 45, BackgroundColor3 = T.OnAccent, BorderSizePixel = 0, Parent = box })
	local legB = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(11, 2),
		Rotation = -45, BackgroundColor3 = T.OnAccent, BorderSizePixel = 0, Parent = box })

	local obj = { Value = false, Instance = row }
	function obj:Set(v, silent)
		v = v and true or false
		self.Value = v
		tw(box, 0.15, { BackgroundTransparency = v and 0 or 1 })
		tw(stroke, 0.15, { Color = v and T.Accent or T.Fg, Transparency = v and 0 or T.T2 })
		tw(legA, 0.15, { BackgroundTransparency = v and 0 or 1 })
		tw(legB, 0.15, { BackgroundTransparency = v and 0 or 1 })
		if o.Flag then Material.Flags[o.Flag] = v end
		if not silent then fire(o.Callback, v) end
	end
	function obj:Get() return self.Value end
	row.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
	flag(o, obj, false)
	obj:Set(o.Default == true, true)
	return obj
end

function Container:Radio(o)
	o = o or {}
	local T = self.T
	if o.Text then self:Subheader(o.Text) end
	local obj = { Value = nil }
	local items = {}
	for _, opt in ipairs(o.Options or {}) do
		local row = self:_row(tostring(opt), 48, 56)
		local ring = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1, Parent = row }, { corner("full") })
		local st = new("UIStroke", { Thickness = 2, Color = T.Fg, Transparency = T.T2, Parent = ring })
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = ring }, { corner("full") })
		table.insert(items, { opt = opt, st = st, dot = dot })
		row.MouseButton1Click:Connect(function() obj:Set(opt) end)
	end
	function obj:Set(v, silent)
		self.Value = v
		for _, it in ipairs(items) do
			local on = it.opt == v
			tw(it.dot, 0.2, { Size = on and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0) }, on and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
			tw(it.st, 0.2, { Color = on and T.Accent or T.Fg, Transparency = on and 0 or T.T2 })
		end
		if o.Flag then Material.Flags[o.Flag] = v end
		if not silent then fire(o.Callback, v) end
	end
	function obj:Get() return self.Value end
	flag(o, obj, nil)
	obj:Set(o.Default, true)
	return obj
end

function Container:Slider(o)
	o = o or {}
	local T = self.T
	local min, max = o.Min or 0, o.Max or 100
	local step = o.Increment or o.Step or 1
	local dec = 0
	do
		local s = tostring(step)
		local p = s:find("%.")
		if p then dec = #s - p end
	end
	local fmt = "%." .. dec .. "f"

	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = self:_o(), Parent = self.list })
	label(T, { Text = o.Text or "", Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -112, 0, 24), Parent = row })
	local val = label(T, { Text = "", TextSize = 14, TextTransparency = T.T2, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(90, 24), Parent = row })
	local track = new("Frame", { Position = UDim2.new(0, 16, 0, 44), Size = UDim2.new(1, -32, 0, 2), BackgroundColor3 = T.Fg,
		BackgroundTransparency = T.Dark and 0.7 or 0.74, BorderSizePixel = 0, Parent = row })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = track })
	local thumb = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = T.Accent, BorderSizePixel = 0, ZIndex = 2, Parent = track }, { corner("full") })
	local ring = new("UIStroke", { Thickness = 2, Color = T.Fg, Transparency = 1, Parent = thumb })
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 32),
		Size = UDim2.new(1, -16, 0, 26), Parent = row })

	local obj = { Value = nil, Instance = row }
	local function snap(v)
		v = math.clamp(v, min, max)
		v = min + math.floor((v - min) / step + 0.5) * step
		return tonumber(string.format(fmt, math.clamp(v, min, max)))
	end
	function obj:Set(v, silent)
		v = snap(tonumber(v) or min)
		local changed = v ~= self.Value
		self.Value = v
		local a = (max == min) and 0 or (v - min) / (max - min)
		tw(fill, 0.1, { Size = UDim2.fromScale(a, 1) }, Enum.EasingStyle.Quad)
		tw(thumb, 0.1, { Position = UDim2.fromScale(a, 0.5) }, Enum.EasingStyle.Quad)
		local atMin = v <= min -- MD1: hollow thumb at zero
		thumb.BackgroundTransparency = atMin and 1 or 0
		ring.Transparency = atMin and T.T3 or 1
		val.Text = string.format(fmt, v) .. (o.Suffix or "")
		if o.Flag then Material.Flags[o.Flag] = v end
		if changed and not silent then fire(o.Callback, v) end
	end
	function obj:Get() return self.Value end

	local dragging = false
	local function at(x)
		local ap, as = track.AbsolutePosition.X, track.AbsoluteSize.X
		obj:Set(min + (max - min) * math.clamp((x - ap) / as, 0, 1))
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			tw(thumb, 0.15, { Size = UDim2.fromOffset(18, 18) })
			at(i.Position.X)
		end
	end)
	self.win:_conn(UIS.InputChanged:Connect(function(i)
		if dragging and isMove(i) then at(i.Position.X) end
	end))
	self.win:_conn(UIS.InputEnded:Connect(function(i)
		if dragging and isPress(i) then
			dragging = false
			tw(thumb, 0.15, { Size = UDim2.fromOffset(12, 12) })
		end
	end))
	flag(o, obj, min)
	obj:Set(o.Default or min, true)
	return obj
end

-- floating-label text field
function Container:TextField(o)
	o = o or {}
	local T = self.T
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = self:_o(), Parent = self.list })
	local lbl = label(T, { Text = o.Text or "", TextTransparency = T.T3, Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 0, 24), Parent = row })
	local box = new("TextBox", { BackgroundTransparency = 1, ClearTextOnFocus = false, Text = tostring(o.Default or ""),
		PlaceholderText = "", PlaceholderColor3 = Color3.fromRGB(158, 158, 158), FontFace = F(W.R), TextSize = 16,
		TextColor3 = T.Fg, TextTransparency = T.T1, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 24), ClipsDescendants = true, Parent = row })
	new("Frame", { BackgroundColor3 = T.Fg, BackgroundTransparency = T.TD, BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 1), Parent = row })
	local focusLine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 61), Size = UDim2.new(0, 0, 0, 2), Parent = row })

	local focused = false
	local function float(anim)
		local up = focused or box.Text ~= ""
		local props = {
			Position = up and UDim2.fromOffset(16, 6) or UDim2.fromOffset(16, 34),
			TextSize = up and 12 or 16,
			TextColor3 = focused and T.Accent or T.Fg,
			TextTransparency = focused and 0 or (up and T.T2 or T.T3),
		}
		if anim then tw(lbl, 0.2, props) else for k, v in pairs(props) do lbl[k] = v end end
		box.PlaceholderText = (focused and box.Text == "") and (o.Placeholder or "") or ""
	end

	local obj = { Value = box.Text, Instance = row, TextBox = box }
	function obj:Set(v, silent, enter)
		v = tostring(v or "")
		box.Text = v
		self.Value = v
		float(true)
		if o.Flag then Material.Flags[o.Flag] = v end
		if not silent then fire(o.Callback, o.Numeric and tonumber(v) or v, enter) end
	end
	function obj:Get() return o.Numeric and tonumber(self.Value) or self.Value end

	box.Focused:Connect(function()
		focused = true
		float(true)
		tw(focusLine, 0.25, { Size = UDim2.new(1, -32, 0, 2) })
	end)
	box.FocusLost:Connect(function(enter)
		focused = false
		tw(focusLine, 0.25, { Size = UDim2.new(0, 0, 0, 2) })
		obj:Set(box.Text, false, enter)
	end)
	if o.Numeric then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local c = box.Text:gsub("[^%d%.%-]", "")
			if c ~= box.Text then box.Text = c end
		end)
	end
	flag(o, obj, box.Text)
	float(false)
	return obj
end

function Container:Dropdown(o)
	o = o or {}
	local T, win = self.T, self.win
	local multi = o.Multi == true
	local options = o.Options or {}
	local row, lbl = self:_row(o.Text, 48, 0)
	lbl.Size = UDim2.new(0.5, -16, 1, 0)
	local vlabel = label(T, { Text = "", TextSize = 14, TextTransparency = T.T2, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 0), Size = UDim2.new(0.5, -40, 1, 0), Parent = row })
	local chev = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(12, 12), Parent = row })
	for _, d in ipairs({ { 4, 45 }, { 8, -45 } }) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(d[1], 6), Size = UDim2.fromOffset(7, 2),
			Rotation = d[2], BackgroundColor3 = T.Fg, BackgroundTransparency = T.T2, BorderSizePixel = 0, Parent = chev })
	end

	local obj = { Value = multi and {} or nil, Instance = row }
	local function list()
		local t = {}
		for _, opt in ipairs(options) do if obj.Value[opt] then table.insert(t, opt) end end
		return t
	end
	local function display()
		if multi then
			local t = {}
			for _, opt in ipairs(list()) do table.insert(t, tostring(opt)) end
			return (#t == 0) and "None" or table.concat(t, ", ")
		end
		return (obj.Value == nil) and "None" or tostring(obj.Value)
	end
	function obj:Set(v, silent)
		if multi then
			local s = {}
			if type(v) == "table" then
				if v[1] ~= nil and type(v[1]) ~= "boolean" then
					for _, x in ipairs(v) do s[x] = true end      -- array form
				else
					for k, x in pairs(v) do if x then s[k] = true end end -- set form
				end
			end
			self.Value = s
		else
			self.Value = v
		end
		vlabel.Text = display()
		local out = multi and list() or self.Value
		if o.Flag then Material.Flags[o.Flag] = out end
		if not silent then fire(o.Callback, out) end
	end
	function obj:Get() return multi and list() or self.Value end
	function obj:Refresh(newOpts, keep)
		options = newOpts or {}
		if keep then vlabel.Text = display() else obj:Set(multi and {} or nil, true) end
	end

	local function open()
		local ov = win.overlay
		local itemH = 48
		local n = #options
		local h = math.min(n, 5) * itemH + 16
		local w = math.max(180, math.floor(row.AbsoluteSize.X * 0.5))
		local ap, as, ovs = row.AbsolutePosition, row.AbsoluteSize, ov.AbsoluteSize
		local y = math.max(8, math.min(ap.Y, ovs.Y - h - 8))
		local catcher = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = ov })
		local holder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(ap.X + as.X - w - 8, y),
			Size = UDim2.fromOffset(w, 0), ZIndex = 2, Parent = ov })
		shadow(holder, 8)
		local surf = new("ScrollingFrame", { BackgroundColor3 = T.Card, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
			ScrollBarImageColor3 = T.Fg, ScrollBarImageTransparency = 0.6, ZIndex = 1, Parent = holder },
			{ corner(2), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
		pad(0, 0, 8, 8, surf)

		local closed = false
		local function close()
			if closed then return end
			closed = true
			tw(holder, 0.15, { Size = UDim2.fromOffset(w, 0) })
			task.delay(0.15, function() holder:Destroy(); catcher:Destroy() end)
		end
		for i, opt in ipairs(options) do
			local sel = multi and obj.Value[opt] or (not multi and obj.Value == opt)
			local it = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.Fg, BackgroundTransparency = 1,
				BorderSizePixel = 0, ClipsDescendants = true, Size = UDim2.new(1, 0, 0, itemH), LayoutOrder = i, Parent = surf })
			local tl = label(T, { Text = tostring(opt), TextColor3 = sel and T.Accent or T.Fg, TextTransparency = sel and 0 or T.T1,
				Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -48, 1, 0), Parent = it })
			hover(it)
			ink(it, T.Fg, 0.88)
			it.MouseButton1Click:Connect(function()
				if multi then
					local s = {}
					for k, x in pairs(obj.Value) do s[k] = x end
					s[opt] = (not s[opt]) or nil
					obj:Set(s)
					local on = s[opt] == true
					tl.TextColor3 = on and T.Accent or T.Fg
					tl.TextTransparency = on and 0 or T.T1
				else
					obj:Set(opt)
					close()
				end
			end)
		end
		catcher.MouseButton1Click:Connect(close)
		tw(holder, 0.2, { Size = UDim2.fromOffset(w, h) })
	end
	row.MouseButton1Click:Connect(open)

	flag(o, obj, multi and {} or nil)
	obj:Set(o.Default, true)
	return obj
end

-- Mode: "Press" (cb()), "Toggle" (cb(state)), "Hold" (cb(true/false))
-- click chip -> press key; Esc/Backspace clears; MB2/MB3 bindable
function Container:Keybind(o)
	o = o or {}
	local T, win = self.T, self.win
	local mode = o.Mode or "Press"
	local row = self:_row(o.Text, 48, 120)
	local chip = new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.Fg, BackgroundTransparency = 0.92, BorderSizePixel = 0,
		FontFace = F(W.M), TextSize = 13, TextColor3 = T.Fg, TextTransparency = T.T1, Text = "", Parent = row }, { corner(2) })
	pad(10, 10, 0, 0, chip)

	local obj = { Value = nil, State = false, Instance = row }
	local binding = false
	local function show()
		if binding then
			chip.Text = "..."
			chip.TextColor3 = T.Accent
			chip.TextTransparency = 0
		else
			chip.Text = string.upper(keyName(obj.Value))
			chip.TextColor3 = T.Fg
			chip.TextTransparency = T.T1
		end
	end
	function obj:Set(k, silent)
		self.Value = toKey(k)
		show()
		if o.Flag then Material.Flags[o.Flag] = self.Value end
		if not silent then fire(o.ChangedCallback, self.Value) end
	end
	function obj:Get() return self.Value end
	local function matches(i)
		local k = obj.Value
		if not k then return false end
		if k.EnumType == Enum.KeyCode then return i.KeyCode == k end
		return i.UserInputType == k
	end

	row.MouseButton1Click:Connect(function()
		binding = true
		Material._binding = true
		show()
	end)
	win:_conn(UIS.InputBegan:Connect(function(i)
		if binding then
			local t = i.UserInputType
			if t == Enum.UserInputType.Keyboard then
				binding = false
				if i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace then obj:Set(nil) else obj:Set(i.KeyCode) end
			elseif t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 then
				binding = false
				obj:Set(t)
			end
			if not binding then task.defer(function() Material._binding = false end) end
			return
		end
		if UIS:GetFocusedTextBox() or not matches(i) then return end
		if mode == "Toggle" then
			obj.State = not obj.State
			fire(o.Callback, obj.State)
		elseif mode == "Hold" then
			obj.State = true
			fire(o.Callback, true)
		else
			fire(o.Callback)
		end
	end))
	if mode == "Hold" then
		win:_conn(UIS.InputEnded:Connect(function(i)
			if obj.State and matches(i) then
				obj.State = false
				fire(o.Callback, false)
			end
		end))
	end
	flag(o, obj, nil)
	obj:Set(o.Default, true)
	return obj
end

Container.Toggle  = Container.Switch
Container.Input   = Container.TextField
Container.Textbox = Container.TextField

---------------------------------------------------------------- Tab
local Tab = {}
Tab.__index = Tab

local function makeSection(tab, title)
	local T = tab.T
	tab._n = tab._n + 1
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = tab._n, Parent = tab.page })
	shadow(holder, 2)
	local surf = new("Frame", { BackgroundColor3 = T.Card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 1, Parent = holder },
		{ corner(2), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	pad(0, 0, title and 0 or 8, 8, surf)
	local s = setmetatable({ T = T, win = tab.win, list = surf, _n = 0, Instance = holder }, Container)
	if title then s:Subheader(title) end
	return s
end

function Tab:Section(title)
	self._def = nil
	return makeSection(self, title)
end

function Tab:Select() self.win:SelectTab(self) end

-- direct component calls on a tab go into an implicit untitled card
for name, fn in pairs(Container) do
	if type(fn) == "function" and name:sub(1, 1) ~= "_" then
		Tab[name] = function(self, ...)
			if not self._def then self._def = makeSection(self) end
			return fn(self._def, ...)
		end
	end
end

---------------------------------------------------------------- Window
local Window = {}
Window.__index = Window

function Window:_conn(c)
	table.insert(self._conns, c)
	return c
end

function Material.Window(a, b)
	local o = (a == Material) and (b or {}) or (a or {})
	local T = theme(o)
	local self = setmetatable({ T = T, _conns = {}, tabs = {}, Visible = true, Minimized = false }, Window)
	local W0 = o.Size and o.Size.X or 560
	local H0 = o.Size and o.Size.Y or 420
	local title = o.Title or "Material"

	local gui = new("ScreenGui", { Name = "Material1_" .. HttpService:GenerateGUID(false):sub(1, 8),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ResetOnSpawn = false, DisplayOrder = 100 })
	mountGui(gui)
	self.gui = gui

	local holder = new("Frame", { Name = "Window", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W0, H0), Parent = gui })
	local scale = new("UIScale", { Parent = holder })
	shadow(holder, 16)
	local surf = new("Frame", { BackgroundColor3 = T.Bg, BorderSizePixel = 0, ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = holder }, { corner(2) })
	self.holder, self.surf, self.scale = holder, surf, scale

	-- app bar (56) + tab strip (48)
	local bar = new("Frame", { BackgroundColor3 = T.Primary, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 104), ZIndex = 3, Parent = surf })
	label(T, { Text = title, FontFace = F(W.M), TextSize = 20, TextColor3 = T.OnPrimary, TextTransparency = 0,
		Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -140, 0, 56), Parent = bar })

	local function iconBtn(xOff)
		local btn = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOff, 0, 28), Size = UDim2.fromOffset(40, 40), ClipsDescendants = true, Parent = bar })
		ink(btn, T.OnPrimary, 0.75, true)
		return btn
	end
	local function bar2(p, w, rot)
		return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, 2),
			Rotation = rot or 0, BackgroundColor3 = T.OnPrimary, BorderSizePixel = 0, Parent = p })
	end
	local closeB = iconBtn(-8)
	bar2(closeB, 16, 45); bar2(closeB, 16, -45)
	local minB = iconBtn(-52)
	bar2(minB, 14, 0)

	local tabList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 56), Size = UDim2.new(1, -16, 0, 48),
		ClipsDescendants = true, Parent = bar },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }) })
	local ind = new("Frame", { BackgroundColor3 = T.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 102),
		Size = UDim2.fromOffset(0, 2), ZIndex = 2, Parent = bar })
	-- app bar elevation (4dp) cast onto content
	new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 0, 6), ZIndex = 3, Parent = surf },
		{ new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.8, 1) }) })
	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -104), ZIndex = 1, Parent = surf })
	self.bar, self.tabList, self.ind, self.content = bar, tabList, ind, content

	-- overlay for menus
	self.overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = gui })

	-- drag (app bar row only)
	if o.Draggable ~= false then
		local dragging, dStart, pStart = false, nil, nil
		bar.InputBegan:Connect(function(i)
			if isPress(i) and (i.Position.Y - bar.AbsolutePosition.Y) <= 56 * scale.Scale then
				dragging, dStart, pStart = true, i.Position, holder.Position
			end
		end)
		self:_conn(UIS.InputChanged:Connect(function(i)
			if dragging and isMove(i) then
				local d = i.Position - dStart
				holder.Position = UDim2.new(pStart.X.Scale, pStart.X.Offset + d.X, pStart.Y.Scale, pStart.Y.Offset + d.Y)
			end
		end))
		self:_conn(UIS.InputEnded:Connect(function(i) if isPress(i) then dragging = false end end))
	end

	minB.MouseButton1Click:Connect(function() self:Minimize() end)
	closeB.MouseButton1Click:Connect(function()
		if o.ConfirmClose == false then return self:Destroy() end
		self:Dialog({ Title = "Close " .. title .. "?", Text = "Running features will keep their current state.",
			Buttons = { { Text = "Cancel" }, { Text = "Close", Callback = function() self:Destroy() end } } })
	end)

	-- show/hide key
	self.ToggleKey = toKey(o.ToggleKey) or Enum.KeyCode.RightShift
	self:_conn(UIS.InputBegan:Connect(function(i)
		if Material._binding or UIS:GetFocusedTextBox() then return end
		if self.ToggleKey and (i.KeyCode == self.ToggleKey or i.UserInputType == self.ToggleKey) then self:Toggle() end
	end))

	scale.Scale = 0.95
	tw(scale, 0.25, { Scale = 1 })
	return self
end
Material.window = Material.Window

function Window:Tab(name)
	local T = self.T
	local idx = #self.tabs + 1
	local btn = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundTransparency = 1, ClipsDescendants = true,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(72, 48), LayoutOrder = idx, Parent = self.tabList })
	local tl = new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 72, 1, 0),
		Text = string.upper(name or ("Tab " .. idx)), FontFace = F(W.M), TextSize = 14, TextColor3 = T.OnPrimary,
		TextTransparency = 0.3, Parent = btn })
	pad(16, 16, 0, 0, tl)
	local page = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Fg, ScrollBarImageTransparency = 0.6, Visible = false, Parent = self.content },
		{ new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }) })
	pad(16, 16, 16, 16, page)

	local tab = setmetatable({ T = T, win = self, page = page, btn = btn, label = tl, _n = 0, Name = name }, Tab)
	ink(btn, T.OnPrimary, 0.75)
	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
	table.insert(self.tabs, tab)
	if idx == 1 then task.delay(0.05, function() if not self.current then self:SelectTab(tab) end end) end
	return tab
end

function Window:SelectTab(tab)
	if type(tab) == "number" then tab = self.tabs[tab] end
	if not tab then return end
	for _, t in ipairs(self.tabs) do
		local on = t == tab
		t.page.Visible = on
		tw(t.label, 0.2, { TextTransparency = on and 0 or 0.3 })
	end
	self.current = tab
	local s = self.scale.Scale
	local x = (tab.btn.AbsolutePosition.X - self.bar.AbsolutePosition.X) / s
	tw(self.ind, 0.3, { Position = UDim2.fromOffset(x, 102), Size = UDim2.fromOffset(tab.btn.AbsoluteSize.X / s, 2) })
end

function Window:Toggle(v)
	if v == nil then v = not self.Visible end
	self.Visible = v
	self.holder.Visible = v
	if v then
		self.scale.Scale = 0.95
		tw(self.scale, 0.2, { Scale = 1 })
	else
		for _, c in ipairs(self.overlay:GetChildren()) do c:Destroy() end
	end
end

function Window:SetToggleKey(k) self.ToggleKey = toKey(k) end

function Window:Minimize(v)
	if v == nil then v = not self.Minimized end
	if v == self.Minimized then return end
	self.Minimized = v
	local w = self.holder.Size.X.Offset
	if v then
		self._fullH = self.holder.Size.Y.Offset
		self.content.Visible = false
	end
	tw(self.holder, 0.25, { Size = UDim2.fromOffset(w, v and 56 or self._fullH) })
	if not v then
		task.delay(0.2, function() if not self.Minimized then self.content.Visible = true end end)
	end
end

-- Snackbar(text, {Action="UNDO", Callback=fn, Duration=3})
function Window:Snackbar(text, o)
	o = o or {}
	local T = self.T
	if self._snack then self._snack() end
	local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 60), Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = hex("323232"), BorderSizePixel = 0, ZIndex = 5, Parent = self.surf },
		{ corner(2), new("UISizeConstraint", { MinSize = Vector2.new(288, 48), MaxSize = Vector2.new(568, 48) }),
		  new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			  Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }) })
	pad(24, 8, 0, 0, bar)
	label(T, { Text = tostring(text), TextSize = 14, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 48), LayoutOrder = 1, Parent = bar })
	local gone = false
	local function dismiss()
		if gone then return end
		gone = true
		if self._snack == dismiss then self._snack = nil end
		tw(bar, 0.2, { Position = UDim2.new(0.5, 0, 1, 60) })
		task.delay(0.2, function() bar:Destroy() end)
	end
	self._snack = dismiss
	if o.Action then
		local a = flatButton(T, bar, o.Action, T.Accent, 2)
		a.MouseButton1Click:Connect(function() fire(o.Callback); dismiss() end)
	end
	tw(bar, 0.25, { Position = UDim2.new(0.5, 0, 1, -16) })
	task.delay(o.Duration or 3, dismiss)
	return { Dismiss = dismiss }
end
Window.Notify = Window.Snackbar

-- Dialog({Title, Text, Buttons={{Text, Callback}}, Dismissable=true, Width=300})
function Window:Dialog(o)
	o = o or {}
	local T = self.T
	local scrim = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = self.surf })
	local h = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(o.Width or 300, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 7, Parent = self.surf })
	local sc = new("UIScale", { Scale = 0.9, Parent = h })
	shadow(h, 24)
	local card = new("Frame", { BackgroundColor3 = T.Card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 1, Parent = h },
		{ corner(2), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	pad(0, 0, 24, 8, card)
	if o.Title then
		local t = label(T, { Text = o.Title, FontFace = F(W.M), TextSize = 20, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1, Parent = card })
		pad(24, 24, 0, 20, t)
	end
	if o.Text then
		local b = label(T, { Text = o.Text, TextSize = 16, TextTransparency = T.T2, TextWrapped = true, RichText = true,
			TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
		pad(24, 24, 0, 24, b)
	end
	local brow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 3, Parent = card },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	pad(8, 8, 0, 0, brow)

	local closed = false
	local function close()
		if closed then return end
		closed = true
		h:Destroy()
		tw(scrim, 0.15, { BackgroundTransparency = 1 })
		task.delay(0.15, function() scrim:Destroy() end)
	end
	for i, bt in ipairs(o.Buttons or { { Text = "OK" } }) do
		local b = flatButton(T, brow, bt.Text or "OK", T.Ink, i)
		b.MouseButton1Click:Connect(function() close(); fire(bt.Callback) end)
	end
	scrim.MouseButton1Click:Connect(function() if o.Dismissable ~= false then close() end end)
	tw(scrim, 0.2, { BackgroundTransparency = 0.5 })
	tw(sc, 0.2, { Scale = 1 })
	return { Close = close }
end

-- FAB({Callback, Image="rbxassetid://..."}) — bottom-right of content
function Window:FAB(o)
	o = o or {}
	local T = self.T
	local h = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(56, 56), ZIndex = 4, Parent = self.surf })
	local setS = shadow(h, 6, "full")
	local b = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.Accent, BorderSizePixel = 0,
		ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = h }, { corner("full") })
	if o.Image then
		new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24), Image = o.Image, ImageColor3 = T.OnAccent, Parent = b })
	else
		for _, r in ipairs({ 0, 90 }) do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 2),
				Rotation = r, BackgroundColor3 = T.OnAccent, BorderSizePixel = 0, Parent = b })
		end
	end
	ink(b, T.OnAccent, 0.75, true)
	b.InputBegan:Connect(function(i) if isPress(i) then setS(12, true) end end)
	b.InputEnded:Connect(function(i) if isPress(i) then setS(6, true) end end)
	b.MouseButton1Click:Connect(function() fire(o.Callback) end)
	return { Instance = h, SetVisible = function(_, v) h.Visible = v end }
end

function Window:Destroy()
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	self._conns = {}
	self.gui:Destroy()
end

---------------------------------------------------------------- config
local CFG = "Material1"

function Material:SaveConfig(name)
	if not writefile then return false, "writefile unavailable" end
	local out = {}
	for k, v in pairs(self.Flags) do
		out[k] = (typeof(v) == "EnumItem") and v.Name or v
	end
	if makefolder and isfolder and not isfolder(CFG) then makefolder(CFG) end
	writefile(CFG .. "/" .. name .. ".json", HttpService:JSONEncode(out))
	return true
end

function Material:LoadConfig(name)
	if not (readfile and isfile) then return false, "readfile unavailable" end
	local p = CFG .. "/" .. name .. ".json"
	if not isfile(p) then return false, "not found" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(p)) end)
	if not ok or type(data) ~= "table" then return false, "bad json" end
	for k, v in pairs(data) do
		local s = self._setters[k]
		if s then s:Set(v) end
	end
	return true
end

function Material:ListConfigs()
	local out = {}
	if not (listfiles and isfolder and isfolder(CFG)) then return out end
	for _, f in ipairs(listfiles(CFG)) do
		local n = f:match("([^/\\]+)%.json$")
		if n then table.insert(out, n) end
	end
	return out
end

return Material

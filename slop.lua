--[[ Yosemite UI: macOS 10.10 styled Roblox UI lib (concept) — final stage
  Stage 4:
  - Fake vibrancy: translucent sidebar/titlebar/popovers over a camera BlurEffect (Settings > Vibrancy)
    Surfaces are built from non-overlapping pieces so translucency has no darker seams at the rounded corners.
  - Popovers: sec:Popover / tb:Popover / w:Popover(anchor, o), any control works inside
  - Color picker: sec:ColorPicker opens a Colors panel (Picker / Sliders / Palette, hex field), saved in configs
  - Keyboard: Tab / Shift+Tab / Up / Down move focus (blue ring), Left/Right adjust, Enter/Space activate,
    Esc closes popover / panel / sheet; Enter fires a sheet's default button; Ctrl+K opens the command bar
  - Command bar (Spotlight style): jump to any tab or control
  - Mobile: draggable floating toggle button, bigger rows and traffic-light hit areas on touch devices
  - Every control returns an object with :SetVisible(bool), :SetDisabled(bool), :SetText(text)
  - Key system: UI:KeySystem({...}) — auth dialog with saved keys, shake on a wrong key
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Http = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local LUCIDE_URL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"
local RGB = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local FONT, BOLD = Enum.Font.Arial, Enum.Font.ArialBold
local CS = ColorSequence.new
local AX, AY = Enum.AutomaticSize.X, Enum.AutomaticSize.Y
local H_DIR, V_DIR = Enum.FillDirection.Horizontal, Enum.FillDirection.Vertical
local LEFT, CENTER, RIGHT = Enum.HorizontalAlignment.Left, Enum.HorizontalAlignment.Center, Enum.HorizontalAlignment.Right
local MID = Enum.VerticalAlignment.Center
local BACK = Enum.EasingStyle.Back
local KC = Enum.KeyCode
local LIGHTS = {
	{ RGB(252, 97, 93), RGB(222, 62, 59), "×" },
	{ RGB(253, 188, 64), RGB(222, 160, 36), "–" },
	{ RGB(52, 200, 74), RGB(26, 171, 41), "+" },
}

local Themes = {
	Light = {
		Window = RGB(236, 236, 236), BarTop = RGB(236, 236, 236), BarBot = RGB(212, 212, 212), WinStroke = .55,
		Sidebar = RGB(240, 240, 242), Border = RGB(176, 176, 176), Line = RGB(170, 170, 170),
		Text = RGB(38, 38, 38), Dim = RGB(128, 128, 128), Icon = RGB(105, 105, 110),
		Title = RGB(77, 77, 77), TitleOff = RGB(160, 160, 160),
		Box = WHITE, BoxBorder = RGB(205, 205, 205), Stripe = RGB(245, 245, 245),
		BtnTop = WHITE, BtnBot = RGB(240, 240, 240), Field = WHITE, Placeholder = RGB(165, 165, 165), Menu = RGB(246, 246, 246),
		Pop = RGB(248, 248, 248),
		Sel = BLACK, SelT = .86, Knob = WHITE, KnobBorder = RGB(150, 150, 150), Track = WHITE, Scroll = BLACK,
		LightOff = RGB(204, 204, 204), LightOffBorder = RGB(184, 184, 184),
		SideT = .2, BarT = .08, PopT = .05, -- vibrancy translucency
	},
	Dark = {
		Window = RGB(42, 42, 44), BarTop = RGB(64, 64, 66), BarBot = RGB(50, 50, 52), WinStroke = .1,
		Sidebar = RGB(34, 34, 36), Border = RGB(92, 92, 94), Line = RGB(20, 20, 20),
		Text = RGB(226, 226, 226), Dim = RGB(140, 140, 140), Icon = RGB(170, 170, 175),
		Title = RGB(200, 200, 200), TitleOff = RGB(115, 115, 115),
		Box = RGB(48, 48, 50), BoxBorder = RGB(70, 70, 72), Stripe = RGB(55, 55, 57),
		BtnTop = RGB(100, 100, 102), BtnBot = RGB(82, 82, 84), Field = RGB(30, 30, 32), Placeholder = RGB(105, 105, 105), Menu = RGB(46, 46, 48),
		Pop = RGB(50, 50, 52),
		Sel = WHITE, SelT = .88, Knob = RGB(205, 205, 205), KnobBorder = RGB(60, 60, 60), Track = RGB(30, 30, 32), Scroll = WHITE,
		LightOff = RGB(80, 80, 82), LightOffBorder = RGB(62, 62, 64),
		SideT = .25, BarT = .1, PopT = .08,
	},
}
local Accents = {
	Blue = { Top = RGB(106, 178, 250), Bot = RGB(15, 128, 247), Border = RGB(40, 114, 222), Solid = RGB(58, 140, 247), Focus = RGB(108, 180, 245) },
	Graphite = { Top = RGB(168, 172, 180), Bot = RGB(122, 127, 136), Border = RGB(100, 105, 113), Solid = RGB(128, 133, 143), Focus = RGB(160, 165, 175) },
}
local PALETTE = { "#FF3B30", "#FF9500", "#FFCC00", "#4CD964", "#5AC8FA", "#007AFF", "#5856D6", "#FF2D55",
	"#C0392B", "#D35400", "#B7950B", "#1E8449", "#1F8EBF", "#1F4FB8", "#6C3483", "#A93250",
	"#FFFFFF", "#D1D1D6", "#AEAEB2", "#8E8E93", "#636366", "#3A3A3C", "#1C1C1E", "#000000" }

local Lib = { Themes = Themes, Accents = Accents, Visible = true, _listening = 0, BlurSize = 14 }
Lib.Touch = UIS.TouchEnabled and not UIS.MouseEnabled
local ROWH = Lib.Touch and 36 or 30

-- files ------------------------------------------------------------------------
local function mkdirs(path)
	if not path or not makefolder then return end
	local acc
	for part in path:gmatch("[^/]+") do
		acc = acc and (acc .. "/" .. part) or part
		pcall(function() if not (isfolder and isfolder(acc)) then makefolder(acc) end end)
	end
end
local UI_FILE = "Yosemite/ui.json"
local saved = {}
pcall(function() if isfile and isfile(UI_FILE) then saved = Http:JSONDecode(readfile(UI_FILE)) end end)
local function save() pcall(function() mkdirs("Yosemite"); writefile(UI_FILE, Http:JSONEncode(saved)) end) end
if saved.Vibrancy == nil then saved.Vibrancy = true end

local T = Themes[saved.Theme] or Themes.Light
local A = Accents[saved.Accent] or Accents.Blue
pcall(function() Lib.ToggleKey = KC[saved.ToggleKey or "RightShift"] end)

-- theming ------------------------------------------------------------------------
local hooks, themeAnim = {}, false
local function bind(fn) table.insert(hooks, fn); fn() end
local function refresh(anim)
	themeAnim = anim and not saved.Reduce
	for _, fn in ipairs(hooks) do fn() end
	themeAnim = false
end
local function setp(i, prop, v)
	if themeAnim and (typeof(v) == "Color3" or type(v) == "number") then
		TS:Create(i, TweenInfo.new(.25), { [prop] = v }):Play()
	else
		i[prop] = v
	end
end
local function vib(key) return saved.Vibrancy and T[key] or 0 end

-- helpers ------------------------------------------------------------------
local function new(class, p, kids)
	local i = Instance.new(class)
	local parent = p.Parent
	p.Parent = nil
	for k, v in pairs(p) do i[k] = v end
	for _, k in ipairs(kids or {}) do k.Parent = i end
	i.Parent = parent
	return i
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function pad(t, b, l, r)
	return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b or t),
		PaddingLeft = UDim.new(0, l or t), PaddingRight = UDim.new(0, r or l or t) })
end
local function list(dir, p, ha, va)
	return new("UIListLayout", { FillDirection = dir or V_DIR, Padding = UDim.new(0, p or 0), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = ha or LEFT, VerticalAlignment = va or Enum.VerticalAlignment.Top })
end
local function tc(i, prop, key) bind(function() setp(i, prop, T[key]) end) return i end
local function stroke(key, tr)
	local s = new("UIStroke", { Color = BLACK, Thickness = 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	if key then tc(s, "Color", key) end
	return s
end
local function sgrad(a, b) return new("UIGradient", { Color = CS(a, b), Rotation = 90 }) end
local function tgrad(ka, kb) local g = sgrad(WHITE, WHITE); bind(function() g.Color = CS(T[ka], T[kb]) end) return g end
local function agrad() local g = sgrad(WHITE, WHITE); bind(function() g.Color = CS(A.Top, A.Bot) end) return g end
local function label(p)
	local key = p.Color
	if key == nil then key = "Text" end
	p.Color = nil
	local d = { BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }
	for k, v in pairs(p) do d[k] = v end
	local l = new("TextLabel", d)
	if key then tc(l, "TextColor3", key) end
	return l
end
local function tw(o, t, p, style, dir)
	local x = TS:Create(o, TweenInfo.new(saved.Reduce and 0 or t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), p)
	x:Play()
	return x
end
local function scaleOf(o) return o:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = o }) end
local function pop(o, from, t) local s = scaleOf(o); s.Scale = from or .6; tw(s, t or .22, { Scale = 1 }, BACK) end
local function textW(s, size, font) return TextService:GetTextSize(s, size, font or FONT, Vector2.new(1000, 100)).X end
local function fmt(v) return tostring(math.round(v * 1000) / 1000) end
local function guiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	if pcall(function() return CoreGui.Name end) then return CoreGui end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end
local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local function isMove(i) return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end
local function inside(g, p)
	local a, s = g.AbsolutePosition, g.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end
local function mousePos() return UIS:GetMouseLocation() - GuiService:GetGuiInset() end
local floating = {} -- menus / popovers / color panel: clicks inside these don't close the others
local function inFloating(p)
	for fr in pairs(floating) do if fr.Parent and fr.Visible and inside(fr, p) then return true end end
	return false
end
local function ring(s, on)
	if on then
		s.Color = A.Focus; s.Thickness = 7; s.Transparency = 1
		tw(s, .2, { Thickness = 3, Transparency = .2 })
	else
		tw(s, .12, { Thickness = 1, Transparency = 0, Color = T.Border })
	end
end
local function flash(f)
	f.BackgroundColor3 = A.Solid
	f.BackgroundTransparency = .7
	tw(f, .9, { BackgroundTransparency = 1 })
end

-- icons (lucide-roblox spritesheets, text fallbacks) -------------------------------
local FALLBACK = { settings = "⚙", search = "🔍", ["circle-x"] = "ⓧ", x = "×", check = "✓", ["chevron-down"] = "▾",
	["chevron-up"] = "▴", ["chevron-left"] = "‹", ["chevron-right"] = "›", info = "ⓘ", ellipsis = "…", ["app-window"] = "▣" }
local KIND_ICONS = { button = "mouse-pointer-click", checkbox = "square-check", slider = "sliders-horizontal", segmented = "columns-3",
	popup = "chevrons-up-down", text = "text-cursor-input", keybind = "keyboard", stepper = "hash", radio = "circle-dot",
	color = "palette", popover = "message-square", table = "table" }
local lucideMod, lucideTried, iconCache = nil, false, {}
local function lucideImage(name, px)
	local key = name .. "@" .. px
	if iconCache[key] ~= nil then return iconCache[key] end
	if not lucideTried then
		lucideTried = true
		if type(Lib.Lucide) == "table" then
			lucideMod = Lib.Lucide
		elseif Lib.Lucide ~= false then
			local ok, m = pcall(function() return loadstring(game:HttpGet(LUCIDE_URL, true))() end)
			if ok and type(m) == "table" then lucideMod = m end
		end
	end
	local img = false
	if lucideMod and lucideMod.GetAsset then
		local ok, a = pcall(lucideMod.GetAsset, name, px)
		if ok and a then img = { Image = a.Url, RectSize = a.ImageRectSize, RectOffset = a.ImageRectOffset } end
	elseif lucideMod and lucideMod.geticon then
		local ok, r = pcall(lucideMod.geticon, lucideMod, name, { size = px, color = "#ffffff", stroke_width = 2 })
		if ok and type(r) == "string" then img = { Image = r } end
	end
	iconCache[key] = img
	return img
end
local function icon(name, size, colorKey, props)
	local lucideName = name:match("^[%l%d%-_]+$") ~= nil
	local img = lucideName and lucideImage(name, size * 2)
	local d = { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) }
	if img then
		d.Image, d.ScaleType = img.Image, Enum.ScaleType.Fit
		if img.RectSize then d.ImageRectSize, d.ImageRectOffset = img.RectSize, img.RectOffset end
	else
		d.Text = FALLBACK[name] or (lucideName and "•" or name)
		d.Font, d.TextSize = FONT, size
	end
	for k, v in pairs(props or {}) do d[k] = v end
	local o = new(img and "ImageLabel" or "TextLabel", d)
	local function paint(c) setp(o, img and "ImageColor3" or "TextColor3", c) end
	if colorKey then bind(function() paint(T[colorKey]) end) end
	return o, paint
end

-- rounded surface built from pieces that never overlap, so translucent fills have no seams
-- rc = { topLeft, topRight, bottomLeft, bottomRight } rounded?
local function panel(parent, r, rc, props)
	props.BackgroundTransparency = 1
	props.Parent = parent
	local root = new("Frame", props)
	local pieces = {}
	local function add(pos, size, from, off, h, round, qx, qy)
		local f
		if round then
			local clip = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = pos, Size = size, Parent = root })
			f = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, Position = UDim2.fromOffset(-qx * r, -qy * r),
				Size = UDim2.fromOffset(2 * r, 2 * r), Parent = clip }, { corner(r) })
			off, h = off - qy * r, 2 * r
		else
			f = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, Position = pos, Size = size, Parent = root })
		end
		table.insert(pieces, { f = f, g = new("UIGradient", { Rotation = 90, Parent = f }), from = from, off = off, h = h })
	end
	local sq = UDim2.fromOffset(r, r)
	add(UDim2.new(), sq, "top", 0, r, rc[1], 0, 0)
	add(UDim2.new(1, -r, 0, 0), sq, "top", 0, r, rc[2], 1, 0)
	add(UDim2.new(0, 0, 1, -r), sq, "bottom", 0, r, rc[3], 0, 1)
	add(UDim2.new(1, -r, 1, -r), sq, "bottom", 0, r, rc[4], 1, 1)
	add(UDim2.fromOffset(r, 0), UDim2.new(1, -2 * r, 0, r), "top", 0, r)
	add(UDim2.new(0, r, 1, -r), UDim2.new(1, -2 * r, 0, r), "bottom", 0, r)
	add(UDim2.fromOffset(0, r), UDim2.new(1, 0, 1, -2 * r), "mid", 0, 0)
	local P = { Root = root }
	function P.Paint(H, c0, c1, t)
		H = math.max(H, 1)
		for _, p in ipairs(pieces) do
			local y0 = p.from == "top" and p.off or p.from == "bottom" and (H - r + p.off) or r
			local h = p.from == "mid" and math.max(H - 2 * r, 0) or p.h
			local a, b = math.clamp(y0 / H, 0, 1), math.clamp((y0 + h) / H, 0, 1)
			p.g.Color = CS(c0:Lerp(c1, a), c0:Lerp(c1, b))
			setp(p.f, "BackgroundTransparency", t)
		end
	end
	return P
end

-- vibrancy blur ---------------------------------------------------------------------
local windows = {}
local blur
local function updateBlur()
	local want = saved.Vibrancy and Lib.Visible and #windows > 0
	local cam = workspace.CurrentCamera
	if want and not blur then blur = new("BlurEffect", { Name = "YosemiteVibrancy", Size = 0, Parent = cam }) end
	if blur then
		blur.Parent = cam
		tw(blur, .3, { Size = want and Lib.BlurSize or 0 })
	end
end

-- shared widgets -------------------------------------------------------------
local function pushButton(parent, o)
	local h = o.Height or 22
	local hasText = o.Text ~= nil and o.Text ~= ""
	local w = o.Width
	if not w then
		w = (hasText and textW(o.Text, o.TextSize or 13) + 20 or 12) + (o.Icon and 18 or 0) + (o.Chevron and 12 or 0)
		w = math.max(w, o.MinWidth or (hasText and 70 or 32))
	end
	local s = stroke(nil)
	local fill = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromOffset(w, h),
		LayoutOrder = o.Order or 0, Parent = parent }, { corner(4), s, o.Default and agrad() or tgrad("BtnTop", "BtnBot") })
	bind(function() setp(s, "Color", o.Default and A.Border or T.Border) end)
	local content = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(0, h), AutomaticSize = AX, Parent = fill }, { list(H_DIR, 4, CENTER, MID) })
	local paints, txt = {}, nil
	if o.Icon then local _, p = icon(o.Icon, 16, nil, { LayoutOrder = 0, Parent = content }); table.insert(paints, p) end
	if hasText then
		txt = label({ Text = o.Text, Color = false, TextSize = o.TextSize or 13, AutomaticSize = AX, Size = UDim2.fromOffset(0, h),
			LayoutOrder = 1, Parent = content })
		table.insert(paints, function(c) setp(txt, "TextColor3", c) end)
	end
	if o.Chevron then local _, p = icon("chevron-down", 10, nil, { LayoutOrder = 2, Parent = content }); table.insert(paints, p) end
	bind(function() for _, p in ipairs(paints) do p(o.Default and WHITE or T.Text) end end)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = fill })
	b.MouseButton1Down:Connect(function() tw(fill, .06, { BackgroundColor3 = RGB(200, 200, 200) }) end)
	local function up() tw(fill, .18, { BackgroundColor3 = WHITE }) end
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
	b.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
	return fill, b, { SetText = function(t) if txt then txt.Text = t end end, Text = txt }
end

local function segmented(parent, o)
	local items, H, n = o.Items, o.Height or 22, #o.Items
	local W = o.SegWidth
	if not W then
		W = o.Icons and 32 or 56
		if not o.Icons then for _, it in ipairs(items) do W = math.max(W, textW(it, 12) + 20) end end
	end
	local cont = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromOffset(W * n, H),
		LayoutOrder = o.Order or 0, Parent = parent }, { corner(4), stroke("Border"), tgrad("BtnTop", "BtnBot") })
	local segs, cur = {}, nil
	local obj = {}
	function obj:Set(name, silent, instant)
		cur = name
		for nm, sg in pairs(segs) do
			local t = nm == name and 0 or 1
			for _, f in ipairs(sg.fills) do
				if instant then f.BackgroundTransparency = t else tw(f, .15, { BackgroundTransparency = t }) end
			end
			sg.paint(nm == name and WHITE or T.Text)
		end
		if not silent and o.Callback then task.spawn(o.Callback, name) end
	end
	function obj:Get() return cur end
	function obj:Step(d)
		local i = math.clamp((table.find(items, cur) or 1) + d, 1, n)
		if items[i] ~= cur then obj:Set(items[i]) end
	end
	for idx, name in ipairs(items) do
		local fill = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = UDim2.fromOffset((idx - 1) * W, 0), Size = UDim2.fromOffset(W, H), Parent = cont }, { agrad() })
		local fills = { fill }
		if idx == 1 or idx == n then
			corner(4).Parent = fill
			if n > 1 then
				table.insert(fills, new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
					Size = UDim2.new(.5, 0, 1, 0), Position = UDim2.fromScale(idx == 1 and .5 or 0, 0), Parent = fill }, { agrad() }))
			end
		end
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = UDim2.fromOffset((idx - 1) * W, 0), Size = UDim2.fromOffset(W, H), ZIndex = 2, Parent = cont })
		local paint
		if o.Icons then
			paint = select(2, icon(name, 15, nil, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), ZIndex = 2, Parent = b }))
		else
			local l = label({ Text = name, Color = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = b })
			paint = function(c) setp(l, "TextColor3", c) end
		end
		if idx > 1 then
			tc(new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset((idx - 1) * W, 0), Size = UDim2.new(0, 1, 1, 0),
				ZIndex = 3, Parent = cont }), "BackgroundColor3", "Border")
		end
		segs[name] = { fills = fills, paint = paint }
		b.MouseButton1Click:Connect(function() if cur ~= name then obj:Set(name) end end)
	end
	obj:Set(o.Default or items[1], true, true)
	bind(function() obj:Set(cur, true, true) end)
	return cont, obj
end

-- dropdown menu: unrolls, blinks the picked item (classic Mac), closes on outside click
local function openMenu(gui, anchor, items, cur, onPick, width)
	local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
	local W = math.max(width or as.X, 120)
	local H = 4 + #items * 20
	local menu = new("Frame", { BackgroundColor3 = T.Menu, BackgroundTransparency = vib("PopT"), BorderSizePixel = 0, ZIndex = 50,
		ClipsDescendants = true, Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 2), Size = UDim2.fromOffset(W, 0), Parent = gui },
		{ corner(5), stroke(nil, .6) })
	floating[menu] = true
	tw(menu, .14, { Size = UDim2.fromOffset(W, H) })
	local conn, closed
	local function kill()
		tw(menu, .1, { Size = UDim2.fromOffset(W, 0) }).Completed:Connect(function() floating[menu] = nil; menu:Destroy() end)
	end
	local function close()
		if closed then return end
		closed = true
		if conn then conn:Disconnect() end
		kill()
	end
	for idx, name in ipairs(items) do
		local it = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = A.Solid, BackgroundTransparency = 1,
			BorderSizePixel = 0, ZIndex = 51, Position = UDim2.fromOffset(2, 2 + (idx - 1) * 20), Size = UDim2.new(1, -4, 0, 20), Parent = menu }, { corner(3) })
		local l = label({ Text = (cur ~= nil and (name == cur and "✓ " or "   ") or "") .. name, Color = false, TextColor3 = T.Text, ZIndex = 52,
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -8, 1, 0), Parent = it })
		it.MouseEnter:Connect(function() if not closed then it.BackgroundTransparency = 0; l.TextColor3 = WHITE end end)
		it.MouseLeave:Connect(function() if not closed then it.BackgroundTransparency = 1; l.TextColor3 = T.Text end end)
		it.MouseButton1Click:Connect(function()
			if closed then return end
			closed = true
			if conn then conn:Disconnect() end
			task.spawn(function()
				if not saved.Reduce then
					for _ = 1, 2 do
						it.BackgroundTransparency = 1; l.TextColor3 = T.Text; task.wait(.05)
						it.BackgroundTransparency = 0; l.TextColor3 = WHITE; task.wait(.05)
					end
				end
				kill()
				onPick(name)
			end)
		end)
	end
	task.defer(function()
		if closed then return end
		conn = UIS.InputBegan:Connect(function(i)
			if isPress(i) and not inside(menu, i.Position) then close() end
		end)
	end)
	return close
end

-- classes ------------------------------------------------------------------
local Window, Tab, Section, Category, Toolbar = {}, {}, {}, {}, {}
Window.__index, Tab.__index, Section.__index, Category.__index, Toolbar.__index = Window, Tab, Section, Category, Toolbar

function Lib:SetTheme(name)
	if not Themes[name] then return end
	T = Themes[name]; saved.Theme = name; save(); refresh(true)
end
function Lib:SetAccent(name)
	if not Accents[name] then return end
	A = Accents[name]; saved.Accent = name; save(); refresh(true)
end
function Lib:SetVibrancy(on) saved.Vibrancy = on; save(); refresh(true); updateBlur() end
function Lib:SetReduceMotion(on) saved.Reduce = on; save() end
function Lib:SetToggleKey(k) Lib.ToggleKey = k; saved.ToggleKey = k and k.Name or "None"; save() end

-- notifications (Yosemite banners are always dark) --------------------------------
local notifyHolder
function Lib:Notify(o)
	if not notifyHolder or not notifyHolder.Parent then
		local g = new("ScreenGui", { Name = "YosemiteNotify", ResetOnSpawn = false, DisplayOrder = 100, Parent = guiParent() })
		notifyHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.new(0, 340, 1, -24), Parent = g }, { list(nil, 8) })
	end
	local btns = o.Buttons
	local slot = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromScale(1, 0), AutomaticSize = AY, Parent = notifyHolder })
	local card = new("Frame", { BackgroundColor3 = RGB(38, 38, 40), BackgroundTransparency = saved.Vibrancy and .12 or .04, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0), AutomaticSize = AY, Position = UDim2.new(1, 10, 0, 0), Parent = slot }, { corner(6), stroke(nil, .4) })
	local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = card })
	local main = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, btns and -72 or 0, 0, 0), AutomaticSize = AY, ZIndex = 2, Parent = card },
		{ pad(10, 10, o.Icon and 52 or 12, 12), list(nil, 2) })
	if o.Icon then
		local _, paint = icon(o.Icon, 28, nil, { Position = UDim2.fromOffset(12, 10), ZIndex = 2, Parent = card })
		paint(WHITE)
	end
	label({ Text = o.Title or "Notification", Font = BOLD, Color = false, TextColor3 = WHITE, TextWrapped = true, AutomaticSize = AY,
		Size = UDim2.new(1, 0, 0, 16), ZIndex = 2, Parent = main })
	if o.Text then
		label({ Text = o.Text, TextSize = 12, Color = false, TextColor3 = RGB(205, 205, 205), TextWrapped = true, AutomaticSize = AY,
			Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, ZIndex = 2, Parent = main })
	end
	local gone, hovering = false, false
	local function dismiss(choice)
		if gone then return end
		gone = true
		tw(card, .22, { Position = UDim2.new(1, 10, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(saved.Reduce and 0 or .2, function()
			slot.AutomaticSize = Enum.AutomaticSize.None
			slot.Size = UDim2.new(1, 0, 0, slot.AbsoluteSize.Y)
			tw(slot, .2, { Size = UDim2.fromScale(1, 0) }).Completed:Connect(function() slot:Destroy() end)
		end)
		if choice and o.Callback then task.spawn(o.Callback, choice) end
	end
	if btns then
		local col = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 72, 1, 0), ZIndex = 2, Parent = card })
		new("Frame", { BackgroundColor3 = RGB(85, 85, 88), BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), ZIndex = 2, Parent = col })
		for k, name in ipairs(btns) do
			local b = new("TextButton", { Text = name, Font = FONT, TextSize = 12, TextColor3 = WHITE, AutoButtonColor = false,
				BackgroundTransparency = 1, Position = UDim2.new(0, 1, (k - 1) / #btns, 0), Size = UDim2.new(1, -1, 1 / #btns, 0), ZIndex = 3, Parent = col })
			if k > 1 then
				new("Frame", { BackgroundColor3 = RGB(85, 85, 88), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), ZIndex = 3, Parent = b })
			end
			b.MouseButton1Click:Connect(function() dismiss(name) end)
		end
	end
	local x = new("TextButton", { Text = "×", Font = BOLD, TextSize = 12, TextColor3 = WHITE, AutoButtonColor = false, BackgroundColor3 = RGB(78, 78, 80),
		Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(16, 16), Visible = false, ZIndex = 4, Parent = card }, { corner(8) })
	card.MouseEnter:Connect(function() hovering = true; x.Visible = true; pop(x, .5, .15) end)
	card.MouseLeave:Connect(function() hovering = false; x.Visible = false end)
	x.MouseButton1Click:Connect(function() dismiss() end)
	hit.MouseButton1Click:Connect(function()
		if o.OnClick then task.spawn(o.OnClick) end
		dismiss()
	end)
	tw(card, .35, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quint)
	if o.Duration ~= 0 then
		task.spawn(function()
			task.wait(o.Duration or 5)
			while hovering and not gone do task.wait(.25) end
			dismiss()
		end)
	end
	return { Dismiss = function() dismiss() end }
end

-- key system (macOS-style authentication dialog) -----------------------------------------
-- local ok = UI:KeySystem({ Title = "My Hub", Keys = { "abc" } or Validate = function(key) return bool end,
--   Link = "https://get.key/here", Note = "...", SaveKey = true, FileName = "MyHub/key.txt" })
-- yields until the user enters a valid key (true) or cancels (false); a saved valid key skips the dialog
function Lib:KeySystem(o)
	o = o or {}
	local file = o.FileName or ("Yosemite/Keys/" .. (o.Title or "key"):gsub("[^%w]", "") .. ".txt")
	local function trim(k) return ((k or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
	local function valid(k)
		k = trim(k)
		if k == "" then return false end
		if o.Validate then
			local ok, r = pcall(o.Validate, k)
			return ok and r == true
		end
		for _, v in ipairs(o.Keys or {}) do if v == k then return true end end
		return false
	end
	if o.SaveKey ~= false then
		local ok, k = pcall(readfile, file)
		if ok and k and valid(k) then return true end
	end

	local result
	local gui = new("ScreenGui", { Name = "YosemiteKey", ResetOnSpawn = false, DisplayOrder = 90, Parent = guiParent() })
	local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(400, 0), AutomaticSize = AY, Parent = gui }, { corner(6) })
	local fs = stroke(nil)
	tc(f, "BackgroundColor3", "Window"); tc(fs, "Transparency", "WinStroke"); fs.Parent = f
	local bar = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 22), Parent = f }, { corner(6), tgrad("BarTop", "BarBot") })
	tc(new("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6), Parent = bar }), "BackgroundColor3", "BarBot")
	label({ Text = o.Title or "Key Required", TextSize = 12, Color = "Title", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = bar })
	local xb = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = LIGHTS[1][1], Position = UDim2.fromOffset(8, 5),
		Size = UDim2.fromOffset(12, 12), Parent = bar }, { corner(6), new("UIStroke", { Color = LIGHTS[1][2] }) })

	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.fromScale(1, 0), AutomaticSize = AY, Parent = f },
		{ pad(18, 16, 20, 20) })
	icon("lock", 48, "Icon", { Position = UDim2.fromOffset(0, 2), Parent = body })
	local col = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -66, 0, 0), AutomaticSize = AY, Parent = body },
		{ list(nil, 8) })
	label({ Text = o.Subtitle or "Enter your key to continue.", Font = BOLD, TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 16), Parent = col })
	if o.Note then
		label({ Text = o.Note, TextSize = 12, Color = "Dim", TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = col })
	end
	local s = stroke("Border")
	local box = new("TextBox", { Text = "", PlaceholderText = "Key", ClearTextOnFocus = false, Font = FONT, TextSize = 13, BorderSizePixel = 0,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2, Parent = col }, { corner(3), s, pad(0, 0, 6, 6) })
	tc(box, "BackgroundColor3", "Field"); tc(box, "TextColor3", "Text"); tc(box, "PlaceholderColor3", "Placeholder")
	local err = label({ Text = "", TextSize = 12, Color = false, TextColor3 = RGB(230, 70, 60), TextWrapped = true, AutomaticSize = AY,
		Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3, Visible = false, Parent = col })
	local foot = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 4, Parent = col },
		{ list(H_DIR, 8, RIGHT, MID) })

	local busy = false
	local function finish(ok)
		if result ~= nil then return end
		result = ok
		tw(scaleOf(f), .15, { Scale = .9 }).Completed:Connect(function() gui:Destroy() end)
	end
	local function shake()
		local p = f.Position
		task.spawn(function()
			for _, dx in ipairs({ -12, 12, -9, 9, -5, 5, 0 }) do
				f.Position = p + UDim2.fromOffset(dx, 0)
				task.wait(saved.Reduce and 0 or .035)
			end
			f.Position = p
		end)
	end
	local function submit()
		if busy or result ~= nil then return end
		busy = true
		err.Visible, err.Text = true, "Checking…"
		err.TextColor3 = T.Dim
		local k = trim(box.Text)
		local ok = valid(k)
		busy = false
		if ok then
			if o.SaveKey ~= false then pcall(function() mkdirs(file:match("^(.*)/")); writefile(file, k) end) end
			finish(true)
		else
			err.TextColor3 = RGB(230, 70, 60)
			err.Text = o.Invalid or "That key isn't valid."
			task.delay(.15, function() s.Color = RGB(230, 70, 60) end) -- after the focus ring's fade-out
			shake()
		end
	end
	if o.Link then
		pushButton(foot, { Text = "Get Key", Order = 0, Callback = function()
			if setclipboard then
				setclipboard(o.Link)
				err.Visible, err.TextColor3, err.Text = true, T.Dim, "Link copied to your clipboard."
			else
				err.Visible, err.TextColor3, err.Text = true, T.Dim, o.Link
			end
		end })
	end
	pushButton(foot, { Text = "Cancel", Order = 1, Callback = function() finish(false) end })
	pushButton(foot, { Text = "Continue", Default = true, Order = 2, Callback = submit })
	xb.MouseButton1Click:Connect(function() finish(false) end)
	box.Focused:Connect(function() ring(s, true) end)
	box.FocusLost:Connect(function(enter) ring(s, false); if enter then submit() end end)

	-- drag by the titlebar
	local drag, start, orig
	bar.InputBegan:Connect(function(i) if isPress(i) then drag, start, orig = true, i.Position, f.Position end end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if drag and isMove(i) then local d = i.Position - start; f.Position = orig + UDim2.fromOffset(d.X, d.Y) end
	end)
	local c2 = UIS.InputEnded:Connect(function(i) if isPress(i) then drag = false end end)

	pop(f, .9, .25)
	task.defer(function() if result == nil then box:CaptureFocus() end end)
	while result == nil do task.wait() end
	c1:Disconnect(); c2:Disconnect()
	return result
end

-- toggle / mobile button / global keys ------------------------------------------------
function Window:_show(on)
	local sc = self._scale
	if on then
		self.Root.Visible = true
		sc.Scale = .92
		tw(sc, .25, { Scale = 1 }, BACK)
	else
		if self._pop then self._pop.Close() end
		if self._cp then self._cp.Close() end
		self:_focus(nil)
		tw(sc, .14, { Scale = .92 }).Completed:Connect(function() if not Lib.Visible then self.Root.Visible = false end end)
	end
end
function Lib:Toggle(state)
	if state == nil then state = not Lib.Visible end
	Lib.Visible = state
	for _, w in ipairs(windows) do if w.Gui.Parent then w:_show(state) end end
	updateBlur()
	if not state and Lib.ToggleKey and not Lib.Touch then
		Lib:Notify({ Title = "Interface hidden", Text = "Press " .. Lib.ToggleKey.Name .. " to show it again.", Icon = "eye-off", Duration = 3 })
	end
end

local mobileBtn
function Lib:SetMobileButton(show)
	saved.MobileButton = show; save()
	if not show then
		if mobileBtn then mobileBtn.Parent:Destroy(); mobileBtn = nil end
		return
	end
	if mobileBtn then return end
	local g = new("ScreenGui", { Name = "YosemiteToggle", ResetOnSpawn = false, DisplayOrder = 99, Parent = guiParent() })
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromOffset(44, 140), Size = UDim2.fromOffset(46, 46), Parent = g }, { corner(23), stroke("Border"), tgrad("BtnTop", "BtnBot") })
	icon("app-window", 22, "Text", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Parent = b })
	local dragging, moved, start, orig = false, false, nil, nil
	b.InputBegan:Connect(function(i)
		if isPress(i) then dragging, moved, start, orig = true, false, i.Position, b.Position end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and isMove(i) then
			local d = i.Position - start
			if math.abs(d.X) + math.abs(d.Y) > 8 then moved = true end
			if moved then b.Position = UDim2.fromOffset(orig.X.Offset + d.X, orig.Y.Offset + d.Y) end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and isPress(i) then
			dragging = false
			if not moved then pop(b, .8, .25); Lib:Toggle() end
		end
	end)
	mobileBtn = b
end

UIS.InputBegan:Connect(function(i, gp)
	if i.UserInputType ~= Enum.UserInputType.Keyboard or Lib._listening > 0 then return end
	if not gp and Lib.ToggleKey and i.KeyCode == Lib.ToggleKey and #windows > 0 then Lib:Toggle() return end
	local w = Lib._active
	if Lib.Visible and w and w.Gui.Parent then w:_key(i.KeyCode, gp) end
end)

-- configs --------------------------------------------------------------------------
local function ser(v)
	if typeof(v) == "EnumItem" then return { __enum = tostring(v.EnumType), name = v.Name } end
	if typeof(v) == "Color3" then return { __color = v:ToHex() } end
	return v
end
local function deser(v)
	if type(v) == "table" then
		if v.__none then return nil end
		if v.__enum then return Enum[v.__enum][v.name] end
		if v.__color then return Color3.fromHex(v.__color) end
	end
	return v
end

function Window:_cfgPath(name)
	local c = self.Config
	local f = c.Format:gsub("{(%w+)}", function(k)
		if k == "name" then return name end
		if k == "place" then return tostring(game.PlaceId) end
		if k == "game" then return tostring(game.GameId) end
		if k == "user" then return Players.LocalPlayer and Players.LocalPlayer.Name or "user" end
	end)
	return c.Folder .. "/" .. f
end
function Window:_cfgDir() return (self:_cfgPath("\1"):match("^(.*)/")) end

function Window:ListConfigs()
	local dir, file = self:_cfgPath("\1"):match("^(.*)/([^/]*)$")
	local esc = file:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	local pat = "^" .. esc:gsub("\1", "(.+)") .. "$"
	local out = {}
	local ok, files = pcall(listfiles, dir)
	if ok and type(files) == "table" then
		for _, p in ipairs(files) do
			p = p:gsub("\\", "/")
			local n = (p:match("([^/]+)$") or ""):match(pat)
			if n and n ~= "_autoload" then table.insert(out, n) end
		end
	end
	table.sort(out)
	return out
end
function Window:SaveConfig(name)
	local data = {}
	for f, obj in pairs(self.Flags) do
		local v = obj:Get()
		data[f] = v == nil and { __none = true } or ser(v)
	end
	local path = self:_cfgPath(name)
	mkdirs(path:match("^(.*)/"))
	return (pcall(writefile, path, Http:JSONEncode(data)))
end
function Window:LoadConfig(name)
	local ok, raw = pcall(readfile, self:_cfgPath(name))
	if not ok or not raw then return false end
	local ok2, data = pcall(Http.JSONDecode, Http, raw)
	if not ok2 then return false end
	for f, v in pairs(data) do
		local obj = self.Flags[f]
		if obj then pcall(function() obj:Set(deser(v)) end) end
	end
	return true
end
function Window:DeleteConfig(name) return (pcall(delfile, self:_cfgPath(name))) end
function Window:SetAutoload(name)
	local p = self:_cfgDir() .. "/_autoload"
	if name then mkdirs(self:_cfgDir()); pcall(writefile, p, name) else pcall(delfile, p) end
end
function Window:GetAutoload()
	local ok, n = pcall(readfile, self:_cfgDir() .. "/_autoload")
	return ok and n and n ~= "" and n or nil
end
function Window:LoadAutoload()
	if self._autoloaded then return end
	self._autoloaded = true
	local n = self:GetAutoload()
	if n and self:LoadConfig(n) then Lib:Notify({ Title = self._titleText.Text, Text = "Loaded config “" .. n .. "”.", Icon = "folder-open", Duration = 3 }) end
end

-- window -------------------------------------------------------------------
function Window:SetActive(on)
	self.Active = on
	if on then Lib._active = self end
	for i, l in ipairs(self._lights) do
		tw(l, .15, { BackgroundColor3 = on and LIGHTS[i][1] or T.LightOff })
		tw(l.UIStroke, .15, { Color = on and LIGHTS[i][2] or T.LightOffBorder })
	end
	local c = on and T.Title or T.TitleOff
	tw(self._titleText, .15, { TextColor3 = c })
	if self._titlePaint then self._titlePaint(c) end
end
function Window:SetTitle(t) self._titleText.Text = t end

function Window:_layout(anim)
	local tb, thin = self._toolbar, self.Thin
	local labels = tb and tb.Labels and not thin
	local titleH, BAR, rowY, rowH
	if tb and thin then titleH, BAR, rowY, rowH = 38, 38, 0, 38
	elseif tb then titleH, rowY, rowH = 22, 22, labels and 48 or 32; BAR = titleH + rowH
	else titleH = thin and 22 or 38; BAR = titleH end
	self.BAR = BAR
	local function set(o, p) if anim then tw(o, .2, p) else for k, v in pairs(p) do o[k] = v end end end
	set(self._bar, { Size = UDim2.new(1, 0, 0, BAR) })
	self._barP.Paint(BAR, T.BarTop, T.BarBot, vib("BarT"))
	set(self._title, { Size = UDim2.new(1, 0, 0, titleH) })
	self._title.Visible = not (tb and thin)
	set(self._grp, { Position = UDim2.fromOffset(12, math.floor((titleH - 12) / 2)) })
	if tb then
		set(self._tbrow, { Position = UDim2.new(0, thin and 80 or 8, 0, rowY), Size = UDim2.new(1, thin and -88 or -16, 0, rowH) })
		for _, c in ipairs(tb.Captions) do c.Visible = labels end
	end
	set(self._line, { Position = UDim2.fromOffset(0, BAR) })
	for _, f in ipairs({ self.Sidebar, self._bodyP.Root, self.Content, self.Overlay }) do
		set(f, { Position = UDim2.new(f.Position.X.Scale, f.Position.X.Offset, 0, BAR + 1),
			Size = UDim2.new(f.Size.X.Scale, f.Size.X.Offset, 1, -(BAR + 1)) })
	end
	if self.Mini then set(self.Root, { Size = UDim2.new(self.Root.Size.X.Scale, self.Root.Size.X.Offset, 0, BAR + 1) }) end
end
function Window:SetThin(on) self.Thin = on; saved.Thin = on; save(); self:_layout(true) end

function Lib:Window(o)
	o = o or {}
	local size = o.Size or UDim2.fromOffset(700, 460)
	local SB = o.SidebarWidth or 170
	local gui = new("ScreenGui", { Name = "Yosemite", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent() })
	local root = new("Frame", { BackgroundTransparency = 1, Size = size,
		Position = UDim2.new(.5, -size.X.Offset / 2, .5, -size.Y.Offset / 2), Parent = gui })
	local winStroke = stroke(nil)
	local win = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = root }, { corner(6), winStroke })
	tc(winStroke, "Transparency", "WinStroke")

	-- surfaces: titlebar (vibrant), sidebar (vibrant), content (opaque)
	local barP = panel(win, 6, { true, true, false, false }, { Size = UDim2.new(1, 0, 0, 38) })
	local sideP = panel(win, 6, { false, false, true, false }, { Size = UDim2.new(0, SB, 1, 0) })
	local bodyP = panel(win, 6, { false, false, false, true }, { Position = UDim2.fromOffset(SB + 1, 0), Size = UDim2.new(1, -(SB + 1), 1, 0) })
	local bar, side = barP.Root, sideP.Root
	local line = tc(new("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = win }), "BackgroundColor3", "Line")

	-- title: optional icon + text, centered (Finder style)
	local titleRow = new("Frame", { BackgroundTransparency = 1, Parent = bar })
	local titleGrp = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromScale(0, 1), AutomaticSize = AX, Parent = titleRow }, { list(H_DIR, 5, CENTER, MID) })
	local titlePaint
	if o.Icon then titlePaint = select(2, icon(o.Icon, 14, nil, { LayoutOrder = 0, Parent = titleGrp })) end
	local titleText = label({ Text = o.Title or "Window", Color = false, AutomaticSize = AX, Size = UDim2.fromScale(0, 1), LayoutOrder = 1, Parent = titleGrp })

	local cfg = o.Config or {}
	local self = setmetatable({ Gui = gui, Root = root, Tabs = {}, Flags = {}, Thin = o.Thin, _bar = bar, _barP = barP, _bodyP = bodyP,
		_line = line, _title = titleRow, _titleText = titleText, _titlePaint = titlePaint, _lights = {}, _n = 0, _q = "", _openSheets = {},
		Config = { Folder = cfg.Folder or "Yosemite/Configs", Format = cfg.Format or "{name}.json" } }, Window)
	if self.Thin == nil then self.Thin = saved.Thin or false end
	self._scale = scaleOf(root)
	bind(function()
		barP.Paint(self.BAR or 38, T.BarTop, T.BarBot, vib("BarT"))
		sideP.Paint(1, T.Sidebar, T.Sidebar, vib("SideT"))
		bodyP.Paint(1, T.Window, T.Window, 0)
	end)

	-- keyboard focus ring
	self._ring = new("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 45, Parent = gui }, { corner(4), stroke(nil) })

	-- traffic lights (hit areas bigger than the 12px circles)
	local grp = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(52, 12), ZIndex = 2, Parent = bar })
	self._grp = grp
	local glyphs, hits = {}, {}
	for i, c in ipairs(LIGHTS) do
		local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = UDim2.fromOffset((i - 1) * 20 - 4, -5), Size = UDim2.fromOffset(20, 22), ZIndex = 2, Parent = grp })
		local b = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = c[1], AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
			Size = UDim2.fromOffset(12, 12), ZIndex = 2, Parent = hit }, { corner(6), stroke(nil) })
		glyphs[i] = label({ Text = c[3], Font = BOLD, TextSize = 11, Color = false, TextColor3 = RGB(80, 40, 30), ZIndex = 2,
			TextTransparency = Lib.Touch and 0 or 1, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = b })
		self._lights[i], hits[i] = b, hit
	end
	if not Lib.Touch then
		grp.MouseEnter:Connect(function() for _, g in ipairs(glyphs) do tw(g, .1, { TextTransparency = 0 }) end end)
		grp.MouseLeave:Connect(function() for _, g in ipairs(glyphs) do tw(g, .1, { TextTransparency = 1 }) end end)
	end

	local big, prev, full = false, nil, nil
	hits[1].MouseButton1Click:Connect(function()
		if self._cmd then self._cmd.Close() end
		self:_focus(nil)
		tw(self._scale, .15, { Scale = .85 }).Completed:Connect(function()
			gui:Destroy()
			local i = table.find(windows, self)
			if i then table.remove(windows, i) end
			if Lib._active == self then Lib._active = windows[#windows] end
			updateBlur()
		end)
	end)
	hits[2].MouseButton1Click:Connect(function()
		self.Mini = not self.Mini
		win.ClipsDescendants = true
		local body = { self.Sidebar, self._bodyP.Root, self.Content }
		if self.Mini then
			full = root.Size
			if self._pop then self._pop.Close() end
			if self._cp then self._cp.Close() end
			self:_focus(nil)
			for _, f in ipairs(body) do f.Visible = false end
			self.Overlay.Visible = false
		end
		local mini = self.Mini
		tw(root, .25, { Size = mini and UDim2.new(root.Size.X.Scale, root.Size.X.Offset, 0, self.BAR + 1) or full }, Enum.EasingStyle.Quint)
			.Completed:Connect(function()
				if self.Mini or mini then return end
				for _, f in ipairs(body) do f.Visible = true end
				self.Overlay.Visible = self._sheets > 0
			end)
	end)
	hits[3].MouseButton1Click:Connect(function()
		if self.Mini then return end
		big = not big
		if big then prev = { root.Size, root.Position } end
		tw(root, .3, big and { Size = UDim2.fromScale(.9, .9), Position = UDim2.fromScale(.05, .05) }
			or { Size = prev[1], Position = prev[2] }, Enum.EasingStyle.Quint)
	end)

	-- drag by titlebar
	local drag, start, orig
	bar.InputBegan:Connect(function(i)
		if isPress(i) then
			drag, start, orig = true, i.Position, root.Position
			if self._pop then self._pop.Close() end
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and isMove(i) then
			local d = i.Position - start
			root.Position = UDim2.new(orig.X.Scale, orig.X.Offset + d.X, orig.Y.Scale, orig.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i) if isPress(i) then drag = false end end)

	-- sidebar
	tc(new("Frame", { BorderSizePixel = 0, Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), Parent = side }), "BackgroundColor3", "Line")
	self.Sidebar = side
	self.List = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -27),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ScrollBarThickness = 3, Parent = side }, { list(nil, 1), pad(8, 8, 8, 8) })
	tc(self.List, "ScrollBarImageColor3", "Scroll")

	-- bottom-left settings corner
	tc(new("Frame", { BorderSizePixel = 0, BackgroundTransparency = .4, Position = UDim2.new(0, 0, 1, -27), Size = UDim2.new(1, 0, 0, 1), Parent = side }),
		"BackgroundColor3", "BoxBorder")
	local gear = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 1, -24), Size = UDim2.fromOffset(22, 22), Parent = side }, { corner(4) })
	local gearIcon = icon("settings", 15, "Icon", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Parent = gear })
	tc(gear, "BackgroundColor3", "Sel")
	gear.MouseEnter:Connect(function() tw(gear, .12, { BackgroundTransparency = T.SelT }) end)
	gear.MouseLeave:Connect(function() tw(gear, .12, { BackgroundTransparency = 1 }) end)
	gear.MouseButton1Click:Connect(function()
		tw(gearIcon, .4, { Rotation = gearIcon.Rotation + 90 }, BACK)
		self:OpenSettings()
	end)

	self.Content = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(SB + 1, 0),
		Size = UDim2.new(1, -(SB + 1), 1, 0), Parent = win })
	self.Overlay = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ClipsDescendants = true,
		Visible = false, ZIndex = 5, Size = UDim2.fromScale(1, 0), Parent = win })
	self._sheets = 0
	self:_layout(false)
	self:_buildSettings()

	win.InputBegan:Connect(function(i)
		if isPress(i) then
			for _, w in ipairs(windows) do w:SetActive(w == self) end
			self:_focus(nil)
		end
	end)
	table.insert(windows, self)
	bind(function() if self.Active ~= nil then self:SetActive(self.Active) end end)
	for _, w in ipairs(windows) do w:SetActive(w == self) end

	-- open animation
	self._scale.Scale = .9
	tw(self._scale, .3, { Scale = 1 }, BACK)
	if not Lib.Visible then root.Visible = false end
	local showBtn = saved.MobileButton
	if showBtn == nil then showBtn = Lib.Touch end
	if showBtn or o.MobileButton then Lib:SetMobileButton(true) end
	updateBlur()
	if cfg.AutoLoad ~= false then task.delay(.5, function() self:LoadAutoload() end) end
	return self
end

-- sheets / alerts --------------------------------------------------------------
function Window:_sheet(width)
	local f = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, -2000),
		Size = UDim2.fromOffset(width, 0), AutomaticSize = AY, Visible = false, ZIndex = 6, Parent = self.Overlay },
		{ corner(6), stroke(nil, .5), pad(22, 14, 16, 16), list(nil, 12) })
	tc(f, "BackgroundColor3", "Window")
	local body = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ScrollBarThickness = 4, ScrollBarImageTransparency = .5, Parent = f },
		{ list(nil, 12), pad(0, 0, 0, 8) })
	tc(body, "ScrollBarImageColor3", "Scroll")
	local foot = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2, Parent = f }, { list(H_DIR, 8, RIGHT) })
	local sh = { Frame = f, Body = body, Footer = foot, Open = false }
	local win = self
	-- body is as tall as its content, capped so the whole sheet fits under the titlebar; past that it scrolls
	local lay = body:FindFirstChildOfClass("UIListLayout")
	local function fit()
		local chrome = f.AbsoluteSize.Y - body.AbsoluteSize.Y
		local maxH = win.Overlay.AbsoluteSize.Y - chrome - 10
		body.Size = UDim2.new(1, 0, 0, math.max(40, math.min(lay.AbsoluteContentSize.Y, maxH)))
	end
	lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	win.Overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	function sh:Show()
		if sh.Open then return end
		sh.Open = true
		win._sheets += 1
		table.insert(win._openSheets, sh)
		win:_focus(nil)
		if win._pop then win._pop.Close() end
		win.Overlay.Visible = true
		f.Visible = true
		task.spawn(function()
			RS.RenderStepped:Wait()
			fit()
			RS.RenderStepped:Wait()
			f.Position = UDim2.new(.5, 0, 0, -f.AbsoluteSize.Y)
			tw(f, .28, { Position = UDim2.new(.5, 0, 0, -6) }, Enum.EasingStyle.Quint)
		end)
	end
	function sh:Close(destroy)
		if not sh.Open then return end
		sh.Open = false
		local i = table.find(win._openSheets, sh)
		if i then table.remove(win._openSheets, i) end
		win:_focus(nil)
		tw(f, .2, { Position = UDim2.new(.5, 0, 0, -f.AbsoluteSize.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			f.Visible = false
			win._sheets -= 1
			if win._sheets <= 0 then win.Overlay.Visible = false end
			if destroy then f:Destroy() end
		end)
	end
	return sh
end

function Window:Alert(o)
	local sh = self:_sheet(o.Width or 340)
	label({ Text = o.Title or "Alert", Font = BOLD, TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 16), Parent = sh.Body })
	if o.Text then
		label({ Text = o.Text, TextSize = 12, TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = sh.Body })
	end
	local btns = o.Buttons or { "OK" }
	local function choose(name)
		sh:Close(true)
		if o.Callback then task.spawn(o.Callback, name) end
	end
	for i, name in ipairs(btns) do
		pushButton(sh.Footer, { Text = name, Default = i == #btns, Order = i, Callback = function() choose(name) end })
	end
	sh.Default = function() choose(btns[#btns]) end
	sh.Cancel = function() choose(btns[1]) end
	sh:Show()
end
function Window:Notify(o) return Lib:Notify(o) end

-- settings sheet (General | Configs) ---------------------------------------------------
function Window:_buildSettings()
	local st = self:_sheet(380)
	self._settings = st
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = st.Frame }, { list(H_DIR, 0, CENTER) })
	local pages, tabs = {}, {}
	local function page(name)
		pages[name] = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = AY, Visible = false, Parent = st.Body }, { list(nil, 12) })
		tabs[name] = setmetatable({ Name = name, Page = pages[name], Sections = {}, Tables = {}, TableNav = {}, Win = self, _n = 0 }, Tab)
		return tabs[name]
	end
	segmented(top, { Items = { "General", "Configs" }, Callback = function(v)
		for n, p in pairs(pages) do p.Visible = n == v end
		st.Scope = tabs[v]
		self:_focus(nil)
		pages[v].Position = UDim2.fromOffset(12, 0)
		tw(pages[v], .2, { Position = UDim2.new() })
	end })

	self.Settings = page("General")
	pages.General.Visible = true
	st.Scope = self.Settings
	local ap = self.Settings:Section("Appearance")
	ap.NoFlags = true
	ap:Segmented({ Text = "Appearance", Items = { "Light", "Dark" }, Default = saved.Theme or "Light", Callback = function(v) Lib:SetTheme(v) end })
	ap:Segmented({ Text = "Accent", Items = { "Blue", "Graphite" }, Default = saved.Accent or "Blue", Callback = function(v) Lib:SetAccent(v) end })
	ap:Segmented({ Text = "Titlebar", Items = { "Normal", "Thin" }, Default = self.Thin and "Thin" or "Normal",
		Callback = function(v) self:SetThin(v == "Thin") end })
	ap:Checkbox({ Text = "Vibrancy (blurs the game behind the UI)", Default = saved.Vibrancy, Callback = function(v) Lib:SetVibrancy(v) end })
	ap:Checkbox({ Text = "Reduce motion", Default = saved.Reduce or false, Callback = function(v) Lib:SetReduceMotion(v) end })
	local ui = self.Settings:Section("Interface")
	ui.NoFlags = true
	ui:Keybind({ Text = "Toggle UI", Default = Lib.ToggleKey, Callback = function(k) Lib:SetToggleKey(k) end })
	local showBtn = saved.MobileButton
	if showBtn == nil then showBtn = Lib.Touch end
	ui:Checkbox({ Text = "Floating toggle button", Default = showBtn, Callback = function(v) Lib:SetMobileButton(v) end })
	ui:Label("Ctrl+K opens the command bar. Tab moves between controls, arrows adjust, Enter activates, Esc closes.")

	local cp = page("Configs"):Section("Configs")
	cp.NoFlags = true
	local nameBox = cp:TextField({ Text = "Name", Placeholder = "config name" })
	local pick = cp:Popup({ Text = "Config", Items = self:ListConfigs(), Callback = function(v) nameBox.Box.Text = v end })
	local auto
	local function refreshList()
		pick:SetItems(self:ListConfigs())
		if auto then auto:Set(self:GetAutoload() ~= nil and self:GetAutoload() == pick:Get(), true) end
	end
	local function chosen()
		local n = (nameBox.Box.Text ~= "" and nameBox.Box.Text or pick:Get() or ""):gsub("[^%w%-_ ]", "")
		return n ~= "" and n or nil
	end
	cp:ButtonRow({
		{ Text = "Save", Callback = function()
			local n = chosen()
			if not n then return end
			local ok = self:SaveConfig(n)
			refreshList(); pick:Set(n, true)
			Lib:Notify({ Title = ok and "Config saved" or "Couldn't save config", Text = ok and n or "This executor may not support writefile.",
				Icon = ok and "save" or "triangle-alert", Duration = 3 })
		end },
		{ Text = "Load", Callback = function()
			local n = chosen()
			if n and self:LoadConfig(n) then Lib:Notify({ Title = "Config loaded", Text = n, Icon = "folder-open", Duration = 3 }) end
		end },
		{ Text = "Delete", Callback = function()
			local n = chosen()
			if not n then return end
			st:Close()
			self:Alert({ Title = "Delete “" .. n .. "”?", Text = "This can't be undone.", Buttons = { "Cancel", "Delete" }, Callback = function(b)
				if b == "Delete" then
					self:DeleteConfig(n)
					if self:GetAutoload() == n then self:SetAutoload(nil) end
					nameBox.Box.Text = ""
					refreshList()
				end
			end })
		end },
	})
	auto = cp:Checkbox({ Text = "Load this config on start", Callback = function(v)
		self:SetAutoload(v and chosen() or nil)
	end })
	cp:Label("Saved to " .. self:_cfgDir())
	self._refreshConfigs = refreshList
	pushButton(st.Footer, { Text = "Done", Default = true, Callback = function() st:Close() end })
	st.Default = function() st:Close() end
	st.Cancel = st.Default
end

function Window:OpenSettings()
	if self._refreshConfigs then self._refreshConfigs() end
	self._settings:Show()
end

-- search filter ----------------------------------------------------------------
function Window:_filter(q)
	self._q = q
	q = q:lower()
	local tab = self.Current
	if not tab then return end
	for _, sec in ipairs(tab.Sections) do
		local secHit = q == "" or sec.Name:lower():find(q, 1, true) ~= nil
		local any = false
		for _, r in ipairs(sec.Rows) do
			local show = not r.hidden and (secHit or r.text:lower():find(q, 1, true) ~= nil)
			r.f.Visible = show
			any = any or show
		end
		sec.Holder.Visible = any or (secHit and #sec.Rows == 0)
	end
	for _, t in ipairs(tab.Tables) do t:_filter(q) end
end

-- keyboard navigation ------------------------------------------------------------------
local function entries(scope)
	local out = {}
	for _, sec in ipairs(scope.Sections or {}) do
		if sec.Holder.Visible then
			for _, n in ipairs(sec.Nav) do
				local r = n.rec
				if not r.hidden and not r.disabled and r.f.Visible then table.insert(out, n) end
			end
		end
	end
	for _, n in ipairs(scope.TableNav or {}) do table.insert(out, n) end
	return out
end

function Window:_focus(n)
	self._focused = n
	if self._ringConn then self._ringConn:Disconnect(); self._ringConn = nil end
	local rf = self._ring
	if not n then rf.Visible = false return end
	local t = n.e.target
	local sf = t:FindFirstAncestorOfClass("ScrollingFrame")
	if sf and n.e.kind ~= "table" then
		local rel = t.AbsolutePosition.Y - sf.AbsolutePosition.Y
		if rel < 8 or rel + t.AbsoluteSize.Y > sf.AbsoluteSize.Y - 8 then
			tw(sf, .2, { CanvasPosition = Vector2.new(0, math.max(0, sf.CanvasPosition.Y + rel - sf.AbsoluteSize.Y / 3)) })
		end
	end
	local s = rf.UIStroke
	s.Color = A.Focus; s.Thickness = 7; s.Transparency = 1
	tw(s, .2, { Thickness = 3, Transparency = .15 })
	self._ringConn = RS.RenderStepped:Connect(function()
		if not t.Parent or not n.rec.f.Visible or not self.Root.Visible then rf.Visible = false return end
		rf.Visible = true
		rf.Position = UDim2.fromOffset(t.AbsolutePosition.X, t.AbsolutePosition.Y)
		rf.Size = UDim2.fromOffset(t.AbsoluteSize.X, t.AbsoluteSize.Y)
	end)
end

function Window:_key(k, gp)
	if self._cmd then return end
	local ctrl = UIS:IsKeyDown(KC.LeftControl) or UIS:IsKeyDown(KC.RightControl)
	-- gp is true for keys Roblox also uses (Tab = player list), so only bail while a TextBox has focus
	if UIS:GetFocusedTextBox() then return end
	if k == KC.K and ctrl then self:OpenCommandBar() return end
	local sh = self._openSheets[#self._openSheets]
	if k == KC.Escape then
		if self._cp and self._cp.Frame.Visible then self._cp.Close() return end
		if self._pop then self._pop.Close() return end
		if sh and sh.Cancel then sh.Cancel() return end
		self:_focus(nil)
		return
	end
	local f = self._focused
	local enter = k == KC.Return or k == KC.KeypadEnter
	if enter and not f and sh and sh.Default then sh.Default() return end
	local scope = (self._pop and self._pop.Scope) or (sh and sh.Scope) or (not sh and self.Current)
	if not scope then return end
	if f and f.e.kind == "table" and (k == KC.Up or k == KC.Down) then f.e.step(k == KC.Down and 1 or -1) return end
	if k == KC.Tab or (f and (k == KC.Up or k == KC.Down)) then
		local l = entries(scope)
		if #l == 0 then return end
		local shift = UIS:IsKeyDown(KC.LeftShift) or UIS:IsKeyDown(KC.RightShift)
		local d = (k == KC.Up or (k == KC.Tab and shift)) and -1 or 1
		local i = (f and table.find(l, f) or (d == 1 and 0 or #l + 1)) + d
		if i < 1 then i = #l elseif i > #l then i = 1 end
		self:_focus(l[i])
	elseif f and (k == KC.Left or k == KC.Right) then
		if f.e.step then f.e.step(k == KC.Right and 1 or -1) end
	elseif f and (enter or k == KC.Space) then
		if f.e.activate then f.e.activate() end
	end
end

-- command bar (Spotlight style) -----------------------------------------------------------
function Window:OpenCommandBar()
	if self._cmd then return end
	self:_focus(nil)
	local items = {}
	for _, tab in ipairs(self.Tabs) do
		table.insert(items, { title = tab.Name, sub = "Tab", icon = tab.Icon or "panel-left", go = function() tab.Select() end })
		for _, sec in ipairs(tab.Sections) do
			for _, n in ipairs(sec.Nav) do
				local title = n.e.title or n.rec.title
				if title and title ~= "" and not n.rec.hidden then
					table.insert(items, { title = title, sub = tab.Name .. " › " .. sec.Name, icon = KIND_ICONS[n.e.kind] or "circle", go = function()
						if self._search then self._search.Text = "" end
						tab.Select()
						RS.RenderStepped:Wait()
						if not n.rec.disabled then self:_focus(n) end
						flash(n.rec.f)
					end })
				end
			end
		end
	end

	local f = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = T.Pop, BackgroundTransparency = vib("PopT"), AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 0, .18, 0), Size = UDim2.fromOffset(540, 0), AutomaticSize = AY, ZIndex = 70, Parent = self.Gui },
		{ corner(10), stroke(nil, .55), list() })
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), ZIndex = 70, Parent = f })
	local _, sp = icon("search", 20, nil, { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 16, .5, 0), ZIndex = 71, Parent = top })
	sp(T.Dim)
	local box = new("TextBox", { Text = "", PlaceholderText = "Search " .. self._titleText.Text, ClearTextOnFocus = false, Font = FONT, TextSize = 20,
		TextColor3 = T.Text, PlaceholderColor3 = T.Placeholder, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -58, 1, 0), ZIndex = 71, Parent = top })
	local sep = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = T.BoxBorder, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 1, Visible = false, ZIndex = 70, Parent = f })
	local res = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = AY, LayoutOrder = 2, ZIndex = 70, Parent = f },
		{ list(), pad(0, 0, 6, 6) })
	local shown, rows, sel, conn, closing = {}, {}, 1, nil, false

	local function close()
		if closing then return end
		closing = true
		if conn then conn:Disconnect() end
		self._cmd = nil
		tw(scaleOf(f), .12, { Scale = .96 }).Completed:Connect(function() f:Destroy() end)
	end
	local function pick(it) close(); task.spawn(it.go) end
	local function highlight()
		for i, r in ipairs(rows) do
			local on = i == sel
			r.b.BackgroundTransparency = on and 0 or 1
			r.t.TextColor3 = on and WHITE or T.Text
			r.s.TextColor3 = on and WHITE or T.Dim
			r.p(on and WHITE or T.Icon)
		end
	end
	local function render()
		for _, r in ipairs(rows) do r.b:Destroy() end
		rows, shown = {}, {}
		local q = box.Text:lower()
		if q ~= "" then
			local later = {}
			for _, it in ipairs(items) do
				local t = it.title:lower()
				if t:sub(1, #q) == q then table.insert(shown, it)
				elseif t:find(q, 1, true) or it.sub:lower():find(q, 1, true) then table.insert(later, it) end
			end
			for _, it in ipairs(later) do table.insert(shown, it) end
			while #shown > 8 do table.remove(shown) end
		end
		sel = math.clamp(sel, 1, math.max(#shown, 1))
		sep.Visible = #shown > 0
		res:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, #shown > 0 and 6 or 0)
		res:FindFirstChildOfClass("UIPadding").PaddingBottom = UDim.new(0, #shown > 0 and 6 or 0)
		for i, it in ipairs(shown) do
			local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = A.Solid, BackgroundTransparency = 1, BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, ZIndex = 71, Parent = res }, { corner(5) })
			local _, p = icon(it.icon, 16, nil, { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 10, .5, 0), ZIndex = 72, Parent = b })
			local t = label({ Text = it.title, Color = false, TextColor3 = T.Text, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(36, 0), Size = UDim2.new(.6, -36, 1, 0), ZIndex = 72, Parent = b })
			local s = label({ Text = it.sub, Color = false, TextSize = 12, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromScale(.6, 0), Size = UDim2.new(.4, -10, 1, 0), ZIndex = 72, Parent = b })
			rows[i] = { b = b, t = t, s = s, p = p }
			b.MouseEnter:Connect(function() sel = i; highlight() end)
			b.MouseButton1Click:Connect(function() pick(it) end)
		end
		highlight()
	end
	box:GetPropertyChangedSignal("Text"):Connect(function() sel = 1; render() end)
	box.FocusLost:Connect(function(enter)
		if closing then return end
		if enter then
			if shown[sel] then pick(shown[sel]) else close() end
		elseif not inside(f, mousePos()) then
			close()
		end
	end)
	conn = UIS.InputBegan:Connect(function(i)
		if i.KeyCode == KC.Down then sel = math.min(sel + 1, #shown); highlight()
		elseif i.KeyCode == KC.Up then sel = math.max(sel - 1, 1); highlight()
		elseif i.KeyCode == KC.Escape then close()
		elseif isPress(i) and not inside(f, i.Position) then close() end
	end)
	self._cmd = { Close = close }
	pop(f, .94, .2)
	box:CaptureFocus()
end

-- popovers ---------------------------------------------------------------------------
function Window:Popover(anchor, o)
	o = o or {}
	local W = o.Width or 260
	local f = new("Frame", { BorderSizePixel = 0, Size = UDim2.fromOffset(W, 0), AutomaticSize = AY, Visible = false, ZIndex = 40, Parent = self.Gui },
		{ corner(8), stroke(nil, .7), pad(8, 8, 12, 12), list() })
	local arrow = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, .5), Rotation = 45, Size = UDim2.fromOffset(14, 14),
		Visible = false, ZIndex = 39, Parent = self.Gui }, { stroke(nil, .7) })
	bind(function()
		setp(f, "BackgroundColor3", T.Pop); setp(arrow, "BackgroundColor3", T.Pop)
		f.BackgroundTransparency = vib("PopT"); arrow.BackgroundTransparency = vib("PopT")
	end)
	if o.Title then label({ Text = o.Title, Font = BOLD, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = f }) end
	local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = AY, LayoutOrder = 1, Parent = f }, { list() })
	local sec = setmetatable({ Box = box, Holder = f, Anim = pad(0), Name = o.Title or o.Name or o.Label or "Popover", Rows = {}, Nav = {},
		Win = self, Gui = self.Gui, _n = 0 }, Section)
	local sc = scaleOf(f)
	local open, conn = false, nil
	local pv = { Section = sec, Frame = f, Scope = { Sections = { sec } } }
	local function place()
		local ap, as, scr = anchor.AbsolutePosition, anchor.AbsoluteSize, self.Gui.AbsoluteSize
		local h = f.AbsoluteSize.Y / math.max(sc.Scale, .01)
		local ax = ap.X + as.X / 2
		local cx = math.clamp(ax, W / 2 + 8, scr.X - W / 2 - 8)
		if ap.Y + as.Y + 10 + h < scr.Y - 8 then
			f.AnchorPoint = Vector2.new(.5, 0)
			f.Position = UDim2.fromOffset(cx, ap.Y + as.Y + 9)
			arrow.Position = UDim2.fromOffset(ax, ap.Y + as.Y + 9)
		else
			f.AnchorPoint = Vector2.new(.5, 1)
			f.Position = UDim2.fromOffset(cx, ap.Y - 9)
			arrow.Position = UDim2.fromOffset(ax, ap.Y - 9)
		end
	end
	function pv.Close()
		if not open then return end
		open = false
		if conn then conn:Disconnect() end
		if self._pop == pv then self._pop = nil end
		if self._focused and table.find(sec.Nav, self._focused) then self:_focus(nil) end
		floating[f] = nil
		arrow.Visible = false
		tw(sc, .1, { Scale = .92 }).Completed:Connect(function() if not open then f.Visible = false end end)
	end
	function pv.Open()
		if open then return end
		if self._pop then self._pop.Close() end
		open = true
		self._pop = pv
		self:_focus(nil)
		floating[f] = true
		f.Visible = true
		sc.Scale = .9
		task.spawn(function()
			RS.RenderStepped:Wait()
			place()
			arrow.Visible = true
			tw(sc, .22, { Scale = 1 }, BACK)
		end)
		task.defer(function()
			if not open then return end
			conn = UIS.InputBegan:Connect(function(i)
				if not isPress(i) then return end
				local p = Vector2.new(i.Position.X, i.Position.Y)
				if inside(f, p) or inFloating(p) or inside(anchor, p) then return end
				pv.Close()
			end)
		end)
	end
	function pv.Toggle() if open then pv.Close() else pv.Open() end end
	if o.Build then o.Build(sec) end
	return pv
end

-- Colors panel (one per window, like NSColorPanel) ---------------------------------------
function Window:_colors()
	if self._cp then return self._cp end
	local W = 236
	local f = new("Frame", { BorderSizePixel = 0, Size = UDim2.fromOffset(W, 0), AutomaticSize = AY, Visible = false, ZIndex = 60, Parent = self.Gui },
		{ corner(6), stroke(nil, .45) })
	tc(f, "BackgroundColor3", "Window")
	local tb = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 22), Parent = f }, { corner(6), tgrad("BarTop", "BarBot") })
	tc(new("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6), Parent = tb }), "BackgroundColor3", "BarBot")
	label({ Text = "Colors", TextSize = 12, Color = "Title", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = tb })
	local xb = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = LIGHTS[1][1], Position = UDim2.fromOffset(8, 5),
		Size = UDim2.fromOffset(12, 12), Parent = tb }, { corner(6), new("UIStroke", { Color = LIGHTS[1][2] }) })
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 23), Size = UDim2.fromScale(1, 0), AutomaticSize = AY, Parent = f },
		{ pad(8, 10, 10, 10), list(nil, 8) })
	local modeRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = body }, { list(H_DIR, 0, CENTER) })

	local h, s, v, bound, updating = 0, 0, 1, nil, false
	local pages = {}
	local function page(name, order)
		pages[name] = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = AY, LayoutOrder = order,
			Visible = name == "Picker", Parent = body }, { list(nil, 8) })
		return pages[name]
	end
	segmented(modeRow, { Items = { "Picker", "Sliders", "Palette" }, Callback = function(m) for n, p in pairs(pages) do p.Visible = n == m end end })

	-- picker: saturation/value square + hue strip
	local pk = page("Picker", 1)
	local sv = new("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 140), Parent = pk }, { corner(3) })
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), Parent = sv },
		{ corner(3), new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = BLACK, Size = UDim2.fromScale(1, 1), Parent = sv },
		{ corner(3), new("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90 }) })
	local cursor = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(12, 12), ZIndex = 2, Parent = sv },
		{ corner(6), new("UIStroke", { Color = WHITE, Thickness = 2 }) })
	local keys = {}
	for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1))) end
	local hue = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 1, Parent = pk },
		{ corner(3), new("UIGradient", { Color = ColorSequence.new(keys) }) })
	local hueKnob = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(6, 16),
		Parent = hue }, { corner(2), new("UIStroke", { Color = BLACK, Transparency = .5 }) })

	-- sliders: reuse Section:Slider
	local sl = page("Sliders", 2)
	local ssec = setmetatable({ Box = sl, Holder = sl, Name = "Colors", Rows = {}, Nav = {}, Win = self, Gui = self.Gui, NoFlags = true, _n = 0 }, Section)
	local apply
	local function fromSliders(_)
		if updating then return end
		local c = Color3.fromRGB(ssec._r:Get(), ssec._g:Get(), ssec._b:Get())
		h, s, v = c:ToHSV()
		apply("sliders")
	end
	ssec._r = ssec:Slider({ Text = "Red", Min = 0, Max = 255, Default = 255, Callback = fromSliders })
	ssec._g = ssec:Slider({ Text = "Green", Min = 0, Max = 255, Default = 255, Callback = fromSliders })
	ssec._b = ssec:Slider({ Text = "Blue", Min = 0, Max = 255, Default = 255, Callback = fromSliders })

	-- palette
	local pl = page("Palette", 3)
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = AY, Parent = pl },
		{ new("UIGridLayout", { CellSize = UDim2.fromOffset(22, 22), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, hex in ipairs(PALETTE) do
		local sw = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex(hex), LayoutOrder = i, Parent = grid },
			{ corner(4), stroke("Border") })
		sw.MouseButton1Click:Connect(function() pop(sw, .8, .2); h, s, v = sw.BackgroundColor3:ToHSV(); apply("palette") end)
	end

	-- footer: preview + hex
	local foot = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 9, Parent = body }, { list(H_DIR, 8, LEFT, MID) })
	local preview = new("Frame", { BorderSizePixel = 0, Size = UDim2.fromOffset(52, 22), Parent = foot }, { corner(4), stroke("Border") })
	local hs = stroke("Border")
	local hex = new("TextBox", { Text = "", ClearTextOnFocus = false, Font = FONT, TextSize = 13, BorderSizePixel = 0, LayoutOrder = 1,
		Size = UDim2.new(1, -60, 0, 22), Parent = foot }, { corner(3), hs, pad(0, 0, 6, 6) })
	tc(hex, "BackgroundColor3", "Field"); tc(hex, "TextColor3", "Text")

	function apply(from)
		local c = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cursor.Position = UDim2.fromScale(s, 1 - v)
		hueKnob.Position = UDim2.new(h, 0, .5, 0)
		preview.BackgroundColor3 = c
		if from ~= "hex" then hex.Text = "#" .. c:ToHex():upper() end
		if from ~= "sliders" then
			updating = true
			ssec._r:Set(math.round(c.R * 255), true, true); ssec._g:Set(math.round(c.G * 255), true, true); ssec._b:Set(math.round(c.B * 255), true, true)
			updating = false
		end
		if bound and from ~= "bind" then bound:Set(c) end
	end

	local dragSV, dragH = false, false
	local function updSV(p)
		local a, z = sv.AbsolutePosition, sv.AbsoluteSize
		s = math.clamp((p.X - a.X) / z.X, 0, 1)
		v = 1 - math.clamp((p.Y - a.Y) / z.Y, 0, 1)
		apply("sv")
	end
	local function updH(p)
		h = math.clamp((p.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, .999)
		apply("hue")
	end
	sv.InputBegan:Connect(function(i) if isPress(i) then dragSV = true; updSV(i.Position); tw(scaleOf(cursor), .12, { Scale = 1.3 }) end end)
	hue.InputBegan:Connect(function(i) if isPress(i) then dragH = true; updH(i.Position) end end)
	local dragP, pStart, pOrig = false, nil, nil
	tb.InputBegan:Connect(function(i) if isPress(i) then dragP, pStart, pOrig = true, i.Position, f.Position end end)
	UIS.InputChanged:Connect(function(i)
		if not isMove(i) then return end
		if dragSV then updSV(i.Position) elseif dragH then updH(i.Position)
		elseif dragP then local d = i.Position - pStart; f.Position = UDim2.fromOffset(pOrig.X.Offset + d.X, pOrig.Y.Offset + d.Y) end
	end)
	UIS.InputEnded:Connect(function(i)
		if isPress(i) then
			if dragSV then tw(scaleOf(cursor), .2, { Scale = 1 }, BACK) end
			dragSV, dragH, dragP = false, false, false
		end
	end)
	hex.Focused:Connect(function() ring(hs, true) end)
	hex.FocusLost:Connect(function()
		ring(hs, false)
		local m = hex.Text:match("%x%x%x%x%x%x")
		if m then
			local ok, c = pcall(Color3.fromHex, m)
			if ok then h, s, v = c:ToHSV(); apply("hex"); return end
		end
		apply("bind")
	end)

	local cp = { Frame = f }
	function cp.Close()
		if not f.Visible then return end
		floating[f] = nil
		bound = nil
		tw(scaleOf(f), .1, { Scale = .9 }).Completed:Connect(function() f.Visible = false end)
	end
	function cp.Bind(obj)
		bound = nil
		h, s, v = obj:Get():ToHSV()
		apply("bind")
		bound = obj
		if not f.Visible then
			local ra, rs, scr = self.Root.AbsolutePosition, self.Root.AbsoluteSize, self.Gui.AbsoluteSize
			local x = ra.X + rs.X + 12
			if x + W > scr.X - 8 then x = math.max(8, ra.X - W - 12) end
			f.Position = UDim2.fromOffset(x, math.max(8, ra.Y))
			f.Visible = true
			floating[f] = true
			pop(f, .9, .22)
		end
	end
	xb.MouseButton1Click:Connect(cp.Close)
	self._cp = cp
	return cp
end

-- toolbar ------------------------------------------------------------------------
function Window:Toolbar(o)
	if self._toolbar then return self._toolbar end
	o = o or {}
	local rowf = new("Frame", { BackgroundTransparency = 1, ZIndex = 2, Parent = self._bar })
	local function side(ha)
		return new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = rowf }, { list(H_DIR, 8, ha, MID) })
	end
	self._tbrow = rowf
	self._toolbar = setmetatable({ Win = self, Labels = o.Labels, Captions = {}, L = side(LEFT), R = side(RIGHT), _n = 0 }, Toolbar)
	self:_layout(false)
	return self._toolbar
end

function Toolbar:_add(o, build)
	self._n += 1
	local parent = (o.Side == "Right") and self.R or self.L
	local holder = new("Frame", { BackgroundTransparency = 1, AutomaticSize = AX, Size = UDim2.fromScale(0, 1), LayoutOrder = self._n, Parent = parent },
		{ list(V_DIR, 3, CENTER, MID) })
	local item = build(holder)
	local cap = label({ Text = o.Label or "", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = AX,
		Size = UDim2.fromOffset(0, 12), LayoutOrder = 1, Visible = self.Labels and not self.Win.Thin, Parent = holder })
	table.insert(self.Captions, cap)
	return item
end

function Toolbar:Button(o)
	return self:_add(o, function(h)
		local _, b = pushButton(h, { Text = o.Text, Icon = o.Icon, Width = o.Width, Height = 24, MinWidth = 32, Default = o.Default, Callback = o.Callback })
		return b
	end)
end

function Toolbar:Menu(o)
	return self:_add(o, function(h)
		local fill, b = pushButton(h, { Text = o.Text, Icon = o.Icon or "settings", Chevron = true, Height = 24, MinWidth = 32 })
		b.MouseButton1Click:Connect(function()
			openMenu(self.Win.Gui, fill, o.Items, nil, function(n) if o.Callback then task.spawn(o.Callback, n) end end, 150)
		end)
		return b
	end)
end

function Toolbar:Popover(o)
	return self:_add(o, function(h)
		local fill, b = pushButton(h, { Text = o.Text, Icon = o.Icon or "ellipsis", Height = 24, MinWidth = 32 })
		local pv = self.Win:Popover(fill, o)
		b.MouseButton1Click:Connect(pv.Toggle)
		return pv
	end)
end

function Toolbar:Segmented(o)
	return self:_add(o, function(h)
		o.Height, o.Order = 24, 0
		local _, obj = segmented(h, o)
		return obj
	end)
end

function Toolbar:Space(w)
	return self:_add({}, function(h)
		return new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w or 10, 1), Parent = h })
	end)
end

function Toolbar:Search(o)
	o = o or {}
	o.Side = o.Side or "Right"
	local W = o.Width or 200
	return self:_add(o, function(h)
		local s = stroke("Border")
		local tb = new("TextBox", { Text = "", PlaceholderText = "", ClearTextOnFocus = false, Font = FONT, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, Size = UDim2.fromOffset(W, 22), Parent = h }, { corner(5), s, pad(0, 0, 22, 22) })
		tc(tb, "BackgroundColor3", "Field"); tc(tb, "TextColor3", "Text")
		local ph = new("Frame", { BackgroundTransparency = 1, AutomaticSize = AX, Size = UDim2.fromOffset(0, 22), Parent = tb }, { list(H_DIR, 4, LEFT, MID) })
		icon("search", 12, "Dim", { LayoutOrder = 0, Parent = ph })
		local phl = label({ Text = o.Placeholder or "Search", Color = "Placeholder", AutomaticSize = AX, Size = UDim2.fromOffset(0, 22), LayoutOrder = 1, Parent = ph })
		local clear = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, .5),
			Position = UDim2.new(1, 18, .5, 0), Size = UDim2.fromOffset(16, 16), Visible = false, Parent = tb })
		icon("circle-x", 13, "Dim", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Parent = clear })
		local function place(anim)
			local active = tb:IsFocused() or tb.Text ~= ""
			phl.Visible = tb.Text == ""
			local x = active and -18 or math.floor((W - 44 - ph.AbsoluteSize.X) / 2)
			if anim then tw(ph, .22, { Position = UDim2.fromOffset(x, 0) }) else ph.Position = UDim2.fromOffset(x, 0) end
			if tb.Text ~= "" and not clear.Visible then clear.Visible = true; pop(clear, .4, .15) elseif tb.Text == "" then clear.Visible = false end
		end
		task.spawn(function() RS.RenderStepped:Wait(); place(false) end)
		tb.Focused:Connect(function() ring(s, true); place(true) end)
		tb.FocusLost:Connect(function() ring(s, false); place(true) end)
		clear.MouseButton1Click:Connect(function() tb.Text = "" end)
		tb:GetPropertyChangedSignal("Text"):Connect(function()
			place(false)
			if o.Filter ~= false then self.Win:_filter(tb.Text) end
			if o.Callback then task.spawn(o.Callback, tb.Text) end
		end)
		self.Win._search = tb
		return tb
	end)
end

-- sidebar: categories / tabs ------------------------------------------------------
function Window:_tab(name, ic, parent, order)
	local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, Lib.Touch and 30 or 22), LayoutOrder = order, Parent = parent }, { corner(4) })
	local x = 10
	if ic then
		icon(ic, 16, "Icon", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 8, .5, 0), Parent = btn })
		x = 32
	end
	label({ Text = name, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
	local page = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ScrollBarThickness = 5, ScrollBarImageTransparency = .5,
		Parent = self.Content }, { list(nil, 14), pad(16, 16, 18, 18) })
	local tab = setmetatable({ Name = name, Icon = ic, Page = page, Btn = btn, Sections = {}, Tables = {}, TableNav = {}, Win = self, _n = 0 }, Tab)
	function tab.Select()
		if self.Current == tab then return end
		local prev = self.Current
		self.Current = tab
		self:_focus(nil)
		for _, t in ipairs(self.Tabs) do
			t.Page.Visible = t == tab
			tw(t.Btn, .12, { BackgroundTransparency = t == tab and T.SelT or 1 })
		end
		self:_filter(self._q)
		if prev and not saved.Reduce then
			page.Position = UDim2.fromOffset(0, 10)
			tw(page, .25, { Position = UDim2.new() }, Enum.EasingStyle.Quint)
			for i, sec in ipairs(tab.Sections) do
				sec.Anim.PaddingTop = UDim.new(0, 14)
				task.delay((i - 1) * .04, function() tw(sec.Anim, .3, { PaddingTop = UDim.new(0, 0) }, Enum.EasingStyle.Quint) end)
			end
		end
	end
	bind(function()
		setp(btn, "BackgroundColor3", T.Sel)
		btn.BackgroundTransparency = self.Current == tab and T.SelT or 1
		setp(page, "ScrollBarImageColor3", T.Scroll)
	end)
	btn.MouseButton1Click:Connect(tab.Select)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then tab.Select() end
	return tab
end

function Window:Tab(name, ic) self._n += 1; return self:_tab(name, ic, self.List, self._n) end

function Window:Category(name, o)
	o = o or {}
	self._n += 1
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = AY,
		LayoutOrder = self._n, Parent = self.List }, { list(nil, 1) })
	local head = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = holder })
	label({ Text = name, Font = BOLD, TextSize = 11, Color = "Dim", Position = UDim2.fromOffset(2, 2), Size = UDim2.fromScale(1, 1), Parent = head })
	local hide = label({ Text = "Hide", Font = BOLD, TextSize = 11, Color = "Dim", TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = Lib.Touch and 0 or 1, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, -4, 1, 0), Parent = head })
	local tabs = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromScale(1, 0), AutomaticSize = AY,
		LayoutOrder = 1, Parent = holder }, { list(nil, 1) })
	if o.Collapsible ~= false then
		local open = true
		local lay = tabs:FindFirstChildOfClass("UIListLayout")
		if not Lib.Touch then
			head.MouseEnter:Connect(function() tw(hide, .12, { TextTransparency = 0 }) end)
			head.MouseLeave:Connect(function() tw(hide, .12, { TextTransparency = 1 }) end)
		end
		head.MouseButton1Click:Connect(function()
			open = not open
			hide.Text = open and "Hide" or "Show"
			local hgt = lay.AbsoluteContentSize.Y
			tabs.AutomaticSize = Enum.AutomaticSize.None
			if open then
				tabs.Visible = true
				tw(tabs, .22, { Size = UDim2.new(1, 0, 0, hgt) }).Completed:Connect(function() if open then tabs.AutomaticSize = AY end end)
			else
				tabs.Size = UDim2.new(1, 0, 0, hgt)
				tw(tabs, .22, { Size = UDim2.new(1, 0, 0, 0) }).Completed:Connect(function() if not open then tabs.Visible = false end end)
			end
		end)
	else
		hide.Visible = false
	end
	return setmetatable({ Win = self, Holder = tabs, _n = 0 }, Category)
end
function Window:Header(name) return self:Category(name, { Collapsible = false }) end
function Category:Tab(name, ic) self._n += 1; return self.Win:_tab(name, ic, self.Holder, self._n) end

-- sections -------------------------------------------------------------------------
function Tab:Section(name)
	self._n += 1
	local anim = pad(0, 0, 0, 0)
	local holder = new("Frame", { BackgroundTransparency = 1, AutomaticSize = AY, Size = UDim2.fromScale(1, 0),
		LayoutOrder = self._n, Parent = self.Page }, { list(nil, 5), anim })
	label({ Text = name, Font = BOLD, TextSize = 12, Size = UDim2.new(1, 0, 0, 16), Parent = holder })
	local box = new("Frame", { BorderSizePixel = 0, AutomaticSize = AY, Size = UDim2.fromScale(1, 0),
		LayoutOrder = 1, Parent = holder }, { corner(5), stroke("BoxBorder"), list(), pad(4, 4, 12, 12) })
	tc(box, "BackgroundColor3", "Box")
	local sec = setmetatable({ Box = box, Holder = holder, Anim = anim, Name = name, Rows = {}, Nav = {}, Win = self.Win, _n = 0,
		Gui = self.Win and self.Win.Gui }, Section)
	table.insert(self.Sections, sec)
	return sec
end

local function row(sec, text, search, h)
	sec._n += 1
	local r = new("Frame", { BackgroundTransparency = 1, BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, h or ROWH),
		LayoutOrder = sec._n, Parent = sec.Box })
	local lbl
	if text then lbl = label({ Text = text, Size = UDim2.new(.4, 0, 0, ROWH), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r }) end
	local rec = { f = r, text = search or text or "", title = text, sec = sec }
	table.insert(sec.Rows, rec)
	return r, lbl, rec
end
local function right(f, x) f.AnchorPoint = Vector2.new(1, .5); f.Position = UDim2.new(1, x or 0, .5, 0); return f end
local function nav(sec, rec, e) local n = { rec = rec, e = e }; table.insert(sec.Nav, n); return n end
local function flag(sec, o, obj)
	if o.Flag == false or sec.NoFlags or not sec.Win then return obj end
	sec.Win.Flags[o.Flag or (sec.Name .. "/" .. (o.Text or o.Label or ("#" .. sec._n)))] = obj
	return obj
end
-- common :SetVisible / :SetDisabled / :SetText on every control
local function api(rec, obj, lbl, setText)
	obj = obj or {}
	obj.Row = rec.f
	function obj:SetVisible(on)
		rec.hidden = not on
		rec.f.Visible = on
		local w = rec.sec.Win
		if w and on then w:_filter(w._q) end
	end
	function obj:SetDisabled(d)
		rec.disabled = d
		obj.Disabled = d
		if not rec.block then
			rec.block = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1), ZIndex = 20, Visible = false, Parent = rec.f })
			tc(rec.block, "BackgroundColor3", "Box")
		end
		local w = rec.sec.Win
		if d and w and w._focused and w._focused.rec == rec then w:_focus(nil) end
		if d then
			rec.block.Visible = true
			tw(rec.block, .15, { BackgroundTransparency = .45 })
		else
			tw(rec.block, .15, { BackgroundTransparency = 1 }).Completed:Connect(function() if not rec.disabled then rec.block.Visible = false end end)
		end
	end
	function obj:SetText(t)
		rec.title, rec.text = t, t
		if setText then setText(t) elseif lbl then lbl.Text = t end
	end
	return obj
end

-- controls ------------------------------------------------------------------------
function Section:Label(text)
	self._n += 1
	local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = AY,
		LayoutOrder = self._n, Parent = self.Box }, { pad(7, 7, 0, 0) })
	local rec = { f = r, text = text, sec = self }
	table.insert(self.Rows, rec)
	local l = label({ Text = text, TextSize = 12, Color = "Dim", TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 14), Parent = r })
	return api(rec, { Label = l }, l)
end

function Section:Separator()
	local r, _, rec = row(self, nil, "", 9)
	tc(new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 1), Parent = r }), "BackgroundColor3", "BoxBorder")
	return api(rec)
end

function Section:Button(o)
	local r, lbl, rec = row(self, o.Label, (o.Label or "") .. " " .. (o.Text or ""))
	rec.title = o.Label or o.Text
	local fill, b, bapi = pushButton(r, o)
	right(fill)
	local obj = { Button = b }
	function obj:Fire()
		pop(fill, .92, .2)
		if o.Callback then task.spawn(o.Callback) end
	end
	nav(self, rec, { target = fill, kind = "button", activate = obj.Fire })
	return api(rec, obj, lbl, function(t) bapi.SetText(t) end)
end

function Section:ButtonRow(btns)
	local names = {}
	for _, b in ipairs(btns) do table.insert(names, b.Text or "") end
	local r, _, rec = row(self, nil, table.concat(names, " "))
	local h = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = r }, { list(H_DIR, 8, RIGHT, MID) })
	local obj = { Buttons = {} }
	for i, b in ipairs(btns) do
		b.Order = i
		local fill, btn = pushButton(h, b)
		obj.Buttons[i] = btn
		nav(self, rec, { target = fill, kind = "button", title = b.Text, activate = function()
			pop(fill, .92, .2)
			if b.Callback then task.spawn(b.Callback) end
		end })
	end
	return api(rec, obj)
end

function Section:Checkbox(o)
	local r, _, rec = row(self, nil, o.Text)
	rec.title = o.Text
	local on = o.Default or false
	local s, g = stroke(nil), sgrad(WHITE, WHITE)
	local box = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, .5), Position = UDim2.fromScale(0, .5), Size = UDim2.fromOffset(14, 14), Parent = r }, { corner(3), s, g })
	local tick, tickPaint = icon("check", 11, nil, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Parent = box })
	tickPaint(WHITE)
	local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = r })
	local lbl = label({ Text = o.Text or "Checkbox", Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Parent = r })
	local obj = {}
	function obj:Set(v, silent)
		v = v and true or false
		local changed = v ~= on
		on = v
		tick.Visible = v
		setp(s, "Color", v and A.Border or T.Border)
		g.Color = v and CS(A.Top, A.Bot) or CS(T.BtnTop, T.BtnBot)
		if changed and not silent then pop(box, .85, .2); if v then pop(tick, .3, .25) end end
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Get() return on end
	hit.MouseButton1Click:Connect(function() obj:Set(not on) end)
	bind(function() obj:Set(on, true) end)
	nav(self, rec, { target = box, kind = "checkbox", activate = function() obj:Set(not on) end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Radio(o)
	local items = o.Items
	local r, lbl, rec = row(self, o.Text, (o.Text or "") .. " " .. table.concat(items, " "), 6 + #items * (Lib.Touch and 28 or 22))
	local col = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(.4, 0, 0, 4), Size = UDim2.new(.6, 0, 1, -6), Parent = r }, { list() })
	local dots, cur = {}, nil
	local obj = {}
	function obj:Set(v, silent)
		local changed = v ~= cur
		cur = v
		for nm, d in pairs(dots) do
			local sel = nm == v
			d.dot.Visible = sel
			d.g.Color = sel and CS(A.Top, A.Bot) or CS(T.BtnTop, T.BtnBot)
			setp(d.s, "Color", sel and A.Border or T.Border)
			if sel and changed and not silent then pop(d.dot, 0, .25) end
		end
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Get() return cur end
	for idx, name in ipairs(items) do
		local it = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Lib.Touch and 28 or 22),
			LayoutOrder = idx, Parent = col })
		local s, g = stroke(nil), sgrad(WHITE, WHITE)
		local c = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, .5),
			Position = UDim2.fromScale(0, .5), Size = UDim2.fromOffset(14, 14), Parent = it }, { corner(7), s, g })
		local dot = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(6, 6), Parent = c }, { corner(3) })
		label({ Text = name, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Parent = it })
		dots[name] = { dot = dot, s = s, g = g }
		it.MouseButton1Click:Connect(function() obj:Set(name) end)
	end
	obj:Set(o.Default or items[1], true)
	bind(function() obj:Set(cur, true) end)
	nav(self, rec, { target = col, kind = "radio", step = function(d)
		local i = math.clamp((table.find(items, cur) or 1) + d, 1, #items)
		if items[i] ~= cur then obj:Set(items[i]) end
	end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Slider(o)
	local r, lbl, rec = row(self, o.Text)
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local val = o.Default or min
	local hit = right(new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(.5, 0, 0, Lib.Touch and 32 or 20), Parent = r }), -44)
	local track = new("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, .5, -2), Size = UDim2.new(1, 0, 0, 4),
		Parent = hit }, { corner(2), stroke("Border") })
	tc(track, "BackgroundColor3", "Track")
	local fill = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track }, { corner(2), agrad() })
	local knob = new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(15, 15), Parent = hit },
		{ corner(8), stroke("KnobBorder") })
	tc(knob, "BackgroundColor3", "Knob")
	local ks = scaleOf(knob)
	local num = label({ Color = "Dim", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -40, 0, 0), Parent = r })
	local obj, dragging = {}, false
	function obj:Set(v, silent, instant)
		v = math.clamp(math.floor((v - min) / step + .5) * step + min, min, max)
		val = v
		local a = (max == min) and 0 or (v - min) / (max - min)
		if instant then
			fill.Size = UDim2.fromScale(a, 1); knob.Position = UDim2.new(a, 0, .5, 0)
		else
			local t = dragging and .05 or .2
			tw(fill, t, { Size = UDim2.fromScale(a, 1) }); tw(knob, t, { Position = UDim2.new(a, 0, .5, 0) })
		end
		num.Text = fmt(v) .. (o.Suffix or "")
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Get() return val end
	local function upd(x) obj:Set(min + (max - min) * math.clamp((x - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)) end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then upd(i.Position.X); dragging = true; tw(ks, .12, { Scale = 1.15 }) end
	end)
	UIS.InputChanged:Connect(function(i) if dragging and isMove(i) then upd(i.Position.X) end end)
	UIS.InputEnded:Connect(function(i)
		if isPress(i) and dragging then dragging = false; tw(ks, .2, { Scale = 1 }, BACK) end
	end)
	obj:Set(val, true, true)
	local keyStep = o.KeyStep or ((max - min) / step > 50 and math.max(step, math.round((max - min) / 50 / step) * step) or step)
	nav(self, rec, { target = hit, kind = "slider", step = function(d) obj:Set(val + d * keyStep); pop(knob, 1.25, .2) end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Stepper(o)
	local r, lbl, rec = row(self, o.Text)
	local min, max, step = o.Min or -math.huge, o.Max or math.huge, o.Step or 1
	local val = o.Default or 0
	local st = right(new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromOffset(13, 22), Parent = r },
		{ corner(4), stroke("Border"), tgrad("BtnTop", "BtnBot") }))
	tc(new("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, .5, 0), Size = UDim2.new(1, 0, 0, 1), Parent = st }), "BackgroundColor3", "Border")
	local function arrow(g, y)
		local b = new("TextButton", { Text = g, Font = FONT, TextSize = 6, AutoButtonColor = false, BackgroundTransparency = 1,
			BackgroundColor3 = BLACK, Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, .5), Parent = st })
		tc(b, "TextColor3", "Text")
		b.MouseButton1Down:Connect(function() b.BackgroundTransparency = .8 end)
		b.MouseButton1Up:Connect(function() tw(b, .15, { BackgroundTransparency = 1 }) end)
		b.MouseLeave:Connect(function() tw(b, .15, { BackgroundTransparency = 1 }) end)
		return b
	end
	local up, down = arrow("▲", 0), arrow("▼", .5)
	local s = stroke("Border")
	local box = right(new("TextBox", { ClearTextOnFocus = false, Font = FONT, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
		BorderSizePixel = 0, Size = UDim2.fromOffset(o.Width or 56, 22), Parent = r }, { corner(3), s, pad(0, 0, 4, 6) }), -18)
	tc(box, "BackgroundColor3", "Field"); tc(box, "TextColor3", "Text")
	local obj = {}
	function obj:Set(v, silent)
		v = math.clamp(math.round(v / step) * step, min, max)
		val = v
		box.Text = fmt(v) .. (o.Suffix or "")
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Get() return val end
	up.MouseButton1Click:Connect(function() obj:Set(val + step) end)
	down.MouseButton1Click:Connect(function() obj:Set(val - step) end)
	box.Focused:Connect(function() ring(s, true) end)
	box.FocusLost:Connect(function()
		ring(s, false)
		obj:Set(tonumber(box.Text:match("%-?[%d%.]+") or "") or val)
	end)
	obj:Set(val, true)
	nav(self, rec, { target = box, kind = "stepper", step = function(d) obj:Set(val + d * step) end, activate = function() box:CaptureFocus() end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Segmented(o)
	local r, lbl, rec = row(self, o.Text, (o.Text or "") .. " " .. table.concat(o.Items, " "))
	local cont, obj = segmented(r, o)
	right(cont)
	nav(self, rec, { target = cont, kind = "segmented", step = function(d) obj:Step(d) end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Popup(o)
	local r, lbl, rec = row(self, o.Text, (o.Text or "") .. " " .. table.concat(o.Items, " "))
	local items = o.Items
	local cur = o.Default or items[1]
	local W = o.Width or 140
	local b = right(new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Size = UDim2.fromOffset(W, 22), Parent = r }, { corner(4), stroke("Border"), tgrad("BtnTop", "BtnBot") }))
	local txt = label({ Text = cur or "", Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
	local cap = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(20, 22), Parent = b }, { corner(4), agrad() })
	for k, g in ipairs({ "▲", "▼" }) do
		label({ Text = g, TextSize = 6, Color = false, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, k == 1 and 4 or 10), Parent = cap })
	end
	local obj = {}
	function obj:Set(v, silent)
		cur = v; txt.Text = v or ""
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Get() return cur end
	function obj:SetItems(t)
		items = t
		if not table.find(t, cur) then obj:Set(t[1], true) end
	end
	local function open()
		if #items == 0 then return end
		openMenu(self.Gui, b, items, cur, function(n) obj:Set(n) end, W)
	end
	b.MouseButton1Click:Connect(open)
	nav(self, rec, { target = b, kind = "popup", activate = open, step = function(d)
		local i = math.clamp((table.find(items, cur) or 1) + d, 1, #items)
		if items[i] and items[i] ~= cur then obj:Set(items[i]) end
	end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:TextField(o)
	local r, lbl, rec = row(self, o.Text)
	local s = stroke("Border")
	local tb = right(new("TextBox", { Text = o.Default or "", PlaceholderText = o.Placeholder or "", ClearTextOnFocus = false,
		Font = FONT, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0,
		Size = UDim2.fromOffset(o.Width or 160, 22), Parent = r }, { corner(3), s, pad(0, 0, 6, 6) }))
	tc(tb, "BackgroundColor3", "Field"); tc(tb, "TextColor3", "Text"); tc(tb, "PlaceholderColor3", "Placeholder")
	tb.Focused:Connect(function() ring(s, true) end)
	tb.FocusLost:Connect(function(enter)
		ring(s, false)
		if o.Callback then task.spawn(o.Callback, tb.Text, enter) end
	end)
	local obj = { Box = tb }
	function obj:Get() return tb.Text end
	function obj:Set(v, silent)
		tb.Text = tostring(v or "")
		if not silent and o.Callback then task.spawn(o.Callback, tb.Text, false) end
	end
	nav(self, rec, { target = tb, kind = "text", activate = function() tb:CaptureFocus() end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Keybind(o)
	local r, lbl, rec = row(self, o.Text)
	local key, listening = o.Default, false
	local fill, b, bapi = pushButton(r, { Text = key and key.Name or "None", Width = o.Width or 110 })
	right(fill)
	local obj = {}
	local function stop()
		listening = false
		if bapi.Text then tw(bapi.Text, .1, { TextTransparency = 0 }) end
		task.defer(function() Lib._listening -= 1 end)
	end
	function obj:Set(k, silent)
		key = k
		bapi.SetText(k and k.Name or "None")
		if not silent and o.Callback then task.spawn(o.Callback, k) end
	end
	function obj:Get() return key end
	local function listen()
		if listening or obj.Disabled then return end
		listening = true
		Lib._listening += 1
		bapi.SetText("Press a key…")
		pop(fill, .9, .2)
		task.spawn(function()
			while listening and bapi.Text do
				tw(bapi.Text, .4, { TextTransparency = .6 }); task.wait(.4)
				if not listening then break end
				tw(bapi.Text, .4, { TextTransparency = 0 }); task.wait(.4)
			end
		end)
	end
	b.MouseButton1Click:Connect(listen)
	UIS.InputBegan:Connect(function(i, gp)
		if listening then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				stop()
				local kc = i.KeyCode
				obj:Set((kc == KC.Escape or kc == KC.Backspace) and nil or kc)
			elseif isPress(i) then
				stop()
				bapi.SetText(key and key.Name or "None")
			end
		elseif key and not gp and i.KeyCode == key and o.OnPress and not obj.Disabled then
			task.spawn(o.OnPress)
		end
	end)
	-- keyboard activation: let the Enter/Space that triggered it finish first
	nav(self, rec, { target = fill, kind = "keybind", activate = function() task.delay(.05, listen) end })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Progress(o)
	local r, lbl, rec = row(self, o.Text)
	local track = right(new("Frame", { BorderSizePixel = 0, Size = UDim2.new(.5, 0, 0, 6), Parent = r }, { corner(3), stroke("Border") }), -44)
	tc(track, "BackgroundColor3", "Track")
	local fill = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track }, { corner(3), agrad() })
	local num = label({ Color = "Dim", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -40, 0, 0), Parent = r })
	local obj, val = {}, 0
	function obj:Set(p)
		val = math.clamp(p, 0, 1)
		tw(fill, .25, { Size = UDim2.fromScale(val, 1) })
		num.Text = math.floor(val * 100) .. "%"
	end
	function obj:Get() return val end
	obj:Set(o.Default or 0)
	return api(rec, obj, lbl)
end

function Section:ColorPicker(o)
	local r, lbl, rec = row(self, o.Text)
	local col = o.Default or RGB(0, 122, 255)
	local well = right(new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Size = UDim2.fromOffset(44, 22), Parent = r }, { corner(4), stroke("Border"), tgrad("BtnTop", "BtnBot") }))
	local sw = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = col, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Parent = well },
		{ corner(2), stroke(nil, .75) })
	local obj = {}
	function obj:Set(c, silent)
		col = c
		tw(sw, .15, { BackgroundColor3 = c })
		if not silent and o.Callback then task.spawn(o.Callback, c) end
	end
	function obj:Get() return col end
	local function open()
		pop(well, .9, .2)
		self.Win:_colors().Bind(obj)
	end
	well.MouseButton1Click:Connect(open)
	nav(self, rec, { target = well, kind = "color", activate = open })
	return flag(self, o, api(rec, obj, lbl))
end

function Section:Popover(o)
	local r, lbl, rec = row(self, o.Label, (o.Label or "") .. " " .. (o.Text or ""))
	rec.title = o.Label or o.Text
	local fill, b = pushButton(r, { Text = o.Text, Icon = (not o.Text) and (o.Icon or "ellipsis") or o.Icon, Chevron = o.Text ~= nil, MinWidth = 32 })
	right(fill)
	o.Name = o.Title or o.Label or o.Text
	local pv = self.Win:Popover(fill, o)
	b.MouseButton1Click:Connect(pv.Toggle)
	nav(self, rec, { target = fill, kind = "popover", activate = pv.Open })
	return api(rec, pv, lbl)
end

-- Finder-style table ------------------------------------------------------------------
function Tab:Table(o)
	local cols, RH, HH = o.Columns, o.RowHeight or (Lib.Touch and 28 or 20), 22
	local frame
	if o.Fill then
		local p = self.Page
		p.AutomaticCanvasSize = Enum.AutomaticSize.None
		p.CanvasSize = UDim2.new()
		p.ScrollBarThickness = 0
		local pd = p:FindFirstChildOfClass("UIPadding")
		pd.PaddingTop, pd.PaddingBottom, pd.PaddingLeft, pd.PaddingRight = UDim.new(), UDim.new(), UDim.new(), UDim.new()
		frame = new("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = p })
	else
		self._n += 1
		frame = new("Frame", { BorderSizePixel = 0, ClipsDescendants = true, Size = UDim2.new(1, 0, 0, o.Height or 220),
			LayoutOrder = self._n, Parent = self.Page }, { corner(5), stroke("BoxBorder") })
	end
	tc(frame, "BackgroundColor3", "Box")
	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HH), Parent = frame })
	tc(new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(0, HH), Size = UDim2.new(1, 0, 0, 1), Parent = frame }), "BackgroundColor3", "BoxBorder")
	local body = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, HH + 1),
		Size = UDim2.new(1, 0, 1, -(HH + 1)), CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ScrollBarThickness = 6,
		ScrollBarImageTransparency = .5, Parent = frame }, { list() })
	tc(body, "ScrollBarImageColor3", "Scroll")

	local total, acc, xs = 0, 0, {}
	for _, c in ipairs(cols) do total += (c.Width or 1) end
	for i, c in ipairs(cols) do xs[i] = { acc / total, (c.Width or 1) / total }; acc += (c.Width or 1) end

	local data, sortCol, sortAsc, selected, query = o.Rows or {}, o.SortColumn, true, nil, ""
	local lastClick, lastRow, view = 0, nil, {}
	local obj, arrows = {}, {}

	for i, c in ipairs(cols) do
		local hb = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = UDim2.fromScale(xs[i][1], 0), Size = UDim2.fromScale(xs[i][2], 1), Parent = header })
		label({ Text = c.Name, TextSize = 12, TextXAlignment = c.Align == "Right" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0), Parent = hb })
		arrows[i] = icon("chevron-up", 10, "Dim", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0), Visible = false, Parent = hb })
		if i < #cols then
			tc(new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, .5, 0),
				Size = UDim2.new(0, 1, 0, 14), Parent = hb }), "BackgroundColor3", "BoxBorder")
		end
		hb.MouseButton1Click:Connect(function()
			if o.Sortable == false then return end
			if sortCol == i then sortAsc = not sortAsc else sortCol, sortAsc = i, true end
			obj:Refresh()
		end)
	end

	local function less(ci)
		return cols[ci].Sort or function(p, q)
			local np, nq = tonumber(p), tonumber(q)
			if np and nq then return np < nq end
			return tostring(p or ""):lower() < tostring(q or ""):lower()
		end
	end

	function obj:Refresh()
		for _, ch in ipairs(body:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end
		view = {}
		for _, r in ipairs(data) do
			local hit = query == ""
			if not hit then
				for ci = 1, #cols do
					if tostring(r[ci] or ""):lower():find(query, 1, true) then hit = true; break end
				end
			end
			if hit then table.insert(view, r) end
		end
		if sortCol then
			local f = less(sortCol)
			table.sort(view, function(a, b)
				if sortAsc then return f(a[sortCol], b[sortCol]) end
				return f(b[sortCol], a[sortCol])
			end)
		end
		for i, arr in ipairs(arrows) do
			arr.Visible = i == sortCol
			tw(arr, .2, { Rotation = sortAsc and 0 or 180 })
		end
		for i, r in ipairs(view) do
			local sel = r == selected
			local rb = new("TextButton", { Text = "", AutoButtonColor = false, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, RH), LayoutOrder = i,
				BackgroundColor3 = sel and A.Solid or (i % 2 == 0 and T.Stripe or T.Box), Parent = body })
			for ci, c in ipairs(cols) do
				local x0 = 8
				local cell = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(xs[ci][1], 0), Size = UDim2.fromScale(xs[ci][2], 1), Parent = rb })
				if ci == 1 and r.Icon then
					local _, paint = icon(r.Icon, 14, nil, { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 8, .5, 0), Parent = cell })
					paint(sel and WHITE or T.Icon)
					x0 = 28
				end
				new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextSize = 13, Text = tostring(r[ci] or ""), TextTruncate = Enum.TextTruncate.AtEnd,
					TextColor3 = sel and WHITE or (ci == 1 and T.Text or T.Dim),
					TextXAlignment = c.Align == "Right" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(x0, 0), Size = UDim2.new(1, -(x0 + 8), 1, 0), Parent = cell })
			end
			rb.MouseButton1Click:Connect(function()
				local now = os.clock()
				if lastRow == r and now - lastClick < .35 and o.Activate then task.spawn(o.Activate, r) end
				lastRow, lastClick = r, now
				if selected ~= r then
					selected = r
					obj:Refresh()
					if o.Callback then task.spawn(o.Callback, r) end
				end
			end)
		end
		local need = math.ceil(body.AbsoluteSize.Y / RH) - #view
		for k = 1, need do
			local i = #view + k
			new("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, RH), LayoutOrder = i, BackgroundColor3 = i % 2 == 0 and T.Stripe or T.Box, Parent = body })
		end
	end
	function obj:SetRows(rows) data = rows; selected = nil; obj:Refresh() end
	function obj:Add(r) table.insert(data, r); obj:Refresh() end
	function obj:Remove(r) local i = table.find(data, r); if i then table.remove(data, i); if selected == r then selected = nil end; obj:Refresh() end end
	function obj:Clear() obj:SetRows({}) end
	function obj:GetSelected() return selected end
	function obj:Select(r) selected = r; obj:Refresh() end
	function obj:_filter(q) if q ~= query then query = q; obj:Refresh() end end

	-- keyboard: Up/Down move the selection, Enter opens
	local rec = { f = frame, title = o.Name or "Table", text = "" }
	table.insert(self.TableNav, { rec = rec, e = { target = frame, kind = "table",
		step = function(d)
			if #view == 0 then return end
			local i = math.clamp((table.find(view, selected) or 0) + d, 1, #view)
			selected = view[i]
			obj:Refresh()
			if o.Callback then task.spawn(o.Callback, selected) end
			local y, cp = (i - 1) * RH, body.CanvasPosition.Y
			if y < cp then body.CanvasPosition = Vector2.new(0, y)
			elseif y + RH > cp + body.AbsoluteSize.Y then body.CanvasPosition = Vector2.new(0, y + RH - body.AbsoluteSize.Y) end
		end,
		activate = function() if selected and o.Activate then task.spawn(o.Activate, selected) end end,
	} })

	local lastH = -1
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if math.abs(body.AbsoluteSize.Y - lastH) >= RH then lastH = body.AbsoluteSize.Y; obj:Refresh() end
	end)
	bind(function() obj:Refresh() end)
	table.insert(self.Tables, obj)
	return obj
end

return Lib

--[[ usage
local UI = loadstring(game:HttpGet("..."))()
-- UI.Lucide = false             -- skip icons (text glyph fallbacks), or UI.Lucide = <your loaded lucide-roblox module>
-- UI.BlurSize = 14              -- vibrancy blur strength
local w = UI:Window({
	Title = "Yosemite", Icon = "folder", Size = UDim2.fromOffset(720, 460),
	Config = { Folder = "MyHub/Configs", Format = "{place}/{name}.json" },   -- tokens: {name} {place} {game} {user}
	-- MobileButton = true                                                    -- force the floating toggle button
})

local tb = w:Toolbar({ Labels = true })
tb:Button({ Icon = "chevron-left", Label = "Back" })
tb:Segmented({ Items = { "layout-grid", "list", "columns-3", "gallery-horizontal" }, Icons = true, Default = "list", Label = "View" })
tb:Menu({ Icon = "settings", Items = { "New Folder", "Get Info", "Rename" }, Label = "Action", Callback = print })
tb:Popover({ Icon = "sliders-horizontal", Label = "Quick", Title = "Quick settings", Build = function(p)
	p:Checkbox({ Text = "Show hidden files", Callback = print })
	p:Slider({ Text = "Icon size", Min = 16, Max = 128, Default = 48 })
end })
tb:Search({ Label = "Search" })

local fav = w:Category("Favorites")
local aimTab = fav:Tab("Aim", "crosshair")
local visTab = fav:Tab("Visuals", "eye")

local aim = aimTab:Section("Aim")
local enabled = aim:Checkbox({ Text = "Enabled", Default = true, Callback = print })
local fov = aim:Slider({ Text = "FOV", Min = 10, Max = 360, Default = 90, Suffix = "°" })
aim:Segmented({ Text = "Mode", Items = { "Hold", "Toggle", "Always" } })
aim:Popover({ Label = "Advanced", Text = "Options", Width = 260, Build = function(p)
	p:Stepper({ Text = "Smoothing", Min = 0, Max = 1, Step = .05, Default = .3 })
	p:Radio({ Text = "Priority", Items = { "Distance", "Health", "Crosshair" } })
end })
aim:Keybind({ Text = "Aim key", Default = Enum.KeyCode.E, OnPress = function() print("pressed") end })

local esp = visTab:Section("ESP")
esp:ColorPicker({ Text = "Box color", Default = Color3.fromRGB(255, 59, 48), Callback = print })
esp:ColorPicker({ Text = "Tracer color", Default = Color3.fromRGB(0, 122, 255) })

-- dynamic updates (every control)
enabled:SetText("Aimbot enabled")
fov:SetDisabled(true); task.delay(3, function() fov:SetDisabled(false) end)
-- fov:SetVisible(false)

-- keyboard: Tab / Shift+Tab, arrows, Enter/Space, Esc; Ctrl+K = command bar (w:OpenCommandBar())
-- UI:SetVibrancy(false) / UI:SetMobileButton(true) / UI:Toggle() / UI:SetTheme("Dark") / w:SetThin(true)
]]

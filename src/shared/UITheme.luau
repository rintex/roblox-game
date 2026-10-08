-- Client presentation only. Currency, unlocks and rewards still belong to the server.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Theme = {}
Theme.Colors = {
	panel = Color3.fromRGB(22, 31, 47), card = Color3.fromRGB(35, 48, 67),
	text = Color3.fromRGB(242, 248, 255), muted = Color3.fromRGB(166, 185, 205),
	teal = Color3.fromRGB(93, 227, 187), gold = Color3.fromRGB(255, 210, 102),
	blue = Color3.fromRGB(119, 192, 255), red = Color3.fromRGB(255, 131, 142),
	line = Color3.fromRGB(84, 111, 137), shade = Color3.fromRGB(8, 14, 26),
}

function Theme.Make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end

function Theme.Round(object, radius)
	return Theme.Make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, object)
end

function Theme.Stroke(object, color, transparency)
	return Theme.Make("UIStroke", {Color = color or Theme.Colors.line, Transparency = transparency or 0.5, Thickness = 1}, object)
end

function Theme.Surface(object, radius, accent)
	Theme.Round(object, radius)
	Theme.Stroke(object, accent)
	Theme.Make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 213, 235)), Rotation = 90}, object)
end

function Theme.Label(parent, name, text, size, position, fontSize, color)
	return Theme.Make("TextLabel", {
		Name = name, BackgroundTransparency = 1, Size = size, Position = position,
		Text = text, TextColor3 = color or Theme.Colors.text, TextSize = fontSize or 14,
		Font = Enum.Font.GothamMedium, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1,
	}, parent)
end

function Theme.Format(value)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return "0" end
	local reversed = string.reverse(tostring(math.max(0, math.floor(value))))
	return string.reverse(string.gsub(reversed, "(%d%d%d)", "%1 ")):gsub("^ ", "")
end

function Theme.Compact(value)
	if type(value) ~= "number" or value ~= value then return "0" end
	if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
	if value >= 10000 then return string.format("%.1fK", value / 1000) end
	return Theme.Format(value)
end

function Theme.Scope()
	local scope = {alive = true, connections = {}, tweens = {}}
	function scope:Connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(self.connections, connection)
		return connection
	end
	function scope:Tween(object, duration, properties)
		if not self.alive then return nil end
		local previous = self.tweens[object]
		if previous then previous:Cancel() end
		local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
		self.tweens[object] = tween
		local completed
		completed = tween.Completed:Connect(function()
			completed:Disconnect()
			if self.tweens[object] == tween then self.tweens[object] = nil end
		end)
		tween:Play()
		return tween
	end
	function scope:Destroy()
		if not self.alive then return end
		self.alive = false
		for _, connection in ipairs(self.connections) do connection:Disconnect() end
		for _, tween in pairs(self.tweens) do tween:Cancel() end
		table.clear(self.connections)
		table.clear(self.tweens)
	end
	return scope
end

function Theme.Button(scope, parent, name, text, size, position, accent)
	local button = Theme.Make("TextButton", {
		Name = name, Text = text, Size = size, Position = position or UDim2.new(),
		BackgroundColor3 = accent or Theme.Colors.card, TextColor3 = if accent then Theme.Colors.panel else Theme.Colors.text,
		Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false,
		BorderSizePixel = 0, Active = true, Selectable = true, ZIndex = parent.ZIndex + 2,
	}, parent)
	Theme.Round(button, 11)
	Theme.DecorateButton(scope, button, accent)
	return button
end

function Theme.DecorateButton(scope, button, accent)
	button.AutoButtonColor = false
	local outline = button:FindFirstChildOfClass("UIStroke") or Theme.Stroke(button, accent or Theme.Colors.line, 0.6)
	local scale = Theme.Make("UIScale", {Name = "PressScale", Scale = 1}, button)
	local function motion(value, highlighted)
		if not button.Active then value = 1; highlighted = false end
		scope:Tween(scale, 0.1, {Scale = value})
		scope:Tween(outline, 0.12, {Transparency = if highlighted then 0.15 else 0.6})
	end
	scope:Connect(button.MouseEnter, function() motion(1.025, true) end)
	scope:Connect(button.MouseLeave, function() motion(1, false) end)
	scope:Connect(button.SelectionGained, function() motion(1.025, true) end)
	scope:Connect(button.SelectionLost, function() motion(1, false) end)
	scope:Connect(button.MouseButton1Down, function() motion(0.97, true) end)
	scope:Connect(button.MouseButton1Up, function() motion(1, true) end)
end

function Theme.SetButton(button, text, enabled, accent)
	button.Text = text
	button.Active = enabled == true
	button.Selectable = enabled == true
	button:SetAttribute("Enabled", enabled == true)
	button.BackgroundColor3 = if enabled then (accent or Theme.Colors.teal) else Theme.Colors.card
	button.TextColor3 = if enabled then Theme.Colors.panel else Theme.Colors.muted
end

-- Native GUI art: no external images, asset permissions or uploads are needed.
function Theme.Icon(parent, kind, color, size, position)
	local frame = Theme.Make("Frame", {Name = "Icon_" .. kind, Size = size or UDim2.fromOffset(24, 24), Position = position or UDim2.new(), BackgroundTransparency = 1, ZIndex = parent.ZIndex + 1}, parent)
	local function shape(name, x, y, w, h, rotation, round)
		local part = Theme.Make("Frame", {Name = name, Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rotation or 0, BackgroundColor3 = color or Theme.Colors.teal, BorderSizePixel = 0, ZIndex = frame.ZIndex + 1}, frame)
		if round then Theme.Make("UICorner", {CornerRadius = UDim.new(0.5, 0)}, part) end
		return part
	end
	if kind == "coin" then
		shape("Coin", .1, .1, .8, .8, 0, true)
		local inner = shape("Inner", .32, .3, .36, .4, 0, true); inner.BackgroundColor3 = Theme.Colors.panel
	elseif kind == "house" then
		shape("Roof", .2, .08, .6, .6, 45); shape("Home", .1, .38, .8, .57)
		local door = shape("Door", .4, .62, .2, .33); door.BackgroundColor3 = Theme.Colors.panel
	elseif kind == "arsenal" then
		shape("Blade", .4, .05, .18, .75, 35); shape("Guard", .15, .65, .6, .12, 35); shape("Grip", .1, .78, .27, .12, -55)
	elseif kind == "settings" then
		for row = 1, 3 do shape("Rail" .. row, .05, row * .25 - .05, .9, .08, 0, true); shape("Switch" .. row, if row == 2 then .58 else .2, row * .25 - .12, .15, .22, 0, true) end
	elseif kind == "health" then
		shape("Vertical", .36, .1, .28, .8, 0, true); shape("Horizontal", .1, .36, .8, .28, 0, true)
	elseif kind == "star" then
		shape("Star", .23, .23, .54, .54, 45); shape("Beam", .07, .42, .86, .16); shape("Spine", .42, .07, .16, .86)
	else
		shape("Dot", .2, .2, .6, .6, 0, true)
	end
	return frame
end

function Theme.WeaponArt(parent, definition, position, size)
	local color = definition.Color and Color3.fromRGB(definition.Color[1], definition.Color[2], definition.Color[3]) or Theme.Colors.teal
	local art = Theme.Make("Frame", {Name = "WeaponPreview", Position = position, Size = size or UDim2.fromOffset(76, 76), BackgroundColor3 = Theme.Colors.panel, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = parent.ZIndex + 1}, parent)
	Theme.Round(art, 12)
	Theme.Stroke(art, color, .35)
	local function p(name, x, y, w, h, tint, rotation, round)
		local value = Theme.Make("Frame", {Name = name, Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = tint, BorderSizePixel = 0, Rotation = rotation or 0, ZIndex = art.ZIndex + 1}, art)
		if round then Theme.Round(value, round) end
		return value
	end
	local steel = Color3.fromRGB(124, 149, 174)
	if definition.Kind == "slam" then
		p("Handle", .46, .34, .09, .53, steel, 22, 3)
		p("Hammer", .18, .19, .65, .28, color, 22, 5)
		p("Core", .39, .23, .17, .2, Theme.Colors.text, 22, 3)
	elseif definition.Id == "solar_lance" then
		p("Shaft", .48, .18, .07, .7, steel, 35, 2)
		p("Lance", .43, .08, .22, .28, color, 35, 4)
		p("Energy", .45, .12, .1, .19, Theme.Colors.text, 35, 3)
	elseif definition.Style then
		p("Cuff", .28, .46, .35, .29, steel, -25, 6)
		p("Gauntlet", .35, .27, .42, .29, color, -25, 7)
		p("Charge", .51, .22, .24, .24, Theme.Colors.text, 0, 12)
	else
		local long = definition.Id == "arc_rifle" or definition.Id == "frost_projector"
		p("Grip", .3, .49, .17, .3, steel, -18, 3)
		p("Barrel", .18, .31, if long then .68 else .52, .2, steel, -18, 4)
		p("EnergyCell", .27, .32, .2, .16, color, -18, 3)
		p("Muzzle", if long then .74 else .59, .23, .12, .25, color, -18, 3)
		if definition.Id == "thread_launcher" then p("Coil", .48, .18, .24, .24, Theme.Colors.text, 0, 12) end
		if definition.Id == "frost_projector" then p("Crystal", .66, .12, .18, .18, Theme.Colors.text, 45, 2) end
	end
	return art
end

function Theme.HeroArt(parent, definition, position, size)
	local color = Color3.fromRGB(definition.Color[1], definition.Color[2], definition.Color[3])
	local art = Theme.Make("Frame", {Name = "CostumePreview", Position = position, Size = size, BackgroundColor3 = Theme.Colors.panel, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = parent.ZIndex + 1}, parent)
	Theme.Round(art, 12)
	Theme.Stroke(art, color, .4)
	local function p(name, x, y, w, h, tint, radius, rotation)
		local value = Theme.Make("Frame", {Name = name, Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = tint, BorderSizePixel = 0, Rotation = rotation or 0, ZIndex = art.ZIndex + 1}, art)
		if radius then Theme.Round(value, radius) end
		return value
	end
	local style = definition.Style
	local legs = if style == "hulk" then Color3.fromRGB(105, 68, 135) elseif style == "spider" then Color3.fromRGB(41, 88, 163) else color
	if style == "thor" then p("Cape", .18, .33, .64, .56, Color3.fromRGB(172, 48, 64), 3) end
	p("LeftLeg", .31, .67, .16, .25, legs, 3)
	p("RightLeg", .53, .67, .16, .25, legs, 3)
	p("Body", .26, .35, .48, .37, color, 5)
	p("LeftArm", .08, .38, .15, .34, color, 5)
	p("RightArm", .77, .38, .15, .34, color, 5)
	p("Head", .33, .08, .34, .28, if style == "thor" then Color3.fromRGB(222, 173, 136) else color, 8)
	if style == "iron" or style == "iron_gold" then
		p("Faceplate", .37, .1, .26, .23, Theme.Colors.gold, 5)
		p("Reactor", .43, .43, .14, .14, Theme.Colors.blue, 8)
	elseif style == "spider" or style == "symbiote" then
		p("Emblem", .465, .44, .07, .18, if style == "spider" then Theme.Colors.shade else Theme.Colors.text, 2)
		for line = 1, 3 do
			p("LeftWeb" .. line, .36, .46 + line * .028, .12, .024, if style == "spider" then Theme.Colors.shade else Theme.Colors.text, 0, 30)
			p("RightWeb" .. line, .52, .46 + line * .028, .12, .024, if style == "spider" then Theme.Colors.shade else Theme.Colors.text, 0, -30)
		end
	elseif style == "hulk" then
		p("Hair", .34, .08, .32, .07, Theme.Colors.shade, 2)
		p("Muscle", .31, .42, .38, .08, Color3.fromRGB(134, 194, 97), 5)
		p("Jaw", .39, .27, .22, .03, Theme.Colors.shade, 1)
	elseif style == "thor" then
		p("Hair", .33, .07, .34, .08, Color3.fromRGB(173, 125, 64), 3)
		p("Beard", .39, .26, .23, .09, Color3.fromRGB(173, 125, 64), 3)
		p("DiscLeft", .33, .43, .11, .11, Theme.Colors.text, 6)
		p("DiscRight", .56, .43, .11, .11, Theme.Colors.text, 6)
	end
	p("LeftEye", .38, .19, .09, .055, Theme.Colors.text, 2, -12)
	p("RightEye", .53, .19, .09, .055, Theme.Colors.text, 2, 12)
	return art
end

local modals = {}
local activeModal = nil
local closeInput = nil
local function publishModal()
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChild("PlayerGui")
	if gui then gui:SetAttribute("QuarterModalOpen", activeModal and activeModal.name or "") end
end

function Theme.RegisterModal(name, panel, backdrop, onClosed, selection)
	if modals[name] then modals[name]:Destroy() end
	local modal = {name = name, panel = panel, scope = Theme.Scope(), open = false, serial = 0}
	local scale = Theme.Make("UIScale", {Name = "PopupScale", Scale = 1}, panel)
	panel.Visible = false
	backdrop.Visible = false
	function modal:Close(immediate)
		self.serial += 1
		local serial = self.serial
		self.open = false
		if activeModal == self then activeModal = nil; publishModal() end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then GuiService.SelectedObject = nil end
		if onClosed then onClosed() end
		if immediate then
			panel.Visible = false; backdrop.Visible = false; scale.Scale = 1
		else
			self.scope:Tween(scale, .14, {Scale = .94})
			self.scope:Tween(backdrop, .14, {BackgroundTransparency = 1})
			task.delay(.14, function() if self.scope.alive and self.serial == serial and not self.open then panel.Visible = false; backdrop.Visible = false end end)
		end
	end
	function modal:Open()
		-- Also finish a previous closing animation before another window appears.
		for _, other in pairs(modals) do
			if other ~= self and (other.open or other.panel.Visible) then other:Close(true) end
		end
		self.serial += 1
		self.open = true
		activeModal = self
		publishModal()
		panel.Visible = true; backdrop.Visible = true; scale.Scale = .94; backdrop.BackgroundTransparency = 1
		self.scope:Tween(scale, .18, {Scale = 1})
		self.scope:Tween(backdrop, .18, {BackgroundTransparency = .28})
		if string.find(UserInputService:GetLastInputType().Name, "^Gamepad") then
			local target = if type(selection) == "function" then selection() else selection
			if target and target.Visible and target.Selectable then GuiService.SelectedObject = target end
		end
	end
	function modal:Toggle() if self.open then self:Close() else self:Open() end end
	function modal:Destroy()
		self:Close(true)
		self.scope:Destroy()
		if modals[name] == self then modals[name] = nil end
		if next(modals) == nil and closeInput then closeInput:Disconnect(); closeInput = nil end
	end
	modals[name] = modal
	if not closeInput then
		closeInput = UserInputService.InputBegan:Connect(function(input, processed)
			if activeModal and not processed and (input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Backspace) then activeModal:Close() end
		end)
	end
	return modal
end

function Theme.CloseAll()
	if activeModal then activeModal:Close(true) end
end

function Theme.HasModal() return activeModal ~= nil end

function Theme.OpenModal(name)
	local modal = modals[name]
	if not modal then return false end
	modal:Open()
	return true
end

function Theme.Shortcut(scope, keyboard, gamepad, callback)
	scope:Connect(UserInputService.InputBegan, function(input, processed)
		if not processed and not UserInputService:GetFocusedTextBox() and (input.KeyCode == keyboard or (gamepad and input.KeyCode == gamepad)) then callback() end
	end)
end

return Theme

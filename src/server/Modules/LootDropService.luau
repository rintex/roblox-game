-- Бесплатный общий груз. Выбор оружия и выдача награды происходят только на сервере.
local LootDropService = {}
LootDropService.__index = LootDropService

local Helpers = {}
LootDropService.Helpers = Helpers

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- unitRoll задаётся серверным Random:NextNumber(). Аргумент удобен для проверки шансов.
function Helpers.WeightedRoll(weapons, unitRoll)
	if type(weapons) ~= "table" or not finite(unitRoll) then return nil end
	local total = 0
	local lastWeapon
	for _, weapon in ipairs(weapons) do
		local weight = weapon.LootWeight
		if finite(weight) and weight > 0 then
			total += weight
			lastWeapon = weapon
		end
	end
	if total <= 0 or not finite(total) then return nil end
	local target = math.clamp(unitRoll, 0, 1) * total
	local accumulated = 0
	for _, weapon in ipairs(weapons) do
		local weight = weapon.LootWeight
		if finite(weight) and weight > 0 then
			accumulated += weight
			if target < accumulated then return weapon end
		end
	end
	return lastWeapon
end

-- Эта функция не обращается к RemoteEvent и не содержит ожиданий.
-- В инвентаре остаётся максимум 99 копий, переполнение заменяется монетами.
function Helpers.Grant(config, profile, weapon)
	if type(profile) ~= "table" or type(weapon) ~= "table" then return nil end
	local known = false
	for _, definition in ipairs(config.Weapons or {}) do
		if definition == weapon then known = true; break end
	end
	if not known or type(weapon.Id) ~= "string" then return nil end
	if type(profile.Inventory) ~= "table" then profile.Inventory = {} end
	local maximum = if finite(config.MaxWeaponCopies) then math.clamp(math.floor(config.MaxWeaponCopies), 1, 99) else 99
	local previous = profile.Inventory[weapon.Id]
	previous = if finite(previous) then math.clamp(math.floor(previous), 0, maximum) else 0
	local count = math.min(maximum, previous + 1)
	local compensation = 0
	if previous >= maximum then
		local coins = if finite(profile.Coins) then math.clamp(math.floor(profile.Coins), 0, config.MaxCoins) else 0
		local reward = config.Airdrops and config.Airdrops.DuplicateCoins or 100
		reward = if finite(reward) then math.max(0, math.floor(reward)) else 100
		compensation = math.min(reward, config.MaxCoins - coins)
		profile.Coins = coins + compensation
	end
	profile.Inventory[weapon.Id] = count
	return {
		weaponId = weapon.Id, name = weapon.Name, rarity = weapon.Rarity,
		count = count, duplicate = previous > 0, compensationCoins = compensation,
	}
end

function LootDropService.new(config, profiles, tycoon, notice, lootResult)
	return setmetatable({
		config = config, profiles = profiles, tycoon = tycoon,
		notice = notice, lootResult = lootResult,
		players = game:GetService("Players"), workspace = game:GetService("Workspace"),
		runService = game:GetService("RunService"), tweenService = game:GetService("TweenService"),
		random = Random.new(), connections = {}, lastAttemptAt = {},
		started = false, destroyed = false, active = nil, folder = nil,
	}, LootDropService)
end

local function part(parent, name, size, cframe, color, material)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

local function attachedPart(parent, body, name, size, offset, color, material)
	local object = part(parent, name, size, body.CFrame * CFrame.new(offset), color, material)
	object.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = object
	weld.Parent = object
	-- Одна закреплённая деталь ведёт весь груз; физика клиента его не перемещает.
	object.Anchored = false
	return object
end

function LootDropService:_removeDrop(drop)
	if drop.removed then return end
	drop.removed = true
	drop.claimed = true
	drop.prompt.Enabled = false
	if self.active == drop then self.active = nil end
	for _, connection in ipairs(drop.connections) do connection:Disconnect() end
	table.clear(drop.connections)
	-- Сначала отключаем Completed, затем отменяем падение.
	if drop.tween then drop.tween:Cancel() end
	drop.model:Destroy()
end

function LootDropService:_currentProfile(player)
	if self.destroyed or self.profiles:IsClosing() or player.Parent ~= self.players
		or player:GetAttribute("DataReady") ~= true then return nil end
	local profile = self.profiles:Get(player)
	local state = self.tycoon:GetState(player)
	if not profile or not state or state.leaving or state.profile ~= profile then return nil end
	return profile
end

function LootDropService:_claim(player, drop)
	local now = os.clock()
	if self.destroyed or self.active ~= drop or drop.claimed or not drop.landed
		or now >= drop.expiresAt or not drop.prompt.Enabled then return end
	if not self.folder or self.folder.Parent ~= self.workspace or drop.model.Parent ~= self.folder or not drop.body:IsDescendantOf(drop.model)
		or drop.prompt.Parent ~= drop.body then return end
	if player.Parent ~= self.players then return end
	if now - (self.lastAttemptAt[player] or -math.huge) < (self.config.ActionCooldown or 0.35) then return end
	self.lastAttemptAt[player] = now
	local profile = self:_currentProfile(player)
	if not profile then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not (humanoid.Health > 0) or not root or not root:IsA("BasePart") then return end
	-- Triggered можно подделать: расстояние перепроверяет сам сервер.
	local distance = (root.Position - drop.body.Position).Magnitude
	if not finite(distance) or distance > 12 then return end
	local weapon = Helpers.WeightedRoll(self.config.Weapons, self.random:NextNumber())
	if not weapon then self:_removeDrop(drop); return end
	-- Проверки, пометка и выдача проходят без yield. Только один игрок получит груз.
	drop.claimed = true
	drop.prompt.Enabled = false
	local outcome = Helpers.Grant(self.config, profile, weapon)
	self:_removeDrop(drop)
	if not outcome then return end
	local synced = pcall(function() self.tycoon:SyncPlayer(player) end)
	if not synced then warn("LootDrop: не удалось обновить интерфейс инвентаря") end
	-- SyncPlayer может в будущем стать асинхронным: старой сессии результат не отправляем.
	if self:_currentProfile(player) ~= profile then return end
	self.lootResult:FireClient(player, outcome)
	local text = "Бесплатный груз: " .. outcome.name .. " (" .. outcome.rarity .. ")!"
	if outcome.compensationCoins > 0 then
		text = "Лимит копий: компенсация +" .. outcome.compensationCoins .. " монет!"
	elseif outcome.duplicate then
		text ..= " Копий в инвентаре: " .. outcome.count .. "."
	end
	self.notice:FireClient(player, { text = text, kind = "success" })
end

function LootDropService:_spawnDrop(now)
	local settings = self.config.Airdrops
	local location = settings.Locations[self.random:NextInteger(1, #settings.Locations)]
	local model = Instance.new("Model")
	model.Name = "FreeSupplyCrate"
	local start = CFrame.new(location.X, 88, location.Z)
	local body = part(model, "Crate", Vector3.new(6, 5, 6), start, Color3.fromRGB(48, 69, 100), Enum.Material.Metal)
	model.PrimaryPart = body
	attachedPart(model, body, "Lid", Vector3.new(6.4, 0.5, 6.4), Vector3.new(0, 2.6, 0), Color3.fromRGB(255, 210, 75), Enum.Material.Metal)
	attachedPart(model, body, "GoldBandX", Vector3.new(6.05, 1, 6.05), Vector3.new(0, 0, 0), Color3.fromRGB(255, 210, 75), Enum.Material.Metal)
	local parachute = Instance.new("Folder")
	parachute.Name = "Parachute"
	parachute.Parent = model
	local canopy = attachedPart(parachute, body, "Canopy", Vector3.new(13, 2.5, 13), Vector3.new(0, 14, 0), Color3.fromRGB(79, 218, 208))
	canopy.Shape = Enum.PartType.Ball
	for index, offset in ipairs({ Vector3.new(-2.6, 8, -2.6), Vector3.new(2.6, 8, -2.6), Vector3.new(-2.6, 8, 2.6), Vector3.new(2.6, 8, 2.6) }) do
		attachedPart(parachute, body, "Rope" .. index, Vector3.new(0.12, 10, 0.12), offset, Color3.fromRGB(232, 238, 244))
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CrateLabel"
	gui.Size = UDim2.fromOffset(240, 54)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 37, 60)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(255, 220, 103)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = "БЕСПЛАТНЫЙ ГРУЗ\nПриземляется..."
	label.Parent = gui
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 75)
	light.Brightness = 1.5
	light.Range = 15
	light.Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LootPrompt"
	prompt.ActionText = "Забрать оружие"
	prompt.ObjectText = "Бесплатный груз"
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0.35
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body
	model.Parent = self.folder
	local drop = {
		model = model, body = body, prompt = prompt, label = label,
		landed = false, claimed = false, removed = false, connections = {},
		landDeadline = now + settings.FallSeconds + 5, expiresAt = math.huge,
	}
	self.active = drop
	self.nextDropAt = now + self.random:NextNumber(settings.MinInterval, settings.MaxInterval)
	table.insert(drop.connections, prompt.Triggered:Connect(function(player) self:_claim(player, drop) end))
	drop.tween = self.tweenService:Create(body, TweenInfo.new(settings.FallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(location.X, 2.7, location.Z),
	})
	table.insert(drop.connections, drop.tween.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed or self.destroyed or self.active ~= drop or drop.removed then return end
		if self.profiles:IsClosing() or model.Parent ~= self.folder or not body:IsDescendantOf(model) then
			self:_removeDrop(drop)
			return
		end
		parachute:Destroy()
		body.CanCollide = true
		drop.landed = true
		drop.expiresAt = os.clock() + settings.Lifetime
		label.Text = "БЕСПЛАТНОЕ ОРУЖИЕ\nПодойди и нажми E"
		prompt.Enabled = true
	end))
	drop.tween:Play()
	self.notice:FireAllClients({ text = "С неба падает бесплатный груз! Забери оружие после приземления.", kind = "info" })
end

function LootDropService:_step(now)
	if self.destroyed then return end
	if self.profiles:IsClosing() or not self.folder or self.folder.Parent ~= self.workspace then
		self:Destroy()
		return
	end
	local drop = self.active
	if drop then
		if drop.model.Parent ~= self.folder or not drop.body:IsDescendantOf(drop.model)
			or drop.prompt.Parent ~= drop.body
			or (not drop.landed and now >= drop.landDeadline)
			or (drop.landed and now >= drop.expiresAt) then
			self:_removeDrop(drop)
		end
	end
	if not self.active and now >= self.nextDropAt then self:_spawnDrop(now) end
end

function LootDropService:Start()
	assert(not self.started and not self.destroyed, "LootDropService уже запущен или завершён")
	local settings = self.config.Airdrops
	assert(settings and type(settings.Locations) == "table" and #settings.Locations > 0, "Не заданы точки бесплатного груза")
	assert(Helpers.WeightedRoll(self.config.Weapons, 0), "Не заданы шансы оружия")
	assert(not self.workspace:FindFirstChild("Airdrops"), "Airdrops уже существует: второй сервис создаст дубликаты")
	self.folder = Instance.new("Folder")
	self.folder.Name = "Airdrops"
	self.folder.Parent = self.workspace
	self.started = true
	self.nextDropAt = os.clock() + settings.FirstDelay
	table.insert(self.connections, self.runService.Heartbeat:Connect(function() self:_step(os.clock()) end))
	table.insert(self.connections, self.players.PlayerRemoving:Connect(function(player) self.lastAttemptAt[player] = nil end))
	game:BindToClose(function() self:Destroy() end)
end

function LootDropService:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.started = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	if self.active then self:_removeDrop(self.active) end
	if self.folder then self.folder:Destroy(); self.folder = nil end
	table.clear(self.lastAttemptAt)
end

return LootDropService

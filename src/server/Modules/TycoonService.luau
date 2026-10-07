-- Авторитетная экономика и владение участками. Клиент не задаёт цены и награды.
local TycoonService = {}
TycoonService.__index = TycoonService

-- Чистые функции экономики также используются в автоматических проверках.
local Economy = {}
TycoonService.Economy = Economy

local function result(ok, text, kind)
	return { ok = ok, text = text, kind = kind or (ok and "success" or "error") }
end

function Economy.Income(config, profile)
	return config.IncomeFor(profile.Floor, profile.DropperTier, profile.Rebirths or 0)
end

function Economy.Accrue(config, profile, ticks)
	local added = math.min(config.MaxBank - profile.Bank, Economy.Income(config, profile) * (ticks or 1))
	if added <= 0 then
		return 0
	end
	profile.Bank += added
	return added
end

function Economy.Collect(config, profile)
	local amount = math.min(profile.Bank, config.MaxCoins - profile.Coins)
	if amount <= 0 then
		if profile.Bank > 0 then
			return result(false, "Кошелёк заполнен. Потратьте монеты на улучшения.")
		end
		return result(false, "Копилка пока пуста. Сначала постройте этаж и немного подождите.", "info")
	end
	profile.Bank -= amount
	profile.Coins += amount
	profile.XP = math.min(config.MaxXP, profile.XP + amount)
	profile.CollectedTotal = math.min(config.MaxCoins, (profile.CollectedTotal or 0) + amount)
	return result(true, "+" .. amount .. " монет и +" .. amount .. " XP из копилки!")
end

function Economy.BuyFloor(config, profile)
	local nextFloor = profile.Floor + 1
	local floor = config.Floors[nextFloor]
	if not floor then
		return result(false, "Все три этажа уже построены!", "info")
	end
	if profile.Coins < floor.Cost then
		return result(false, "Для этажа " .. nextFloor .. " нужно " .. floor.Cost .. " монет.")
	end
	profile.Coins -= floor.Cost
	profile.Floor = nextFloor
	profile.XP = math.min(config.MaxXP, profile.XP + floor.XP)
	local suffix = nextFloor == 3 and " Доступны бонусный сундук и ускорение персонажа!" or " Генератор приносит больше монет."
	return result(true, "Этаж " .. nextFloor .. " построен!" .. suffix)
end

function Economy.BuyDropper(config, profile)
	if profile.Floor < 1 then
		return result(false, "Сначала постройте первый этаж.")
	end
	local nextTier = profile.DropperTier + 1
	local cost = config.DropperCosts[nextTier]
	if not cost then
		return result(false, "Генератор уже улучшен до максимума!", "info")
	end
	if profile.Coins < cost then
		return result(false, "Для улучшения генератора нужно " .. cost .. " монет.")
	end
	profile.Coins -= cost
	profile.DropperTier = nextTier
	return result(true, "Генератор улучшен! Доход: " .. Economy.Income(config, profile) .. " монет/сек.")
end

function Economy.ClaimBonus(config, profile, now)
	if profile.Floor < 3 then
		return result(false, "Бонусный сундук откроется на третьем этаже.")
	end
	if now < profile.BonusReadyAt then
		return result(false, "Следующий бонус через " .. math.ceil(profile.BonusReadyAt - now) .. " сек.", "info")
	end
	local amount = math.min(config.BonusCoins, config.MaxCoins - profile.Coins)
	if amount <= 0 then
		return result(false, "Кошелёк заполнен. Сначала потратьте монеты.")
	end
	profile.Coins += amount
	profile.XP = math.min(config.MaxXP, profile.XP + config.BonusXP)
	profile.BonusReadyAt = now + config.BonusCooldown
	return result(true, "Бонус третьего этажа: +" .. amount .. " монет и +" .. config.BonusXP .. " XP!")
end

function TycoonService.new(config, profiles, world, plots, notice)
	return setmetatable({
		config = config,
		profiles = profiles,
		world = world,
		plots = plots,
		notice = notice,
		players = game:GetService("Players"),
		httpService = game:GetService("HttpService"),
		runService = game:GetService("RunService"),
		states = {},
		owners = {},
		connections = {},
		started = false,
		elapsed = 0,
	}, TycoonService)
end

function TycoonService:_notify(player, text, kind)
	if player.Parent == self.players then
		self.notice:FireClient(player, { text = text, kind = kind or "info" })
	end
end

local function findPrompt(plot, partName, promptName)
	local part = plot:FindFirstChild(partName)
	assert(part and part:IsA("BasePart"), "На участке отсутствует " .. partName)
	local prompt = part:FindFirstChild(promptName)
	assert(prompt and prompt:IsA("ProximityPrompt"), "На участке отсутствует " .. promptName)
	return prompt
end

function TycoonService:_refreshPlot(plot)
	local state = self.owners[plot]
	local ready = state ~= nil and state.profile ~= nil and state.player:GetAttribute("DataReady") == true
	local profile = ready and state.profile or nil
	local prompts = self.promptSets[plot]
	prompts.claim.Enabled = state == nil
	prompts.floor.Enabled = ready and profile.Floor < #self.config.Floors
	prompts.dropper.Enabled = ready and profile.Floor > 0 and profile.DropperTier < #self.config.DropperCosts
	prompts.collect.Enabled = ready and profile.Floor > 0
	prompts.bonus.Enabled = ready and profile.Floor >= 3
	local heroPad = plot:FindFirstChild("HeroPad")
	local heroPrompt = heroPad and heroPad:FindFirstChild("HeroPrompt")
	if heroPrompt then
		heroPrompt.Enabled = ready and (profile.Floor >= 1 or (profile.Rebirths or 0) > 0)
	end
	plot:SetAttribute("OwnerReady", ready)
	plot:SetAttribute("Bank", profile and profile.Bank or 0)
	plot:SetAttribute("DropperTier", profile and profile.DropperTier or 0)
	plot:SetAttribute("Income", profile and Economy.Income(self.config, profile) or 0)
	if profile then
		local nextFloor = self.config.Floors[profile.Floor + 1]
		prompts.floor.ActionText = "Построить этаж " .. (profile.Floor + 1)
		prompts.floor.ObjectText = nextFloor and (nextFloor.Cost .. " монет") or "Дом достроен"
		local cost = self.config.DropperCosts[profile.DropperTier + 1]
		prompts.dropper.ActionText = "Улучшить генератор"
		prompts.dropper.ObjectText = cost and (cost .. " монет") or "Максимум"
		prompts.collect.ActionText = "Забрать монеты"
		prompts.collect.ObjectText = "Копилка: " .. profile.Bank
		prompts.bonus.ActionText = "Открыть бонус"
		prompts.bonus.ObjectText = "+" .. self.config.BonusCoins .. " монет"
	end
end

function TycoonService:_sync(state)
	local profile = state.profile
	local player = state.player
	if not profile or player.Parent ~= self.players then
		return
	end
	state.coins.Value = profile.Coins
	state.level.Value = self.config.GetLevel(profile.XP)
	player:SetAttribute("Floor", profile.Floor)
	player:SetAttribute("DropperTier", profile.DropperTier)
	player:SetAttribute("Bank", profile.Bank)
	player:SetAttribute("Income", Economy.Income(self.config, profile))
	player:SetAttribute("XP", profile.XP)
	player:SetAttribute("BonusReadyAt", profile.BonusReadyAt)
	player:SetAttribute("Rebirths", profile.Rebirths or 0)
	player:SetAttribute("EquippedHero", profile.EquippedHero or "")
	player:SetAttribute("EquippedWeapon", profile.EquippedWeapon or "")
	player:SetAttribute("WeaponInventory", self.httpService:JSONEncode(profile.Inventory or {}))
	player:SetAttribute("CollectedTotal", profile.CollectedTotal or 0)
	player:SetAttribute("EnemiesDefeated", profile.EnemiesDefeated or 0)
	player:SetAttribute("DailyReadyAt", profile.DailyReadyAt or 0)
	player:SetAttribute("ObbyReadyAt", profile.ObbyReadyAt or 0)
	player:SetAttribute("ObbyWins", profile.ObbyWins or 0)
	player:SetAttribute("ObbyBestMilliseconds", profile.ObbyBestMilliseconds or 0)
	local claims = profile.QuestClaims or {}
	player:SetAttribute("QuestCollectorDone", claims.collector == true)
	player:SetAttribute("QuestBuilderDone", claims.builder == true)
	player:SetAttribute("QuestFighterDone", claims.fighter == true)
	if state.plot then
		self:_refreshPlot(state.plot)
	end
end

function TycoonService:_rebuild(state)
	self.world.UpdatePlot(state.plot, state.profile.Floor, state.player.DisplayName)
	state.plot:SetAttribute("OwnerUserId", state.player.UserId)
	state.plot:SetAttribute("OwnerName", state.player.DisplayName)
	state.plot:SetAttribute("Floor", state.profile.Floor)
	self:_refreshPlot(state.plot)
end

function TycoonService:_applyPerks(state, character)
	-- WaitForChild имеет таймаут: удалённый персонаж не оставит вечную задачу.
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		if self.states[state.player] ~= state or state.player.Character ~= character then
			return
		end
		if self.perkHandler and state.profile and state.player:GetAttribute("DataReady") == true then
			self.perkHandler(state.player, humanoid, state.profile)
			return
		end
		local unlocked = state.profile and (state.profile.Floor >= 3 or (state.profile.Rebirths or 0) > 0)
			and state.player:GetAttribute("DataReady") == true
		humanoid.WalkSpeed = unlocked and self.config.ThirdFloorWalkSpeed or self.config.DefaultWalkSpeed
	end)
end

-- Узкий серверный API для прогрессии и боя. Балансы остаются в общем профиле.
function TycoonService:GetState(player)
	return self.states[player]
end

function TycoonService:SyncPlayer(player)
	local state = self.states[player]
	if not state or not state.profile or not state.coins or not state.level then
		return false
	end
	self:_sync(state)
	return true
end

function TycoonService:RebuildPlayer(player)
	local state = self.states[player]
	if not state or not state.profile then
		return false
	end
	if state.plot then
		self:_rebuild(state)
	end
	self:_sync(state)
	if player.Character then
		self:_applyPerks(state, player.Character)
	end
	return true
end

function TycoonService:SetPerkHandler(callback)
	assert(type(callback) == "function", "PerkHandler должен быть функцией")
	self.perkHandler = callback
	for _, state in pairs(self.states) do
		if state.profile and state.player.Character then
			self:_applyPerks(state, state.player.Character)
		end
	end
end

local function getValue(parent, name, className)
	local value = parent:FindFirstChild(name)
	if value then
		assert(value:IsA(className), name .. " должен быть " .. className)
		return value
	end
	value = Instance.new(className)
	value.Name = name
	value.Parent = parent
	return value
end

function TycoonService:_addPlayer(player)
	if self.states[player] then
		return
	end
	local state = { player = player, profile = nil, plot = nil, lastActionAt = -math.huge, leaving = false }
	self.states[player] = state
	player:SetAttribute("DataReady", false)
	player:SetAttribute("PlotId", "")
	state.characterConnection = player.CharacterAdded:Connect(function(character)
		self:_applyPerks(state, character)
	end)
	if player.Character then
		self:_applyPerks(state, player.Character)
	end
	local profile, loadError = self.profiles:Load(player)
	if player.Parent ~= self.players or state.leaving or self.states[player] ~= state or self.profiles:IsClosing() then
		self.profiles:Release(player)
		return
	end
	if not profile then
		player:SetAttribute("PersistenceStatus", "error")
		warn("Tycoon: профиль игрока " .. player.UserId .. " недоступен: " .. tostring(loadError))
		self:_notify(player, "Прогресс не удалось загрузить. Переподключитесь; покупки временно отключены.", "error")
		return
	end
	state.profile = profile
	local leaderstats = getValue(player, "leaderstats", "Folder")
	state.coins = getValue(leaderstats, "Coins", "IntValue")
	state.level = getValue(leaderstats, "Level", "IntValue")
	self:_sync(state)
	player:SetAttribute("DataReady", true)
	if player.Character then
		self:_applyPerks(state, player.Character)
	end
	local sessionOnly = player:GetAttribute("PersistenceMode") == "session"
	local text = sessionOnly and "Тестовый режим: прогресс действует до выхода. Займите свободный участок!"
		or "Прогресс загружен. Займите свободный участок!"
	self:_notify(player, text, "info")
end

function TycoonService:_removePlayer(player)
	local state = self.states[player]
	if not state then
		self.profiles:Release(player)
		return
	end
	state.leaving = true
	player:SetAttribute("DataReady", false)
	if state.characterConnection then
		state.characterConnection:Disconnect()
	end
	if state.plot then
		local plot = state.plot
		self.owners[plot] = nil
		state.plot = nil
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
		plot:SetAttribute("Floor", 0)
		self.world.UpdatePlot(plot, 0, "")
		self:_refreshPlot(plot)
	end
	self.states[player] = nil
	self.profiles:Release(player)
end

function TycoonService:_validate(player, plot, prompt, needsOwner)
	local state = self.states[player]
	if self.profiles:IsClosing() then
		return nil
	end
	if not state or not state.profile or state.leaving or player.Parent ~= self.players then
		return nil
	end
	if player:GetAttribute("DataReady") ~= true or self.profiles:Get(player) ~= state.profile then
		return nil
	end
	if not plot.Parent or not prompt.Enabled or not prompt:IsDescendantOf(plot) then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	local pad = prompt.Parent
	if not pad or not pad:IsA("BasePart") then
		return nil
	end
	-- Triggered может быть вызван эксплойтом: сервер сам измеряет расстояние.
	local distance = (root.Position - pad.Position).Magnitude
	if distance ~= distance or distance > prompt.MaxActivationDistance + 2 then
		return nil
	end
	-- Сундук нужно открывать с третьего этажа, а не с площадки под ним.
	if prompt.Name == "BonusPrompt" and math.abs(root.Position.Y - pad.Position.Y) > 7 then
		return nil
	end
	local now = os.clock()
	if now - state.lastActionAt < self.config.ActionCooldown then
		return nil
	end
	state.lastActionAt = now
	if needsOwner and (state.plot ~= plot or self.owners[plot] ~= state or plot:GetAttribute("OwnerUserId") ~= player.UserId) then
		self:_notify(player, "Это чужой дом. Займите свой свободный участок.", "error")
		return nil
	end
	return state
end

function TycoonService:_claim(player, plot, prompt)
	local state = self:_validate(player, plot, prompt, false)
	if not state then
		return
	end
	if state.plot then
		self:_notify(player, "У вас уже есть участок. Улучшайте свой дом!", "info")
		return
	end
	if self.owners[plot] or plot:GetAttribute("OwnerUserId") ~= 0 then
		return
	end
	-- Захват и обновление не содержат yield: два игрока не займут один участок.
	self.owners[plot] = state
	state.plot = plot
	player:SetAttribute("PlotId", plot:GetAttribute("PlotId") or plot.Name)
	self:_rebuild(state)
	self:_sync(state)
	local text = state.profile.Floor == 0 and ("Участок ваш! Постройте первый этаж за " .. self.config.Floors[1].Cost .. " монет на синей площадке.")
		or "Участок ваш! Сохранённый дом восстановлен."
	self:_notify(player, text, "success")
end

function TycoonService:_action(player, plot, prompt, action)
	local state = self:_validate(player, plot, prompt, true)
	if not state then
		return
	end
	local outcome
	if action == "floor" then
		outcome = Economy.BuyFloor(self.config, state.profile)
	elseif action == "dropper" then
		outcome = Economy.BuyDropper(self.config, state.profile)
	elseif action == "collect" then
		outcome = Economy.Collect(self.config, state.profile)
	elseif action == "bonus" then
		outcome = Economy.ClaimBonus(self.config, state.profile, os.time())
	else
		return
	end
	if outcome.ok then
		if action == "floor" then
			self:_rebuild(state)
			if player.Character then
				self:_applyPerks(state, player.Character)
			end
		end
		self:_sync(state)
	end
	self:_notify(player, outcome.text, outcome.kind)
end

function TycoonService:Start()
	assert(not self.started, "TycoonService уже запущен")
	self.started = true
	self.promptSets = {}
	for _, plot in ipairs(self.plots) do
		local prompts = {
			claim = findPrompt(plot, "ClaimPad", "ClaimPrompt"),
			floor = findPrompt(plot, "UpgradePad", "FloorPrompt"),
			dropper = findPrompt(plot, "DropperUpgradePad", "DropperPrompt"),
			collect = findPrompt(plot, "Collector", "CollectPrompt"),
			bonus = findPrompt(plot, "BonusPad", "BonusPrompt"),
		}
		self.promptSets[plot] = prompts
		table.insert(self.connections, prompts.claim.Triggered:Connect(function(player)
			self:_claim(player, plot, prompts.claim)
		end))
		for _, action in ipairs({ "floor", "dropper", "collect", "bonus" }) do
			local actionName = action
			local actionPrompt = prompts[actionName]
			table.insert(self.connections, actionPrompt.Triggered:Connect(function(player)
				self:_action(player, plot, actionPrompt, actionName)
			end))
		end
		self:_refreshPlot(plot)
	end
	table.insert(self.connections, self.players.PlayerAdded:Connect(function(player)
		self:_addPlayer(player)
	end))
	table.insert(self.connections, self.players.PlayerRemoving:Connect(function(player)
		self:_removePlayer(player)
	end))
	table.insert(self.connections, self.runService.Heartbeat:Connect(function(delta)
		if self.profiles:IsClosing() then
			return
		end
		self.elapsed += delta
		local ticks = math.floor(self.elapsed / self.config.IncomeInterval)
		if ticks < 1 then
			return
		end
		self.elapsed -= ticks * self.config.IncomeInterval
		for _, state in pairs(self.states) do
			if state.profile and state.plot then
				if state.player:GetAttribute("DataReady") == true then
					Economy.Accrue(self.config, state.profile, ticks)
					self:_sync(state)
				else
					self:_refreshPlot(state.plot)
				end
			end
		end
	end))
	for _, player in ipairs(self.players:GetPlayers()) do
		task.spawn(function()
			self:_addPlayer(player)
		end)
	end
end

function TycoonService:Destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	for _, state in pairs(self.states) do
		if state.characterConnection then
			state.characterConnection:Disconnect()
		end
	end
	self.started = false
end

return TycoonService

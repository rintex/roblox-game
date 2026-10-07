-- Ежедневная награда, задания, перерождения и безопасные действия общего меню.
local ProgressionService = {}
ProgressionService.__index = ProgressionService
local Economy = {}
ProgressionService.Economy = Economy

local function outcome(ok, text, kind)
	return { ok = ok, text = text, kind = kind or (ok and "success" or "error") }
end

function Economy.GetQuestProgress(config, profile, id)
	local definition
	for _, quest in ipairs(config.Quests) do
		if quest.Id == id then definition = quest; break end
	end
	if not definition then return 0, nil end
	if id == "collector" then return profile.CollectedTotal or 0, definition end
	if id == "builder" then
		return (profile.Rebirths or 0) > 0 and definition.Target or profile.Floor, definition
	end
	if id == "fighter" then return profile.EnemiesDefeated or 0, definition end
	return 0, definition
end

function Economy.ClaimQuest(config, profile, id)
	local progress, quest = Economy.GetQuestProgress(config, profile, id)
	if not quest then return outcome(false, "Такого задания нет.") end
	profile.QuestClaims = profile.QuestClaims or {}
	if profile.QuestClaims[id] == true then
		return outcome(false, "Награда за это задание уже получена.", "info")
	end
	if progress < quest.Target then
		return outcome(false, "Задание пока не выполнено: " .. math.min(progress, quest.Target) .. "/" .. quest.Target .. ".", "info")
	end
	if profile.Coins > config.MaxCoins - quest.RewardCoins then
		return outcome(false, "Потратьте монеты, чтобы в кошельке хватило места для награды.")
	end
	profile.Coins += quest.RewardCoins
	profile.XP = math.min(config.MaxXP, profile.XP + quest.RewardXP)
	profile.QuestClaims[id] = true
	return outcome(true, "Задание выполнено: +" .. quest.RewardCoins .. " монет и +" .. quest.RewardXP .. " XP!")
end

function Economy.ClaimDaily(config, profile, now)
	if now < (profile.DailyReadyAt or 0) then
		local minutes = math.max(1, math.ceil((profile.DailyReadyAt - now) / 60))
		return outcome(false, "Следующая ежедневная награда через " .. minutes .. " мин.", "info")
	end
	if profile.Coins > config.MaxCoins - config.DailyReward then
		return outcome(false, "Потратьте монеты, чтобы в кошельке хватило места для награды.")
	end
	profile.Coins += config.DailyReward
	profile.DailyReadyAt = now + config.DailyCooldown
	return outcome(true, "Ежедневная награда: +" .. config.DailyReward .. " монет!")
end

function Economy.Rebirth(config, profile)
	local count = profile.Rebirths or 0
	if count >= config.MaxRebirths then
		return outcome(false, "Достигнуто максимальное число перерождений.", "info")
	end
	if profile.Floor < #config.Floors or profile.DropperTier < #config.DropperCosts then
		return outcome(false, "Для перерождения нужны три этажа и все улучшения генератора.")
	end
	local cost = config.RebirthCost(count)
	if profile.Coins < cost then
		return outcome(false, "Для перерождения нужно " .. cost .. " монет.")
	end
	-- Это один шаг без yield: клиент не выбирает число перерождений или цену.
	profile.Rebirths = count + 1
	profile.Coins = config.StartingCoins
	profile.Floor = 0
	profile.DropperTier = 0
	profile.Bank = 0
	profile.BonusReadyAt = 0
	return outcome(true, "Перерождение " .. profile.Rebirths .. "! Дом сброшен, доход навсегда увеличен.")
end

function ProgressionService.new(config, profiles, tycoon, notice, request, worldFolder, heroCombat)
	return setmetatable({
		config = config, profiles = profiles, tycoon = tycoon, notice = notice,
		request = request, worldFolder = worldFolder, heroCombat = heroCombat,
		players = game:GetService("Players"), connections = {}, lastActions = {}, started = false,
	}, ProgressionService)
end

function ProgressionService:_notify(player, response)
	if player.Parent == self.players then self.notice:FireClient(player, response) end
end

function ProgressionService:_context(player, prompt, needsPlot)
	if self.profiles:IsClosing() or player.Parent ~= self.players or player:GetAttribute("DataReady") ~= true then return nil end
	local state = self.tycoon:GetState(player)
	local profile = self.profiles:Get(player)
	if not state or not profile or state.profile ~= profile then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
	if prompt then
		local pad = prompt.Parent
		if not prompt.Enabled or not pad or not pad:IsA("BasePart") or not pad:IsDescendantOf(workspace) then return nil end
		local distance = (root.Position - pad.Position).Magnitude
		if distance ~= distance or distance > prompt.MaxActivationDistance + 2 then return nil end
	end
	local now = os.clock()
	if now - (self.lastActions[player] or -math.huge) < 0.4 then return nil end
	self.lastActions[player] = now
	if needsPlot and (not state.plot or state.plot:GetAttribute("OwnerUserId") ~= player.UserId) then
		self:_notify(player, { kind = "error", text = "Сначала займите собственный участок." })
		return nil
	end
	return { state = state, profile = profile, root = root }
end

function ProgressionService:_perform(player, context, command, id)
	local response
	if command == "ClaimQuest" then
		response = Economy.ClaimQuest(self.config, context.profile, id)
	elseif command == "ClaimDaily" then
		response = Economy.ClaimDaily(self.config, context.profile, os.time())
	elseif command == "Rebirth" then
		response = Economy.Rebirth(self.config, context.profile)
		if response.ok then
			self.tycoon:RebuildPlayer(player)
			if self.heroCombat then
				if self.heroCombat.Refresh then self.heroCombat:Refresh(player)
				elseif self.heroCombat.RefreshPlayer then self.heroCombat:RefreshPlayer(player) end
			end
		end
	elseif command == "EquipHero" then
		if not self.heroCombat then return end
		local ok, message = self.heroCombat:Equip(player, id)
		response = outcome(ok == true, message or (ok and "Герой выбран!" or "Этот герой пока недоступен."))
	elseif command == "EquipWeapon" then
		if not self.heroCombat or not self.heroCombat.EquipWeapon then return end
		local ok, message = self.heroCombat:EquipWeapon(player, id)
		response = outcome(ok == true, message or (ok and "Оружие выбрано!" or "Такого оружия нет в инвентаре."))
	else
		return
	end
	if response.ok then self.tycoon:SyncPlayer(player) end
	self:_notify(player, response)
end

function ProgressionService:_request(player, command, id)
	-- Данные клиента лишь выбирают известное действие; цены и награды серверные.
	local commands = { EquipHero = true, EquipWeapon = true, ClaimQuest = true, ClaimDaily = true, Rebirth = true }
	if type(command) ~= "string" or not commands[command] then return end
	if (command == "EquipHero" or command == "EquipWeapon" or command == "ClaimQuest") and (type(id) ~= "string" or #id > 40) then return end
	local context = self:_context(player, nil, command == "Rebirth")
	if context then self:_perform(player, context, command, id) end
end

function ProgressionService:_claimAll(player, prompt)
	local context = self:_context(player, prompt, false)
	if not context then return end
	local completed = 0
	local eligible = 0
	for _, quest in ipairs(self.config.Quests) do
		local progress = Economy.GetQuestProgress(self.config, context.profile, quest.Id)
		if progress >= quest.Target and not (context.profile.QuestClaims or {})[quest.Id] then
			eligible += 1
			local response = Economy.ClaimQuest(self.config, context.profile, quest.Id)
			self:_notify(player, response)
			if response.ok then completed += 1 end
		end
	end
	if completed > 0 then self.tycoon:SyncPlayer(player)
	elseif eligible == 0 then self:_notify(player, { kind = "info", text = "Нет готовых наград. Собирайте монеты, стройте дом и побеждайте на арене!" }) end
end

function ProgressionService:_bindPrompt(container, partName, promptName, callback)
	local part = container:FindFirstChild(partName)
	assert(part and part:IsA("BasePart"), "Для прогрессии отсутствует " .. partName)
	local prompt = part:FindFirstChild(promptName)
	assert(prompt and prompt:IsA("ProximityPrompt"), "Для прогрессии отсутствует " .. promptName)
	table.insert(self.connections, prompt.Triggered:Connect(function(player) callback(player, prompt) end))
end

function ProgressionService:Start()
	assert(not self.started, "ProgressionService уже запущен")
	self.started = true
	table.insert(self.connections, self.request.OnServerEvent:Connect(function(player, command, id) self:_request(player, command, id) end))
	table.insert(self.connections, self.players.PlayerRemoving:Connect(function(player) self.lastActions[player] = nil end))
	self:_bindPrompt(self.worldFolder, "DailyStand", "ClaimDailyPrompt", function(player, prompt)
		local context = self:_context(player, prompt, false)
		if context then self:_perform(player, context, "ClaimDaily") end
	end)
	self:_bindPrompt(self.worldFolder, "QuestStand", "QuestPrompt", function(player, prompt) self:_claimAll(player, prompt) end)
	self:_bindPrompt(self.worldFolder, "RebirthStand", "RebirthPrompt", function(player, prompt)
		local context = self:_context(player, prompt, true)
		if context then self:_perform(player, context, "Rebirth") end
	end)
	self:_bindPrompt(self.worldFolder, "ArenaPortal", "EnterArenaPrompt", function(player, prompt)
		local context = self:_context(player, prompt, false)
		if context then
			player:SetAttribute("ArenaCombatOptIn", true)
			context.root.CFrame = CFrame.new(0, 5, -98)
			context.root.AssemblyLinearVelocity = Vector3.zero
			context.root.AssemblyAngularVelocity = Vector3.zero
			self:_notify(player, { kind = "info", text = "Арена: выберите героя и сражайтесь с бандитами и другими игроками!" })
		end
	end)
	self:_bindPrompt(self.worldFolder, "ReturnStand", "ReturnPrompt", function(player, prompt)
		local context = self:_context(player, prompt, false)
		if context then
			player:SetAttribute("ArenaCombatOptIn", false)
			context.root.CFrame = CFrame.new(0, 5, 14)
			context.root.AssemblyLinearVelocity = Vector3.zero
			context.root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
	for _, plot in ipairs(self.tycoon.plots) do
		self:_bindPrompt(plot, "HeroPad", "HeroPrompt", function(player, prompt)
			local context = self:_context(player, prompt, true)
			if context and context.state.plot == plot then
				self:_notify(player, { kind = "heroes", text = "Выберите героя и отправляйтесь на арену!" })
			end
		end)
	end
end

function ProgressionService:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	table.clear(self.lastActions)
	self.started = false
end

return ProgressionService

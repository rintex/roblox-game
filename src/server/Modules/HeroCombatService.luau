-- Сервер выдаёт костюмы/оружие и проверяет каждый выстрел. Клиент передаёт лишь точку прицеливания.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Rules = require(script.Parent:WaitForChild("CombatRules"))

local HeroCombatService = {}
HeroCombatService.__index = HeroCombatService

local BODY_COLORS = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

local function colorFor(definition)
	local rgb = definition.Color or { 80, 205, 255 }
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function part(parent, name, size, frame, color, material)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = frame
	value.Color = color
	value.Material = material or Enum.Material.Metal
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	value.Anchored = true
	value.Parent = parent
	return value
end

local function attach(parent, anchor, name, size, offset, color, material, shape)
	local value = part(parent, name, size, anchor.CFrame * offset, color, material)
	value.Anchored = false
	value.CanCollide = false
	value.CanTouch = false
	value.CanQuery = false
	value.Massless = true
	if shape then value.Shape = shape end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = value
	weld.Parent = value
	return value
end

local function liveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
	return character, humanoid, root
end

function HeroCombatService.new(config, profiles, tycoon, notice, skillRemote, effectRemote)
	return setmetatable({
		config = config, profiles = profiles, tycoon = tycoon, notice = notice,
		skillRemote = skillRemote, effectRemote = effectRemote, players = Players,
		connections = {}, playerConnections = {}, issuedTools = {}, appearances = {},
		nextAttackAt = {}, lastRequest = {}, lastEquip = {}, targets = {}, targetParts = {},
		started = false, destroyed = false,
	}, HeroCombatService)
end

function HeroCombatService:_profile(player)
	if self.destroyed or self.profiles:IsClosing() or player.Parent ~= self.players
		or player:GetAttribute("DataReady") ~= true then return nil end
	local profile = self.profiles:Get(player)
	local state = self.tycoon:GetState(player)
	if not profile or not state or state.leaving or state.profile ~= profile then return nil end
	return profile
end

function HeroCombatService:_notify(player, text, kind)
	if player.Parent == self.players then self.notice:FireClient(player, { text = text, kind = kind or "info" }) end
end

function HeroCombatService:_definition(profile)
	local weaponId = profile.EquippedWeapon or ""
	if weaponId ~= "" and Rules.OwnsWeapon(self.config, profile, weaponId) then
		return self.config.GetWeapon(weaponId), "loot:" .. weaponId
	end
	local hero = self.config.GetHero(profile.EquippedHero or "")
	if hero and self.config.CanUseHero(profile, hero) then return hero, hero.Id end
	return nil
end

function HeroCombatService:_clearAppearance(player)
	local old = self.appearances[player]
	if not old then return end
	if old.folder.Parent then old.folder:Destroy() end
	if old.colors.Parent then
		if old.created then old.colors:Destroy()
		else for name, value in pairs(old.original) do old.colors[name] = value end end
	end
	self.appearances[player] = nil
end

function HeroCombatService:_removeTool(player)
	local old = self.issuedTools[player]
	if old then old:Destroy() end
	self.issuedTools[player] = nil
end

function HeroCombatService:_costume(player, character, hero)
	self:_clearAppearance(player)
	if not hero then return end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	if not torso or not torso:IsA("BasePart") or not head or not head:IsA("BasePart") then return end
	local accent = colorFor(hero)
	local dark = Color3.fromRGB(25, 32, 48)
	local colors = character:FindFirstChildOfClass("BodyColors")
	local created = colors == nil
	if not colors then colors = Instance.new("BodyColors"); colors.Parent = character end
	local original = {}
	for _, name in ipairs(BODY_COLORS) do original[name] = colors[name]; colors[name] = dark end
	colors.HeadColor3 = accent:Lerp(dark, 0.6)
	local folder = Instance.new("Folder")
	folder.Name = "HeroArmor"
	folder.Parent = character
	self.appearances[player] = { folder = folder, colors = colors, original = original, created = created }
	local chestWidth = math.clamp(torso.Size.X * 0.85, 1, 2.2)
	local chestHeight = math.clamp(torso.Size.Y * 0.85, 0.7, 1.8)
	local front = -torso.Size.Z / 2 - 0.12
	attach(folder, torso, "ChestArmor", Vector3.new(chestWidth, chestHeight, 0.22), CFrame.new(0, 0, front), dark)
	attach(folder, torso, "EnergyCore", Vector3.new(0.46, 0.46, 0.16), CFrame.new(0, 0.06, front - 0.19) * CFrame.Angles(0, 0, math.pi / 4), accent, Enum.Material.Neon)
	attach(folder, torso, "ChestTrimLeft", Vector3.new(0.12, chestHeight * 0.8, 0.13), CFrame.new(-chestWidth * 0.38, 0, front - 0.16), accent, Enum.Material.Neon)
	attach(folder, torso, "ChestTrimRight", Vector3.new(0.12, chestHeight * 0.8, 0.13), CFrame.new(chestWidth * 0.38, 0, front - 0.16), accent, Enum.Material.Neon)
	for _, side in ipairs({ -1, 1 }) do
		attach(folder, torso, side == -1 and "LeftPauldron" or "RightPauldron", Vector3.new(0.55, 0.35, 0.75), CFrame.new(side * (torso.Size.X / 2 + 0.16), torso.Size.Y * 0.32, 0), accent, Enum.Material.Metal)
	end
	local visorZ = -head.Size.Z / 2 - 0.09
	attach(folder, head, "VisorFrame", Vector3.new(head.Size.X * 0.85, 0.32, 0.14), CFrame.new(0, 0.06, visorZ), dark)
	attach(folder, head, "EnergyVisor", Vector3.new(head.Size.X * 0.70, 0.12, 0.09), CFrame.new(0, 0.06, visorZ - 0.10), accent, Enum.Material.Neon)
	if hero.Id == "titan" then
		attach(folder, torso, "GravityPack", Vector3.new(1.25, 1.25, 0.5), CFrame.new(0, 0, torso.Size.Z / 2 + 0.3), accent)
	elseif hero.Id == "helios" then
		for _, side in ipairs({ -1, 1 }) do
			attach(folder, torso, "SolarFin" .. side, Vector3.new(0.2, 1.5, 1.0), CFrame.new(side * 0.7, 0.35, torso.Size.Z / 2 + 0.55) * CFrame.Angles(0, 0, side * -0.45), accent, Enum.Material.Neon)
		end
	elseif hero.Id == "frost" then
		attach(folder, torso, "CryoCell", Vector3.new(0.65, 0.65, 0.4), CFrame.new(0, 0.2, torso.Size.Z / 2 + 0.3) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(180, 240, 255), Enum.Material.Glass)
	elseif hero.Id == "volt" then
		attach(folder, torso, "ArcSpine", Vector3.new(0.3, 1.3, 0.3), CFrame.new(0, 0.1, torso.Size.Z / 2 + 0.3), accent, Enum.Material.Neon)
	elseif hero.Id == "nightweaver" then
		attach(folder, torso, "StealthPack", Vector3.new(1.15, 1.05, 0.3), CFrame.new(0, 0, torso.Size.Z / 2 + 0.2), dark)
	end
end

function HeroCombatService:_giveTool(player, definition, id)
	self:_removeTool(player)
	if not definition then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = Instance.new("Tool")
	tool.Name = definition.Weapon or definition.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Арена: нажмите или коснитесь для атаки"
	tool:SetAttribute("HeroWeapon", id)
	tool:SetAttribute("WeaponKind", definition.Kind)
	local accent = colorFor(definition)
	local handle = part(tool, "Handle", Vector3.new(0.35, 1.0, 0.35), CFrame.new(), Color3.fromRGB(28, 36, 54))
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	if definition.Kind == "slam" then
		attach(tool, handle, "GravityHead", Vector3.new(1.6, 0.7, 0.7), CFrame.new(0, 0.8, 0), accent)
		attach(tool, handle, "GravityCore", Vector3.new(0.4, 0.8, 0.78), CFrame.new(0, 0.8, 0), accent, Enum.Material.Neon)
	else
		attach(tool, handle, "Emitter", Vector3.new(0.6, 0.55, 1.2), CFrame.new(0, 0.45, -0.3), Color3.fromRGB(38, 48, 68))
		attach(tool, handle, "Barrel", Vector3.new(0.3, 0.3, 0.6), CFrame.new(0, 0.45, -1.05), accent, Enum.Material.Neon)
	end
	self.issuedTools[player] = tool
	tool.Parent = backpack
	local character, humanoid = liveCharacter(player)
	if character and humanoid then humanoid:EquipTool(tool) end
end

function HeroCombatService:ApplyPerks(player, humanoid, profile)
	local speed = (profile.Floor >= 3 or (profile.Rebirths or 0) > 0) and self.config.ThirdFloorWalkSpeed or self.config.DefaultWalkSpeed
	local hero = self.config.GetHero(profile.EquippedHero or "")
	if hero and self.config.CanUseHero(profile, hero) then speed = math.max(speed, hero.WalkSpeed or speed) end
	humanoid.WalkSpeed = speed
end

function HeroCombatService:Refresh(player)
	local profile = self:_profile(player)
	if not profile then self:_removeTool(player); self:_clearAppearance(player); return end
	local hero = self.config.GetHero(profile.EquippedHero or "")
	if not hero or not self.config.CanUseHero(profile, hero) then hero = nil end
	local character, humanoid = liveCharacter(player)
	if character then self:_costume(player, character, hero); self:ApplyPerks(player, humanoid, profile) end
	local definition, id = self:_definition(profile)
	self:_giveTool(player, definition, id)
end

HeroCombatService.RefreshPlayer = HeroCombatService.Refresh

function HeroCombatService:_equipReady(player)
	local profile = self:_profile(player)
	if not profile then return nil, "Дождитесь загрузки прогресса." end
	local now = os.clock()
	if not Rules.CooldownReady(now, self.lastEquip[player] or -math.huge, 0.3) then return nil, "Подождите перед сменой снаряжения." end
	self.lastEquip[player] = now
	return profile
end

function HeroCombatService:Equip(player, id)
	if type(id) ~= "string" or #id > 48 then return false, "Неизвестный герой." end
	local profile, reason = self:_equipReady(player)
	if not profile then return false, reason end
	local hero = id ~= "" and self.config.GetHero(id) or nil
	if id ~= "" and (not hero or not self.config.CanUseHero(profile, hero)) then return false, "Этот герой ещё не открыт. Стройте этажи и делайте перерождения." end
	profile.EquippedHero = id
	profile.EquippedWeapon = ""
	self.tycoon:SyncPlayer(player)
	self:Refresh(player)
	return true, hero and ("Герой «" .. hero.Name .. "» выбран. Оружие готово!") or "Костюм снят."
end

function HeroCombatService:EquipWeapon(player, id)
	if type(id) ~= "string" or #id > 48 then return false, "Неизвестное оружие." end
	local profile, reason = self:_equipReady(player)
	if not profile then return false, reason end
	if id ~= "" and not Rules.OwnsWeapon(self.config, profile, id) then return false, "Сначала получите это оружие из бесплатного контейнера." end
	profile.EquippedWeapon = id
	self.tycoon:SyncPlayer(player)
	self:Refresh(player)
	local definition = self.config.GetWeapon(id)
	return true, definition and ("Оружие «" .. definition.Name .. "» экипировано!") or "Выбрано оружие героя."
end

function HeroCombatService:_targetLabel(record)
	record.model:SetAttribute("Health", record.health)
	record.model:SetAttribute("Alive", not record.dead)
	record.label.Text = record.name .. "\n" .. math.ceil(record.health) .. " / " .. record.maxHealth
	for _, object in ipairs(record.model:GetChildren()) do
		if object:IsA("BasePart") then
			object.Transparency = record.dead and 0.8 or 0
			object.CanQuery = not record.dead
			object.CanCollide = not record.dead
		end
	end
end

function HeroCombatService:_buildTargets()
	-- Управляем только папкой, созданной этим модулем.
	local folder = Workspace:FindFirstChild("TrainingEnemies")
	if folder then
		assert(folder:IsA("Folder") and folder:GetAttribute("HeroCombatManaged") == true, "TrainingEnemies уже используется другим объектом")
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "TrainingEnemies"
	folder:SetAttribute("HeroCombatManaged", true)
	folder.Parent = Workspace
	self.targetFolder = folder
	local positions = {
		Vector3.new(-30, 0, -100), Vector3.new(30, 0, -100),
		Vector3.new(-30, 0, -120), Vector3.new(30, 0, -120),
		Vector3.new(-30, 0, -140), Vector3.new(30, 0, -140), Vector3.new(0, 0, -140),
	}
	for index, position in ipairs(positions) do
		local boss = index == #positions
		local model = Instance.new("Model")
		model.Name = boss and "ArenaSentinel" or "TrainingBot" .. index
		model.Parent = folder
		local accent = boss and Color3.fromRGB(255, 130, 80) or Color3.fromRGB(80, 195, 235)
		local scale = boss and 1.45 or 1
		local chest = part(model, "Core", Vector3.new(3, 3, 2) * scale, CFrame.new(position + Vector3.new(0, 3.7 * scale, 0)), Color3.fromRGB(54, 64, 83))
		part(model, "Head", Vector3.new(2, 1.6, 1.7) * scale, CFrame.new(position + Vector3.new(0, 6 * scale, 0)), accent)
		part(model, "EnergyCell", Vector3.new(1.1, 1.1, 0.15) * scale, CFrame.new(position + Vector3.new(0, 3.9 * scale, -1.1 * scale)) * CFrame.Angles(0, 0, math.pi / 4), accent, Enum.Material.Neon)
		for _, side in ipairs({ -1, 1 }) do
			part(model, "Arm" .. side, Vector3.new(0.8, 2.8, 1) * scale, CFrame.new(position + Vector3.new(side * 2 * scale, 3.6 * scale, 0)), accent)
			part(model, "Leg" .. side, Vector3.new(0.9, 2.2, 1) * scale, CFrame.new(position + Vector3.new(side * 0.8 * scale, 1.1 * scale, 0)), Color3.fromRGB(54, 64, 83))
		end
		model.PrimaryPart = chest
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "HealthDisplay"
		billboard.Size = UDim2.fromOffset(190, 54)
		billboard.StudsOffset = Vector3.new(0, 4.3 * scale, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 130
		billboard.Parent = chest
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.25
		label.BackgroundColor3 = Color3.fromRGB(18, 27, 43)
		label.TextColor3 = accent
		label.TextStrokeTransparency = 0.6
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.Parent = billboard
		local record = {
			model = model, center = chest, label = label, name = boss and "СТРАЖ АРЕНЫ" or "Тренировочный дрон",
			health = boss and 400 or 80, maxHealth = boss and 400 or 80,
			coins = boss and 500 or 60, xp = boss and 200 or 40, respawn = boss and 30 or 8, dead = false,
		}
		self.targets[model] = record
		for _, object in ipairs(model:GetChildren()) do if object:IsA("BasePart") then self.targetParts[object] = record end end
		self:_targetLabel(record)
	end
end

function HeroCombatService:_effect(kind, from, to, definition, id)
	self.effectRemote:FireAllClients({ kind = kind, from = from, to = to, color = colorFor(definition), hero = id })
end

function HeroCombatService:_damageTarget(player, profile, record, damage, origin, range)
	if not record or self.targets[record.model] ~= record or not record.model.Parent
		or not record.model:IsDescendantOf(self.targetFolder) or record.dead
		or (record.center.Position - origin).Magnitude > range + 4 then return false end
	-- Урон, флаг смерти и награда идут без yield: один дрон не выдаст награду дважды.
	local amount, killed = Rules.ApplyDamage(record, damage)
	if amount <= 0 then return false end
	self:_targetLabel(record)
	if killed then
		local coins, xp = Rules.Reward(self.config, profile, record.coins, record.xp)
		self.tycoon:SyncPlayer(player)
		self:_notify(player, record.name .. ": +" .. coins .. " монет, +" .. xp .. " XP!", "success")
		task.delay(record.respawn, function()
			if self.destroyed or self.targets[record.model] ~= record or not record.model.Parent then return end
			record.health = record.maxHealth
			record.dead = false
			self:_targetLabel(record)
		end)
	end
	return true
end

function HeroCombatService:_combatant(player)
	local profile = self:_profile(player)
	local character, humanoid, root = liveCharacter(player)
	return { id = player.UserId, ready = profile ~= nil, optedIn = player:GetAttribute("ArenaCombatOptIn") == true,
		alive = humanoid ~= nil, protected = character and character:FindFirstChildOfClass("ForceField") ~= nil,
		position = root and root.Position }, humanoid, root
end

function HeroCombatService:_damagePlayer(attacker, target, amount, origin, range)
	local attackerData = self:_combatant(attacker)
	local targetData, humanoid, root = self:_combatant(target)
	if not Rules.PvPAllowed(attackerData, targetData) or not root
		or (root.Position - origin).Magnitude > range + 3 then return false end
	-- Никаких наград за убийство игроков: нельзя фармить валюту вторым аккаунтом.
	humanoid:TakeDamage(amount)
	return true
end

function HeroCombatService:_hitPlayer(partHit)
	local node = partHit
	while node and node ~= Workspace do
		if node:IsA("Model") then
			local player = self.players:GetPlayerFromCharacter(node)
			if player then return player end
		end
		node = node.Parent
	end
	return nil
end

function HeroCombatService:_attack(player, aim)
	local now = os.clock()
	-- Недорогой ограничитель отклоняет спам до Raycast и обхода игроков.
	if not Rules.CooldownReady(now, self.lastRequest[player] or -math.huge, 0.08) then return end
	self.lastRequest[player] = now
	local profile = self:_profile(player)
	if not profile then return end
	local definition, id = self:_definition(profile)
	local character, _, root = liveCharacter(player)
	local issued = self.issuedTools[player]
	if not definition or not character or not issued or issued.Parent ~= character
		or issued:GetAttribute("HeroWeapon") ~= id or not Rules.InArena(root.Position) then return end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local direction = Rules.CastDirection(origin, aim, definition.Range)
	if not direction or now < (self.nextAttackAt[player] or -math.huge) then return end
	-- Смена оружия не сбрасывает общий cooldown игрока.
	self.nextAttackAt[player] = now + definition.Cooldown
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { character }
	parameters.IgnoreWater = true
	if definition.Kind == "slam" then
		self:_effect("slam", root.Position, root.Position, definition, id)
		for _, record in pairs(self.targets) do
			local offset = record.center.Position - origin
			if not record.dead and offset.Magnitude <= definition.Range then
				local hit = Workspace:Raycast(origin, offset, parameters)
				if hit and self.targetParts[hit.Instance] == record then
					self:_damageTarget(player, profile, record, definition.Damage, origin, definition.Range)
				end
			end
		end
		for _, target in ipairs(self.players:GetPlayers()) do
			if target ~= player then
				local _, _, targetRoot = liveCharacter(target)
				if targetRoot then
					local offset = targetRoot.Position - origin
					if offset.Magnitude <= definition.Range then
						local hit = Workspace:Raycast(origin, offset, parameters)
						if hit and hit.Instance:IsDescendantOf(target.Character) then self:_damagePlayer(player, target, definition.Damage, origin, definition.Range) end
					end
				end
			end
		end
	else
		local hit = Workspace:Raycast(origin, direction, parameters)
		local endpoint = hit and hit.Position or origin + direction
		self:_effect("beam", origin, endpoint, definition, id)
		if hit then
			local record = self.targetParts[hit.Instance]
			if record then
				self:_damageTarget(player, profile, record, definition.Damage, origin, definition.Range)
			else
				local target = self:_hitPlayer(hit.Instance)
				if target then self:_damagePlayer(player, target, definition.Damage, origin, definition.Range) end
			end
		end
	end
end

function HeroCombatService:_watchPlayer(player)
	if self.playerConnections[player] then return end
	local connections = {}
	self.playerConnections[player] = connections
	local function characterReady(character)
		player:SetAttribute("ArenaCombatOptIn", false)
		self:_removeTool(player)
		self:_clearAppearance(player)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
			if humanoid and root and backpack and self.playerConnections[player] == connections and player.Character == character then self:Refresh(player) end
		end)
	end
	table.insert(connections, player.CharacterAdded:Connect(characterReady))
	table.insert(connections, player.CharacterAppearanceLoaded:Connect(function(character)
		if player.Character == character then self:Refresh(player) end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("DataReady"):Connect(function() self:Refresh(player) end))
	if player.Character then characterReady(player.Character) end
end

function HeroCombatService:_removePlayer(player)
	local connections = self.playerConnections[player]
	if connections then for _, connection in ipairs(connections) do connection:Disconnect() end end
	self.playerConnections[player] = nil
	self:_removeTool(player)
	self:_clearAppearance(player)
	self.nextAttackAt[player] = nil
	self.lastRequest[player] = nil
	self.lastEquip[player] = nil
end

function HeroCombatService:Start()
	assert(not self.started, "HeroCombatService уже запущен")
	self.started = true
	self:_buildTargets()
	if self.tycoon.SetPerkHandler then
		self.tycoon:SetPerkHandler(function(player, humanoid, profile) self:ApplyPerks(player, humanoid, profile) end)
	end
	table.insert(self.connections, self.skillRemote.OnServerEvent:Connect(function(player, aim) self:_attack(player, aim) end))
	table.insert(self.connections, self.players.PlayerAdded:Connect(function(player) self:_watchPlayer(player) end))
	table.insert(self.connections, self.players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	for _, player in ipairs(self.players:GetPlayers()) do self:_watchPlayer(player) end
end

function HeroCombatService:Destroy()
	self.destroyed = true
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	for player in pairs(self.playerConnections) do self:_removePlayer(player) end
	if self.targetFolder and self.targetFolder.Parent then self.targetFolder:Destroy() end
	table.clear(self.connections)
	table.clear(self.targets)
	table.clear(self.targetParts)
end

return HeroCombatService

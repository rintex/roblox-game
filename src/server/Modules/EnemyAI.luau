-- Движение и ближние атаки NPC выполняет сервер. Арена открытая, без лабиринтов.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Rules = require(script.Parent:WaitForChild("CombatRules"))
local AI = {}
AI.__index = AI

function AI.new(combat)
	return setmetatable({combat = combat, elapsed = 0, time = 0}, AI)
end

function AI:_target(player)
	local data, humanoid, root = self.combat:_combatant(player)
	if data.ready and data.alive and data.optedIn and not data.protected and Rules.InArena(data.position)
		and player:GetAttribute("ObbyActive") ~= true then return humanoid, root end
	return nil
end

function AI:_visible(record, player, root)
	local origin = record.center.Position
	local delta = root.Position - origin
	if delta.Magnitude < 0.1 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {record.model}
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, delta, params)
	return hit == nil or hit.Instance:IsDescendantOf(player.Character)
end

function AI:_move(record, destination, seconds)
	local current = record.center.Position
	local delta = Vector3.new(destination.X - current.X, 0, destination.Z - current.Z)
	if delta.Magnitude < 0.05 then return end
	local direction = delta.Unit
	local nextPosition = current + direction * math.min(delta.Magnitude, record.ai.Speed * seconds)
	nextPosition = Vector3.new(math.clamp(nextPosition.X, -44, 44), record.home.Y, math.clamp(nextPosition.Z, -153, -87))
	-- NPC используют серверные anchored-части: клиент не может владеть их физикой.
	record.model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + direction) * CFrame.Angles(0, math.pi, 0))
	self:_animate(record, true)
end

function AI:_animate(record, walking)
	local swing = if walking then math.sin(self.time * 9) * 0.45 else 0
	for _, limb in ipairs(record.limbs) do
		local angle = swing * limb.side * (if limb.arm then -1 else 1)
		if record.pending and limb.arm then angle = -1.15 end
		limb.part.CFrame = record.center.CFrame * limb.rest * CFrame.Angles(angle, 0, 0)
	end
end

function AI:_warning(record, visible)
	local warning = record.warning
	if warning then
		warning.Transparency = if visible then 0.35 else 1
		warning.CanQuery = false
	end
	record.model:SetAttribute("Attacking", visible)
end

function AI:Reset(record)
	record.pending = nil
	record.nextAttack = self.time + 1
	self:_warning(record, false)
	record.model:PivotTo(CFrame.new(record.home))
	self:_animate(record, false)
end

function AI:_step(record, seconds)
	if record.dead or not record.model.Parent then
		record.pending = nil
		self:_warning(record, false)
		return
	end
	if record.pending then
		self:_animate(record, false)
		if self.time < record.pending.at then return end
		local player = record.pending.player
		record.pending = nil
		self:_warning(record, false)
		local humanoid, root = self:_target(player)
		if humanoid and (root.Position - record.center.Position).Magnitude <= record.ai.AttackRange
			and self:_visible(record, player, root) then
			humanoid:TakeDamage(record.ai.Damage)
			self.combat:_effect("slam", root.Position, root.Position, {Color = {255, 90, 78}}, "bandit")
		end
		return
	end
	local nearest, nearestRoot, nearestDistance
	for _, player in ipairs(self.combat.players:GetPlayers()) do
		local humanoid, root = self:_target(player)
		if humanoid then
			local distance = (root.Position - record.center.Position).Magnitude
			if distance <= record.ai.AggroRange and (not nearestDistance or distance < nearestDistance) then
				nearest, nearestRoot, nearestDistance = player, root, distance
			end
		end
	end
	if not nearest then
		record.model:SetAttribute("State", "Патруль")
		self:_move(record, record.home, seconds)
		if (record.center.Position - record.home).Magnitude < 0.1 then self:_animate(record, false) end
		return
	end
	if nearestDistance <= record.ai.AttackRange then
		self:_animate(record, false)
		if self.time >= (record.nextAttack or 0) and self:_visible(record, nearest, nearestRoot) then
			record.nextAttack = self.time + record.ai.Windup + record.ai.Cooldown
			record.pending = {player = nearest, at = self.time + record.ai.Windup}
			record.model:SetAttribute("State", "Замах — отойди!")
			self:_warning(record, true)
			self:_animate(record, false)
		end
	else
		record.model:SetAttribute("State", "Преследует")
		self:_move(record, nearestRoot.Position, seconds)
	end
end

function AI:Step(seconds)
	if self.combat.destroyed or self.combat.profiles:IsClosing() then return end
	self.time += seconds
	for _, record in pairs(self.combat.targets) do self:_step(record, seconds) end
end

function AI:Start()
	assert(not self.connection, "EnemyAI уже запущен")
	self.connection = RunService.Heartbeat:Connect(function(seconds)
		self.elapsed += seconds
		if self.elapsed < 0.1 then return end
		local delta = math.min(self.elapsed, 0.25)
		self.elapsed = 0
		self:Step(delta)
	end)
end

function AI:Destroy()
	if self.connection then self.connection:Disconnect(); self.connection = nil end
end

return AI

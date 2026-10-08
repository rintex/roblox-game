-- Серверная AI для открытой арены: преследование, разделение NPC и атаки с окнами уклонения.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Rules = require(script.Parent:WaitForChild("CombatRules"))
local AI = {}
AI.__index = AI

function AI.new(combat)
	return setmetatable({combat = combat, elapsed = 0, time = 0}, AI)
end

function AI:_state(record, text)
	if record.model:GetAttribute("State") ~= text then record.model:SetAttribute("State", text) end
	if record.stateLabel and record.stateLabel.Text ~= text then record.stateLabel.Text = text end
end

function AI:_target(player)
	local data, humanoid, root = self.combat:_combatant(player)
	if data.ready and data.alive and data.optedIn and not data.protected and Rules.InArena(data.position)
		and player:GetAttribute("ObbyActive") ~= true then return humanoid, root end
	return nil
end

function AI:_visible(record, player, root, from)
	local origin = from or record.center.Position
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
	if delta.Magnitude < 0.05 then self:_animate(record, false); return end
	local direction = delta.Unit
	-- Небольшое разделение не даёт бандитам собраться в одну пересекающуюся модель.
	local separation = Vector3.new(0, 0, 0)
	for _, other in pairs(self.combat.targets) do
		if other ~= record and not other.dead then
			local apart = Vector3.new(current.X - other.center.Position.X, 0, current.Z - other.center.Position.Z)
			if apart.Magnitude > 0.05 and apart.Magnitude < 5 then separation += apart.Unit * (1 - apart.Magnitude / 5) end
		end
	end
	local steering = direction + separation * 0.8
	if steering.Magnitude > 0.05 then direction = steering.Unit end
	local phase = if record.boss then Rules.BossPhase(record.health, record.maxHealth) else 1
	local speed = record.ai.Speed * (1 + (phase - 1) * 0.1)
	if self.time < (record.slowUntil or 0) then speed *= record.slowFactor or 0.55 end
	local nextPosition = current + direction * math.min(delta.Magnitude, speed * math.min(seconds, 1))
	nextPosition = Vector3.new(math.clamp(nextPosition.X, -44, 44), record.home.Y, math.clamp(nextPosition.Z, -153, -87))
	local travel = nextPosition - current
	if travel.Magnitude > 0.05 then
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = {self.combat.targetFolder}
		parameters.IgnoreWater = true
		parameters.RespectCanCollide = true
		local obstacle = Workspace:Raycast(current, travel, parameters)
		if obstacle and obstacle.Instance.CanCollide == true then self:_animate(record, false); return end
	end
	-- Anchored-части никогда не передаются под сетевое управление клиента.
	record.model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + direction) * CFrame.Angles(0, math.pi, 0))
	self:_animate(record, true)
end

function AI:_animate(record, walking)
	local pose = if walking then "walk" elseif record.pending then "windup" else "idle"
	if pose ~= "walk" and record.pose == pose and record.poseFrame == record.center.CFrame then return end
	record.pose, record.poseFrame = pose, record.center.CFrame
	local swing = if walking then math.sin(self.time * 9) * 0.35 else 0
	for _, limb in ipairs(record.limbs) do
		local angle = swing * limb.side * (if limb.arm then -1 else 1)
		if record.pending and limb.arm then angle = -1.1 end
		local rest = limb.rest.Position
		local pivot = Vector3.new(rest.X, if limb.arm then record.center.Size.Y * 0.4 else -record.center.Size.Y * 0.4, rest.Z)
		limb.part.CFrame = record.center.CFrame * CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(rest - pivot)
	end
end

function AI:_warning(record, visible, pending)
	local warning = record.warning
	if warning then
		local transparency = if visible then 0.35 else 1
		if warning.Transparency ~= transparency then warning.Transparency = transparency end
		warning.CanQuery = false
		if visible and pending then
			local floorFrom = Vector3.new(pending.from.X, 0.3, pending.from.Z)
			if pending.kind == "rush" then
				local floorTo = Vector3.new(pending.to.X, 0.3, pending.to.Z)
				warning.Shape = Enum.PartType.Block
				warning.Size = Vector3.new(pending.radius * 2, 0.05, (floorTo - floorFrom).Magnitude + pending.radius * 2)
				warning.CFrame = CFrame.lookAt((floorFrom + floorTo) * 0.5, floorTo)
			else
				warning.Shape = Enum.PartType.Cylinder
				warning.Size = Vector3.new(0.05, pending.radius * 2, pending.radius * 2)
				warning.CFrame = CFrame.new(floorFrom) * CFrame.Angles(0, 0, math.pi / 2)
			end
		end
	end
	record.model:SetAttribute("Attacking", visible)
end

function AI:Reset(record)
	record.pending = nil
	record.nextAttack = self.time + 1
	record.slowUntil = 0
	record.staggerUntil = 0
	record.attackCycle = 0
	self:_state(record, "Патруль")
	self:_warning(record, false)
	record.model:PivotTo(CFrame.new(record.home))
	self:_animate(record, false)
end

function AI:_damage(record, player, humanoid, root, amount)
	local applied = math.min(humanoid.Health, amount)
	if applied <= 0 then return end
	humanoid:TakeDamage(applied)
	self.combat:_hurt(player, applied, record.center.Position)
end

function AI:_finish(record, pending)
	self:_warning(record, false)
	if pending.kind == "melee" then
		local humanoid, root = self:_target(pending.player)
		if humanoid and (root.Position - pending.from).Magnitude <= pending.radius
			and self:_visible(record, pending.player, root, pending.from) then
			self:_damage(record, pending.player, humanoid, root, record.ai.Damage)
		end
		return
	end
	self.combat:_effect("boss_impact", pending.from, pending.to, {Color = {255, 100, 74}}, "bandit", {
		radius = pending.radius, duration = 0.4, style = pending.kind,
	})
	for _, player in ipairs(self.combat.players:GetPlayers()) do
		local humanoid, root = self:_target(player)
		if humanoid then
			local inside = if pending.kind == "rush" then Rules.SegmentDistance(root.Position, pending.from, pending.to) <= pending.radius
				else Rules.SegmentDistance(root.Position, pending.from, pending.from) <= pending.radius
			if inside and math.abs(root.Position.Y - pending.from.Y) <= 6
				and self:_visible(record, player, root, pending.from) then
				self:_damage(record, player, humanoid, root, math.floor(record.ai.Damage * (if pending.kind == "rush" then 0.9 else 1)))
			end
		end
	end
	if pending.kind == "rush" then
		local direction = pending.to - pending.from
		if direction.Magnitude > 0.05 then record.model:PivotTo(CFrame.lookAt(pending.to, pending.to + direction) * CFrame.Angles(0, math.pi, 0)) end
	end
end

function AI:_begin(record, player, root, phase)
	record.attackCycle = (record.attackCycle or 0) + 1
	local kind = "melee"
	if record.boss and phase >= 2 then
		if phase == 3 and record.attackCycle % 3 == 0 then kind = "rush"
		elseif record.attackCycle % 2 == 0 then kind = "shockwave" end
	end
	local windup = if kind == "shockwave" then 1.2 elseif kind == "rush" then 1.15 else record.ai.Windup
	local radius = if kind == "shockwave" then 10 elseif kind == "rush" then 3.5 else record.ai.AttackRange
	local from = record.center.Position
	local facing = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	if facing.Magnitude > 0.05 then record.model:PivotTo(CFrame.lookAt(from, from + facing) * CFrame.Angles(0, math.pi, 0)) end
	local destination = from
	if kind == "rush" then
		local delta = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
		if delta.Magnitude > 0.1 then
			local travel = from + delta.Unit * math.min(delta.Magnitude + 4, 26)
			destination = Vector3.new(math.clamp(travel.X, -44, 44), record.home.Y, math.clamp(travel.Z, -153, -87))
			local parameters = RaycastParams.new()
			parameters.FilterType = Enum.RaycastFilterType.Exclude
			local excluded = {self.combat.targetFolder}
			for _, candidate in ipairs(self.combat.players:GetPlayers()) do if candidate.Character then table.insert(excluded, candidate.Character) end end
			parameters.FilterDescendantsInstances = excluded
			parameters.IgnoreWater = true
			parameters.RespectCanCollide = true
			local path = destination - from
			local obstacle = Workspace:Raycast(from, path, parameters)
			if obstacle and obstacle.Instance.CanCollide == true then
				local allowed = math.max(0, (obstacle.Position - from).Magnitude - 2)
				destination = from + path.Unit * math.min(path.Magnitude, allowed)
			end
		end
		if (destination - from).Magnitude < 1 then kind, radius, windup = "shockwave", 10, 1.2; destination = from end
	end
	record.pending = {player = player, at = self.time + windup, kind = kind, radius = radius, from = from, to = destination}
	record.nextAttack = self.time + windup + record.ai.Cooldown
	self:_state(record, if kind == "rush" then "РЫВОК — уйди в сторону!" elseif kind == "shockwave" then "ВОЛНА — выйди из круга!" else "Замах — отойди!")
	self:_warning(record, true, record.pending)
	self:_animate(record, false)
	if kind ~= "melee" then
		self.combat:_effect("boss_warning", from, destination, {Color = {255, 108, 80}}, "bandit", {
			radius = radius, duration = windup, style = kind,
		})
	end
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
		local pending = record.pending
		record.pending = nil
		self:_finish(record, pending)
		return
	end
	if self.time < (record.staggerUntil or 0) then self:_animate(record, false); return end
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
		self:_state(record, "Патруль")
		self:_move(record, record.home, seconds)
		return
	end
	local phase = if record.boss then Rules.BossPhase(record.health, record.maxHealth) else 1
	if nearestDistance <= record.ai.AttackRange then
		self:_animate(record, false)
		if self.time >= (record.nextAttack or 0) and self:_visible(record, nearest, nearestRoot) then self:_begin(record, nearest, nearestRoot, phase) end
	else
		self:_state(record, "Преследует")
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

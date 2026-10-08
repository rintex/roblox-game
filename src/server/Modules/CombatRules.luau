-- Чистые проверки боя: их выполняет сервер и автоматические тесты.
local Rules = {}

function Rules.IsFinite(value, limit)
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
		and (limit == nil or math.abs(value) <= limit)
end

function Rules.IsVector(value)
	return typeof(value) == "Vector3" and Rules.IsFinite(value.X, 100000)
		and Rules.IsFinite(value.Y, 100000) and Rules.IsFinite(value.Z, 100000)
end

function Rules.CastDirection(origin, aim, range)
	if not Rules.IsVector(origin) or not Rules.IsVector(aim) or not Rules.IsFinite(range, 1000) or range <= 0 then
		return nil
	end
	local delta = aim - origin
	if not Rules.IsFinite(delta.Magnitude, 10000) or delta.Magnitude < 0.05 then return nil end
	-- Клиент задаёт только направление; длину луча устанавливает сервер.
	return delta.Unit * range
end

function Rules.CooldownReady(now, last, cooldown)
	return Rules.IsFinite(now) and type(last) == "number" and Rules.IsFinite(cooldown, 60)
		and cooldown >= 0 and now - last >= cooldown
end

function Rules.InArena(position)
	return Rules.IsVector(position) and math.abs(position.X) <= 48
		and position.Z >= -158 and position.Z <= -82 and position.Y >= -2 and position.Y <= 30
end

-- Геометрия телеграфированного рывка: X/Z фиксированы при замахе.
-- Игрок может уйти в сторону; клиент не передаёт список попавших целей.
function Rules.SegmentDistance(position, from, to)
	if not Rules.IsVector(position) or not Rules.IsVector(from) or not Rules.IsVector(to) then return math.huge end
	local dx, dz = to.X - from.X, to.Z - from.Z
	local lengthSquared = dx * dx + dz * dz
	local alpha = if lengthSquared > 0.0001 then math.clamp(((position.X - from.X) * dx + (position.Z - from.Z) * dz) / lengthSquared, 0, 1) else 0
	local x, z = from.X + dx * alpha, from.Z + dz * alpha
	return math.sqrt((position.X - x) ^ 2 + (position.Z - z) ^ 2)
end

function Rules.BossPhase(health, maximum)
	if not Rules.IsFinite(health) or not Rules.IsFinite(maximum) or maximum <= 0 then return 1 end
	if health / maximum <= 0.30 then return 3 end
	if health / maximum <= 0.65 then return 2 end
	return 1
end

function Rules.PvPAllowed(attacker, target)
	return attacker ~= nil and target ~= nil and attacker.id ~= target.id
		and attacker.ready == true and target.ready == true
		and attacker.optedIn == true and target.optedIn == true
		and attacker.alive == true and target.alive == true
		and attacker.protected ~= true and target.protected ~= true
		and Rules.InArena(attacker.position) and Rules.InArena(target.position)
end

function Rules.OwnsWeapon(config, profile, id)
	if type(id) ~= "string" or #id > 48 or type(profile.Inventory) ~= "table" then return false end
	local count = profile.Inventory[id]
	return config.GetWeapon(id) ~= nil and Rules.IsFinite(count, config.MaxWeaponCopies or 99) and count >= 1 and count % 1 == 0
end

function Rules.ApplyDamage(target, amount)
	if target.dead or not Rules.IsFinite(target.health) or target.health <= 0
		or not Rules.IsFinite(amount, 10000) or amount <= 0 then return 0, false end
	local applied = math.min(target.health, amount)
	target.health -= applied
	local killed = target.health <= 0
	if killed then target.dead = true end
	return applied, killed
end

function Rules.Reward(config, profile, coins, xp)
	local earnedCoins = math.max(0, math.min(coins, config.MaxCoins - profile.Coins))
	local earnedXP = math.max(0, math.min(xp, config.MaxXP - profile.XP))
	profile.Coins += earnedCoins
	profile.XP += earnedXP
	profile.EnemiesDefeated = math.min(config.MaxEnemiesDefeated or 1000000000, (profile.EnemiesDefeated or 0) + 1)
	return earnedCoins, earnedXP
end

return Rules

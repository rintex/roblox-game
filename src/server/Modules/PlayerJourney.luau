-- Чистые серверные правила обучения и достижений. Клиент не отмечает цели выполненными.
local Journey = {}

function Journey.GetProgress(config, profile, field)
	if field == "Floor" then return (profile.Rebirths or 0) > 0 and #config.Floors or profile.Floor end
	if field == "WeaponTypes" then
		local total = 0
		for _, weapon in ipairs(config.Weapons) do
			local copies = (profile.Inventory or {})[weapon.Id]
			if type(copies) == "number" and copies > 0 and copies < math.huge then total += 1 end
		end
		return total
	end
	local allowed = {CollectedTotal = true, EnemiesDefeated = true, BossDefeated = true, ObbyWins = true, Rebirths = true}
	return allowed[field] and (profile[field] or 0) or 0
end

local function completed(config, profile, ownsPlot, target)
	if target == "plot" then return ownsPlot end
	if target == "floor" then return ownsPlot and profile.Floor >= 1 end
	if target == "collect" then return (profile.CollectedTotal or 0) > 0 end
	if target == "generator" then return profile.DropperTier >= 1 or (profile.Rebirths or 0) > 0 end
	if target == "hero" then return config.CanUseHero(profile, config.GetHero(profile.EquippedHero)) end
	if target == "combat" then return profile.CombatPractice == true end
	return false
end

function Journey.Advance(config, profile, ownsPlot)
	local events = {}
	local step = profile.TutorialStep or 1
	while step <= #config.TutorialSteps do
		local definition = config.TutorialSteps[step]
		if not completed(config, profile, ownsPlot, definition.Target) then break end
		if profile.Coins > config.MaxCoins - definition.Coins then break end
		profile.Coins += definition.Coins
		profile.XP = math.min(config.MaxXP, profile.XP + definition.XP)
		step += 1
		profile.TutorialStep = step
		table.insert(events, {kind = "success", text = definition.Title .. ": выполнено! +" .. definition.Coins .. " монет, +" .. definition.XP .. " XP."})
	end
	profile.TutorialStep = step
	return events
end

function Journey.ClaimAchievement(config, profile, id)
	local definition = config.GetAchievement(id)
	if not definition then return {ok = false, kind = "error", text = "Такого достижения нет."} end
	profile.AchievementClaims = profile.AchievementClaims or {}
	if profile.AchievementClaims[id] then return {ok = false, kind = "info", text = "Награда уже получена."} end
	if Journey.GetProgress(config, profile, definition.Field) < definition.Target then
		return {ok = false, kind = "info", text = "Условие достижения ещё не выполнено."}
	end
	if profile.Coins > config.MaxCoins - definition.RewardCoins then return {ok = false, kind = "error", text = "Потрать монеты, чтобы освободить место для награды."} end
	-- Изменение профиля атомарно: повторный запрос не выдаст награду второй раз.
	profile.Coins += definition.RewardCoins
	profile.XP = math.min(config.MaxXP, profile.XP + definition.RewardXP)
	profile.AchievementClaims[id] = true
	if definition.TitleReward and (profile.EquippedTitle or "") == "" then profile.EquippedTitle = id end
	return {ok = true, kind = "success", text = "Достижение «" .. definition.Title .. "»: +" .. definition.RewardCoins .. " монет!"}
end

function Journey.EquipTitle(config, profile, id)
	if id == "" then profile.EquippedTitle = ""; return {ok = true, kind = "info", text = "Титул скрыт."} end
	local definition = config.GetAchievement(id)
	if not definition or not definition.TitleReward or not (profile.AchievementClaims or {})[id] then
		return {ok = false, kind = "error", text = "Сначала получи награду за это достижение."}
	end
	profile.EquippedTitle = id
	return {ok = true, kind = "success", text = "Титул «" .. definition.TitleReward .. "» выбран."}
end

return Journey

-- Проверка сохранённого профиля. Уровень вычисляется из XP, а не хранится отдельно.
local Schema = {}

local function boundedInteger(value, default, maximum)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return default
	end
	return math.clamp(math.floor(value), 0, maximum)
end

function Schema.New(config)
	return { Coins = config.StartingCoins, XP = 0, Floor = 0, DropperTier = 0, Bank = 0, BonusReadyAt = 0,
		Rebirths = 0, EquippedHero = "", CollectedTotal = 0, EnemiesDefeated = 0, DailyReadyAt = 0, QuestClaims = {},
		Inventory = {}, EquippedWeapon = "", WeaponUpgrades = {}, ObbyReadyAt = 0, ObbyWins = 0, ObbyBestMilliseconds = 0,
		DailyLastClaimAt = 0, DailyStreak = 0, AchievementClaims = {}, EquippedTitle = "", TutorialStep = 1, CombatPractice = false, BossDefeated = 0 }
end

function Schema.Normalize(data, config, now)
	if type(data) ~= "table" then
		return Schema.New(config)
	end
	local floor = boundedInteger(data.Floor, 0, #config.Floors)
	local rebirths = boundedInteger(data.Rebirths, 0, config.MaxRebirths or 20)
	local hero = config.GetHero and config.GetHero(data.EquippedHero)
	local equipped = if hero and config.CanUseHero({ Floor = floor, Rebirths = rebirths }, hero) then hero.Id else ""
	local claims = {}
	for _, quest in ipairs(config.Quests or {}) do
		if type(data.QuestClaims) == "table" and data.QuestClaims[quest.Id] == true then claims[quest.Id] = true end
	end
	local inventory = {}
	for _, weapon in ipairs(config.Weapons or {}) do
		local count = if type(data.Inventory) == "table" then boundedInteger(data.Inventory[weapon.Id], 0, config.MaxWeaponCopies or 99) else 0
		if count > 0 then inventory[weapon.Id] = count end
	end
	local equippedWeapon = if type(data.EquippedWeapon) == "string" and inventory[data.EquippedWeapon] then data.EquippedWeapon else ""
	local upgrades = {}
	local savedUpgrades = if type(data.WeaponUpgrades) == "table" then data.WeaponUpgrades else {}
	for _, heroDefinition in ipairs(config.Heroes or {}) do
		local key = "hero:" .. heroDefinition.Id
		local level = boundedInteger(savedUpgrades[key], 0, #config.WeaponUpgradeCosts)
		if level > 0 then upgrades[key] = level end
	end
	for id in pairs(inventory) do
		local key = "loot:" .. id
		local level = boundedInteger(savedUpgrades[key], 0, #config.WeaponUpgradeCosts)
		if level > 0 then upgrades[key] = level end
	end
	local achievementClaims = {}
	for _, definition in ipairs(config.Achievements or {}) do
		if type(data.AchievementClaims) == "table" and data.AchievementClaims[definition.Id] == true then achievementClaims[definition.Id] = true end
	end
	local title = config.GetAchievement(data.EquippedTitle)
	local equippedTitle = if title and title.TitleReward and achievementClaims[title.Id] then title.Id else ""
	-- Старым развитым профилям не навязываем повторное обучение и не выдаём его награды заново.
	local hasPriorProgress = floor > 0 or rebirths > 0 or (type(data.XP) == "number" and data.XP > 0)
		or (type(data.CollectedTotal) == "number" and data.CollectedTotal > 0) or next(inventory) ~= nil
	local tutorialDefault = if hasPriorProgress then #config.TutorialSteps + 1 else 1
	local tutorialStep = math.max(1, boundedInteger(data.TutorialStep, tutorialDefault, #config.TutorialSteps + 1))
	return {
		Coins = boundedInteger(data.Coins, config.StartingCoins, config.MaxCoins),
		XP = boundedInteger(data.XP, 0, config.MaxXP),
		Floor = floor,
		DropperTier = if floor == 0 then 0 else boundedInteger(data.DropperTier, 0, #config.DropperCosts),
		Bank = if floor == 0 then 0 else boundedInteger(data.Bank, 0, config.MaxBank),
		BonusReadyAt = boundedInteger(data.BonusReadyAt, 0, now + 86400),
		Rebirths = rebirths, EquippedHero = equipped,
		CollectedTotal = boundedInteger(data.CollectedTotal, 0, config.MaxCoins),
		EnemiesDefeated = boundedInteger(data.EnemiesDefeated, 0, config.MaxCoins),
		DailyReadyAt = boundedInteger(data.DailyReadyAt, 0, now + (config.DailyCooldown or 86400)),
		QuestClaims = claims,
		Inventory = inventory, EquippedWeapon = equippedWeapon,
		WeaponUpgrades = upgrades,
		DailyLastClaimAt = boundedInteger(data.DailyLastClaimAt, 0, now),
		DailyStreak = boundedInteger(data.DailyStreak, 0, #config.DailyRewards),
		AchievementClaims = achievementClaims, EquippedTitle = equippedTitle,
		TutorialStep = tutorialStep, CombatPractice = data.CombatPractice == true,
		BossDefeated = boundedInteger(data.BossDefeated, 0, config.MaxCoins),
		ObbyReadyAt = boundedInteger(data.ObbyReadyAt, 0, now + config.Obby.RewardCooldown),
		ObbyWins = boundedInteger(data.ObbyWins, 0, config.MaxCoins),
		ObbyBestMilliseconds = boundedInteger(data.ObbyBestMilliseconds, 0, config.Obby.MaximumRunSeconds * 1000),
	}
end

function Schema.Copy(profile)
	local claims = {}
	for id, claimed in pairs(profile.QuestClaims or {}) do if claimed == true then claims[id] = true end end
	local inventory = {}
	for id, count in pairs(profile.Inventory or {}) do inventory[id] = count end
	local upgrades = {}
	for id, level in pairs(profile.WeaponUpgrades or {}) do upgrades[id] = level end
	local achievements = {}
	for id, value in pairs(profile.AchievementClaims or {}) do if value == true then achievements[id] = true end end
	return {
		Coins = profile.Coins, XP = profile.XP, Floor = profile.Floor,
		DropperTier = profile.DropperTier, Bank = profile.Bank, BonusReadyAt = profile.BonusReadyAt,
		Rebirths = profile.Rebirths or 0, EquippedHero = profile.EquippedHero or "",
		CollectedTotal = profile.CollectedTotal or 0, EnemiesDefeated = profile.EnemiesDefeated or 0,
		DailyReadyAt = profile.DailyReadyAt or 0, QuestClaims = claims,
		Inventory = inventory, EquippedWeapon = profile.EquippedWeapon or "",
		WeaponUpgrades = upgrades,
		DailyLastClaimAt = profile.DailyLastClaimAt or 0, DailyStreak = profile.DailyStreak or 0,
		AchievementClaims = achievements, EquippedTitle = profile.EquippedTitle or "",
		TutorialStep = profile.TutorialStep or 1, CombatPractice = profile.CombatPractice == true, BossDefeated = profile.BossDefeated or 0,
		ObbyReadyAt = profile.ObbyReadyAt or 0, ObbyWins = profile.ObbyWins or 0, ObbyBestMilliseconds = profile.ObbyBestMilliseconds or 0,
	}
end

return Schema

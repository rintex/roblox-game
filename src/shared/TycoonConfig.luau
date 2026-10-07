-- Цены и награды читает сервер. Клиент использует их только для подписей.
local Config = {
	StartingCoins = 75,
	Floors = {
		{ Name = "Первый этаж", Cost = 50, Income = 5, XP = 20 },
		{ Name = "Второй этаж", Cost = 200, Income = 14, XP = 40 },
		{ Name = "Третий этаж", Cost = 600, Income = 35, XP = 70 },
	},
	DropperCosts = { 60, 140, 320 },
	DropperMultiplierStep = 0.5,
	ThirdFloorIncomeMultiplier = 1.5,
	ThirdFloorWalkSpeed = 24,
	DefaultWalkSpeed = 16,
	BonusCoins = 120,
	BonusXP = 15,
	BonusCooldown = 60,
	IncomeInterval = 1,
	ActionCooldown = 0.35,
	MaxBank = 100000,
	MaxCoins = 1000000000,
	MaxXP = 1000000000,
	Persistence = {
		StoreName = "HouseTycoon_v1",
		SaveInterval = 60,
		LockSeconds = 180,
		MaxRetries = 3,
	},
}

function Config.GetLevel(xp)
	return 1 + math.floor(xp / 100)
end

function Config.IncomeFor(floor, tier)
	local definition = Config.Floors[floor]
	if not definition then
		return 0
	end
	local amount = definition.Income * (1 + tier * Config.DropperMultiplierStep)
	if floor == #Config.Floors then
		amount *= Config.ThirdFloorIncomeMultiplier
	end
	return math.floor(amount)
end

return Config

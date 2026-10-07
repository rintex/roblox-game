-- Проверка сохранённого профиля. Уровень вычисляется из XP, а не хранится отдельно.
local Schema = {}

local function boundedInteger(value, default, maximum)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return default
	end
	return math.clamp(math.floor(value), 0, maximum)
end

function Schema.New(config)
	return { Coins = config.StartingCoins, XP = 0, Floor = 0, DropperTier = 0, Bank = 0, BonusReadyAt = 0 }
end

function Schema.Normalize(data, config, now)
	if type(data) ~= "table" then
		return Schema.New(config)
	end
	local floor = boundedInteger(data.Floor, 0, #config.Floors)
	return {
		Coins = boundedInteger(data.Coins, config.StartingCoins, config.MaxCoins),
		XP = boundedInteger(data.XP, 0, config.MaxXP),
		Floor = floor,
		DropperTier = if floor == 0 then 0 else boundedInteger(data.DropperTier, 0, #config.DropperCosts),
		Bank = if floor == 0 then 0 else boundedInteger(data.Bank, 0, config.MaxBank),
		BonusReadyAt = boundedInteger(data.BonusReadyAt, 0, now + 86400),
	}
end

function Schema.Copy(profile)
	return {
		Coins = profile.Coins, XP = profile.XP, Floor = profile.Floor,
		DropperTier = profile.DropperTier, Bank = profile.Bank, BonusReadyAt = profile.BonusReadyAt,
	}
end

return Schema

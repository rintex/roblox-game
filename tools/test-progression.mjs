// Runs production Luau progression with deterministic Roblox event/object mocks.
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LuauState } from 'luau-web';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [configSource, serviceSource, journeySource] = await Promise.all([
  readFile(resolve(root, 'src/shared/TycoonConfig.luau'), 'utf8'),
  readFile(resolve(root, 'src/server/Modules/ProgressionService.luau'), 'utf8'),
  readFile(resolve(root, 'src/server/Modules/PlayerJourney.luau'), 'utf8'),
]);
const fixture = String.raw`
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { active = true }
			function connection:Disconnect() self.active = false end
			table.insert(listeners, { callback = callback, connection = connection })
			return connection
		end,
		Fire = function(_, ...)
			for _, listener in ipairs(listeners) do if listener.connection.active then listener.callback(...) end end
		end,
	}
end
local workspace = {}
local Players = { PlayerRemoving = signal() }
local game = { GetService = function(_, name) assert(name == "Players"); return Players end }
local CFrame = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local Vector3 = { zero = { X = 0, Y = 0, Z = 0 } }
local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, {
		__sub = function(a, b)
			local dx, dy, dz = a.X-b.X, a.Y-b.Y, a.Z-b.Z
			return { Magnitude = math.sqrt(dx*dx + dy*dy + dz*dz) }
		end,
	})
end
local function fresh()
	return { Coins = 75, XP = 0, Floor = 0, DropperTier = 0, Bank = 0, BonusReadyAt = 0,
		Rebirths = 0, EquippedHero = "", CollectedTotal = 0, EnemiesDefeated = 0, DailyReadyAt = 0, QuestClaims = {},
		Inventory = {}, EquippedWeapon = "" }
end
local function makePlayer(id)
	local p = { Parent = Players, UserId = id, attrs = { DataReady = true } }
	function p:GetAttribute(name) return self.attrs[name] end
	function p:SetAttribute(name, value) self.attrs[name] = value end
	p.root = { Position = vector(0, 3, 0), IsA = function(_, class) return class == "BasePart" end }
	p.humanoid = { Health = 100 }
	p.Character = {
		FindFirstChildOfClass = function(_, class) return class == "Humanoid" and p.humanoid or nil end,
		FindFirstChild = function(_, name) return name == "HumanoidRootPart" and p.root or nil end,
	}
	return p
end
local function makePart(name, promptName)
	local pad = { Name = name, Position = vector(0, 0, 0), inWorkspace = true }
	function pad:IsA(class) return class == "BasePart" end
	function pad:IsDescendantOf(ancestor) return ancestor == workspace and self.inWorkspace end
	local prompt = { Name = promptName, Parent = pad, Enabled = true, MaxActivationDistance = 10, Triggered = signal() }
	function prompt:IsA(class) return class == "ProximityPrompt" end
	function pad:FindFirstChild(childName) return childName == promptName and prompt or nil end
	return pad, prompt
end
local function makePlot(id)
	local heroPad, heroPrompt = makePart("HeroPad", "HeroPrompt")
	local p = { attrs = { OwnerUserId = id } }
	function p:GetAttribute(name) return self.attrs[name] end
	function p:FindFirstChild(name) return name == "HeroPad" and heroPad or nil end
	return p, heroPrompt
end
`;

const assertions = String.raw`
local E = Service.Economy
local p = fresh()
assert(not E.ClaimQuest(Config, p, "collector").ok and p.Coins == 75, "Quest cannot be claimed before target")
assert(not E.ClaimQuest(Config, p, "forged").ok, "Quest IDs are whitelisted")
p.CollectedTotal = 1000
assert(E.ClaimQuest(Config, p, "collector").ok and p.Coins == 575 and p.XP == 100 and p.QuestClaims.collector, "Eligible quest grants server-configured reward")
assert(not E.ClaimQuest(Config, p, "collector").ok and p.Coins == 575, "Quest reward cannot be duplicated")
p.Floor = 3
assert(E.ClaimQuest(Config, p, "builder").ok and p.QuestClaims.builder, "Builder quest uses floor progress")
p.EnemiesDefeated = 5
assert(E.ClaimQuest(Config, p, "fighter").ok and p.QuestClaims.fighter, "Fighter quest uses server kill progress")
assert(E.ClaimDaily(Config, p, 1000).ok and p.DailyReadyAt == 87400, "Daily stores full persisted cooldown")
local dailyCoins = p.Coins
assert(not E.ClaimDaily(Config, p, 87400-1).ok and p.Coins == dailyCoins, "Daily rejects early repeat")
assert(E.ClaimDaily(Config, p, 87400).ok, "Daily can be claimed at exact ready time")
assert(p.DailyStreak == 2 and p.DailyLastClaimAt == 87400 and p.Coins == dailyCoins + 600, "Second day uses persisted streak and increased configured reward")
local sevenDays = fresh()
for day = 1, 7 do
	local before = sevenDays.Coins
	local claimAt = 1000 + (day - 1) * Config.DailyCooldown
	assert(E.ClaimDaily(Config, sevenDays, claimAt).ok, "Each eligible day can be claimed")
	assert(sevenDays.DailyStreak == day and sevenDays.Coins - before == Config.DailyRewards[day], "Seven-day rewards match only server configuration")
	assert(not E.ClaimDaily(Config, sevenDays, claimAt + Config.DailyCooldown - 1).ok, "Streak cannot bypass 24-hour cooldown")
end
assert(E.ClaimDaily(Config, sevenDays, 1000 + 7 * Config.DailyCooldown).ok and sevenDays.DailyStreak == 1, "Day eight restarts reward cycle")
local beforeGap = sevenDays.Coins
assert(E.ClaimDaily(Config, sevenDays, sevenDays.DailyLastClaimAt + 2 * Config.DailyCooldown + 1).ok and sevenDays.DailyStreak == 1 and sevenDays.Coins - beforeGap == 500, "Missed two-day window resets streak without erasing prior rewards")
local legacyDaily = fresh()
legacyDaily.DailyReadyAt = 90000
assert(not E.ClaimDaily(Config, legacyDaily, 89999).ok and legacyDaily.Coins == 75, "Existing saved daily cooldown remains authoritative")
assert(E.ClaimDaily(Config, legacyDaily, 90000).ok and legacyDaily.DailyStreak == 1, "Old profile starts additive streak only when old cooldown expires")
local full = fresh()
full.Coins = Config.MaxCoins
full.CollectedTotal = 1000
assert(not E.ClaimDaily(Config, full, 1000).ok and full.DailyReadyAt == 0, "Full wallet does not lose daily reward")
assert(not E.ClaimQuest(Config, full, "collector").ok and not full.QuestClaims.collector, "Full wallet does not lose quest reward")
assert(not full.DailyLastClaimAt and not full.DailyStreak, "Rejected daily does not consume new streak fields")
local newGoals = fresh()
for _, id in ipairs({"roof_runner", "boss_hunter", "district_patrol", "city_builder"}) do
	assert(not E.ClaimQuest(Config, newGoals, id).ok, "New goals cannot be claimed before their real targets")
end
newGoals.ObbyWins = 1
newGoals.BossDefeated = 1
newGoals.EnemiesDefeated = 25
newGoals.Rebirths = 1
for _, id in ipairs({"roof_runner", "boss_hunter", "district_patrol", "city_builder"}) do
	assert(E.ClaimQuest(Config, newGoals, id).ok and newGoals.QuestClaims[id], "New quest reads actual lifetime progress")
	local paidOnce = newGoals.Coins
	assert(not E.ClaimQuest(Config, newGoals, id).ok and newGoals.Coins == paidOnce, "New quest cannot pay twice")
end

local reborn = fresh()
reborn.Coins = Config.RebirthCost(0)
reborn.Floor = 3
reborn.DropperTier = #Config.DropperCosts - 1
assert(not E.Rebirth(Config, reborn).ok and reborn.Rebirths == 0, "Rebirth requires maximum generator")
reborn.DropperTier = #Config.DropperCosts
reborn.Coins -= 1
assert(not E.Rebirth(Config, reborn).ok and reborn.Floor == 3, "Rebirth requires exact server balance threshold")
reborn.Coins += 1
reborn.XP = 456
reborn.Bank = 999
reborn.BonusReadyAt = 1000
reborn.EquippedHero = "volt"
reborn.EquippedWeapon = "pulse_pistol"
reborn.Inventory.pulse_pistol = 2
reborn.CollectedTotal = 12500
reborn.EnemiesDefeated = 11
reborn.DailyReadyAt = 300000
reborn.QuestClaims.collector = true
assert(E.Rebirth(Config, reborn).ok and reborn.Rebirths == 1 and reborn.Coins == Config.StartingCoins, "Rebirth increases count and resets spendable coins")
assert(reborn.Floor == 0 and reborn.DropperTier == 0 and reborn.Bank == 0 and reborn.BonusReadyAt == 0, "Rebirth resets house, generator and bank")
assert(reborn.XP == 456 and reborn.CollectedTotal == 12500 and reborn.EnemiesDefeated == 11 and reborn.DailyReadyAt == 300000 and reborn.QuestClaims.collector, "Rebirth retains lifetime progress and daily state")
assert(reborn.EquippedHero == "volt" and reborn.EquippedWeapon == "pulse_pistol" and reborn.Inventory.pulse_pistol == 2, "Rebirth retains unlocked hero and weapon inventory")
assert(Config.IncomeFor(1, 0, reborn.Rebirths) > Config.IncomeFor(1, 0, 0), "Rebirth improves future income")
assert(E.GetQuestProgress(Config, reborn, "builder") == 3, "Earned builder target remains eligible after rebirth")
reborn.Rebirths = Config.MaxRebirths
reborn.Coins = Config.MaxCoins
reborn.Floor = 3
reborn.DropperTier = #Config.DropperCosts
assert(not E.Rebirth(Config, reborn).ok and reborn.Rebirths == Config.MaxRebirths, "Rebirth count is bounded")

local player = makePlayer(1)
local ownerPlot, heroPrompt = makePlot(1)
local foreignPlot, foreignHeroPrompt = makePlot(2)
local profile = fresh()
local states = { [player] = { profile = profile, plot = ownerPlot } }
local records = { [player] = profile }
local profiles = { closing = false }
function profiles:Get(target) return records[target] end
function profiles:IsClosing() return self.closing end
local tycoon = { plots = { ownerPlot, foreignPlot }, syncCount = 0, rebuildCount = 0 }
function tycoon:GetState(target) return states[target] end
function tycoon:SyncPlayer() self.syncCount += 1 end
function tycoon:RebuildPlayer() self.rebuildCount += 1 end
local heroCombat = { refreshCount = 0 }
function heroCombat:Equip(target, id)
	local hero = Config.GetHero(id)
	if not hero or not Config.CanUseHero(records[target], hero) then return false, "Locked" end
	records[target].EquippedHero = id
	return true, "Equipped"
end
function heroCombat:EquipWeapon(target, id)
	if not Config.GetWeapon(id) or not (records[target].Inventory[id] and records[target].Inventory[id] > 0) then return false, "Missing" end
	records[target].EquippedWeapon = id
	return true, "Equipped weapon"
end
function heroCombat:Refresh() self.refreshCount += 1 end
local messages = {}
local notice = { FireClient = function(_, target, payload) assert(target == player); table.insert(messages, payload) end }
local request = { OnServerEvent = signal() }
local campus = { parts = {} }
function campus:FindFirstChild(name) return self.parts[name] end
local campusPrompts = {}
for partName, promptName in pairs({ DailyStand = "ClaimDailyPrompt", QuestStand = "QuestPrompt", RebirthStand = "RebirthPrompt", ArenaPortal = "EnterArenaPrompt", ReturnStand = "ReturnPrompt" }) do
	local part, prompt = makePart(partName, promptName)
	campus.parts[partName] = part
	campusPrompts[partName] = prompt
end
local service = Service.new(Config, profiles, tycoon, notice, request, campus, heroCombat)
service:Start()
local function allow() service.lastActions[player] = os.clock() - 1 end

request.OnServerEvent:Fire(player, "GiveCoins", Config.MaxCoins)
request.OnServerEvent:Fire(player, "ClaimQuest", { Coins = 999999 })
assert(profile.Coins == 75 and #messages == 0, "Unknown actions and malformed client IDs are ignored")
request.OnServerEvent:Fire(player, "ClaimDaily", 99999999)
assert(profile.Coins == 575 and profile.DailyReadyAt > os.time(), "Remote only grants configured daily amount")
local noticesBeforeDuplicate = #messages
request.OnServerEvent:Fire(player, "ClaimDaily")
assert(profile.Coins == 575 and #messages == noticesBeforeDuplicate, "Remote cooldown blocks duplicate calls and notice spam")
allow()
player.humanoid.Health = 0
request.OnServerEvent:Fire(player, "ClaimQuest", "collector")
assert(#messages == noticesBeforeDuplicate, "Dead characters cannot use progression remote")
player.humanoid.Health = 100
player:SetAttribute("DataReady", false)
request.OnServerEvent:Fire(player, "ClaimQuest", "collector")
assert(#messages == noticesBeforeDuplicate, "Unready profiles cannot use progression remote")
player:SetAttribute("DataReady", true)
profiles.closing = true
request.OnServerEvent:Fire(player, "ClaimQuest", "collector")
assert(#messages == noticesBeforeDuplicate, "Closing server rejects progression writes")
profiles.closing = false

profile.Floor = 1
allow()
request.OnServerEvent:Fire(player, "ClaimAchievement", "penthouse")
assert(not (profile.AchievementClaims or {}).penthouse, "Remote achievement requires server-side progress")
allow()
local beforeAchievement = profile.Coins
request.OnServerEvent:Fire(player, "ClaimAchievement", "first_home")
assert(profile.AchievementClaims.first_home and profile.Coins == beforeAchievement + 40 and profile.EquippedTitle == "first_home", "Achievement remote pays configured amount and equips earned cosmetic title")
local afterAchievement = profile.Coins
allow()
request.OnServerEvent:Fire(player, "ClaimAchievement", "first_home")
assert(profile.Coins == afterAchievement, "Repeated achievement remote cannot duplicate currency")
allow()
request.OnServerEvent:Fire(player, "EquipTitle", "penthouse")
assert(profile.EquippedTitle == "first_home", "Unclaimed cosmetic title cannot be equipped")
allow()
request.OnServerEvent:Fire(player, "EquipTitle", "<font color='red'>OWNER</font>")
assert(profile.EquippedTitle == "first_home", "Client cannot forge title markup")
allow()
request.OnServerEvent:Fire(player, "EquipTitle", "")
assert(profile.EquippedTitle == "", "Earned title can be hidden")
allow()
request.OnServerEvent:Fire(player, "EquipTitle", "first_home")
assert(profile.EquippedTitle == "first_home", "Owned cosmetic title can be selected again")
states[player].leaving = true
allow()
request.OnServerEvent:Fire(player, "ClaimAchievement", "first_home")
assert(profile.Coins == afterAchievement, "Leaving state blocks new progression mutations")
states[player].leaving = false
allow()
request.OnServerEvent:Fire(player, "EquipHero", "arachna")
assert(profile.EquippedHero == "arachna", "Hero selection delegates server unlock validation")
allow()
request.OnServerEvent:Fire(player, "EquipHero", "helios")
assert(profile.EquippedHero == "arachna", "Locked hero cannot replace equipped hero")
allow()
request.OnServerEvent:Fire(player, "EquipWeapon", "pulse_pistol")
assert(profile.EquippedWeapon == "", "Unowned weapon cannot be equipped")
profile.Inventory.pulse_pistol = 1
allow()
request.OnServerEvent:Fire(player, "EquipWeapon", "pulse_pistol")
assert(profile.EquippedWeapon == "pulse_pistol", "Owned weapon equips through server combat service")

profile.CollectedTotal = 1000
profile.Floor = 3
profile.EnemiesDefeated = 5
allow()
campusPrompts.QuestStand.Triggered:Fire(player)
assert(profile.QuestClaims.collector and profile.QuestClaims.builder and profile.QuestClaims.fighter, "Quest stand claims each eligible lifetime reward once")
local paid = profile.Coins
allow()
campusPrompts.QuestStand.Triggered:Fire(player)
assert(profile.Coins == paid, "Quest stand cannot pay duplicate rewards")

profile.Coins = Config.RebirthCost(0)
profile.DropperTier = #Config.DropperCosts
states[player].plot = nil
allow()
request.OnServerEvent:Fire(player, "Rebirth")
assert(profile.Rebirths == 0 and profile.Floor == 3, "Rebirth requires owned plot")
states[player].plot = ownerPlot
allow()
request.OnServerEvent:Fire(player, "Rebirth")
assert(profile.Rebirths == 1 and profile.Floor == 0 and tycoon.rebuildCount == 1 and heroCombat.refreshCount == 1, "Rebirth rebuilds own house and refreshes retained hero")

player.root.Position = vector(500, 3, 0)
allow()
local beforeFar = #messages
campusPrompts.ArenaPortal.Triggered:Fire(player)
assert(player:GetAttribute("ArenaCombatOptIn") ~= true and #messages == beforeFar, "Distant forged arena prompt cannot opt into combat")
player.root.Position = vector(0, 3, 0)
allow()
campusPrompts.ArenaPortal.Triggered:Fire(player)
assert(player:GetAttribute("ArenaCombatOptIn") == true and player.root.CFrame.Z == -98, "Valid arena portal opts into combat and teleports")
allow()
campusPrompts.ReturnStand.Triggered:Fire(player)
assert(player:GetAttribute("ArenaCombatOptIn") == false and player.root.CFrame.Z == 14, "Return portal clears combat opt-in")
allow()
heroPrompt.Triggered:Fire(player)
assert(messages[#messages].kind == "heroes", "Own HeroPad opens hero interface")
allow()
local beforeForeign = #messages
foreignHeroPrompt.Triggered:Fire(player)
assert(#messages == beforeForeign, "Foreign HeroPad cannot open owned interaction")

records[player] = fresh()
allow()
request.OnServerEvent:Fire(player, "ClaimDaily")
assert(profile.Coins == Config.StartingCoins, "Stale state cannot mutate a released profile")
records[player] = profile
Players.PlayerRemoving:Fire(player)
assert(service.lastActions[player] == nil, "Player removal clears throttle bookkeeping")
service:Destroy()
request.OnServerEvent:Fire(player, "ClaimDaily")
assert(profile.Coins == Config.StartingCoins, "Destroy disconnects remote and prompt handlers")
return true
`;

const vm = await LuauState.createAsync();
try {
  const run = vm.loadstring(`${fixture}\nlocal Config = (function()\n${configSource}\nend)()\nlocal Journey = (function()\n${journeySource}\nend)()\nlocal script = {Parent = {WaitForChild = function(_, name) return name end}}\nlocal function require(name) assert(name == "PlayerJourney"); return Journey end\nlocal Service = (function()\n${serviceSource}\nend)()\n${assertions}`, 'Progression rewards and server event tests', true);
  const [passed] = await run();
  if (passed !== true) throw new Error('Progression Luau tests did not complete');
  console.log('Progression tests passed: quest/daily rewards, rebirth resets and retained progress, remote whitelist/throttle/readiness, hero and weapon selection, public prompts and arena opt-in.');
} finally {
  vm.destroy();
}

// Real Luau economy and server guards under deterministic mocks, not a Studio run.
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LuauState } from 'luau-web';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [configSource, serviceSource] = await Promise.all([
  readFile(resolve(root, 'src/shared/TycoonConfig.luau'), 'utf8'),
  readFile(resolve(root, 'src/server/Modules/TycoonService.luau'), 'utf8'),
]);

const mock = String.raw`
local Players = {}
local RunService = {}
local HttpService = { JSONEncode = function() return "{}" end }
local game = { GetService = function(_, name)
	if name == "Players" then return Players end
	if name == "RunService" then return RunService end
	if name == "HttpService" then return HttpService end
	error("Unexpected service " .. name)
end }
local task = { spawn = function(callback) callback() end }
local vectorMeta = {}
local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
function vectorMeta.__sub(a, b)
	local x, y, z = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return { Magnitude = math.sqrt(x*x + y*y + z*z) }
end
local function fresh()
	return { Coins = 75, XP = 0, Floor = 0, DropperTier = 0, Bank = 0, BonusReadyAt = 0,
		Rebirths = 0, EquippedHero = "", CollectedTotal = 0, EnemiesDefeated = 0, DailyReadyAt = 0, QuestClaims = {}, Inventory = {}, EquippedWeapon = "" }
end
local function player(id)
	local p = { Parent = Players, UserId = id, DisplayName = "Player " .. id, attrs = { DataReady = true } }
	function p:GetAttribute(name) return self.attrs[name] end
	function p:SetAttribute(name, value) self.attrs[name] = value end
	function p:FindFirstChild() return nil end
	local root = { Position = vector(0, 3, 0), IsA = function(_, name) return name == "BasePart" end }
	local humanoid = { Health = 100, WalkSpeed = 16, IsA = function(_, name) return name == "Humanoid" end }
	p.Character = {
		FindFirstChildOfClass = function(_, name) return name == "Humanoid" and humanoid or nil end,
		FindFirstChild = function(_, name) return name == "HumanoidRootPart" and root or nil end,
	}
	p.root = root
	p.humanoid = humanoid
	return p
end
local function plot(id)
	local p = { Parent = {}, Name = "Plot" .. id, attrs = { PlotId = "Plot" .. id, OwnerUserId = 0, Floor = 0 } }
	function p:GetAttribute(name) return self.attrs[name] end
	function p:SetAttribute(name, value) self.attrs[name] = value end
	function p:FindFirstChild() return nil end
	local prompts = {}
	local names = { claim = "ClaimPrompt", floor = "FloorPrompt", dropper = "DropperPrompt", collect = "CollectPrompt", bonus = "BonusPrompt" }
	for action, name in pairs(names) do
		local pad = { Position = vector(0, 0, 0), IsA = function(_, class) return class == "BasePart" end }
		prompts[action] = {
			Name = name, Parent = pad, MaxActivationDistance = 10, Enabled = action == "claim",
			IsDescendantOf = function(_, ancestor) return ancestor == p end,
		}
	end
	return p, prompts
end
`;

const assertions = String.raw`
local E = Service.Economy
local p = fresh()
assert(E.Income(Config, p) == 0, "Unbuilt plot must not generate income")
assert(not E.BuyDropper(Config, p).ok, "Dropper requires first floor")
assert(E.BuyFloor(Config, p).ok and p.Coins == 25 and p.Floor == 1 and p.XP == 20, "First floor purchase")
assert(not E.BuyFloor(Config, p).ok and p.Coins == 25 and p.Floor == 1, "Cannot buy an unaffordable floor")
assert(E.Accrue(Config, p, 40) == 200 and p.Bank == 200, "First floor generates into bank")
assert(E.Collect(Config, p).ok and p.Coins == 225 and p.Bank == 0 and p.XP == 220 and p.CollectedTotal == 200, "Collection transfers coins and awards XP and quest progress")
assert(not E.Collect(Config, p).ok and p.Coins == 225, "Cannot collect same coins twice")
assert(E.BuyFloor(Config, p).ok and p.Floor == 2 and p.Coins == 25, "Second floor purchase")
E.Accrue(Config, p, 42)
E.Collect(Config, p)
assert(E.BuyFloor(Config, p).ok and p.Floor == 3 and p.XP == 918, "Three floor progression preserves XP")
assert(E.Income(Config, p) == 52 and Config.GetLevel(p.XP) == 10, "Third floor income perk and XP levels")
assert(not E.BuyFloor(Config, p).ok, "Cannot purchase a fourth floor")
local lockedBonus = fresh()
assert(not E.ClaimBonus(Config, lockedBonus, 1000).ok, "Third floor chest cannot be opened early")
assert(E.ClaimBonus(Config, p, 1000).ok and p.BonusReadyAt == 1060, "Bonus stores server cooldown")
local earned, xp = p.Coins, p.XP
assert(not E.ClaimBonus(Config, p, 1001).ok and p.Coins == earned and p.XP == xp, "Early duplicate bonus grants nothing")
assert(E.ClaimBonus(Config, p, 1060).ok, "Bonus becomes claimable after cooldown")
p.Bank = Config.MaxBank - 3
assert(E.Accrue(Config, p, 10) == 3 and p.Bank == Config.MaxBank, "Bank cannot overflow")
p.Coins = Config.MaxCoins - 2
p.XP = Config.MaxXP - 1
assert(E.Collect(Config, p).ok and p.Coins == Config.MaxCoins and p.Bank == Config.MaxBank - 2 and p.XP == Config.MaxXP, "Collection caps wallet and XP, preserves overflow in bank")
assert(not E.Collect(Config, p).ok, "Full wallet cannot collect")
assert(not E.ClaimBonus(Config, p, 1200).ok and p.BonusReadyAt == 1120, "Full wallet does not consume chest cooldown")
p.Coins = 1000
assert(E.BuyDropper(Config, p).ok and p.Coins == 940 and p.DropperTier == 1 and E.Income(Config, p) == 78, "Dropper multiplier")
p.Coins = Config.MaxCoins
for tier = 2, #Config.DropperCosts do assert(E.BuyDropper(Config, p).ok and p.DropperTier == tier, "All dropper upgrades") end
assert(not E.BuyDropper(Config, p).ok, "Dropper maximum enforced")

local a, b = player(1), player(2)
local one, promptsOne = plot(1)
local two, promptsTwo = plot(2)
local records = { [a] = fresh(), [b] = fresh() }
local released = {}
local profiles = {
	closing = false,
	Get = function(_, target) return records[target] end,
	IsClosing = function(self) return self.closing end,
	Release = function(_, target)
		released[target] = (released[target] or 0) + 1
		records[target] = nil
		return true
	end,
}
local notices = {}
local notice = { FireClient = function(_, target, message) table.insert(notices, { player = target, text = message.text }) end }
local world = { UpdatePlot = function(target, floor) target.renderedFloor = floor end }
local service = Service.new(Config, profiles, world, { one, two }, notice)
service.promptSets = { [one] = promptsOne, [two] = promptsTwo }
for _, target in ipairs({ a, b }) do
	service.states[target] = {
		player = target, profile = records[target], coins = { Value = 0 }, level = { Value = 1 },
		lastActionAt = -math.huge, leaving = false,
	}
end
local stateA, stateB = service.states[a], service.states[b]
local function allowAction(state) state.lastActionAt = os.clock() - Config.ActionCooldown - 1 end

service:_claim(a, one, promptsOne.claim)
assert(stateA.plot == one and service.owners[one] == stateA and one:GetAttribute("OwnerUserId") == 1, "Claim establishes exclusive ownership")
service:_claim(b, one, promptsOne.claim)
assert(not stateB.plot and service.owners[one] == stateA, "Second player cannot steal claimed plot")
allowAction(stateA)
service:_claim(a, two, promptsTwo.claim)
assert(stateA.plot == one and not service.owners[two], "Player may own only one plot")
allowAction(stateA)
service:_action(a, one, promptsOne.floor, "floor")
assert(records[a].Floor == 1 and records[a].Coins == 25 and one.renderedFloor == 1, "Server purchase deducts balance and rebuilds own house")
records[a].Bank = 50
allowAction(stateB)
service:_action(b, one, promptsOne.collect, "collect")
local deniedNotices = #notices
service:_action(b, one, promptsOne.collect, "collect")
assert(records[a].Bank == 50 and records[b].Coins == 75 and #notices == deniedNotices, "Foreign collection blocked; cooldown limits notices")
allowAction(stateA)
a.root.Position = vector(500, 3, 0)
local beforeFar = #notices
service:_action(a, one, promptsOne.collect, "collect")
assert(records[a].Bank == 50 and #notices == beforeFar, "Remote prompt spoof cannot collect or spam notices")
a.root.Position = vector(0, 3, 0)
a.humanoid.Health = 0
allowAction(stateA)
service:_action(a, one, promptsOne.collect, "collect")
assert(records[a].Bank == 50, "Dead character cannot interact")
a.humanoid.Health = 100
a:SetAttribute("DataReady", false)
service:_action(a, one, promptsOne.collect, "collect")
assert(records[a].Bank == 50, "Unready profile cannot interact")
a:SetAttribute("DataReady", true)
profiles.closing = true
service:_action(a, one, promptsOne.collect, "collect")
assert(records[a].Bank == 50, "Server closing freezes economy for final save")
profiles.closing = false
allowAction(stateA)
service:_action(a, one, promptsOne.collect, "collect")
assert(records[a].Bank == 0 and records[a].Coins == 75, "Nearby living owner can collect")
service:_action(a, one, promptsOne.collect, "collect")
assert(records[a].Coins == 75, "Same-frame duplicate collection grants nothing")

-- Floor three enables server speed perk and chest only at the right height.
records[a].Coins = 1000
allowAction(stateA)
service:_action(a, one, promptsOne.floor, "floor")
allowAction(stateA)
service:_action(a, one, promptsOne.floor, "floor")
assert(a.humanoid.WalkSpeed == Config.ThirdFloorWalkSpeed and records[a].Floor == 3, "Third floor speed perk applied on server")
promptsOne.bonus.Parent.Position = vector(0, 11, 0)
a.root.Position = vector(0, 1, 0)
allowAction(stateA)
local beforeBelow = records[a].Coins
service:_action(a, one, promptsOne.bonus, "bonus")
assert(records[a].Coins == beforeBelow, "Chest cannot be triggered from floor below")
a.root.Position = vector(0, 14, 0)
allowAction(stateA)
service:_action(a, one, promptsOne.bonus, "bonus")
assert(records[a].Coins == beforeBelow + Config.BonusCoins, "Chest grants reward on third floor")

-- Server must own the current profile object, even if player attrs look ready.
local actualProfile = records[a]
records[a] = fresh()
actualProfile.Bank = 20
allowAction(stateA)
a.root.Position = vector(0, 3, 0)
service:_action(a, one, promptsOne.collect, "collect")
assert(actualProfile.Bank == 20, "Stale profile cannot be used after session release")
records[a] = actualProfile
service:_removePlayer(a)
assert(not service.states[a] and not service.owners[one] and one:GetAttribute("OwnerUserId") == 0 and one.renderedFloor == 0, "Leaving owner frees and resets plot")
assert(promptsOne.claim.Enabled and not promptsOne.collect.Enabled and released[a] == 1, "Removal releases profile once and prevents abandoned collection")
allowAction(stateB)
service:_claim(b, one, promptsOne.claim)
assert(service.owners[one] == stateB and stateB.plot == one and records[b].Coins == 75 and records[b].Bank == 0, "Next owner inherits no previous coins or bank")
return true
`;

const vm = await LuauState.createAsync();
try {
  const source = `${mock}\nlocal Config = (function()\n${configSource}\nend)()\nlocal Service = (function()\n${serviceSource}\nend)()\n${assertions}`;
  const run = vm.loadstring(source, 'Tycoon economy and server guard tests', true);
  const [passed] = await run();
  if (passed !== true) throw new Error('Luau test did not finish successfully');
  console.log('Tycoon tests passed: economy, XP, caps, ownership, distance, life state, cooldown, profile readiness, shutdown, third-floor perks and plot cleanup.');
} finally {
  vm.destroy();
}

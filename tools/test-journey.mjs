// Executes the shipped Luau rules. These tests never let a client mark a goal complete.
import {readFile} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {LuauState} from 'luau-web';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [config, schema, journey] = await Promise.all([
  readFile(resolve(root, 'src/shared/TycoonConfig.luau'), 'utf8'),
  readFile(resolve(root, 'src/server/Modules/ProfileSchema.luau'), 'utf8'),
  readFile(resolve(root, 'src/server/Modules/PlayerJourney.luau'), 'utf8'),
]);
const assertions = String.raw`
local cases = 0
local function check(name, callback)
 local ok, message = pcall(callback)
 assert(ok, name .. ': ' .. tostring(message))
 cases += 1
end
local now = 1000000
local function fresh() return Schema.New(Config) end
local function advance(profile, owned) return Journey.Advance(Config, profile, owned) end

check('new players start before claiming a plot, with independent nested state', function()
 local a, b = fresh(), fresh()
 assert(a.Coins == Config.StartingCoins and a.TutorialStep == 1 and not a.CombatPractice and a.BossDefeated == 0)
 assert(a.DailyStreak == 0 and a.DailyLastClaimAt == 0 and a.EquippedTitle == '')
 assert(#advance(a, false) == 0 and a.TutorialStep == 1)
 a.Inventory.arc_rifle = 1; a.AchievementClaims.first_home = true; a.QuestClaims.collector = true
 assert(next(b.Inventory) == nil and next(b.AchievementClaims) == nil and next(b.QuestClaims) == nil)
end)

check('all six tutorial steps grant each configured prize exactly once', function()
 local p = fresh()
 local expectedCoins, expectedXP = p.Coins, 0
 local setters = {
  function() end,
  function() p.Floor = 1 end,
  function() p.CollectedTotal = 5 end,
  function() p.DropperTier = 1 end,
  function() p.EquippedHero = 'arachna' end,
  function() p.CombatPractice = true end,
 }
 assert(#Config.TutorialSteps == 6)
 for index, setter in ipairs(setters) do
  setter()
  local events = advance(p, true)
  expectedCoins += Config.TutorialSteps[index].Coins
  expectedXP += Config.TutorialSteps[index].XP
  assert(#events == 1 and events[1].kind == 'success', 'One completed step emits one event')
  assert(p.TutorialStep == index + 1 and p.Coins == expectedCoins and p.XP == expectedXP)
  assert(#advance(p, true) == 0 and p.Coins == expectedCoins and p.XP == expectedXP, 'Repeated sync must not replay a reward')
 end
 assert(p.TutorialStep == 7 and p.Coins == 240 and p.XP == 90)
end)

check('owning a plot is required for the first two goals', function()
 local p = fresh(); p.Floor = 1; p.CollectedTotal = 5; p.DropperTier = 1; p.EquippedHero = 'arachna'; p.CombatPractice = true
 assert(#advance(p, false) == 0 and p.TutorialStep == 1 and p.Coins == 75)
 p.TutorialStep = 2
 assert(#advance(p, false) == 0 and p.TutorialStep == 2)
 assert(#advance(p, true) == 5 and p.TutorialStep == 7)
end)

check('out-of-order lifetime progress waits at the missing step, then catches up once', function()
 local p = fresh(); p.CollectedTotal = 100; p.DropperTier = 1; p.EquippedHero = 'arachna'; p.CombatPractice = true
 assert(#advance(p, true) == 1 and p.TutorialStep == 2 and p.Coins == 75)
 assert(#advance(p, true) == 0, 'Combat cannot bypass an unbuilt first floor')
 p.Floor = 1
 assert(#advance(p, true) == 5 and p.TutorialStep == 7 and p.Coins == 240 and p.XP == 90)
 assert(#advance(p, true) == 0)
end)

check('hero tutorial requires a real unlocked hero and combat flag requires boolean true', function()
 local p = fresh(); p.TutorialStep = 5; p.Floor = 1
 for _, id in ipairs({'', 'fake_hero', 'helios'}) do
  p.EquippedHero = id; assert(#advance(p, true) == 0 and p.TutorialStep == 5)
 end
 p.EquippedHero = 'arachna'; assert(#advance(p, true) == 1 and p.TutorialStep == 6)
 p.CombatPractice = 'true'; assert(#advance(p, true) == 0)
 p.CombatPractice = 1; assert(#advance(p, true) == 0)
 p.CombatPractice = true; assert(#advance(p, true) == 1 and p.TutorialStep == 7)
end)

check('full wallet does not consume a positive tutorial reward; spending permits exact-cap retry', function()
 local p = fresh(); p.Coins = Config.MaxCoins; p.Floor = 1
 assert(#advance(p, true) == 1 and p.TutorialStep == 2 and p.Coins == Config.MaxCoins and p.XP == 10)
 assert(#advance(p, true) == 0 and p.TutorialStep == 2)
 p.Coins -= Config.TutorialSteps[2].Coins
 assert(#advance(p, true) == 1 and p.Coins == Config.MaxCoins and p.TutorialStep == 3 and p.XP == 20)
 assert(#advance(p, true) == 0)
end)

check('tutorial rewards cap XP without overflowing or blocking goal completion', function()
 local p = fresh(); p.TutorialStep = 6; p.CombatPractice = true; p.XP = Config.MaxXP - 2
 assert(#advance(p, true) == 1 and p.XP == Config.MaxXP and p.TutorialStep == 7)
 assert(#advance(p, true) == 0)
end)

check('partly completed tutorial survives save normalization without replaying earlier rewards', function()
 local p = fresh(); advance(p, true); p.Floor = 1; advance(p, true)
 assert(p.TutorialStep == 3)
 local restored = Schema.Normalize(Schema.Copy(p), Config, now)
 assert(restored.TutorialStep == 3 and restored.Coins == p.Coins and restored.XP == p.XP)
 assert(#advance(restored, true) == 0, 'Coins must actually have been collected')
 restored.CollectedTotal = 1
 assert(#advance(restored, true) == 1 and restored.TutorialStep == 4)
end)

for _, definition in ipairs(Config.Achievements) do
 check('achievement ' .. definition.Id .. ' enforces target and grants its prize once', function()
  local p = fresh()
  if definition.Field == 'WeaponTypes' then
   for index = 1, definition.Target - 1 do p.Inventory[Config.Weapons[index].Id] = 1 end
  else p[definition.Field] = definition.Target - 1 end
  assert(not Journey.ClaimAchievement(Config, p, definition.Id).ok and not p.AchievementClaims[definition.Id])
  assert(p.Coins == Config.StartingCoins and p.XP == 0)
  if definition.Field == 'WeaponTypes' then p.Inventory[Config.Weapons[definition.Target].Id] = 1
  else p[definition.Field] = definition.Target end
  local result = Journey.ClaimAchievement(Config, p, definition.Id)
  assert(result.ok and p.Coins == Config.StartingCoins + definition.RewardCoins and p.XP == definition.RewardXP)
  assert(p.AchievementClaims[definition.Id] == true and p.EquippedTitle == definition.Id)
  assert(not Journey.ClaimAchievement(Config, p, definition.Id).ok)
  assert(p.Coins == Config.StartingCoins + definition.RewardCoins and p.XP == definition.RewardXP)
 end)
end

check('unknown achievement IDs and arbitrary progress fields never award currency', function()
 local p = fresh(); p.Coins = 2000; p.EnemiesDefeated = 100; p.unknown_counter = 999999
 for _, id in ipairs({'', 'forged', 'collector', string.rep('x', 100)}) do
  assert(not Journey.ClaimAchievement(Config, p, id).ok)
 end
 assert(p.Coins == 2000 and p.XP == 0 and next(p.AchievementClaims) == nil)
 assert(Journey.GetProgress(Config, p, 'Coins') == 0 and Journey.GetProgress(Config, p, 'XP') == 0)
 assert(Journey.GetProgress(Config, p, 'unknown_counter') == 0)
end)

check('weapon collection counts distinct known owned IDs, rather than duplicates or forged IDs', function()
 local p = Schema.Normalize({Inventory = {arc_rifle = 99, solar_lance = 50, fake_weapon = 99, pulse_pistol = 0}}, Config, now)
 assert(Journey.GetProgress(Config, p, 'WeaponTypes') == 2)
 assert(not Journey.ClaimAchievement(Config, p, 'collector_set').ok)
 p.Inventory.pulse_pistol = 1; p.Inventory.thread_launcher = 1
 assert(Journey.GetProgress(Config, p, 'WeaponTypes') == 4)
 assert(Journey.ClaimAchievement(Config, p, 'collector_set').ok)
end)

check('earned building achievement stays eligible after rebirth resets the house', function()
 local p = fresh(); p.Floor = 0; p.Rebirths = 1
 assert(Journey.GetProgress(Config, p, 'Floor') == #Config.Floors)
 assert(Journey.ClaimAchievement(Config, p, 'penthouse').ok)
 assert(Journey.ClaimAchievement(Config, p, 'architect').ok)
end)

check('full wallet retains unclaimed achievement and title; exact-cap retry bounds XP', function()
 local p = fresh(); p.Floor = 1; p.Coins = Config.MaxCoins; p.XP = Config.MaxXP - 3
 assert(not Journey.ClaimAchievement(Config, p, 'first_home').ok)
 assert(not p.AchievementClaims.first_home and p.EquippedTitle == '' and p.XP == Config.MaxXP - 3)
 p.Coins -= Config.GetAchievement('first_home').RewardCoins
 assert(Journey.ClaimAchievement(Config, p, 'first_home').ok and p.Coins == Config.MaxCoins and p.XP == Config.MaxXP)
 assert(not Journey.ClaimAchievement(Config, p, 'first_home').ok)
end)

check('titles require claimed achievement ownership and later claims preserve selected title', function()
 local p = fresh(); p.Floor = 3
 assert(not Journey.EquipTitle(Config, p, 'first_home').ok and p.EquippedTitle == '')
 assert(not Journey.EquipTitle(Config, p, 'forged').ok)
 assert(Journey.ClaimAchievement(Config, p, 'first_home').ok and p.EquippedTitle == 'first_home')
 assert(Journey.ClaimAchievement(Config, p, 'penthouse').ok and p.EquippedTitle == 'first_home')
 assert(Journey.EquipTitle(Config, p, 'penthouse').ok and p.EquippedTitle == 'penthouse')
 assert(Journey.EquipTitle(Config, p, '').ok and p.EquippedTitle == '')
 assert(Journey.EquipTitle(Config, p, 'first_home').ok and p.EquippedTitle == 'first_home')
 local copy = Schema.Normalize(Schema.Copy(p), Config, now)
 assert(copy.EquippedTitle == 'first_home' and copy.AchievementClaims.first_home and copy.AchievementClaims.penthouse)
end)

check('legacy save migration is additive and skips tutorial rewards for progressed players', function()
 local old = {Coins = 800, XP = 230, Floor = 2, DropperTier = 3, Bank = 55, Rebirths = 0,
  EquippedHero = 'nightweaver', CollectedTotal = 1000, EnemiesDefeated = 11,
  Inventory = {arc_rifle = 2}, EquippedWeapon = 'arc_rifle', WeaponUpgrades = {['loot:arc_rifle'] = 3},
  QuestClaims = {collector = true}, DailyReadyAt = now + 100,
  ObbyWins = 3, ObbyReadyAt = now + 60, ObbyBestMilliseconds = 22000}
 local p = Schema.Normalize(old, Config, now)
 for _, key in ipairs({'Coins','XP','Floor','DropperTier','Bank','Rebirths','EquippedHero','CollectedTotal','EnemiesDefeated','EquippedWeapon','DailyReadyAt','ObbyWins','ObbyReadyAt','ObbyBestMilliseconds'}) do
  assert(p[key] == old[key], 'Legacy field lost: ' .. key)
 end
 assert(p.Inventory.arc_rifle == 2 and p.WeaponUpgrades['loot:arc_rifle'] == 3 and p.QuestClaims.collector)
 assert(p.TutorialStep == 7 and p.BossDefeated == 0 and p.CombatPractice == false)
 assert(p.DailyStreak == 0 and p.DailyLastClaimAt == 0 and p.EquippedTitle == '' and next(p.AchievementClaims) == nil)
 assert(#advance(p, true) == 0 and p.Coins == 800 and p.XP == 230, 'Migration cannot replay training payouts')
 for _, legacy in ipairs({{Floor = 1}, {XP = 1}, {Rebirths = 1}, {CollectedTotal = 1}, {Inventory = {pulse_pistol = 1}}}) do
  assert(Schema.Normalize(legacy, Config, now).TutorialStep == 7)
 end
 assert(Schema.Normalize({Coins = 75}, Config, now).TutorialStep == 1)
end)

check('schema normalizes invalid new counters and permits only real claimed cosmetic titles', function()
 local p = Schema.Normalize({BossDefeated = 0/0, DailyStreak = math.huge, DailyLastClaimAt = -12,
  TutorialStep = 'done', CombatPractice = 'true', AchievementClaims = {first_home = true, penthouse = 'true', fake = true},
  EquippedTitle = 'penthouse'}, Config, now)
 assert(p.BossDefeated == 0 and p.DailyStreak == 0 and p.DailyLastClaimAt == 0 and p.TutorialStep == 1 and not p.CombatPractice)
 assert(p.AchievementClaims.first_home == true and not p.AchievementClaims.penthouse and not p.AchievementClaims.fake and p.EquippedTitle == '')
 local bounded = Schema.Normalize({BossDefeated = Config.MaxCoins + 10, DailyStreak = 99, DailyLastClaimAt = now + 100,
  TutorialStep = 99, CombatPractice = true, AchievementClaims = {first_home = true}, EquippedTitle = 'first_home'}, Config, now)
 assert(bounded.BossDefeated == Config.MaxCoins and bounded.DailyStreak == 7 and bounded.DailyLastClaimAt == now)
 assert(bounded.TutorialStep == 7 and bounded.CombatPractice and bounded.EquippedTitle == 'first_home')
 local negative = Schema.Normalize({BossDefeated = -1, TutorialStep = -7}, Config, now)
 assert(negative.BossDefeated == 0 and negative.TutorialStep == 1)
 assert(Schema.Normalize({TutorialStep = 3.9, XP = 10}, Config, now).TutorialStep == 3)
 assert(Schema.Normalize({TutorialStep = 0/0, XP = 10}, Config, now).TutorialStep == 7)
end)

check('save snapshots deep-copy every mutable collection and retain journey counters', function()
 local p = fresh(); p.Floor = 1; p.Inventory.arc_rifle = 2; p.WeaponUpgrades['loot:arc_rifle'] = 3
 p.QuestClaims.collector = true; p.AchievementClaims.first_home = true; p.EquippedTitle = 'first_home'
 p.TutorialStep = 6; p.CombatPractice = true; p.BossDefeated = 4; p.DailyStreak = 3; p.DailyLastClaimAt = now
 local copy = Schema.Copy(p)
 assert(copy.TutorialStep == 6 and copy.CombatPractice and copy.BossDefeated == 4 and copy.DailyStreak == 3 and copy.DailyLastClaimAt == now)
 p.Inventory.arc_rifle = 99; p.WeaponUpgrades['loot:arc_rifle'] = 5; p.QuestClaims.collector = false; p.AchievementClaims.first_home = false
 assert(copy.Inventory.arc_rifle == 2 and copy.WeaponUpgrades['loot:arc_rifle'] == 3 and copy.QuestClaims.collector and copy.AchievementClaims.first_home)
 copy.Inventory.solar_lance = 1; copy.AchievementClaims.penthouse = true
 assert(p.Inventory.solar_lance == nil and p.AchievementClaims.penthouse == nil)
 assert(Schema.Normalize(copy, Config, now).EquippedTitle == 'first_home')
end)

check('daily reward preview follows all seven days and wraps without mutating the profile', function()
 local p = fresh(); local clock = now
 for expectedDay = 1, 7 do
  local beforeLast, beforeStreak = p.DailyLastClaimAt, p.DailyStreak
  local reward, day = Config.NextDailyReward(p, clock)
  assert(day == expectedDay and reward == Config.DailyRewards[expectedDay])
  assert(p.DailyLastClaimAt == beforeLast and p.DailyStreak == beforeStreak, 'Preview cannot commit daily reward')
  p.DailyLastClaimAt = clock; p.DailyStreak = day; clock += Config.DailyCooldown
 end
 local reward, day = Config.NextDailyReward(p, clock)
 assert(day == 1 and reward == 500)
end)

check('daily preview preserves streak through grace boundary and resets after lapse or clock reversal', function()
 local p = fresh(); p.DailyLastClaimAt = now; p.DailyStreak = 3
 local reward, day = Config.NextDailyReward(p, now + Config.DailyCooldown * 2)
 assert(day == 4 and reward == 800)
 reward, day = Config.NextDailyReward(p, now + Config.DailyCooldown * 2 + 1)
 assert(day == 1 and reward == 500)
 reward, day = Config.NextDailyReward(p, now - 1)
 assert(day == 1 and reward == 500)
 local snapshot = Schema.Normalize(Schema.Copy(p), Config, now)
 assert(Config.NextDailyReward(snapshot, now + Config.DailyCooldown) == 800, 'Persisted streak must continue after reconnect')
end)
return cases
`;

const source = [
  `local Config = (function()\n${config}\nend)()`,
  `local Schema = (function()\n${schema}\nend)()`,
  `local Journey = (function()\n${journey}\nend)()`,
  assertions,
].join('\n');
const state = await LuauState.createAsync();
try {
  const result = await state.loadstring(source, 'Production tutorial, achievements and migration', true)();
  console.log(`Journey tests passed: ${result[0]} cases for six tutorial steps, gated/once-only rewards, achievements, caps, titles, old-save migration, deepcopy, invalid counters and seven-day daily preview.`);
} finally {
  state.destroy();
}

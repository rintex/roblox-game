// Real server loot code under deterministic mocks; Studio validates the falling visuals.
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LuauState } from 'luau-web';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [config, service] = await Promise.all([
  readFile(resolve(root, 'src/shared/TycoonConfig.luau'), 'utf8'),
  readFile(resolve(root, 'src/server/Modules/LootDropService.luau'), 'utf8'),
]);

const mock = String.raw`
local Players, Workspace, RunService, TweenService = {}, {}, {}, {}
local game = {GetService=function(_,name) return ({Players=Players,Workspace=Workspace,RunService=RunService,TweenService=TweenService})[name] end}
local Random = {new=function() return {NextNumber=function() return 0 end} end}
local vectorMeta = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
function vectorMeta.__sub(a,b)
 local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
 return {Magnitude=math.sqrt(x*x+y*y+z*z)}
end
`;

const checks = String.raw`
local H=Service.Helpers
assert(H.WeightedRoll(Config.Weapons,0).Id=='pulse_pistol')
assert(H.WeightedRoll(Config.Weapons,0.3999).Id=='pulse_pistol')
assert(H.WeightedRoll(Config.Weapons,0.4).Id=='thread_launcher')
assert(H.WeightedRoll(Config.Weapons,0.68).Id=='arc_rifle')
assert(H.WeightedRoll(Config.Weapons,0.86).Id=='gravity_hammer')
assert(H.WeightedRoll(Config.Weapons,0.95).Id=='frost_projector')
assert(H.WeightedRoll(Config.Weapons,0.99).Id=='solar_lance')
assert(H.WeightedRoll(Config.Weapons,1).Id=='solar_lance')
assert(H.WeightedRoll({},0)==nil and H.WeightedRoll(Config.Weapons,0/0)==nil)
local weights={}
for index=0,9999 do
 local id=H.WeightedRoll(Config.Weapons,index/10000).Id
 weights[id]=(weights[id] or 0)+1
end
for _,weapon in ipairs(Config.Weapons) do
 assert(weights[weapon.Id]==weapon.LootWeight*100,weapon.Id..' weight mismatch')
end

local profile={Inventory={},Coins=Config.StartingCoins}
local first=H.Grant(Config,profile,Config.Weapons[1])
assert(first.count==1 and not first.duplicate and profile.Inventory.pulse_pistol==1 and profile.Coins==75)
assert(H.Grant(Config,profile,{Id='bad'})==nil and profile.Inventory.bad==nil)
assert(H.Grant(Config,profile,Config.Weapons[1]).duplicate and profile.Inventory.pulse_pistol==2)
profile.Inventory.pulse_pistol=99
local capped=H.Grant(Config,profile,Config.Weapons[1])
assert(capped.count==99 and capped.compensationCoins==100 and profile.Coins==175)
profile.Coins=Config.MaxCoins-2
assert(H.Grant(Config,profile,Config.Weapons[1]).compensationCoins==2 and profile.Coins==Config.MaxCoins)
assert(H.Grant(Config,profile,Config.Weapons[1]).compensationCoins==0 and profile.Coins==Config.MaxCoins)

local function player()
 local p={Parent=Players,attrs={DataReady=true}}
 function p:GetAttribute(name) return self.attrs[name] end
 p.root={Position=vec(0,3,0),IsA=function(_,name) return name=='BasePart' end}
 p.humanoid={Health=100}
 p.Character={FindFirstChildOfClass=function() return p.humanoid end,FindFirstChild=function() return p.root end}
 return p
end
local a,b=player(),player()
local profiles={records={},closing=false}
function profiles:Get(p) return self.records[p] end
function profiles:IsClosing() return self.closing end
local states={}
local tycoon={GetState=function(_,p) return states[p] end}
local noticeCount,resultCount=0,0
local notice={FireClient=function() noticeCount+=1 end}
local lootResult={FireClient=function(_,p,result)
 assert(profiles.records[p].Inventory[result.weaponId]==result.count,'inventory must precede result')
 resultCount+=1
end}
local s=Service.new(Config,profiles,tycoon,notice,lootResult)
s.folder={Parent=Workspace,Destroy=function(self) self.Parent=nil end}
local function reset()
 for _,p in ipairs({a,b}) do
  profiles.records[p]={Coins=75,Inventory={}}
  states[p]={profile=profiles.records[p]}
 end
 a.Parent=Players
 a.attrs.DataReady=true
 a.root.Position=vec(0,3,0)
 a.humanoid.Health=100
 profiles.closing=false
 s.destroyed=false
 s.folder.Parent=Workspace
 s.lastAttemptAt={}
 local drop={landed=true,claimed=false,removed=false,expiresAt=os.clock()+90,connections={}}
 drop.model={Parent=s.folder,Destroy=function(self) self.Parent=nil end}
 drop.body={Position=vec(0,2.7,0),IsDescendantOf=function(_,parent) return parent==drop.model end}
 drop.prompt={Enabled=true,Parent=drop.body}
 drop.tween={Cancel=function() end}
 s.active=drop
 tycoon.SyncPlayer=function(_,p) assert(profiles:Get(p).Inventory.pulse_pistol==1) end
 return drop
end

local drop=reset()
local rewards=resultCount
s:_claim(a,drop)
s:_claim(b,drop)
s:_claim(a,drop)
assert(profiles.records[a].Inventory.pulse_pistol==1 and not profiles.records[b].Inventory.pulse_pistol
 and resultCount==rewards+1 and not s.active and drop.removed,'crate must grant once')
local failures={
 function(d) a.root.Position=vec(100,3,0) end,
 function(d) a.root.Position=vec(0/0,3,0) end,
 function(d) a.humanoid.Health=0 end,
 function(d) a.humanoid.Health=0/0 end,
 function(d) a.attrs.DataReady=false end,
 function(d) a.Parent=nil end,
 function(d) profiles.closing=true end,
 function(d) profiles.records[a]=nil end,
 function(d) states[a].profile={} end,
 function(d) states[a].leaving=true end,
 function(d) d.expiresAt=0 end,
 function(d) d.landed=false end,
 function(d) d.prompt.Enabled=false end,
 function(d) d.model.Parent=nil end,
 function(d) d.prompt.Parent=nil end,
 function(d) s.folder.Parent=nil end,
 function(d) s.active={} end,
}
for index,change in ipairs(failures) do
 local d=reset()
 local original=profiles.records[a]
 local before=resultCount
 change(d)
 s:_claim(a,d)
 assert(next(original.Inventory)==nil and resultCount==before,'server guard '..index)
end

-- Reentrant sync cannot award the crate again; a lost profile receives no result.
drop=reset()
local before=resultCount
local awardedProfile=profiles.records[a]
tycoon.SyncPlayer=function()
 s:_claim(b,drop)
 profiles.records[a]=nil
end
s:_claim(a,drop)
assert(awardedProfile.Inventory.pulse_pistol==1 and not profiles.records[b].Inventory.pulse_pistol
 and resultCount==before,'sync reentry/profile loss')

-- Deleted and expired drops are removed; a stalled fall has a bounded timeout.
for _,reason in ipairs({'expired','removed','timeout'}) do
 local d=reset()
 s.nextDropAt=math.huge
 if reason=='expired' then d.expiresAt=0
 elseif reason=='removed' then d.model.Parent=nil
 else d.landed=false; d.landDeadline=0 end
 s:_step(os.clock())
 assert(not s.active and d.removed and not d.prompt.Enabled,reason..' cleanup')
end
reset()
local closingDrop=s.active
profiles.closing=true
s:_step(os.clock())
assert(s.destroyed and not s.active and closingDrop.removed and not s.folder,'shutdown cleanup')
s:Destroy()
return true
`;

const vm = await LuauState.createAsync();
try {
  const run = vm.loadstring(`${mock}\nlocal Config=(function()\n${config}\nend)()\nlocal Service=(function()\n${service}\nend)()\n${checks}`, 'LootDrop deterministic economy and server guards', true);
  const [passed] = await run();
  if (passed !== true) throw new Error('LootDrop tests did not complete');
  console.log('LootDrop tests passed: exact weapon weights, inventory-first rewards, duplicate compensation/caps, 17 server guards, single claim, reentrant sync/profile loss, expiry/deletion/fall timeout/shutdown.');
} finally {
  vm.destroy();
}

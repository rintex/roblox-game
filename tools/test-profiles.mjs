// Executes production persistence Luau with deterministic DataStore/task doubles.
// This checks locking/lifecycle policy, not connectivity to Roblox DataStore.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const [config,schema,service]=await Promise.all([
 readFile('src/shared/TycoonConfig.luau','utf8'),
 readFile('src/server/Modules/ProfileSchema.luau','utf8'),
 readFile('src/server/Modules/ProfileService.luau','utf8'),
]);
const mock=String.raw`
local Config=(function() CONFIG_SOURCE end)()
local Schema=(function() SCHEMA_SOURCE end)()
local clock=0
local os={time=function() return 1000000 end,clock=function() return clock end}
local taskQueue={}
local task={spawn=function(fn) table.insert(taskQueue,fn) end,
 wait=function(seconds) clock+=seconds or 0.1; coroutine.yield('wait') end}
local function warn() end
local function clone(value)
 if type(value)~='table' then return value end
 local result={}; for k,v in pairs(value) do result[k]=clone(v) end; return result
end
local store={data={},calls=0,fail=false,blockBefore=false,blockAfter=false}
function store:UpdateAsync(key,callback)
 self.calls+=1
 if self.fail then error('Simulated DataStore outage') end
 if self.blockBefore then self.blockBefore=false; coroutine.yield('store-before') end
 local proposed=callback(clone(self.data[key]))
 if proposed~=nil then self.data[key]=clone(proposed) end
 if self.blockAfter then self.blockAfter=false; coroutine.yield('store-after') end
 return clone(proposed)
end
local studio=false
local guid=0
local binds={}
local game={JobId='Server_A',GameId=123,
 GetService=function(_,name)
  if name=='DataStoreService' then return {GetDataStore=function() return store end} end
  if name=='HttpService' then return {GenerateGUID=function() guid+=1;return 'Guid_'..guid end} end
  if name=='RunService' then return {IsStudio=function() return studio end} end
  error(name)
 end,
 BindToClose=function(_,fn) table.insert(binds,fn) end,
}
local script={Parent={WaitForChild=function(_,name) return name end}}
local function require(name) assert(name=='ProfileSchema'); return Schema end
local Service=(function() SERVICE_SOURCE end)()
local function player(id)
 return {UserId=id,attrs={},SetAttribute=function(self,k,v) self.attrs[k]=v end,
  GetAttribute=function(self,k) return self.attrs[k] end,Kick=function(self,text) self.kicked=text end}
end
local function resume(thread)
 local ok,result=coroutine.resume(thread)
 assert(ok,tostring(result))
 return result
end
local function complete(fn)
 local thread=coroutine.create(fn)
 local result=resume(thread)
 for _=1,1000 do
  if coroutine.status(thread)=='dead' then return result end
  result=resume(thread)
 end
 error('Operation did not finish')
end
local tests=0
local function check(name,fn) fn();tests+=1 end
check('new profile and saved round trip',function()
 local s=Service.new(Config);local p=player(1);local data=s:Load(p)
 assert(data.Coins==75 and p.attrs.PersistenceMode=='saved')
 data.Coins=444; data.Floor=2;data.DropperTier=1;data.Bank=34;data.XP=140;data.BonusReadyAt=1000100
 data.Inventory.arc_rifle=2;data.EquippedWeapon='arc_rifle';data.WeaponUpgrades={['loot:arc_rifle']=3,['hero:arachna']=2};data.QuestClaims.collector=true
 data.ObbyWins=3;data.ObbyReadyAt=1000150;data.ObbyBestMilliseconds=21500
 assert(s:Save(p));assert(store.data.Player_1.Data.Coins==444)
 assert(s:Release(p));assert(store.data.Player_1.Session==nil)
 local s2=Service.new(Config);local p2=player(1);local restored=s2:Load(p2)
 assert(restored.Coins==444 and restored.Floor==2 and restored.Bank==34 and restored.XP==140)
 assert(restored.Inventory.arc_rifle==2 and restored.EquippedWeapon=='arc_rifle' and restored.QuestClaims.collector)
 assert(restored.WeaponUpgrades['loot:arc_rifle']==3 and restored.WeaponUpgrades['hero:arachna']==2)
 assert(restored.ObbyWins==3 and restored.ObbyReadyAt==1000150 and restored.ObbyBestMilliseconds==21500)
 assert(s2:Release(p2))
end)
check('different servers and same-server reconnects cannot share a lock',function()
 local s=Service.new(Config);local p=player(2);assert(s:Load(p))
 local other=player(2);local profile,message=s:Load(other)
 assert(profile==nil and string.find(message,'другом сервере'))
 local different=Service.new(Config);assert(different:Load(player(2))==nil)
 assert(s:Release(p));assert(s:Load(other));assert(s:Release(other))
end)
check('expired lease restores progress with a new token',function()
 store.data.Player_3={Version=1,Data={Coins=900,Floor=3},Session={Id='expired',ExpiresAt=999999}}
 local s=Service.new(Config);local p=player(3);assert(s:Load(p).Coins==900)
 assert(store.data.Player_3.Session.Id~='expired');assert(s:Release(p))
end)
check('unknown data never overwritten',function()
 store.data.Player_4={Version=99,Data={Coins=765}}
 local s=Service.new(Config);assert(s:Load(player(4))==nil)
 assert(store.data.Player_4.Version==99 and store.data.Player_4.Data.Coins==765)
end)
check('upgrade schema rejects corrupt IDs and levels and makes independent snapshots',function()
 local data=Schema.Normalize({Inventory={arc_rifle=1},WeaponUpgrades={['loot:arc_rifle']=90,['hero:arachna']=2,['hero:volt']=0/0,['loot:solar_lance']=5,['forged:weapon']=3}},Config,os.time())
 assert(data.WeaponUpgrades['loot:arc_rifle']==5 and data.WeaponUpgrades['hero:arachna']==2)
 assert(not data.WeaponUpgrades['hero:volt'] and not data.WeaponUpgrades['loot:solar_lance'] and not data.WeaponUpgrades['forged:weapon'])
 local copy=Schema.Copy(data);copy.WeaponUpgrades['hero:arachna']=4;assert(data.WeaponUpgrades['hero:arachna']==2)
 local old=Schema.Normalize({Coins=900,Floor=2},Config,os.time());assert(next(old.WeaponUpgrades)==nil and old.Coins==900)
end)
check('schema rejects NaN infinity negative and oversized values',function()
 local data=Schema.Normalize({Coins=0/0,XP=math.huge,Floor=90,DropperTier=-9,Bank=9999999,BonusReadyAt=math.huge},Config,os.time())
 assert(data.Coins==75 and data.XP==0 and data.Floor==3 and data.DropperTier==0 and data.Bank==Config.MaxBank)
 local empty=Schema.Normalize({Floor=0,DropperTier=3,Bank=999},Config,os.time())
 assert(empty.DropperTier==0 and empty.Bank==0)
end)
check('legacy profiles preserve progress and start with an empty inventory',function()
 local old=Schema.Normalize({Coins=800,XP=230,Floor=2,DropperTier=3,Bank=55},Config,os.time())
 assert(old.Coins==800 and old.XP==230 and old.Floor==2 and old.Bank==55)
 assert(old.Rebirths==0 and next(old.Inventory)==nil and old.EquippedWeapon=='' and next(old.QuestClaims)==nil)
 assert(old.ObbyReadyAt==0 and old.ObbyWins==0 and old.ObbyBestMilliseconds==0)
end)
check('inventory accepts known owned weapons and bounds copies',function()
 local checked=Schema.Normalize({Floor=1,EquippedHero='helios',EquippedWeapon='arc_rifle',
  Inventory={arc_rifle=2.9,solar_lance=900,unknown_weapon=1,pulse_pistol=0/0,thread_launcher=-2},
  QuestClaims={fighter=true,unknown=true,collector='true'}},Config,os.time())
 assert(checked.Inventory.arc_rifle==2 and checked.Inventory.solar_lance==99)
 assert(checked.Inventory.unknown_weapon==nil and checked.Inventory.pulse_pistol==nil and checked.Inventory.thread_launcher==nil)
 assert(checked.EquippedWeapon=='arc_rifle' and checked.EquippedHero=='')
 assert(checked.QuestClaims.fighter and not checked.QuestClaims.unknown and not checked.QuestClaims.collector)
 assert(Schema.Normalize({EquippedWeapon='solar_lance',Inventory={arc_rifle=1}},Config,os.time()).EquippedWeapon=='')
end)
check('save snapshots independently copy inventory and quest claims',function()
 local data=Schema.New(Config);data.Inventory.arc_rifle=1;data.QuestClaims.collector=true
 local snapshot=Schema.Copy(data);data.Inventory.arc_rifle=8;data.QuestClaims.collector=false
 assert(snapshot.Inventory.arc_rifle==1 and snapshot.QuestClaims.collector==true)
 snapshot.Inventory.solar_lance=1;assert(data.Inventory.solar_lance==nil)
end)
check('production load failures do not create defaults or overwrite data',function()
 local s=Service.new(Config);local p=player(5);store.fail=true
 local before=store.calls
 complete(function() assert(s:Load(p)==nil) end)
 assert(store.calls-before==3 and s:Get(p)==nil and store.data.Player_5==nil)
 store.fail=false
end)
check('Studio preview fallback is explicitly session-only',function()
 studio=true;game.GameId=0
 local s=Service.new(Config);local p=player(6);local before=store.calls
 assert(s:Load(p).Coins==75 and p.attrs.PersistenceMode=='session')
 assert(s:Save(p) and s:Release(p));assert(store.calls==before)
 game.GameId=123;studio=false
end)
check('save failures retain latest profile for a later final retry',function()
 local s=Service.new(Config);local p=player(7);local data=s:Load(p);data.Coins=555
 store.fail=true;complete(function() assert(not s:Release(p)) end)
 assert(s.records[p] and s:Get(p)==nil and p.attrs.PersistenceStatus=='error')
 store.fail=false;assert(s:Release(p));assert(store.data.Player_7.Data.Coins==555 and store.data.Player_7.Session==nil)
end)
check('lost lock forbids stale write',function()
 local s=Service.new(Config);local p=player(8);local data=s:Load(p);data.Coins=999
 store.data.Player_8.Session={Id='another_session',ExpiresAt=1000900}
 store.data.Player_8.Data.Coins=333
 assert(not s:Save(p));assert(store.data.Player_8.Data.Coins==333 and p.kicked and s:Get(p)==nil)
end)
check('exit waits for loading then unlocks without starter overwrite',function()
 local s=Service.new(Config);local p=player(9)
 store.data.Player_9={Version=1,Data={Coins=888,Floor=2}}
 store.blockAfter=true
 local loading=coroutine.create(function() assert(s:Load(p)==nil) end)
 assert(resume(loading)=='store-after')
 local releasing=coroutine.create(function() assert(s:Release(p)) end)
 assert(resume(releasing)=='wait')
 resume(loading);assert(coroutine.status(loading)=='dead')
 resume(releasing);assert(coroutine.status(releasing)=='dead')
 assert(store.data.Player_9.Session==nil and store.data.Player_9.Data.Coins==888)
end)
check('two simultaneous final releases share completion',function()
 local s=Service.new(Config);local p=player(10);s:Load(p).Coins=555
 store.blockAfter=true
 local first=coroutine.create(function() assert(s:Release(p)) end);assert(resume(first)=='store-after')
 local calls=store.calls
 local second=coroutine.create(function() assert(s:Release(p)) end);assert(resume(second)=='wait')
 resume(first);resume(second)
 assert(store.calls==calls and s.records[p]==nil and store.data.Player_10.Data.Coins==555)
end)
check('autosave plus exit saves latest snapshot after in-flight save',function()
 local s=Service.new(Config);local p=player(11);local data=s:Load(p);data.Coins=111
 store.blockAfter=true
 local saving=coroutine.create(function() assert(s:Save(p)) end);assert(resume(saving)=='store-after')
 data.Coins=777
 local releasing=coroutine.create(function() assert(s:Release(p)) end);assert(resume(releasing)=='wait')
 resume(saving);resume(releasing)
 assert(store.data.Player_11.Data.Coins==777 and store.data.Player_11.Session==nil)
end)
check('expired old writer cannot overwrite same-server new arrival',function()
 local s=Service.new(Config);local p=player(12);s:Load(p).Coins=456
 local token=s.records[p].token
 store.blockBefore=true
 local saving=coroutine.create(function() assert(not s:Save(p)) end);assert(resume(saving)=='store-before')
 store.data.Player_12.Session.ExpiresAt=999999
 local newPlayer=player(12);local newData=s:Load(newPlayer)
 assert(newData and s.records[newPlayer].token~=token)
 newData.Coins=777
 resume(saving)
 assert(s:Get(newPlayer)==newData and store.data.Player_12.Session.Id==s.records[newPlayer].token)
 assert(s:Save(newPlayer) and s:Release(newPlayer));assert(store.data.Player_12.Data.Coins==777)
end)
check('shutdown waits for pending final save',function()
 local s=Service.new(Config);local p=player(13);s:Load(p).Coins=555
 local closing=coroutine.create(binds[#binds]);assert(resume(closing)=='wait')
 assert(s:IsClosing() and coroutine.status(closing)=='suspended')
 store.blockAfter=true
 local final=coroutine.create(taskQueue[#taskQueue]);assert(resume(final)=='store-after')
 assert(resume(closing)=='wait')
 resume(final);resume(closing)
 assert(coroutine.status(closing)=='dead' and store.data.Player_13.Session==nil)
end)
return tests
`;
const code=mock.replace('CONFIG_SOURCE',config).replace('SCHEMA_SOURCE',schema).replace('SERVICE_SOURCE',service);
const state=await LuauState.createAsync();
try {
 const run=state.loadstring(code,'Profile lifecycle tests',true);
 const result=await run();
 console.log(`Profile tests passed: ${result[0]} cases for persistence, corruption, lease conflicts, outages, reconnects, loading exit, concurrent final saves, and shutdown.`);
} finally {state.destroy();}

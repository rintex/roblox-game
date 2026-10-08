// Headless policy checks; no real purchases, Robux or Creator Hub operations.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const [money,admin]=await Promise.all([readFile('src/server/Modules/MonetizationService.luau','utf8'),readFile('src/server/Modules/AdminService.luau','utf8')]);
const source=String.raw`
local now=0;local os={clock=function() return now end}
local queued={}
local task={spawn=function(fn) table.insert(queued,fn) end,defer=function(fn) table.insert(queued,fn) end}
local function signal()
 local entries={}
 return {Connect=function(self,fn)
  local c={active=true};function c:Disconnect() self.active=false end
  table.insert(entries,{c,fn});self.callback=fn;return c
 end,Fire=function(self,...)
  for _,entry in ipairs(entries) do if entry[1].active then entry[2](...) end end
 end,ActiveCount=function()
  local count=0;for _,entry in ipairs(entries) do if entry[1].active then count+=1 end end;return count
 end}
end
local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {} end}
local studio=false
local market={PromptGamePassPurchaseFinished=signal(),checks=0,prompts=0,owned=false,sale=true,fail=false,
 UserOwnsGamePassAsync=function(self,id,pass) self.checks+=1;if self.blockOwn then self.blockOwn=false;coroutine.yield('ownership') end;if self.fail then error('unavailable') end;return self.owned end,
 GetProductInfo=function(self) if self.blockInfo then self.blockInfo=false;coroutine.yield('product') end;return {IsForSale=self.sale} end,
 PromptGamePassPurchase=function(self) self.prompts+=1 end}
local Enum={InfoType={GamePass='GamePass'},CreatorType={User='User',Group='Group'},Font={GothamBold='GothamBold'}}
local Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
local UDim2={fromOffset=function(x,y) return {x,y} end,fromScale=function(x,y) return {x,y} end}
local Color3={fromRGB=function(r,g,b) return {r,g,b} end}
local Instance={}
function Instance.new(class)
 local stored={};local object={ClassName=class,children={}}
 function object:IsA(target) return self.ClassName==target end
 function object:FindFirstChild(name) return self.children[name] end
 function object:Destroy() if self.Parent then self.Parent.children[self.Name]=nil end;self.Parent=nil end
 return setmetatable(object,{__index=function(_,key) return stored[key] end,__newindex=function(self,key,value)
  if key=='Parent' then
   local old=stored[key];if old then old.children[self.Name]=nil end
   stored[key]=value;if value then value.children[self.Name]=self end
  else rawset(self,key,value) end
 end})
end
local game={GameId=123,CreatorId=7,CreatorType='User',GetService=function(_,name)
 if name=='Players' then return players elseif name=='MarketplaceService' then return market
 elseif name=='RunService' then return {IsStudio=function() return studio end} end;error(name)
end}
local Config={MaxCoins=1000000000,AdminUserIds={},GamePasses={VIP={Id=0,Name='VIP'},Neon={Id=0,Name='Neon'}}}
local profile={Coins=0};local closing=false
local profiles={Get=function(_,player) return player.ready and profile or nil end,IsClosing=function() return closing end}
local function player(id)
 return {UserId=id,Parent=players,ready=true,attrs={DataReady=true},signals={},CharacterAdded=signal(),GetAttribute=function(self,k) return self.attrs[k] end,
 SetAttribute=function(self,k,v) self.attrs[k]=v end,FindFirstChildOfClass=function() return nil end,
 GetAttributeChangedSignal=function(self,k) self.signals[k]=self.signals[k] or signal();return self.signals[k] end,
 WaitForChild=function() return nil end,
 GetRankInGroup=function(self) if self.blockRank then self.blockRank=false;coroutine.yield('rank') end;return self.rank or 0 end}
end
local notice={FireClient=function() end};local request={OnServerEvent=signal()}
local Commerce=(function() MONEY_SOURCE end)()
local money=Commerce.new(Config,profiles,notice,request);money:Start()
local p=player(7);money.states[p]={last=-math.huge}
money:_request(p,'VIP');assert(market.prompts==0 and market.checks==0,'Disabled passes must make no purchase API calls')
money:_request(p,999);money:_request(p,'NotAPass');assert(market.prompts==0)
Config.GamePasses.VIP.Id=101;now=4;money:_request(p,'VIP');assert(market.prompts==1)
money:_request(p,'VIP');assert(market.prompts==1,'Prompt flood must be throttled')
market.PromptGamePassPurchaseFinished.callback(p,101,false);assert(p.attrs.HasVIP~=true)
market.PromptGamePassPurchaseFinished.callback(p,987654,true);assert(p.attrs.HasVIP~=true)
market.PromptGamePassPurchaseFinished.callback(p,101,true);assert(p.attrs.HasVIP~=true,'Unverified finished event must not grant VIP')
market.owned=true;market.PromptGamePassPurchaseFinished.callback(p,101,true);assert(p.attrs.HasVIP==true)
market.fail=true;local p2=player(8);money.states[p2]={last=-math.huge};market.PromptGamePassPurchaseFinished.callback(p2,101,true)
assert(p2.attrs.HasVIP~=true,'Ownership API failure must fail closed');market.fail=false;market.owned=false
market.sale=false;now=10;money:_request(p2,'VIP');assert(market.prompts==1,'Off-sale pass must not prompt')
market.sale=true;p2.ready=false;now=14;money:_request(p2,'VIP');assert(market.prompts==1)
local sync=0;local tycoon={SyncPlayer=function() sync+=1 end}
local Admin=(function() ADMIN_SOURCE end)()
local admin=Admin.new(Config,profiles,tycoon,notice,request)
assert(admin:IsAuthorized(p));assert(not admin:IsAuthorized(p2))
game.CreatorType='Group';game.CreatorId=44;p2.rank=254;assert(not admin:IsAuthorized(p2));p2.rank=255;assert(admin:IsAuthorized(p2))
game.CreatorType='User';game.CreatorId=7
studio=true;game.GameId=0;assert(admin:IsAuthorized(p2));game.GameId=123;assert(not admin:IsAuthorized(p2));studio=false
Config.AdminUserIds={8};assert(admin:IsAuthorized(p2));Config.AdminUserIds={}
admin.states[p]={authorized=true,last=-math.huge};admin.states[p2]={authorized=false,last=-math.huge}
p2.attrs.IsGameAdmin=true;p2.ready=true;now=20;admin:_request(p2,'GrantCoins');assert(profile.Coins==0,'Client attr spoof must not authorize')
admin:_request(p,'GrantCoins');assert(profile.Coins==25000 and sync==1)
admin:_request(p,'GrantCoins');assert(profile.Coins==25000)
now=22;closing=true;admin:_request(p,'GrantCoins');assert(profile.Coins==25000);closing=false
now=24;admin:_request(p,'PreviewNeon');assert(p.attrs.HasNeon~=true,'Preview must be Studio-only')
now=26;p.attrs.ObbyActive=true;p.attrs.ArenaCombatOptIn=true;admin:_request(p,'TeleportHome')
assert(p.attrs.ArenaCombatOptIn==true,'Home teleport must be rejected during an active obby');p.attrs.ObbyActive=false
-- Character observers are replaced on respawn instead of accumulating forever.
local function character()
 return {ChildAdded=signal(),FindFirstChild=function() return nil end,GetChildren=function() return {} end,
  WaitForChild=function() return nil end}
end
local p3=player(9);p3.Character=character();local old=p3.Character
local lifecycle=Commerce.new(Config,profiles,notice,request);lifecycle:_add(p3)
assert(old.ChildAdded:ActiveCount()==1)
for _=1,12 do
 p3.Character=character();p3.CharacterAdded:Fire(p3.Character)
 assert(old.ChildAdded:ActiveCount()==0 and #lifecycle.states[p3].characterConnections==1)
 old=p3.Character
end
local checksBefore=market.checks
lifecycle:Destroy();assert(old.ChildAdded:ActiveCount()==0 and p3.CharacterAdded:ActiveCount()==0)
for _,fn in ipairs(queued) do fn() end
assert(market.checks==checksBefore and not lifecycle.states[p3],'Queued callbacks must stay inert after teardown')
-- Free achievement titles share a billboard with VIP instead of covering it.
local pTitle=player(12);local head=Instance.new('Part');head.Name='Head'
pTitle.Character={FindFirstChild=function(_,name) if name=='Head' then return head end end,GetChildren=function() return {} end}
local titles=Commerce.new(Config,profiles,notice,request);titles.states[pTitle]={last=-math.huge}
pTitle.attrs.DisplayTitle='Строитель';titles:_cosmetics(pTitle)
local title=head:FindFirstChild('HeroClubTitle');assert(title and title:FindFirstChild('Title').Text=='Строитель')
pTitle.attrs.HasVIP=true;titles:_cosmetics(pTitle)
assert(title:FindFirstChild('Title').Text=='КЛУБ ГЕРОЕВ · Строитель')
pTitle.attrs.DisplayTitle='';titles:_cosmetics(pTitle);assert(title:FindFirstChild('Title').Text=='КЛУБ ГЕРОЕВ')
pTitle.attrs.HasVIP=false;titles:_cosmetics(pTitle);assert(not head:FindFirstChild('HeroClubTitle'))
-- Ownership and product lookups may resume after the service was destroyed.
local p4=player(10);local pending=Commerce.new(Config,profiles,notice,request);pending.states[p4]={last=-math.huge}
market.owned=true;market.blockOwn=true
local verifying=coroutine.create(function() assert(not pending:_verify(p4,'VIP')) end)
assert(coroutine.resume(verifying));assert(coroutine.status(verifying)=='suspended')
pending:Destroy();assert(coroutine.resume(verifying));assert(p4.attrs.HasVIP~=true)
pending=Commerce.new(Config,profiles,notice,request);pending.states[p4]={last=-math.huge}
market.owned=false;market.blockInfo=true;now=30
local requesting=coroutine.create(function() pending:_request(p4,'VIP') end)
assert(coroutine.resume(requesting));assert(coroutine.status(requesting)=='suspended')
local prompts=market.prompts;pending:Destroy();assert(coroutine.resume(requesting));assert(market.prompts==prompts)
-- A pending group-rank lookup must not recreate admin authorization on teardown.
local p5=player(11);p5.rank=255;p5.blockRank=true;game.CreatorType='Group';game.CreatorId=44
local staleAdmin=Admin.new(Config,profiles,tycoon,notice,request)
local authorizing=coroutine.create(function() staleAdmin:_add(p5) end)
assert(coroutine.resume(authorizing));assert(coroutine.status(authorizing)=='suspended')
staleAdmin:Destroy();assert(coroutine.resume(authorizing));assert(not staleAdmin.states[p5] and p5.attrs.IsGameAdmin==nil)
staleAdmin:_request(p5,'GrantCoins');assert(profile.Coins==25000)
local pLeaving=player(13);pLeaving.rank=255;pLeaving.blockRank=true
local leavingAdmin=Admin.new(Config,profiles,tycoon,notice,request);leavingAdmin:Start()
authorizing=coroutine.create(function() leavingAdmin:_add(pLeaving) end)
assert(coroutine.resume(authorizing));assert(coroutine.status(authorizing)=='suspended')
players.PlayerRemoving:Fire(pLeaving)
assert(coroutine.resume(authorizing));assert(not leavingAdmin.states[pLeaving] and pLeaving.attrs.IsGameAdmin==nil,
 'An owner lookup must not re-add a departing player while Parent is still Players')
return 'Commerce/admin checks passed: Roblox ownership policy, prompt throttling, admin authorization, Obby teleport guard, earned/VIP titles, respawn observer cleanup and delayed API teardown/leave races.'
`;
const state=await LuauState.createAsync();
try {console.log((await state.loadstring(source.replace('MONEY_SOURCE',money).replace('ADMIN_SOURCE',admin),'commerce/admin checks',true)())[0]);}
finally {state.destroy();}

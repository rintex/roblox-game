// Headless policy checks; no real purchases, Robux or Creator Hub operations.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const [money,admin]=await Promise.all([readFile('src/server/Modules/MonetizationService.luau','utf8'),readFile('src/server/Modules/AdminService.luau','utf8')]);
const source=String.raw`
local now=0;local os={clock=function() return now end}
local task={spawn=function() end,defer=function() end}
local function signal()
 return {Connect=function(self,fn) self.callback=fn;return {Disconnect=function() end} end}
end
local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {} end}
local studio=false
local market={PromptGamePassPurchaseFinished=signal(),checks=0,prompts=0,owned=false,sale=true,fail=false,
 UserOwnsGamePassAsync=function(self,id,pass) self.checks+=1;if self.fail then error('unavailable') end;return self.owned end,
 GetProductInfo=function(self) return {IsForSale=self.sale} end,
 PromptGamePassPurchase=function(self) self.prompts+=1 end}
local Enum={InfoType={GamePass='GamePass'},CreatorType={User='User',Group='Group'}}
local game={GameId=123,CreatorId=7,CreatorType='User',GetService=function(_,name)
 if name=='Players' then return players elseif name=='MarketplaceService' then return market
 elseif name=='RunService' then return {IsStudio=function() return studio end} end;error(name)
end}
local Config={MaxCoins=1000000000,AdminUserIds={},GamePasses={VIP={Id=0,Name='VIP'},Neon={Id=0,Name='Neon'}}}
local profile={Coins=0};local closing=false
local profiles={Get=function(_,player) return player.ready and profile or nil end,IsClosing=function() return closing end}
local function player(id)
 return {UserId=id,Parent=players,ready=true,attrs={DataReady=true},GetAttribute=function(self,k) return self.attrs[k] end,
 SetAttribute=function(self,k,v) self.attrs[k]=v end,FindFirstChildOfClass=function() return nil end,
 GetRankInGroup=function(self) return self.rank or 0 end}
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
return 'commerce and admin authorization checks passed'
`;
const state=await LuauState.createAsync();
try {console.log((await state.loadstring(source.replace('MONEY_SOURCE',money).replace('ADMIN_SOURCE',admin),'commerce/admin checks',true)())[0]);}
finally {state.destroy();}

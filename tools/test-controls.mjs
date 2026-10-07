// Exercise the production LocalScript through tool, input and remote signals.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const controls = await readFile('src/client/HeroControls.client.luau', 'utf8');
const source = String.raw`
local clock = 100
local os = {clock = function() return clock end}
local task = {spawn = function(fn) fn() end}
local function signal()
 local listeners = {}
 return {
  Connect = function(_, fn)
   local connected = true
   table.insert(listeners, function(...) if connected then fn(...) end end)
   return {Disconnect = function() connected = false end}
  end,
  Fire = function(_, ...) for _, fn in ipairs(table.clone(listeners)) do fn(...) end end,
 }
end
local vectorMethods = {}
local vectorMeta = {
 __index = vectorMethods,
 __add = function(a,b) return vectorMethods.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
 __mul = function(a,b) return vectorMethods.new(a.X*b,a.Y*b,a.Z*b) end,
 __div = function(a,b) return vectorMethods.new(a.X/b,a.Y/b,a.Z/b) end,
}
function vectorMethods.new(x,y,z) return setmetatable({X=x,Y=y,Z=z or 0,__type='Vector3'},vectorMeta) end
local Vector3 = {new = vectorMethods.new}
local function typeof(value) return type(value)=='table' and value.__type or type(value) end
local UDim2 = {new = function(...) return {...} end}
local Enum = {
 UserInputType = {MouseButton1={Name='MouseButton1'},Touch={Name='Touch'},Gamepad1={Name='Gamepad1'}},
 UserInputState = {Begin='Begin',End='End'},
 ContextActionResult = {Sink='Sink'},
 KeyCode = {Q='Q',ButtonX='ButtonX'},
 RaycastFilterType = {Exclude='Exclude'},
}
local RaycastParams = {new = function() return {} end}
local methods = {}
local objectMeta = {
 __index=function(self,key) return methods[key] or self.values[key] end,
 __newindex=function(self,key,value)
  if key=='Parent' then
   local old = self.values.Parent
   if old==value then return end
   if old then
    local at=table.find(old.children,self);if at then table.remove(old.children,at) end
   end
   self.values.Parent=value
   if old then old.ChildRemoved:Fire(self) end
   if value then table.insert(value.children,self);value.ChildAdded:Fire(self) end
  else self.values[key]=value end
 end,
}
local function object(class,name)
 local item=setmetatable({values={ClassName=class,Name=name or class},children={},attrs={},attrSignals={},propertySignals={}},objectMeta)
 item.ChildAdded=signal();item.ChildRemoved=signal();item.Destroying=signal()
 if class=='Tool' then item.Activated=signal() end
 if class=='BindableEvent' then item.Event=signal() end
 return item
end
function methods:IsA(class) return self.ClassName==class end
function methods:GetChildren() return table.clone(self.children) end
function methods:FindFirstChild(name) for _,child in ipairs(self.children) do if child.Name==name then return child end end end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:SetAttribute(name,value) self.attrs[name]=value;self:GetAttributeChangedSignal(name):Fire() end
function methods:GetAttributeChangedSignal(name)
 if not self.attrSignals[name] then self.attrSignals[name]=signal() end
 return self.attrSignals[name]
end
function methods:GetPropertyChangedSignal(name)
 if not self.propertySignals[name] then self.propertySignals[name]=signal() end
 return self.propertySignals[name]
end
function methods:Destroy()
 if self.destroyed then return end;self.destroyed=true;self.Destroying:Fire()
 for _,child in ipairs(self:GetChildren()) do child:Destroy() end
 self.Parent=nil
end
function methods:Fire(...) self.Event:Fire(...) end
local Instance={new=function(class) return object(class) end}
local player=object('Player','Tester')
player.CharacterAdded=signal();player.CharacterRemoving=signal()
local character=object('Model','Character');player.Character=character
local workspace=object('Workspace','Workspace');character.Parent=workspace
local camera=object('Camera','Camera');camera.ViewportSize=Vector3.new(1000,600,0)
local screenRays,centerRays=0,0
function camera:ScreenPointToRay(x,y)
 assert(x==220 and y==180,'Mouse should use screen coordinates')
 screenRays+=1;return {Origin=Vector3.new(0,8,12),Direction=Vector3.new(0,0,-1)}
end
function camera:ViewportPointToRay(x,y)
 assert(x==500 and y==300,'Touch should aim from the viewport center')
 centerRays+=1;return {Origin=Vector3.new(0,8,12),Direction=Vector3.new(0,0,-1)}
end
workspace.CurrentCamera=camera
local raycasts=0
function workspace:Raycast(origin,direction,parameters)
 raycasts+=1
 assert(parameters.FilterDescendantsInstances[1]==character,'Own character must be excluded from aim')
 assert(direction.Z==-250)
 return {Position=Vector3.new(10,4,-100)}
end
local storage=object('ReplicatedStorage','ReplicatedStorage')
local remotes=object('Folder','TycoonRemotes');remotes.Parent=storage
local remote=object('RemoteEvent','SkillRequest');remote.Parent=remotes
local shots={}
function remote:FireServer(...) table.insert(shots,table.pack(...)) end
local inputType=Enum.UserInputType.MouseButton1
local input={MouseEnabled=true,GetLastInputType=function() return inputType end,
 GetMouseLocation=function() return {X=220,Y=180} end}
local actions,binds,unbinds={},0,0
local cas={
 BindAction=function(_,name,fn,touchButton,key,gamepad)
  assert(touchButton==true and key=='Q' and gamepad=='ButtonX')
  actions[name]=fn;binds+=1
 end,
 UnbindAction=function(_,name) actions[name]=nil;unbinds+=1 end,
 SetTitle=function() end,SetPosition=function() end,
}
local services={Players={LocalPlayer=player},ReplicatedStorage=storage,Workspace=workspace,UserInputService=input,ContextActionService=cas}
local game={GetService=function(_,name) assert(services[name],name);return services[name] end}
local script=object('LocalScript','HeroControls');script.Parent=object('Folder','PlayerScripts')
local function runController() CONTROLS_SOURCE end
runController()
local action='TycoonHeroSkill'
local function tool(marker)
 local result=object('Tool','Weapon');result:SetAttribute('HeroWeapon',marker);return result
end
assert(actions[action]==nil and #shots==0,'No equipped tool means no action')
local hero=tool('arachna');hero.Parent=character
assert(actions[action] and binds==1,'String hero marker should bind the action')
hero.Activated:Fire()
assert(#shots==1 and shots[1].n==1 and typeof(shots[1][1])=='Vector3','Hero sends only aim Vector3')
assert(screenRays==1 and centerRays==0)
hero.Activated:Fire();assert(#shots==1,'Client throttles immediate repeated activation')
clock+=1;hero.Parent=object('Backpack','Backpack')
assert(actions[action]==nil and unbinds==1,'Removing tool unbinds the action')
hero.Activated:Fire();assert(#shots==1,'Removed tools cannot fire')
local loot=tool('loot:solar_lance');loot.Parent=character
assert(actions[action] and binds==2,'Loot string marker should bind the action')
inputType=Enum.UserInputType.Touch
actions[action](action,Enum.UserInputState.Begin,{UserInputType=Enum.UserInputType.Touch})
assert(#shots==2 and centerRays==1,'Touch action should fire from the viewport center')
assert(raycasts==2)
clock+=1;inputType=Enum.UserInputType.MouseButton1
actions[action](action,Enum.UserInputState.Begin,{UserInputType=Enum.UserInputType.MouseButton1})
assert(#shots==3 and screenRays==2,'Keyboard action should use mouse aim')
loot.Parent=nil;assert(actions[action]==nil)
for _,marker in ipairs({false,true,'',string.rep('x',65),123}) do
 local bad=tool(marker);bad.Parent=character
 assert(actions[action]==nil,'Malformed or legacy boolean markers must remain inactive')
 clock+=1;bad.Activated:Fire();assert(#shots==3)
 bad.Parent=nil
end
local unmarked=tool(nil);unmarked.Parent=character
assert(actions[action]==nil);unmarked.Parent=nil
-- Attribute arrival after the Tool replicates must still activate controls.
local delayed=tool(nil);delayed.Parent=character;delayed:SetAttribute('HeroWeapon','loot:arc_rifle')
assert(actions[action]);delayed:SetAttribute('HeroWeapon',true);assert(actions[action]==nil)
delayed:SetAttribute('HeroWeapon','volt');assert(actions[action])
script:Destroy();assert(actions[action]==nil,'Cleanup unbinds the action')
clock+=1;delayed.Activated:Fire();assert(#shots==3,'Destroyed controller cannot send requests')
return 'Controls checks passed: production hero and loot tools, mouse/touch aim, cooldown, malformed markers, removal and cleanup.'
`;
const state = await LuauState.createAsync();
try {
  console.log((await state.loadstring(source.replace('CONTROLS_SOURCE', controls), 'production controls integration', true)())[0]);
} finally {
  state.destroy();
}

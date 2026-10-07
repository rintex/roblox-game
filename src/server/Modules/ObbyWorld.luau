-- Rooftop route geometry; ObbyService owns checkpoints and rewards.
local World = {}
local function child(parent, class, name)
 local value=parent:FindFirstChild(name)
 if not value then value=Instance.new(class);value.Name=name;value.Parent=parent
 else assert(value:IsA(class),name..' has the wrong type') end
 return value
end
local function part(parent,name,size,position,color,material,collide)
 local value=child(parent,'Part',name)
 value.Size=size;value.CFrame=CFrame.new(position);value.Color=color
 value.Material=material;value.Anchored=true;value.CanCollide=collide~=false
 value.CanTouch=true;value.CanQuery=true
 return value
end
local function label(part,name,text,color)
 local gui=child(part,'BillboardGui',name)
 gui.Size=UDim2.new(0,210,0,52);gui.StudsOffset=Vector3.new(0,4,0);gui.MaxDistance=80
 local value=child(gui,'TextLabel','Text')
 value.Size=UDim2.new(1,0,1,0);value.BackgroundColor3=Color3.fromRGB(25,31,43)
 value.BackgroundTransparency=0.15;value.BorderSizePixel=0
 value.TextColor3=color;value.Text=text;value.TextScaled=true;value.TextWrapped=true
 value.Font=Enum.Font.GothamBold
end
function World.Build(workspace,config)
 local folder=child(workspace,'Folder','RooftopObby')
 local platforms=child(folder,'Folder','Platforms')
 local decor=child(folder,'Folder','Decor')
 local checkpoint={}
 for _,index in ipairs(config.Obby.Checkpoints) do checkpoint[index]=true end
 for index,point in ipairs(config.Obby.Platforms) do
  local color=if checkpoint[index] then Color3.fromRGB(91,221,164) elseif index==#config.Obby.Platforms then Color3.fromRGB(255,205,74) else Color3.fromRGB(70+index%3*15,94,122)
  local value=part(platforms,'Stage'..index,Vector3.new(7,0.8,7),Vector3.new(point.X,point.Y,point.Z),color,Enum.Material.Concrete)
  value:SetAttribute('ObbyStage',index)
  if checkpoint[index] then label(value,'StageLabel','ТОЧКА '..index,color)
  elseif index==#config.Obby.Platforms then label(value,'StageLabel','ФИНИШ · +300 монет',color) end
  local trim=part(decor,'RoofTrim'..index,Vector3.new(7.1,0.12,0.4),Vector3.new(point.X,point.Y+0.46,point.Z-3.3),color,Enum.Material.Neon,false)
  trim.CanTouch=false;trim.CanQuery=false
 end
 local recovery=part(folder,'RecoveryField',Vector3.new(72,0.25,76),Vector3.new(0,0.4,112),Color3.fromRGB(67,147,187),Enum.Material.Glass,false)
 recovery.Transparency=0.32
 local start=part(folder,'StartStand',Vector3.new(8,0.5,6),Vector3.new(-27,0.6,78),Color3.fromRGB(236,187,73),Enum.Material.Neon)
 local prompt=child(start,'ProximityPrompt','StartObbyPrompt')
 prompt.ActionText='Начать обби';prompt.ObjectText='Крыши квартала · 16 этапов'
 prompt.MaxActivationDistance=10;prompt.HoldDuration=0.25;prompt.RequiresLineOfSight=false
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.Enabled=true
 label(start,'StartLabel','КРЫШИ КВАРТАЛА\nОББИ С КОНТРОЛЬНЫМИ ТОЧКАМИ',Color3.fromRGB(255,218,104))
 -- Decorative building shells stay away from the route and below jump height.
 for index,point in ipairs({{X=-43,Z=101,H=8},{X=43,Z=125,H=11},{X=-42,Z=139,H=6},{X=40,Z=86,H=7}}) do
  part(decor,'CityBlock'..index,Vector3.new(13,point.H,16),Vector3.new(point.X,point.H/2,point.Z),Color3.fromRGB(160+index*12,157,143),Enum.Material.Brick)
  for row=1,2 do
   for column=1,3 do
    local window=part(decor,'Window'..index..'_'..row..'_'..column,Vector3.new(2,1.4,0.12),Vector3.new(point.X-4+column*2,1+row*2,point.Z-8.1),Color3.fromRGB(158,214,238),Enum.Material.Glass,false)
    window.CanTouch=false;window.CanQuery=false
   end
  end
 end
 folder:SetAttribute('ObbyReady',true)
 return folder
end
return World

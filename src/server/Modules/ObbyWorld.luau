-- Rooftop route geometry; ObbyService owns checkpoints and rewards.
local World = {}
local Style = require(script.Parent:WaitForChild("VisualStyle"))
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
 value.CanTouch=true;value.CanQuery=value.CanCollide
 value.TopSurface=Enum.SurfaceType.Smooth;value.BottomSurface=Enum.SurfaceType.Smooth
 return value
end
local function label(part,name,text,color)
 local gui=child(part,'BillboardGui',name)
 gui.Size=UDim2.new(0,210,0,52);gui.StudsOffset=Vector3.new(0,4,0);gui.MaxDistance=80
 local value=child(gui,'TextLabel','Text')
 value.Size=UDim2.new(1,0,1,0);value.BackgroundColor3=Style.Palette.Ink
 value.BackgroundTransparency=0.15;value.BorderSizePixel=0
 value.TextColor3=color;value.Text=text;value.TextScaled=true;value.TextWrapped=true
 value.Font=Enum.Font.GothamBold
 child(value,'UICorner','Round').CornerRadius=UDim.new(0,8)
end
function World.Build(workspace,config)
 local folder=child(workspace,'Folder','RooftopObby')
 local platforms=child(folder,'Folder','Platforms')
 local decor=child(folder,'Folder','Decor')
 local checkpoint={}
 for _,index in ipairs(config.Obby.Checkpoints) do checkpoint[index]=true end
 for index,point in ipairs(config.Obby.Platforms) do
  local color=if checkpoint[index] then Style.Palette.Mint elseif index==#config.Obby.Platforms then Style.Palette.Gold else Style.Palette.Ink
  local value=part(platforms,'Stage'..index,Vector3.new(7,0.8,7),Vector3.new(point.X,point.Y,point.Z),color,Enum.Material.Slate)
  value:SetAttribute('ObbyStage',index)
  if checkpoint[index] then label(value,'StageLabel','ТОЧКА '..index,color)
  elseif index==#config.Obby.Platforms then label(value,'StageLabel','ФИНИШ · +300 монет',color) end
  local trim=part(decor,'RoofTrim'..index,Vector3.new(7.1,0.12,0.4),Vector3.new(point.X,point.Y+0.46,point.Z-3.3),color,Enum.Material.Neon,false)
  trim.CanTouch=false;trim.CanQuery=false
  for _,side in ipairs({-1,1}) do
   local edge=part(decor,'RoofEdge'..index..side,Vector3.new(0.17,0.06,6.8),Vector3.new(point.X+side*3.3,point.Y+0.44,point.Z),Style.Palette.Stone,Enum.Material.Metal,false)
   edge.CanTouch=false
  end
  local tile=part(decor,'LandingTile'..index,Vector3.new(2.8,0.025,2.8),Vector3.new(point.X,point.Y+0.415,point.Z),if checkpoint[index] then Style.Palette.Paper else Style.Palette.Road,Enum.Material.DiamondPlate,false)
  tile.CanTouch=false
  local bracket=part(decor,'RoofBracket'..index,Vector3.new(5,0.3,5),Vector3.new(point.X,point.Y-0.55,point.Z),Style.Palette.Stone,Enum.Material.Concrete,false)
  bracket.CanTouch=false
  if checkpoint[index] then
   local flag=part(decor,'CheckpointMarker'..index,Vector3.new(0.18,3,0.18),Vector3.new(point.X+4.2,point.Y+1.5,point.Z),Style.Palette.Ink,Enum.Material.Metal,false)
   flag.CanTouch=false
   local panel=part(decor,'CheckpointFlag'..index,Vector3.new(1.7,0.9,0.1),Vector3.new(point.X+5,point.Y+2.5,point.Z),color,Enum.Material.Fabric,false)
   panel.CanTouch=false
  end
 end
 local recovery=part(folder,'RecoveryField',Vector3.new(72,0.25,76),Vector3.new(0,0.4,112),Style.Palette.Mint,Enum.Material.Glass,false)
 recovery.Transparency=0.88
 local start=part(folder,'StartStand',Vector3.new(8,0.5,6),Vector3.new(-27,0.6,78),Style.Palette.Gold,Enum.Material.Neon)
 local prompt=child(start,'ProximityPrompt','StartObbyPrompt')
 prompt.ActionText='Начать обби';prompt.ObjectText='Крыши квартала · 16 этапов'
 prompt.MaxActivationDistance=10;prompt.HoldDuration=0.25;prompt.RequiresLineOfSight=false
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.Enabled=true
 label(start,'StartLabel','КРЫШИ КВАРТАЛА\nОББИ С КОНТРОЛЬНЫМИ ТОЧКАМИ',Style.Palette.Gold)
 for _,side in ipairs({-1,1}) do
  local post=part(decor,'StartGatePost'..side,Vector3.new(0.7,8,0.7),Vector3.new(-27+side*5,4,81),Style.Palette.Ink,Enum.Material.Metal,false)
  post.CanTouch=false
 end
 local beam=part(decor,'StartGateTop',Vector3.new(11,0.5,0.8),Vector3.new(-27,8.2,81),Style.Palette.Gold,Enum.Material.Neon,false)
 beam.CanTouch=false
 local endPoint=config.Obby.Platforms[#config.Obby.Platforms]
 local finish=part(decor,'FinishArch',Vector3.new(9,0.4,0.65),Vector3.new(endPoint.X,endPoint.Y+6,endPoint.Z),Style.Palette.Gold,Enum.Material.Neon,false)
 finish.CanTouch=false
 for _,side in ipairs({-1,1}) do
  local post=part(decor,'FinishPost'..side,Vector3.new(0.45,5.6,0.45),Vector3.new(endPoint.X+side*4.2,endPoint.Y+3,endPoint.Z),Style.Palette.Ink,Enum.Material.Metal,false)
  post.CanTouch=false
 end
 -- Decorative building shells stay away from the route and below jump height.
 for index,point in ipairs({{X=-43,Z=101,H=8},{X=43,Z=125,H=11},{X=-42,Z=139,H=6},{X=40,Z=86,H=7}}) do
  part(decor,'CityBlock'..index,Vector3.new(13,point.H,16),Vector3.new(point.X,point.H/2,point.Z),Color3.fromRGB(160+index*12,157,143),Enum.Material.Brick)
  local roof=part(decor,'CityBlockRoof'..index,Vector3.new(14,0.35,17),Vector3.new(point.X,point.H+0.2,point.Z),Style.Palette.Ink,Enum.Material.Slate)
  roof.CanTouch=false
  local vent=part(decor,'CityBlockVent'..index,Vector3.new(2.5,0.8,3),Vector3.new(point.X-3,point.H+0.85,point.Z+3),Style.Palette.Stone,Enum.Material.Metal)
  vent.CanTouch=false
  for row=1,2 do
   for column=1,3 do
    local window=part(decor,'Window'..index..'_'..row..'_'..column,Vector3.new(2,1.4,0.12),Vector3.new(point.X-4+column*2,1+row*2,point.Z-8.1),Style.Palette.Window,Enum.Material.Glass,false)
    window.CanTouch=false;window.CanQuery=false
   end
  end
 end
 folder:SetAttribute('ObbyReady',true)
 return folder
end
return World

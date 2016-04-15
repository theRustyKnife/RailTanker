require "defines"

MOD_NAME = "RailTanker"

function debugLog(message)
  if true then -- set for debug
    local msg
    if type(message) == "string" then
      msg = message
    else
      msg = serpent.dump(message, {name="var", comment=false, sparse=false, sortkeys=true})
    end
    for i,player in pairs(game.players) do
      player.print(msg)
    end
  end
end

Proxy = {}
Proxy.create = function(tanker)
  --local offsetPosition = {x = position.x, y = position.y}
  --offsetPosition = position
  local position, fluidbox, surface = tanker.entity.position, tanker.fluidbox, tanker.entity.surface
  --  local pumps = surface.find_entities_filtered{area = {{position.x - 1.5, position.y - 1.5}, {position.x + 1.5, position.y + 1.5}}, type="pump"}
  --  local proxyName = "rail-tanker-proxy-noconnect"
  --  if isValid(pumps[1]) then
  --    debugLog("foundpump" .. game.tick)
  --    proxyName = "rail-tanker-proxy"
  --  end
  local proxyName = "rail-tanker-proxy"
  local foundProxy = surface.create_entity{name=proxyName, position=position, force=game.players[1].force}
  --local foundProxy = Proxy.find(position)
  foundProxy.fluidbox[1] = fluidbox
  debugLog(foundProxy.name .. game.tick)
  return foundProxy
end

Proxy.destroy = function(carriage)

end

Proxy.find = function(position, surface)
  local entities = surface.find_entities{{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}}
  local foundProxies = nil
  for i, entity in pairs(entities) do
    if isValid(entity) and (entity.name == "rail-tanker-proxy" or entity.name == "rail-tanker-proxy-noconnect") then
      --debugLog("Found entity: " .. entity.name)
      if foundProxies == nil then
        foundProxies = entity
      else
        if isValid(entity) then
          entity.destroy()
        end
      end
    end
  end
  return foundProxies
end

add_manualTanker = function(tanker)
  table.insert(global.manualTankers, tanker)
  script.on_event(defines.events.on_tick, onTickMain)  
end

remove_manualTanker = function(entity)
  for i=#global.manualTankers,1,-1 do
    if global.manualTankers[i].entity == entity then
      table.remove(global.manualTankers, i)
      return      
    end
  end
end

function filter(func, arr)
  if arr == nil then return nil end
  local new_array = {}
  for _,v in pairs(arr) do
    if func(v) then table.insert(new_array, v) end
  end
  return new_array
end

function isValid(entity)
  return (entity and entity.valid)
end

function getTankerFromEntity(entity)
  if global.tankers == nil then return nil end
  --debugLog("tankers not nil")
  for i,tanker in pairs(global.tankers) do
    if isValid(tanker.entity) and entity == tanker.entity then
      return i, tanker
    end
  end
end

local function init_global()
  global = global or {}
  global.tankers = global.tankers or {}
  global.manualTankers = global.manualTankers or {}
end

local function on_configuration_changed(data)
  if not data or not data.mod_changes then
    return
  end
  local newVersion = false
  local oldVersion = false
  if data.mod_changes[MOD_NAME] then
    newVersion = data.mod_changes[MOD_NAME].new_version
    oldVersion = data.mod_changes[MOD_NAME].old_version
    if oldVersion then
      init_global()
    end
  end
end

local function on_init()
  init_global()
end

local function on_load()

end
script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)

isEntityMoving = function(entity)
  return entity.train.speed ~= 0
end

isTankerMoving = function(tanker)
  return (isEntityMoving(tanker.entity))
end

isTankerValid = function(tanker)
  return(tanker ~= nil and (isValid(tanker.proxy))) --  or (isValid(tanker.entity) and (tanker.entity.state ~= 8 or tanker.entity.state ~= 9))))
end

onTickMain = function(event)
  if #global.manualTankers == 0 then
    script.on_event(defines.events.on_tick, nil)
    return
  end
  if event.tick % 20 == 16 then
    for i=#global.manualTankers,1,-1 do
      local tanker = global.manualTankers[i]
      if isValid(tanker.entity) then
        if isEntityMoving(tanker.entity) then
          if isValid(tanker.proxy) then
            tanker.fluidbox = tanker.proxy.fluidbox[1]
            tanker.proxy.destroy()
            tanker.proxy = nil
          else
            tanker.proxy = nil
          end
        elseif tanker.proxy == nil then
          tanker.proxy = Proxy.create(tanker)
        end
      else
        table.remove(global.manualTankers,i)
      end
    end
  end
end

isTankerEntity = function(entity)
  --if isValid(entity) then debugLog(entity.name) end
  return (isValid(entity) and entity.name == "rail-tanker")

end

isPumpEntity = function (entity)
  --if isValid(entity) then debugLog(entity.name) end
  return (isValid(entity) and entity.type == "pump")
end


entityRemoved = function (event)
  if isTankerEntity(event.entity) then
    local index, tanker = getTankerFromEntity(event.entity)
    if index and isTankerValid(tanker) then
      if isValid(tanker.proxy) then
        local found
        for i=#global.manualTankers,1,-1 do
          local m = global.manualTankers[i]
          if m.proxy == tanker.proxy then
            found = i
            break
          end
        end
        tanker.proxy.destroy()
        tanker.proxy = nil
        table.remove(global.tankers, index)
        if found then
          table.remove(global.manualTankers, found)
        end
      end
    end
  end
end

script.on_event(defines.events.on_preplayer_mined_item, entityRemoved)
script.on_event(defines.events.on_robot_pre_mined, entityRemoved)
script.on_event(defines.events.on_entity_died, entityRemoved)

entityBuilt = function(event)
  debugLog("On build")
  local entity = event.created_entity
  if isTankerEntity(entity) then
    debugLog("entity is tanker")
    local tanker = {entity = entity}
    if not isTankerMoving(tanker) then
      tanker.proxy=Proxy.create(tanker)
    end
    table.insert(global.tankers, tanker)
    debugLog("new tanker: " .. #global.tankers)
    if entity.train.state == 9 then
      debugLog("Manual Train")
      add_manualTanker(tanker)
      debugLog("manual tanker: " .. #global.manualTankers)
    end
  elseif isPumpEntity(entity) then
    local position = entity.position
    local foundEntities = entity.surface.find_entities_filtered{area = {{position.x - 1.5, position.y - 1.5}, {position.x + 1.5, position.y + 1.5}}, name="rail-tanker"}
    for i,entity in pairs(foundEntities) do
      local _, tanker = getTankerFromEntity(entity)
      if isTankerValid(tanker) and isValid(tanker.proxy) and tanker.proxy.name == "rail-tanker-proxy-noconnect" then
        tanker.fluidbox = tanker.proxy.fluidbox[1]
        tanker.proxy.destroy()
        tanker.proxy = Proxy.create(tanker)
      end
    end
  end
end

script.on_event(defines.events.on_built_entity, entityBuilt)
script.on_event(defines.events.on_robot_built_entity, entityBuilt)

script.on_event(defines.events.on_train_changed_state, function(event)
  local train = event.train
  local tankers = filter(isTankerEntity, train.carriages)
  debugLog("Tanker state: " .. train.state)
  for i,entity in pairs(tankers) do
    local _, tanker = getTankerFromEntity(entity)
    if tanker == nil then
      --debugLog("something went wrong!")
      tanker = {entity = entity}
      table.insert(global.tankers, tanker)
    end
    local state = train.state
    if state ~= defines.trainstate.manual_control_stop and state ~= defines.trainstate.manual_control and global.manualTankers ~= nil then
      remove_manualTanker(entity)
    end

    if state == defines.trainstate.no_path or state == defines.trainstate.wait_signal or state == defines.trainstate.wait_station then --Stopped
      debugLog("Train Stopped " .. i)
      --local tanker = {entity = entity, proxy=Proxy.create(entity.position), fluidbox = tanker.proxy.fluidbox[1][1]}
      if state ~= defines.trainstate.wait_signal or (state == defines.trainstate.wait_signal and not tanker.proxy) then
        tanker.proxy = Proxy.create(tanker)
      end
    elseif state == defines.trainstate.manual_control_stop or state == defines.trainstate.manual_control then
      debugLog("Train Manual " .. i)
      table.insert(global.manualTankers, tanker)
      script.on_event(defines.events.on_tick, onTickMain)
    else --moving
      debugLog("Train moving" .. i)
      if isValid(tanker.proxy) then
        tanker.fluidbox = tanker.proxy.fluidbox[1]
        tanker.proxy.destroy()
        tanker.proxy = nil
      end
    end
  end
end)

-- added by Choumiko
remote.add_interface("railtanker",
  {
    getLiquidByWagon = function(wagon)
      local i, tanker = getTankerFromEntity(wagon)
      if not i then return nil end
      local res = {amount = 0, type = nil}
      if tanker ~= nil and isValid(tanker.entity) and tanker.entity.name == "rail-tanker" then
        if tanker.proxy ~= nil then
          if tanker.proxy.fluidbox[1] ~= nil then
            res = {amount = tanker.proxy.fluidbox[1].amount, type = tanker.proxy.fluidbox[1].type}
          end
        else
          if tanker.fluidbox ~= nil then
            res = {amount = tanker.fluidbox.amount, type = tanker.fluidbox.type}
          end
        end
      end
      return res
    end,

    saveVar = function()
      game.write_file("railtanker.lua", serpent.block(global, {name="glob"}))
    end,
  }
)

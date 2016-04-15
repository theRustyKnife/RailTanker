require "defines"

MOD_NAME = "RailTanker"

function debugLog(message, force)
  if false or force then -- set for debug
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

function isValid(entity)
  return (entity and entity.valid)
end

isTankerMoving = function(tanker)
  return tanker.entity.train.speed ~= 0
end

isTankerValid = function(tanker)
  return tanker and isValid(tanker.proxy)
end

isTankerEntity = function(entity)
  return (isValid(entity) and entity.name == "rail-tanker")
end

isPumpEntity = function (entity)
  --if isValid(entity) then debugLog(entity.name) end
  return (isValid(entity) and entity.type == "pump")
end

Proxy = {}
Proxy.create = function(tanker, found_pump)
  --local offsetPosition = {x = position.x, y = position.y}
  --offsetPosition = position
  local position, fluidbox, surface = tanker.entity.position, tanker.fluidbox, tanker.entity.surface
  local proxyName = "rail-tanker-proxy-noconnect"
  if not found_pump then
    local pumps = surface.find_entities_filtered{area = {{position.x - 1.5, position.y - 1.5}, {position.x + 1.5, position.y + 1.5}}, type="pump"}
    if isValid(pumps[1]) then
      debugLog("found pump " .. game.tick)
      proxyName = "rail-tanker-proxy"
    end
  else
    proxyName = "rail-tanker-proxy"
  end
  local foundProxy = surface.create_entity{name=proxyName, position=position, force=tanker.entity.force}
  --local foundProxy = Proxy.find(position)
  foundProxy.fluidbox[1] = fluidbox
  debugLog(foundProxy.name .. game.tick)
  tanker.proxy = foundProxy
  return tanker.proxy
end

Proxy.destroy = function(carriage)

end

Proxy.pickup = function(tanker)
  if tanker.proxy and tanker.proxy.valid then
    tanker.fluidbox = tanker.proxy.fluidbox[1]
    tanker.proxy.destroy()
  end
  tanker.proxy = nil
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

on_tick = function(event)
  if #global.manualTankers == 0 then
    script.on_event(defines.events.on_tick, nil)
    return
  end
  if event.tick % 20 == 16 then
    for i=#global.manualTankers,1,-1 do
      local tanker = global.manualTankers[i]
      if isValid(tanker.entity) then
        if isTankerMoving(tanker) then
          Proxy.pickup(tanker)
        elseif tanker.proxy == nil then
          Proxy.create(tanker)
        end
      else
        table.remove(global.manualTankers,i)
      end
    end
  end
end

add_manualTanker = function(tanker)
  table.insert(global.manualTankers, tanker)
  script.on_event(defines.events.on_tick, on_tick)
end

remove_manualTanker = function(entity)
  for i=#global.manualTankers,1,-1 do
    if global.manualTankers[i].entity == entity then
      table.remove(global.manualTankers, i)
      return
    end
  end
end

function getTankerFromEntity(entity)
  if global.tankers == nil then return nil end
  --debugLog("tankers not nil")
  for i,tanker in pairs(global.tankers) do
    if isValid(tanker.entity) and entity == tanker.entity then
      return i, tanker
    end
  end
  return nil
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

on_entity_removed = function (event)
  if isTankerEntity(event.entity) then
    local index, tanker = getTankerFromEntity(event.entity)
    if index and isTankerValid(tanker) then
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

script.on_event(defines.events.on_preplayer_mined_item, on_entity_removed)
script.on_event(defines.events.on_robot_pre_mined, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)

on_entitiy_built = function(event)
  local entity = event.created_entity
  if isTankerEntity(entity) then
    local tanker = {entity = entity}
    if not isTankerMoving(tanker) then
      tanker.proxy = Proxy.create(tanker)
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
      if isTankerValid(tanker) and tanker.proxy.name == "rail-tanker-proxy-noconnect" then
        tanker.fluidbox = tanker.proxy.fluidbox[1]
        tanker.proxy.destroy()
        tanker.proxy = Proxy.create(tanker, true)
      end
    end
  end
end

script.on_event(defines.events.on_built_entity, on_entitiy_built)
script.on_event(defines.events.on_robot_built_entity, on_entitiy_built)

on_train_changed_state = function(event)
  local train = event.train
  local state = train.state
  local remove_manual = state ~= defines.trainstate.manual_control_stop and state ~= defines.trainstate.manual_control
  local train_stopped = state == defines.trainstate.no_path or state == defines.trainstate.wait_signal or state == defines.trainstate.wait_station
  local add_manual = state == defines.trainstate.manual_control_stop or state == defines.trainstate.manual_control
  debugLog("Tanker state: " .. train.state)
  for i,entity in pairs(train.cargo_wagons) do
    if isTankerEntity(entity) then
      local _, tanker = getTankerFromEntity(entity)
      if tanker == nil then
        --debugLog("something went wrong!")
        tanker = {entity = entity}
        table.insert(global.tankers, tanker)
      end
      if remove_manual then
        remove_manualTanker(entity)
      end
      if train_stopped then
        debugLog("Train Stopped " .. i)
        if state ~= defines.trainstate.wait_signal or (state == defines.trainstate.wait_signal and not tanker.proxy) then
          tanker.proxy = Proxy.create(tanker)
        end
      elseif add_manual then
        debugLog("Train Manual " .. i)
        add_manualTanker(tanker)
      else --moving
        debugLog("Train moving" .. i)
        Proxy.pickup(tanker)
      end
    end
  end
end

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)

-- added by Choumiko
remote.add_interface("railtanker",
  {
    getLiquidByWagon = function(wagon)
      local i, tanker = getTankerFromEntity(wagon)
      if not i then return nil end
      if isValid(tanker.entity) and tanker.entity.name == "rail-tanker" then
        if tanker.proxy and tanker.proxy.valid and tanker.proxy.fluidbox[1] then
          return {amount = tanker.proxy.fluidbox[1].amount, type = tanker.proxy.fluidbox[1].type}
        end
        if tanker.fluidbox then
          return {amount = tanker.fluidbox.amount, type = tanker.fluidbox.type}
        end
      end
      return {amount = 0, type = nil}
    end,

    saveVar = function()
      game.write_file("railtanker.lua", serpent.block(global, {name="glob"}))
    end,
  }
)

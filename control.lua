require "defines"

MOD_NAME = "RailTanker"

function debugLog(message, force, version)
  if false or force then -- set for debug
    local msg
    if type(message) == "string" then
      msg = message
    else
      msg = serpent.dump(message, {name="var", comment=false, sparse=false, sortkeys=true})
    end
    msg = version and version .. " " .. msg or msg
    log(msg)
    for _,player in pairs(game.players) do
      player.print(msg)
    end
  end
end

function key_by_value(tbl, value)
  for i,c in pairs(tbl) do
    if c == value then
      return i
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
      --debugLog("found pump @"..pumps[1].position.x.."|"..pumps[1].position.y.." " .. game.tick, true)
      proxyName = "rail-tanker-proxy"
    end
  else
    proxyName = "rail-tanker-proxy"
  end
  local foundProxy = surface.create_entity{name=proxyName, position=position, force=tanker.entity.force}
  --local foundProxy = Proxy.find(position)
  foundProxy.fluidbox[1] = fluidbox
  debugLog(game.tick .. " created " .. foundProxy.name)
  tanker.proxy = foundProxy
  return tanker.proxy
end

Proxy.pickup = function(tanker)
  if tanker.proxy and tanker.proxy.valid then
    debugLog(game.tick .. "pickup " .. serpent.line(tanker.proxy.position,{comment=false}))
    tanker.fluidbox = tanker.proxy.fluidbox[1]
    tanker.proxy.destroy()
  end
  tanker.proxy = nil
end

Proxy.find = function(position, surface)
  local entities = surface.find_entities{{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}}
  local foundProxies = nil
  for _, entity in pairs(entities) do
    if isValid(entity) and (entity.name == "rail-tanker-proxy" or entity.name == "rail-tanker-proxy-noconnect") then
      debugLog(game.tick .. " found entity: " .. entity.name)
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
      debugLog(game.tick .. " remove manual " .. i)
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

function map_size(surface)
  -- determine map size
  local min_x, min_y, max_x, max_y = 0, 0, 0, 0
  for c in surface.get_chunks() do
    if c.x < min_x then
      min_x = c.x
    elseif c.x > max_x then
      max_x = c.x
    end
    if c.y < min_y then
      min_y = c.y
    elseif c.y > max_y then
      max_y = c.y
    end
  end
  return min_x, min_y, max_x, max_y
end

function findTankers(show)
  local surface = game.surfaces['nauvis']
  local min_x, min_y, max_x, max_y = map_size(surface)

  if show then
    debugLog("Searching tankers..",true)
  end
  -- create bounding box covering entire generated map
  local bounds = {{min_x*32,min_y*32},{max_x*32,max_y*32}}
  local found = 0
  for _, ent in pairs(surface.find_entities_filtered{area=bounds, type="cargo-wagon"}) do
    local i, tanker = getTankerFromEntity(ent)
    if i then
      local proxy = Proxy.find(ent.position,ent.surface)
      if proxy and proxy.valid then
        tanker.proxy = proxy
        if proxy.fluidbox and proxy.fluidbox[1] then
          tanker.fluidbox = proxy.fluidbox[1]
        end
      end
      if ent.train.state ==  defines.trainstate.manual_control_stop or ent.train.state == defines.trainstate.manual_control then
        add_manualTanker(tanker)
      end
    else
      on_entitiy_built({created_entity=ent})
      found = found+1
    end
  end
  local removed = 0
  for _, ent in pairs(surface.find_entities_filtered{area=bounds, name="rail-tanker-proxy"}) do
    found = false
    for _, tanker in pairs(global.tankers) do
      if ent == tanker.proxy then
        found = true
        break
      end
    end
    if not found then
      removed = removed + 1
      ent.destroy()
    end
  end
  for _, ent in pairs(surface.find_entities_filtered{area=bounds, name="rail-tanker-proxy-noconnect"}) do
    found = false
    for _, tanker in pairs(global.tankers) do
      if ent == tanker.proxy then
        found = true
        break
      end
    end
    if not found then
      removed = removed + 1
      ent.destroy()
    end
  end
  if show then
    debugLog("Found "..#global.tankers.." tankers",true)
    if removed > 0 then
      debugLog("Removed "..removed.." invalid tanks", true)
    end
  end
end

local function init_global()
  global = global or {}
  global.tankers = global.tankers or {}
  global.manualTankers = global.manualTankers or {}
end

local function on_configuration_changed(data)
  local _, err = pcall(function()
    if not data or not data.mod_changes then
      return
    end
    local newVersion
    local oldVersion
    if data.mod_changes[MOD_NAME] then
      newVersion = data.mod_changes[MOD_NAME].new_version
      oldVersion = data.mod_changes[MOD_NAME].old_version
      init_global()
      if oldVersion and oldVersion < "1.2.2" then
        init_global()
        global.manualTankers = {}
        findTankers(true)
      end

      global.version = newVersion
    end
  end)
  if err then debugLog(err,true, global.version) end
end

local function on_init()
  init_global()
end

local function on_load()
  init_global()
  if #global.manualTankers > 0 then
    script.on_event(defines.events.on_tick, on_tick)
  end
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)

on_entity_removed = function (event)
  local _, err = pcall(function()
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
  end)
  if err then debugLog(err,true, global.version) end
end

script.on_event(defines.events.on_preplayer_mined_item, on_entity_removed)
script.on_event(defines.events.on_robot_pre_mined, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)

on_entitiy_built = function(event)
  local _, err = pcall(function()
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
      for _,ent in pairs(foundEntities) do
        local _, tanker = getTankerFromEntity(ent)
        if isTankerValid(tanker) and tanker.proxy.name == "rail-tanker-proxy-noconnect" then
          tanker.fluidbox = tanker.proxy.fluidbox[1]
          tanker.proxy.destroy()
          tanker.proxy = Proxy.create(tanker, true)
        end
      end
    end
  end)
  if err then debugLog(err,true, global.version) end
end

script.on_event(defines.events.on_built_entity, on_entitiy_built)
script.on_event(defines.events.on_robot_built_entity, on_entitiy_built)

on_train_changed_state = function(event)
  local _, err = pcall(function()
    local train = event.train
    local state = train.state
    local remove_manual = state ~= defines.trainstate.manual_control_stop and state ~= defines.trainstate.manual_control
    local train_stopped = state == defines.trainstate.wait_station
    local add_manual = state == defines.trainstate.manual_control_stop or state == defines.trainstate.manual_control
    debugLog(game.tick .. " Tanker state: " .. key_by_value(defines.trainstate, train.state))
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
          debugLog(game.tick .. " Train Stopped " .. i)
          tanker.proxy = Proxy.create(tanker)
        elseif add_manual then
          debugLog(game.tick .. " Train Manual " .. i)
          add_manualTanker(tanker)
        else --moving
          debugLog(game.tick .. " Train moving" .. i)
          Proxy.pickup(tanker)
        end
      end
    end
  end)
  if err then debugLog(err,true, global.version) end
end

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)

remote.add_interface("railtanker",
  {
    getLiquidByWagon = function(wagon)
      local i, tanker = getTankerFromEntity(wagon)
      if not i then return {amount = 0, type = nil} end
      if isTankerEntity(tanker.entity) then
        if tanker.proxy and tanker.proxy.valid and tanker.proxy.fluidbox and tanker.proxy.fluidbox[1] then
          return {amount = tanker.proxy.fluidbox[1].amount, type = tanker.proxy.fluidbox[1].type}
        end
        if not tanker.proxy and tanker.fluidbox then
          return {amount = tanker.fluidbox.amount, type = tanker.fluidbox.type}
        end
      end
      return {amount = 0, type = nil}
    end,

    saveVar = function()
      game.write_file("railtanker.lua", serpent.block(global, {name="glob"}))
    end,

    findTankers = function()
      global.manualTankers = {}
      findTankers(true)
    end,
  }
)

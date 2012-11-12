-- global definitions

dinnerTableCount = 4
maxCustomerCount = dinnerTableCount + 4
plateCount = dinnerTableCount + maxCustomerCount

require "menu"
require "dinnerTable"
require "kitchen"
require "customer"
require "utils"
require "plate"
require "seatingQueue"

kitchenTable = {}
dish = {}
trash = {}
bussStation = {}
selectedCustomer = nil
serverQueue = nil
kitchenQueue = nil
servingCounter = nil
plateQueue = nil
revenue = 0
openDuration = 90
numTablesWithPlates = 0

timer = 10 -- 120
wallTime = 0.0

-- patience functions (tweakable by restaurant modifications, later on)
waitInLineImpatience = 1
waitToOrderImpatience = 2
waitForFoodImpatience = 3

-- game modes: 
-- 1: top-level menu
-- 2: instructions
-- 3: options?
-- 4: store
-- 5: gameplay

mode = 1

-- ------------------
-- definition of the server
-- ------------------

server = {
    act_x = 200,
    act_y = 200,
    speed = 5, 
    carrying = {},
    color = {255,255,255,255}
}

serverQueueObject = {
    x = nil,
    y = nil,
    action = nil,
    arg = nil,
    name = nil
}

function server:draw() 
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.act_x, self.act_y, 32, 32)
    if self.carrying ~= nil then -- draw the plates server is carrying
        left = self.carrying[1]
        right = self.carrying[2]
        if left ~= nil then
            left:draw(self.act_x-10, self.act_y-20)
        end
        if right ~= nil then
            right:draw(self.act_x + 20, self.act_y-20)
        end
    end
end    

function newServerAction(x,y,act,arg,name)
    ret = table.copy(serverQueueObject)
    ret.x = x 
    ret.y = y 
    ret.action = act -- LUA!!$*&^#@ when I wrote ret.action = action, no error, but BAD behavior sigh.
    ret.arg = arg
    ret.name = name
    serverQueue:enqueue(ret)
end
    
function server:update(dt)
    nextAction = serverQueue:peekAtFirst()
    if nextAction ~= nil then
        self.act_y = self.act_y - ((self.act_y - nextAction.y) * self.speed * dt)
        self.act_x = self.act_x - ((self.act_x - nextAction.x) * self.speed * dt)
        if math.abs(self.act_x - nextAction.x) < 0.5 and math.abs(self.act_y -nextAction.y) < 0.5 then
            nextAction.action(nextAction.arg)
            -- do the thing we're supposed to do here
            -- then do the next thing in the server's queue
            serverQueue:dequeue()
        end
    end
end

function takeCustomerOrder(cust) 
    print("what is your order, sir/madam?")
    order = cust.order
    yellOrderToKitchen(order,cust.act_x, cust.act_y)
    cust.state="ordered"
end

function visitTable(toTable)
    -- if this table has an order for food we're carrying, deliver it
    if (toTable.seatedCustomer ~= nil) and (toTable.seatedCustomer.state=="ordered") then
        -- todo: refactor this -- too much repeated code, too many "customer" manipulations here in server
        -- todo^2: we've got a race / bad logic - if customer hasn't ordered yet, but we're carrying
        --         the thing they want, bad stuff happens
        if (server.carrying[1]~=nil) and (toTable.seatedCustomer.order == server.carrying[1].menuItem) then
            toTable.seatedCustomer.plateEatingFrom = server.carrying[1]
            putPlateOnTable(server.carrying[1], toTable)
            server.carrying[1] = nil
            toTable.seatedCustomer.order = nil
            toTable.seatedCustomer.state = "eating"
            numTablesWithPlates = numTablesWithPlates + 1
        else
            if (server.carrying[2]~=nil) and (toTable.seatedCustomer.order == server.carrying[2].menuItem) then
                toTable.seatedCustomer.plateEatingFrom = server.carrying[2]
                putPlateOnTable(server.carrying[2], toTable)
                server.carrying[2] = nil
                toTable.seatedCustomer.order = nil
                toTable.seatedCustomer.state = "eating"
                numTablesWithPlates = numTablesWithPlates + 1
            end
        end
    else -- no customer here, check for trash and/or tip
        if toTable.tipAmount > 0 then
            revenue = revenue + toTable.tipAmount
            toTable.tipAmount = 0
        end
        if toTable.plateHere ~= nil then
            toTable.plateHere.menuItem = nil
            toTable.plateHere.trash = false
            plateQueue:enqueue(toTable.plateHere)
            toTable.plateHere = nil
            numTablesWithPlates = numTablesWithPlates - 1
        end
        toTable.state = "empty"
    end
end

-- take plate from serving counter (carry it), if I have a hand free
function takePlate(plate)
    local gotit=false
    if server.carrying[1] == nil then
        server.carrying[1] = plate
        gotit = true
    else
        if server.carrying[2] == nil then
            server.carrying[2] = plate
            gotit=true
        end
    end
    if gotit then
        plate.onServingCounter=false
        servingCounter:removeElement(plate)
        kitchen:updateServingCounterPlates()
        print("server taking plate...")
    else
        print("server hands full")
    end
end

function putPlateOnTable(plate, toTable)
    plate.act_x = toTable.act_x + 5
    plate.act_y = toTable.act_y + 5
    plate.grid_x = nil
    plate.grid_y = nil
    toTable.plateHere = plate
end


-- ------------------
-- menu functions
-- ------------------

menuItems = {
    [1] = { color = {20, 250, 40,255}, name = "Spinach souffle", cost = 5, time = 5},
    [2] = { color = {200, 250, 40,255}, name = "Mac & cheese", cost = 2, time = 2},
    [3] = { color = {20, 40, 255,255}, name = "Salmon sashimi", cost = 10, time = 7},
    [4] = { color = {80, 250, 250,255}, name = "Edamami", cost = 1, time = 2}   
}

-- if chefs become objects, we'll need to do things much closer to how servers work here...
function yellOrderToKitchen(menuItem,x,y)
    kitchenQueue:enqueue(menuItem)
    createEvent(menuItem.time, "done cooking", orderUp, menuItem)
end


function timePasses()
    print(".")
    createEvent(1, "time passes", timePasses, nil)
    print("#outside: " .. outsideQueue:size() .. ", tables with plates " .. numTablesWithPlates)

    if timer > 0 then
        if math.random() > 0.75 then
            enterCustomer()
        end
    else -- check to see whether this round is over
        if outsideQueue:size() == maxCustomerCount then
            if numTablesWithPlates == 0 then
                mode = 1 -- TODO
            end
        end
    end
end

-- ------------------
-- outside queue functions
-- ------------------

function enterCustomer()
    print("ding, ding")
    newCust = outsideQueue:dequeue()
    if newCust ~= nil then
        newCust.happiness = 100
        newCust.state = "line"
        addToSeatingQueue(newCust, seatingQueue)
    end
end

-- ------------------
-- initialization
-- ------------------

function love.load()
    customers = { }
    tables = { }
    drawables = { }
    updatables = { server }
    clickables = { }
    timedEvents = { }
    seatingQueue = newQueue()
    outsideQueue = newQueue()
    serverQueue = newQueue()
    kitchenQueue = newQueue()
    servingCounter = newQueue()
    plateQueue = newQueue()
    
    timer = 10 -- 120
    wallTime = 0.0
    revenue = 0

    local i = 0
    local newCust = nil

    table.insert(drawables, kitchen)

    for i = 1, dinnerTableCount do 
        newTable = newDinnerTable(i)
        table.insert(tables, newTable)
        table.insert(drawables, newTable)
        table.insert(clickables, newTable)
    end
    for i = 1, maxCustomerCount do 
        newCust = newCustomer(i) 
        table.insert(customers, newCust)
        table.insert(drawables, newCust)
        table.insert(clickables, newCust)
        table.insert(updatables, newCust)
        outsideQueue:enqueue(newCust)
        print("customer " .. i .. " has entered the game")
    end
    
    for i = 0, plateCount do
        newPlate = table.copy(plate)
        table.insert(drawables, newPlate)
        table.insert(clickables, newPlate)
        -- table.insert(updatables, newPlate)
        plateQueue:enqueue(newPlate)
    end
    enterCustomer()
    createEvent(2, "bootstrap time", timePasses, nil)
    table.insert(drawables, server)
    table.insert(drawables, seatingQueueClickBox) -- for debugging
    table.insert(clickables, seatingQueueClickBox)
    table.insert(updatables, kitchen) -- used to update plate positions (conveyer belt?)
    
    menu:initialize()
    print("done loading ")
end

function love.update(dt)
    if mode == 1 then
        menu:update(dt)
    else 
        if mode == 5 then
            wallTime = wallTime + dt
            while (peekEventTime() < wallTime) do
                event = table.remove(timedEvents, 1)
                print("processing " .. event.event)
                event.eventFunc(event.eventArg)
            end
            local i = 0
            for i in values(updatables) do 
                i:update(dt)
            end
            timer = timer - dt
        end
    end
end

function values(t)
    local i = 0
    return function() i = i + 1; return t[i] end
end

function love.draw()
    if mode == 1 then
        menu:draw()
    else 
        if mode == 5 then
            love.graphics.setColor(255,255,255)
            rev = string.format("%.2f", revenue)
            love.graphics.print("Earnings: $" .. rev .. "    Time left: " .. math.floor(timer), 500, 0)
            for i in values(drawables) do 
                i:draw()
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        mode = 1
        print ("mode ".. mode)
    else
        print (key)
    end
end

function love.mousepressed(x, y, button)
   if button == 'lshift' then
        print ("x: ".. x .. ", y:" .. y)
   end
   if mode == 5 then
       if button == 'l' then
           for i in values(clickables) do 
               i:checkClick(x,y)
           end
       end
    else
        if mode == 1 then
            menu:mousePressed(x,y,button)
        end
    end
end


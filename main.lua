-- global definitions
require "menu"
require "dinnerTable"

dinnerTableCount = 4
maxCustomerCount = dinnerTableCount + 4
plateCount = dinnerTableCount + maxCustomerCount

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
-- kitchen functions
-- ------------------

kitchen = {
    act_x = 500,
    act_y = 500,
    width = 300,
    height = 100,
    color = {128,128,128,255}
}

function kitchen:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
    local posn = 1
    for order in values(kitchenQueue.elements) do 
        love.graphics.setColor(order.color)
        love.graphics.rectangle("fill", self.act_x + self.width - 40, self.act_y + 5 + (posn * 15), 10, 10)
        posn = posn + 1
    end
    posn = 1
    for plate in values(servingCounter.elements) do 
        plate:drawOnCounter()
    end
end

function kitchen:updateServingCounterPlates()
    posn = 1
    for plate in values(servingCounter.elements) do 
        plate.grid_x = self.act_x + 10 + (posn * (plate.width))
        plate.grid_y = self.act_y + 5
        posn = posn + 1
    end
end    

function kitchen:update(dt)
    for plate in values(servingCounter.elements) do 
        plate:updateOnCounter(dt)
    end
end

function orderUp(menuItem)
    print ("Order Up!")
    food = kitchenQueue:dequeue() -- assuming one chef
    plate = plateQueue:dequeue()
    plate.menuItem = food
    plate.onServingCounter = true
    plate.act_x = kitchen.act_x + kitchen.width 
    plate.act_y = kitchen.act_y + 5
    plate.percentLeft = 100
    servingCounter:enqueue(plate)
    kitchen:updateServingCounterPlates()
    return ret
end

-- kitchen note: the order isn't drawable, and chefs aren't either -- they're pure model objects,
-- so they don't logically go in either the drawable queue or the updatable queue. Instead, their 
-- actions are driven by the discrete event processing loop. 
-- Will want to rethink this if you can hire additional chefs, but that might be crazy.


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

-- ------------------
-- plate functions
-- ------------------

plate = {
    menuItem = nil,
    trash = false,
    onServingCounter = false,
    act_x = 0, 
    act_y = 0,
    grid_x = 0,
    grid_y = 0,
    -- no grid_x / grid_y because they don't move on their own, do they?
    color = {50,50,50,255},
    width = 35,
    height = 35,
    speed = 1,
    percentLeft = 100   
}

function plate:visible()
    return menuItem ~= nil or trash
end

function plate:checkClick(x,y)
    if self.onServingCounter then
        if checkClick(x,y,self.act_x,self.act_y,self.width, self.height) then
            print("cooked food clicked on")
            if self.onServingCounter then
                newServerAction(self.act_x - 20, self.act_y + 20, takePlate, self, "pick up order")
            end    
        end
    end
end

function plate:draw(x,y)
    if x ~= nil then
        self.act_x = x 
        self.act_y = y
    end
    if self.menuItem ~= nil then
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
        love.graphics.setColor(self.menuItem.color)
        love.graphics.rectangle("fill",self.act_x+5,self.act_y+5,self.width-10,(self.height-10) * (self.percentLeft / 100))        
    else 
        if self.trash then
            love.graphics.setColor(self.color)
            love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
            love.graphics.setColor({0,0,0,255})
            love.graphics.line(self.act_x,self.act_y,self.act_x + self.width,self.act_y + self.height)
        end
    end
end

function plate:updateOnCounter(dt)
    self.act_y = self.act_y - ((self.act_y - self.grid_y) * self.speed * dt)
    self.act_x = self.act_x - ((self.act_x - self.grid_x) * self.speed * dt)
end

function plate:drawOnCounter()
    if self.menuItem ~= nil then
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
        love.graphics.setColor(self.menuItem.color)
        love.graphics.rectangle("fill",self.act_x+5,self.act_y+5,self.width-10,(self.height-10) * (self.percentLeft / 100))        
    end
end


-- ------------------
-- customer functions
-- ------------------
customer = {
    grid_x = 0,
    grid_y = 0,
    act_x = 50,
    act_y = 0,
    width = 32,
    height = 32,
    speed = 5,
    happiness = 100,
    state = "outside",
    seatedAt = nil,
    color = {100,100,255},
    selected = false,
    name = nil,
    label = nil,
    order = nil, 
    plateEatingFrom = nil,
    eatingSpeed = 10
}

customer.states = {"outside", "line", "choosing", "readyToOrder", "ordered", "eating"}

customerCount = 1

function newCustomer(num)
    local nc = table.copy(customer, true)
    nc.grid_x = nc.grid_x + customerCount * 50
    nc.name = "C" .. customerCount
    customerCount = customerCount + 1
    return nc
end


function customer:draw() 
    if (self.state ~= "outside") then 
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", self.act_x, self.act_y, self.width, self.height)
        if self.selected then
            love.graphics.setColor({0,255,0})
            love.graphics.rectangle("line", self.act_x, self.act_y, self.width, self.height)
        end   
        if self.label ~= nil then
            love.graphics.setColor(255,255,255,255)
            --love.graphics.print(self.name .. self.label, self.act_x + 5, self.act_y - 5)
        end
        love.graphics.print(self.state, self.act_x + 5, self.act_y - 5)
        love.graphics.print("" .. math.floor(self.happiness) , self.act_x + 5, self.act_y + 5)
        if self.order ~= nil then
            love.graphics.setColor(self.order.color)
            if self.state == "readyToOrder" then
                love.graphics.rectangle("fill", self.act_x-8, self.act_y+5, 10, 10)
            else
                love.graphics.rectangle("fill", self.act_x + self.width-5, self.act_y+5, 10, 10)                
            end
        end
    end
end    

function customer:update(dt)
    self.act_y = self.act_y - ((self.act_y - self.grid_y) * self.speed * dt)
    self.act_x = self.act_x - ((self.act_x - self.grid_x) * self.speed * dt)
    self.label = self.state -- .. "(" .. self.act_x .. "," .. self.act_y .. ") "
    if self.plateEatingFrom ~= nil then
        self.plateEatingFrom.percentLeft = self.plateEatingFrom.percentLeft - self.eatingSpeed * dt
        if self.plateEatingFrom.percentLeft <= 0 then
            self.plateEatingFrom = nil
            self:payAndLeave() 
        end
    end
    self:updateHappiness(dt)
end

function customer:updateHappiness(dt)
    if self.state == "line" then
        self.happiness = self.happiness - (dt * waitInLineImpatience)
    else 
        if self.state == "readyToOrder" then
            self.happiness = self.happiness - (dt * waitToOrderImpatience)
        else 
            if self.state == "ordered" then
                self.happiness = self.happiness - (dt * waitForFoodImpatience)
            end
        end
    end
end

function customer:payAndLeave()
    self.seatedAt.seatedCustomer = nil
    self.seatedAt.tipAmount = (15 * self.happiness) / 100 -- todo: fill this in based on happiness with experience.
    self.seatedAt = nil
    self.grid_x = 0
    self.grid_y = 0
    self.state = "leaving"
    print("thanks for the meal!")
    outsideQueue:enqueue(self)
end

-- we click on customers to take their order
function customer:checkClick(x,y)
    if self.state == "readyToOrder" then
        if checkClick(x,y,self.act_x,self.act_y,self.width, self.height) then
            print("get busy, server!")
            newServerAction(self.act_x - 20, self.act_y + 20, takeCustomerOrder, self, "take order")
        end
    end
end

function customer:seatAtTable(myTable)
    x = removeFromSeatingQueue(seatingQueue) -- is this the best place for this? Hope it's me!!
    -- print (self.name .. " just dequeued " .. x.name)
    self.grid_x = myTable.act_x - 20
    self.grid_y = myTable.act_y + 20
    self.selected = false
    self.state = "choosing"
    self.seatedAt = myTable
    myTable.state = "customers"
    myTable.seatedCustomer = self
    selectedCustomer = nil
    createEvent(math.random(5), "ready to order", readyToOrder, self)
end

function readyToOrder(cust)
   cust.state = "readyToOrder" 
   cust.order = menuItems[1+math.random(3)]
end

-- ------------------
-- seating queue functions
-- ------------------

seatingQueueClickBox = {
    color = {128,128,128,128},
    frontX = 50,
    frontY = 300,
    width = customer.width,
    height = (50 * maxCustomerCount),
    act_x = 50,
    act_y = 300 - (50 * maxCustomerCount)
}

function removeFromSeatingQueue(q)
    ret = q:dequeue()
    updateSeatingQueue(q)
    return ret
end

function addToSeatingQueue(c,q)
    q:enqueue(c)
    c.state="line"
    updateSeatingQueue(q)
end

function updateSeatingQueue(q)
    local posn = 1
    for c in values(q.elements) do 
        c.grid_x = seatingQueueClickBox.frontX
        c.grid_y = seatingQueueClickBox.frontY - (posn * 50)
        posn = posn + 1
        -- print ("updated posn of " .. c.name .. " in posn " .. posn)
    end
end

function seatingQueueClickBox:checkClick(x,y)
    if checkClick(x,y,self.act_x,self.act_y,self.width, self.height) then
        local first = seatingQueue:peekAtFirst()
        if first ~= nil then
            if selectedCustomer ~= nil then 
                selectedCustomer.selected = false
            end
            selectedCustomer = first
            first.selected = true
        end    
    end
end

function seatingQueueClickBox:draw() 
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.act_x, self.act_y, self.width, self.height)
    if timer > 0 then
        love.graphics.setColor(0,255,0)
        love.graphics.print("Open", self.act_x, 20)
    else
        love.graphics.setColor(255,0,0)
        love.graphics.print("Closed", self.act_x, 20)
    end
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

-- initialization
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

-- utility functions (Lua's a very "roll your own" language)
function checkClick(x,y,objX,objY,objWidth,objHeight)
    if x >= objX then
        if y >= objY then
            if x <= objX + objWidth then
                if y <= objY + objHeight then
                    return true
                end
            end
        end
    end
    return false
end

--  rolling my own prototype-based object system
function table.copy(t, deep, seen)
    seen = seen or {}
    if t == nil then return nil end
    if seen[t] then return seen[t] end

    local nt = {}
    for k, v in pairs(t) do
        if deep and type(v) == 'table' then
            nt[k] = table.copy(v, deep, seen)
        else
            nt[k] = v
        end
    end
    setmetatable(nt, table.copy(getmetatable(t), deep, seen))
    seen[t] = nt
    return nt
end

-- queue functions
queue = {
    myCount = 0,
    elements = {}
}

function newQueue()
    nq = table.copy(queue, true)
    return nq
end

function queue:enqueue(obj)
    table.insert(self.elements, obj)
    self.myCount = self.myCount + 1
    -- print ("enqueue - count " .. self.myCount)
end

function queue:dequeue()
    ret = table.remove(self.elements,1)
    self.myCount = self.myCount - 1
    -- print ("dequeue - count " .. self.myCount)
    return ret
end

function queue:peekAtFirst()
    return self.elements[1]
end

function queue:find(elt)
    posn = 1
    for val in values(self.elements) do
        if val == elt then 
            return posn
        end
    end
    return -1
end

function queue:size()
    return self.myCount
end

function queue:removeElement(elt)
    posn = self:find(elt)
    if posn >= 0 then
        table.remove(self.elements, posn)
        self.myCount = self.myCount - 1
        return true
    end
    return false
end
-- event queue functions - these are the time-based events
timedEvents = {}

timeEvent = {
    time = nil, -- the time to do the event
    event = nil, -- a string describing the event
    eventFunc = nil, -- the function to call in order to perform the event
    eventArg = nil -- the argument to the event function    
}

function createEvent(fromNow, name, func, arg) 
    if func == nil then
        print ("BLURG")
        error ("blug")
    end
    ret = table.copy(timeEvent)
    ret.time = wallTime + fromNow
    ret.event = name
    ret.eventFunc = func
    ret.eventArg = arg
    table.insert(timedEvents,ret)
    table.sort(timedEvents,
        function (A,B)
            return A.time < B.time
        end)
end

function peekEventTime()
    if timedEvents[1] ~= nil then
        return timedEvents[1].time
    else
        return math.huge
    end
end

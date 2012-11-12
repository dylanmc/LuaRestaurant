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
	if (toTable.seatedCustomer ~= nil) then
		if (toTable.seatedCustomer.state=="ordered") then
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
		end -- else would be interrupting an eating customer ... not helpful
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

-- TODO: seems to be doing something wrong when you don't click on the front element of the queue
-- FIXME
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



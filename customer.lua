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

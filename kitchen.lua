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
	local posn = 1
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
	local food = kitchenQueue:dequeue() -- assuming one chef
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


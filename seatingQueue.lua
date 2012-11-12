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

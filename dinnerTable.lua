-- ------------------    
-- table functions
-- ------------------

-- dinnerTable.states = { empty = "empty", customers = "customers", dirty = "dirty"}

dinnerTable = {
	act_x = 300,
	act_y = 300,
	color = {128,128,128},
	width = 75,
	height = 75,
	state = "empty",
	seatedCustomer = nil,
	tipAmount = 0,
	plateHere = nil
}


function newDinnerTable(number)
	local nt = table.copy(dinnerTable, true)
	nt.act_y = nt.act_y - ((number - 1) * 100)
	return nt
end

function dinnerTable:draw()
	love.graphics.setColor(self.color)
	love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
	love.graphics.setColor(255,255,255)
	if self.tipAmount > 0 then
		tip = string.format("%.2f", self.tipAmount)
		love.graphics.print("$" .. tip,  self.act_x + self.width - 15, self.act_y + 10)
	end
	-- love.graphics.print(self.state, self.act_x + 5, self.act_y + self.height - 10)
end

function dinnerTable:checkClick(x,y)
	if checkClick(x,y,self.act_x,self.act_y,self.width, self.height) then
		if selectedCustomer ~= nil then
			if self.state == "empty" then
				selectedCustomer:seatAtTable(self)
			else
				selectedCustomer.selected = false
				selectedCustomer = nil
			end
		else 
			newServerAction(self.act_x, self.act_y, visitTable, self, "what's going on here")
		end    
	end
end


-- Level Up Modal
-- Displays when player levels up, showing ability choices
local Settings = require("src/core/settings")

local LevelUpModal = {}

-- Create a new level up modal
-- @param player - Reference to the player entity for checking weapon levels
-- @param onClose - Callback function to call when modal is closed
-- @return A new level up modal object
function LevelUpModal.new(player, onClose)
  -- Debug log if enabled
  if Settings.debug.enabled and Settings.debug.files.levelup then
    if Debug and Debug.log then
      Debug.log("LEVELUP", "Creating level up modal")
    end
  end
  
  -- Generate upgrade options based on player's current inventory
  local options = LevelUpModal.generateOptions(player)
  
  local self = {
    width = 600,                 -- Modal width
    height = 400,                -- Modal height
    cardWidth = 160,             -- Card width
    cardHeight = 200,            -- Card height
    cardSpacing = 20,            -- Space between cards
    options = options,           -- Upgrade options
    selectedOption = nil,        -- Currently selected option
    onClose = onClose or function() end, -- Callback when modal closes
    visible = true,              -- Whether modal is visible
    blockGrid = nil,             -- Reference to block grid for positioning
    title = "LEVEL UP!"          -- Modal title
  }
  
  -- Set the metatable for the modal object
  setmetatable(self, {__index = LevelUpModal})
  
  -- Get block grid if available
  if _G.BlockGrid then
    self.blockGrid = _G.BlockGrid
  end
  
  return self
end

-- Generate upgrade options based on the player's current inventory
-- @param player - Reference to the player entity
-- @return Array of upgrade options
function LevelUpModal.generateOptions(player)
  local options = {}
  
  -- Check if debug logging is enabled
  local debugEnabled = Settings.debug.enabled and Settings.debug.files.levelup
  
  -- Add Power Chord upgrade with the correct level based on player's current inventory
  local powerChordLevel = 1
  
  -- If player exists and has weapons, check for existing Power Chord
  if player and player.weapons then
    for i, weapon in ipairs(player.weapons) do
      if weapon.name == "Power Chord" then
        powerChordLevel = weapon.level + 1
        if debugEnabled and Debug and Debug.log then
          Debug.log("LEVELUP", "Found Power Chord at level " .. weapon.level)
        end
        break
      end
    end
  end
  
  -- Add Power Chord with correct level
  table.insert(options, "Power Chord Lv" .. powerChordLevel)
  
  -- Add other weapon options
  table.insert(options, "Bass Drop")
  
  -- Add stat boost option
  table.insert(options, "Speed Up")
  
  -- Log generated options if debug is enabled
  if debugEnabled and Debug and Debug.log then
    Debug.log("LEVELUP", "Generated options: " .. table.concat(options, ", "))
  end
  
  return options
end

-- Update the level up modal
-- @param dt - Delta time since last update
function LevelUpModal:update(dt)
  -- Nothing to update if not visible
  if not self.visible then return end
  
  -- Animation updates could go here
end

-- Draw the level up modal
function LevelUpModal:draw()
  -- Skip if not visible
  if not self.visible then return end
  
  -- Save current graphics state
  love.graphics.push("all")
  
  -- Get screen dimensions
  local screenWidth, screenHeight = love.graphics.getDimensions()

  local modalWidth = math.min(self.width, screenWidth - 40)
  local modalHeight = math.min(self.height, screenHeight - 40)

  local x = (screenWidth - modalWidth) / 2
  local y = (screenHeight - modalHeight) / 2
  
  -- Draw semi-transparent background overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
  
  -- Draw modal background
  love.graphics.setColor(0.2, 0.2, 0.25, 0.95)
  love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10, 10)
  love.graphics.setColor(0.5, 0.5, 0.6, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10, 10)
  
  -- Draw title
  love.graphics.setColor(1, 0.8, 0.2, 1)
  love.graphics.setFont(love.graphics.newFont(32))
  local titleWidth = love.graphics.getFont():getWidth(self.title)
  love.graphics.print(self.title, x + (modalWidth - titleWidth) / 2, y + 30)
  
  -- Draw subtitle
  love.graphics.setColor(0.9, 0.9, 0.9, 1)
  love.graphics.setFont(love.graphics.newFont(18))
  local subtitle = "Choose an upgrade:"
  local subtitleWidth = love.graphics.getFont():getWidth(subtitle)
  love.graphics.print(subtitle, x + (modalWidth - subtitleWidth) / 2, y + 80)
  
  -- Calculate card positions
  local totalCardsWidth = (#self.options * self.cardWidth) + ((#self.options - 1) * self.cardSpacing)
  local startX = x + (modalWidth - totalCardsWidth) / 2
  local cardY = y + 120
  
  -- Draw each option card
  for i, option in ipairs(self.options) do
    local cardX = startX + (i-1) * (self.cardWidth + self.cardSpacing)
    
    -- Draw card background
    if self.selectedOption == i then
      -- Highlighted card
      love.graphics.setColor(0.3, 0.6, 0.9, 0.8)
    else
      -- Normal card
      love.graphics.setColor(0.3, 0.3, 0.4, 0.8)
    end
    love.graphics.rectangle("fill", cardX, cardY, self.cardWidth, self.cardHeight, 5, 5)
    
    -- Card border
    love.graphics.setColor(0.5, 0.5, 0.6, 1)
    love.graphics.rectangle("line", cardX, cardY, self.cardWidth, self.cardHeight, 5, 5)
    
    -- Draw option number
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(36))
    love.graphics.printf(i, cardX, cardY + 20, self.cardWidth, "center")
    
    -- Draw option name (split into multiple lines if needed)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf(option, cardX + 10, cardY + 80, self.cardWidth - 20, "center")
    
    -- Draw hint to select
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.printf("Press " .. i .. " or click", cardX + 10, cardY + self.cardHeight - 30, self.cardWidth - 20, "center")
  end
  
  -- Restore graphics state
  love.graphics.pop()
end

-- Handle key press events
-- @param key - Key that was pressed
function LevelUpModal:keypressed(key)
  -- Skip if not visible
  if not self.visible then return end
  
  -- Check for number keys
  local num = tonumber(key)
  if num and num >= 1 and num <= #self.options then
    self:selectOption(num)
  end
  
  -- Check for escape key to close without selecting
  if key == "escape" then
    self:close()
  end
end

-- Handle mouse press events
-- @param x - Mouse X position
-- @param y - Mouse Y position
-- @param button - Mouse button that was pressed
function LevelUpModal:mousepressed(x, y, button)
  -- Skip if not visible
  if not self.visible then return end
  
  -- Only handle left mouse button
  if button ~= 1 then return end
  
  -- Calculate modal position
  local screenWidth, screenHeight = love.graphics.getDimensions()
  local modalWidth = math.min(self.width, screenWidth - 40)
  local modalHeight = math.min(self.height, screenHeight - 40)
  local modalX = (screenWidth - modalWidth) / 2
  local modalY = (screenHeight - modalHeight) / 2
  
  -- Calculate card positions
  local totalCardsWidth = (#self.options * self.cardWidth) + ((#self.options - 1) * self.cardSpacing)
  local startX = modalX + (modalWidth - totalCardsWidth) / 2
  local cardY = modalY + 120
  
  -- Check each card
  for i = 1, #self.options do
    local cardX = startX + (i-1) * (self.cardWidth + self.cardSpacing)
    
    -- Check if click is inside card
    if x >= cardX and x <= cardX + self.cardWidth and
       y >= cardY and y <= cardY + self.cardHeight then
      self:selectOption(i)
      return
    end
  end
end

-- Select an upgrade option
-- @param index - Index of the option to select
function LevelUpModal:selectOption(index)
  -- Check if index is valid
  if index < 1 or index > #self.options then
    return
  end
  
  -- Set selected option
  self.selectedOption = index
  local selectedCard = self.options[index]
  
  -- Log the selection
  if Debug then
    Debug.log("LEVEL", "Selected upgrade: " .. selectedCard)
  end
  
  -- Send event for the selected card
  if EventBus then
    EventBus:emit("CARD_PICKED", {
      card = selectedCard
    })
  end
  
  -- Close the modal
  self:close()
end

-- Close the modal
function LevelUpModal:close()
  self.visible = false
  
  -- Call the close callback
  if self.onClose then
    self.onClose(self.selectedOption)
  end
end

-- Return the level up modal module
return LevelUpModal

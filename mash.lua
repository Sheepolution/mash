--
-- Mash
--
-- Copyright (c) 2025 Sheepolution

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

-- Each category maps input names to their current state
local INPUT = {
    key = {},    -- Keyboard keys by name
    sc = {},     -- Scancodes by name
    mouse = {},  -- Mouse buttons by number
    button = {}, -- Gamepad buttons by joystick ID and button name
    axis = {},   -- Gamepad axes by joystick ID and axis name
}

-- Input modes for automatic switching between input types
local modes = {
    both = 1,     -- Accept both keyboard and gamepad input
    joystick = 2, -- Only accept gamepad input
    keyboard = 3  -- Only accept keyboard input
}

local mash = {}

-- Internal state tracking
mash._data = {
    mouse = {},       -- Current mouse position {x, y}
    wheel = {},       -- Current wheel movement {x, y}
    joystick = {},    -- Gamepad analog stick data by joystick ID
}
mash._threshold = 0.5 -- Deadzone threshold for analog inputs (0-1)
mash._last = -1       -- Last input device used (-1 = keyboard, joystick ID = gamepad)

--- Parses a trigger string into category and input name
-- @param trigger_string string The trigger string (e.g., "button:a", "key:space", "leftx+")
-- @return string input_category The input category ("key", "button", "axis", etc.)
-- @return string input_name The input name ("a", "space", "leftx+", etc.)
local function parse_trigger(trigger_string)
    local input_category, input_name = trigger_string:match('(.+):(.+)')
    if input_category then
        return input_category, input_name
    end

    -- Default to keyboard key if no category specified
    return "key", trigger_string
end

local function get_joystick_id(joystick)
    local numeric_id = tonumber(joystick)
    if numeric_id then
        return numeric_id
    end

    return joystick:getID()
end

local function get_new_joystick_data()
    return {
        left = { x = 0, y = 0 },  -- Left analog stick
        right = { x = 0, y = 0 }, -- Right analog stick
        triggerleft = 0,          -- Left trigger value
        triggerright = 0          -- Right trigger value
    }
end

local function get_input(category, name, joystick_id)
    if joystick_id then
        joystick_id = get_joystick_id(joystick_id)
        if not INPUT[category][joystick_id] then
            INPUT[category][joystick_id] = {}
        end

        if not INPUT[category][joystick_id][name] then
            INPUT[category][joystick_id][name] = {}
        end

        return INPUT[category][joystick_id][name]
    end

    if not INPUT[category][name] then
        INPUT[category][name] = {}
    end

    return INPUT[category][name]
end

local function inject(callback_name, callback_function)
    local existing_callback = love[callback_name]
    if existing_callback then
        love[callback_name] = function(...)
            existing_callback(...)
            callback_function(...)
        end
    else
        love[callback_name] = callback_function
    end
end

--- Handles keyboard key press events
-- @param key string The key that was pressed
-- @param sc string The scancode of the pressed key
function mash.keypressed(key, sc)
    assert(type(key) == "string", "Key must be a string")
    assert(type(sc) == "string", "Scancode must be a string")

    local input = get_input("key", key)
    input.pressed = true
    input.down = true

    local input_sc = get_input("sc", sc)
    input_sc.pressed = true
    input_sc.down = true
    mash._last = -1
end

--- Handles keyboard key release events
-- @param key string The key that was released
-- @param sc string The scancode of the released key
function mash.keyreleased(key, sc)
    assert(type(key) == "string", "Key must be a string")
    assert(type(sc) == "string", "Scancode must be a string")

    local input = get_input("key", key)
    input.down = false
    input.released = true

    local input_sc = get_input("sc", sc)
    input_sc.down = false
    input_sc.released = true
    mash._last = -1
end

--- Handles mouse button press events
-- @param x number Mouse x position when pressed
-- @param y number Mouse y position when pressed
-- @param button number Mouse button that was pressed (1=left, 2=right, 3=middle)
function mash.mousepressed(x, y, button)
    assert(type(x) == "number", "Mouse x must be a number")
    assert(type(y) == "number", "Mouse y must be a number")
    assert(type(button) == "number" and button > 0, "Button must be a positive number")

    local input = get_input("mouse", tostring(button))
    input.pressed = true
    input.down = true
    mash._last = -1
end

--- Handles mouse button release events
-- @param x number Mouse x position when released
-- @param y number Mouse y position when released
-- @param button number Mouse button that was released
function mash.mousereleased(x, y, button)
    assert(type(x) == "number", "Mouse x must be a number")
    assert(type(y) == "number", "Mouse y must be a number")
    assert(type(button) == "number" and button > 0, "Button must be a positive number")

    local input = get_input("mouse", tostring(button))
    input.down = false
    input.released = true
    mash._last = -1
end

--- Handles mouse movement events
-- @param x number New mouse x position
-- @param y number New mouse y position
function mash.mousemoved(x, y)
    assert(type(x) == "number", "Mouse x must be a number")
    assert(type(y) == "number", "Mouse y must be a number")

    mash._data.mouse.x = x
    mash._data.mouse.y = y
    mash._last = -1
end

--- Handles mouse wheel movement events
-- @param x number Horizontal wheel movement
-- @param y number Vertical wheel movement
function mash.wheelmoved(x, y)
    assert(type(x) == "number", "Wheel x must be a number")
    assert(type(y) == "number", "Wheel y must be a number")

    -- Map wheel directions to virtual mouse buttons
    if x < 0 then
        get_input("mouse", "wr").pressed = true -- wheel right
    elseif x > 0 then
        get_input("mouse", "wl").pressed = true -- wheel left
    end

    if y < 0 then
        get_input("mouse", "wd").pressed = true -- wheel down
    elseif y > 0 then
        get_input("mouse", "wu").pressed = true -- wheel up
    end

    -- Store wheel values (only update if non-zero to preserve momentum)
    mash._data.wheel.x = x ~= 0 and x or mash._data.wheel.x
    mash._data.wheel.y = y ~= 0 and y or mash._data.wheel.y
    mash._last = -1
end

--- Handles gamepad button press events
-- @param joystick Joystick The joystick object that generated the event
-- @param button string The name of the button that was pressed
function mash.gamepadpressed(joystick, button)
    assert(joystick and joystick.getID, "Invalid joystick object")
    assert(type(button) == "string", "Button must be a string")

    local input = get_input("button", button, joystick:getID())
    input.pressed = true
    input.down = true
    mash._last = joystick:getID()
end

--- Handles gamepad button release events
-- @param joystick Joystick The joystick object that generated the event
-- @param button string The name of the button that was released
function mash.gamepadreleased(joystick, button)
    assert(joystick and joystick.getID, "Invalid joystick object")
    assert(type(button) == "string", "Button must be a string")

    local input = get_input("button", button, joystick:getID())
    input.down = false
    input.released = true
    mash._last = joystick:getID()
end

--- Handles gamepad axis movement events
-- @param joystick Joystick The joystick object that generated the event
-- @param axis_name string The name of the axis that moved (e.g., "leftx", "lefty", "triggerleft")
-- @param axis_value number The new axis value (-1 to 1 for sticks, 0 to 1 for triggers)
function mash.gamepadaxis(joystick, axis_name, axis_value)
    assert(joystick and joystick.getID, "Invalid joystick object")
    assert(type(axis_name) == "string", "Axis must be a string")
    assert(type(axis_value) == "number", "Value must be a number")
    assert(axis_value >= -1 and axis_value <= 1, "Axis value must be between -1 and 1")

    local joystick_id = joystick:getID()
    mash._last = joystick_id

    -- Extract axis base name and coordinate (x or y)
    local base_axis_name, coordinate = axis_name:match("([%a]+)([xy])")
    coordinate = coordinate or "x"

    if not mash._data.joystick[joystick_id] then
        mash._data.joystick[joystick_id] = get_new_joystick_data()
    end

    local joystick_data = mash._data.joystick[joystick_id]

    -- Handle positive axis direction (e.g., "leftx+")
    local positive_input = get_input("axis", axis_name .. "+", joystick_id)
    local previous_positive_value = positive_input[coordinate] or 0

    if previous_positive_value <= mash._threshold then
        if axis_value > mash._threshold then
            positive_input.pressed = true
            positive_input.down = true
        end
    else
        if axis_value <= mash._threshold then
            positive_input.down = false
            positive_input.released = true
        end
    end

    positive_input[coordinate] = axis_value

    -- Triggers don't have negative values, so skip negative axis handling
    if axis_name == "triggerleft" or axis_name == "triggerright" then
        joystick_data[axis_name] = axis_value
        return
    end

    -- Handle negative axis direction (e.g., "leftx-")
    local negative_input = get_input("axis", axis_name .. "-", joystick_id)
    local previous_negative_value = negative_input[coordinate] or 0

    if previous_negative_value >= -mash._threshold then
        if axis_value < -mash._threshold then
            negative_input.pressed = true
            negative_input.down = true
        end
    else
        if axis_value >= -mash._threshold then
            negative_input.down = false
            negative_input.released = true
        end
    end

    negative_input[coordinate] = axis_value

    -- Store the raw axis value in joystick data
    if base_axis_name then
        joystick_data[base_axis_name][coordinate] = axis_value
    end
end

--- Injects Mash's input handlers into LÖVE's callback system
-- This function automatically integrates Mash with LÖVE by hooking into
-- all the necessary input callbacks. Call this once during initialization.
function mash.inject()
    inject("keypressed", mash.keypressed)
    inject("keyreleased", mash.keyreleased)
    inject("mousepressed", mash.mousepressed)
    inject("mousereleased", mash.mousereleased)
    inject("mousemoved", mash.mousemoved)
    inject("wheelmoved", mash.wheelmoved)
    inject("gamepadpressed", mash.gamepadpressed)
    inject("gamepadreleased", mash.gamepadreleased)
    inject("gamepadaxis", mash.gamepadaxis)
end

-- Create direct access tables for each input category
-- These allow syntax like mash.key.space.down or mash.mouse[1].pressed
for name, _ in pairs(INPUT) do
    local joystick = (name == "button" or name == "axis") and 1 or nil
    mash[name] = setmetatable({}, {
        __index = function(t, k)
            return get_input(name, tostring(k), joystick)
        end
    })
end

--- Resets all input states for the next frame
-- This should be called at the end of each frame (typically in love.update)
-- to clear pressed/released flags and prepare for the next frame's input
function mash.reset()
    -- Reset keyboard inputs
    for _, input in pairs(INPUT.key) do
        input.pressed = false
        input.released = false
    end

    -- Reset scancode inputs
    for _, input in pairs(INPUT.sc) do
        input.pressed = false
        input.released = false
    end

    -- Reset mouse inputs
    for _, input in pairs(INPUT.mouse) do
        input.pressed = false
        input.released = false
    end

    -- Reset gamepad button inputs
    for _, joystick in pairs(INPUT.button) do
        for __, button in pairs(joystick) do
            button.pressed = false
            button.released = false
        end
    end

    -- Reset gamepad axis inputs
    for _, joystick in pairs(INPUT.axis) do
        for __, axis in pairs(joystick) do
            axis.pressed = false
            axis.released = false
        end
    end

    -- Reset wheel movement
    mash._data.wheel.x = 0
    mash._data.wheel.y = 0
end

--- Sets the deadzone threshold for analog inputs
-- @param threshold number The new threshold value (0-1, default 0.5)
function mash.setThreshold(threshold)
    assert(type(threshold) == "number", "Threshold must be a number")
    assert(threshold >= 0 and threshold <= 1, "Threshold must be between 0 and 1")

    mash._threshold = threshold
end

-- Control mapping for common gamepad input aliases
-- Maps common gamepad control names to their actual input names
local control_map = {
    ["triggerleft"] = "triggerleft+",
    ["triggerright"] = "triggerright+",
    ["lt"] = "triggerleft+",  -- Xbox-style left trigger
    ["rt"] = "triggerright+", -- Xbox-style right trigger
    ["lb"] = "leftshoulder",  -- Xbox-style left bumper
    ["rb"] = "rightshoulder", -- Xbox-style right bumper
}

-- Metatable for mash instance methods
local instance_mt = {}
instance_mt.__index = instance_mt

local function trigger_to_input(trigger_string, joystick_id)
    assert(type(trigger_string) == "string", "Trigger must be a string")

    local input_category, input_name = parse_trigger(trigger_string)
    input_name = control_map[input_name] or input_name

    if input_category == "button" or input_category == "axis" then
        return get_input(input_category, input_name, joystick_id)
    end

    return get_input(input_category, input_name)
end

--- Sets the control configuration for this input instance
-- @param controls table A table mapping control names to trigger definitions
--   - Key: string - The name of the control (e.g., "jump", "move_left")
--   - Value: string|table|function - The trigger definition:
--     - string: Single trigger (e.g., "key:space")
--     - table: Multiple triggers (e.g., {"key:space", "button:a"})
--     - function: Custom function returning (pressed, x, y)
function instance_mt:setControls(controls)
    assert(type(controls) == "table", "Controls must be a table")

    local controls_list = {}
    for name, value in pairs(controls) do
        assert(type(name) == "string", "Control name must be a string")

        local definition_type = type(value)
        local config = {
            name = name,
        }

        if definition_type == "string" then
            -- Single trigger string
            config.list = { trigger_to_input(value, self._joystickId or 1) }
            self[name] = {}
        elseif definition_type == "table" then
            -- Multiple trigger strings
            local input_list = {}
            for _, trigger_string in ipairs(value) do
                assert(type(trigger_string) == "string", "Trigger item must be a string")
                local input_state = trigger_to_input(trigger_string, self._joystickId or 1)
                table.insert(input_list, input_state)
            end
            config.list = input_list
            self[name] = {}
        elseif definition_type == "function" then
            -- Custom function
            config.func = value
            self[name] = {}
        else
            error("Invalid trigger type: " .. definition_type .. " for control: " .. name)
        end

        table.insert(controls_list, config)
    end

    self._controls = controls_list
end

--- Updates all controls for this input instance
-- This should be called once per frame, typically in love.update()
-- It processes all configured controls and updates their state
function instance_mt:update()
    if not self._controls then
        return
    end

    for _, control_config in ipairs(self._controls) do
        local control_state = self[control_config.name]

        if control_config.list then
            -- Handle trigger list (string or table of strings)
            control_state.pressed = false
            control_state.down = false
            control_state.released = false
            control_state.x = 0
            control_state.y = 0

            -- Aggregate state from all triggers in the list
            for __, input_state in ipairs(control_config.list) do
                control_state.pressed = control_state.pressed or input_state.pressed
                control_state.down = control_state.down or input_state.down
                control_state.released = control_state.released or input_state.released

                -- Use the strongest axis value (highest absolute value)
                if input_state.x and input_state.x ^ 2 > control_state.x ^ 2 then
                    control_state.x = input_state.x
                end

                if input_state.y and input_state.y ^ 2 > control_state.y ^ 2 then
                    control_state.y = input_state.y
                end
            end
        else
            -- Handle custom function
            local current_state = control_config.state
            local new_state, axis_x, axis_y = control_config.func()
            control_state.x, control_state.y = axis_x or 0, axis_y or 0

            -- Detect state changes for pressed/released events
            if current_state == new_state then
                -- No state change
                control_state.pressed = false
                if not current_state then
                    control_state.down = false
                    control_state.released = false
                end
            elseif not current_state then
                -- Became active
                control_state.pressed = true
                control_state.down = true
                control_state.released = false
            else
                -- Became inactive
                control_state.pressed = false
                control_state.down = false
                control_state.released = true
            end
            control_config.state = new_state
        end
    end

    -- Handle automatic input method switching
    if self._autoSwitch then
        if mash._last == -1 then
            self._mode = modes.keyboard
        elseif self._joystickId == mash._last then
            self._mode = modes.joystick
        end
    end
end

--- Sets the input mode for this instance
-- @param mode string The input mode ("both", "keyboard", "joystick")
function instance_mt:setMode(mode)
    assert(type(mode) == "string", "Mode must be a string")
    assert(modes[mode], "Invalid mode: " .. mode)

    self._mode = modes[mode]
    self._autoSwitch = false
end

--- Gets the current input mode
-- @return string The current input mode ("both", "keyboard", "joystick")
function instance_mt:getMode()
    for mode, value in pairs(modes) do
        if self._mode == value then
            return mode
        end
    end
    return "both" -- fallback
end

--- Sets whether to automatically switch between input modes
-- @param state boolean True to enable automatic switching
function instance_mt:setAutoSwitch(state)
    assert(type(state) == "boolean", "Auto switch state must be boolean")
    self._autoSwitch = state
end

--- Gets the current auto-switch setting
-- @return boolean True if auto-switching is enabled
function instance_mt:getAutoSwitch()
    return self._autoSwitch
end

--- Sets the joystick for this input instance
-- @param joystick number|Joystick Either a joystick ID or LÖVE Joystick object
function instance_mt:setJoystick(joystick)
    local id = get_joystick_id(joystick)
    self._joystickId = id

    -- Re-apply controls with new joystick ID
    if self._controls then
        self:setControls(self._controls)
    end
end

--- Gets the LÖVE Joystick object for this instance
-- @return Joystick|nil The Joystick object, or nil if not found
function instance_mt:getJoystick()
    if not love.joystick then
        return nil
    end

    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:getID() == self._joystickId then
            return joystick
        end
    end
    return nil
end

--- Sets a transform matrix for mouse coordinate conversion
-- @param transform Transform A LÖVE Transform object for coordinate conversion
function instance_mt:setTransform(transform)
    assert(not transform or (transform and transform.inverseTransformPoint),
        "Transform must be a valid LÖVE Transform object or nil")
    self._transform = transform
end

--- Gets the current transform matrix
-- @return Transform|nil The current transform or nil
function instance_mt:getTransform()
    return self._transform
end

--- Vibrates the gamepad associated with this instance
-- @param left number Left motor strength (0-1)
-- @param right number Right motor strength (0-1)
-- @param duration number Duration in seconds (optional)
function instance_mt:vibrate(left, right, duration)
    assert(type(left) == "number", "Left strength must be a number")
    assert(type(right) == "number", "Right strength must be a number")
    assert(left >= 0 and left <= 1, "Left strength must be between 0 and 1")
    assert(right >= 0 and right <= 1, "Right strength must be between 0 and 1")
    assert(not duration or type(duration) == "number", "Duration must be a number or nil")

    -- Only vibrate in joystick or both modes (not keyboard-only mode)
    if self._mode == modes.keyboard then
        return
    end

    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:getID() == self._joystickId then
            if joystick:isVibrationSupported() then
                joystick:setVibration(left, right, duration)
            end
            return
        end
    end
end

-- Metatable for input value getters
local get_mt = {}
get_mt.__index = get_mt

--- Gets the current mouse position, optionally transformed
-- @param transform Transform Optional transform to apply (overrides instance transform)
-- @return number x The mouse x coordinate
-- @return number y The mouse y coordinate
function get_mt:mouse(transform)
    local x, y = mash._data.mouse.x or 0, mash._data.mouse.y or 0
    transform = transform or self._transform

    if transform and transform.inverseTransformPoint then
        return transform:inverseTransformPoint(x, y)
    end
    return x, y
end

--- Gets the current mouse wheel movement
-- @return number x Horizontal wheel movement
-- @return number y Vertical wheel movement
function get_mt:wheel()
    return mash._data.wheel.x or 0, mash._data.wheel.y or 0
end

--- Gets the left analog stick position
-- @param joystick number|Joystick Optional specific joystick to query
-- @return number x The x-axis value (-1 to 1)
-- @return number y The y-axis value (-1 to 1)
function get_mt:left(joystick)
    if self._parent._mode == modes.keyboard then
        return 0, 0
    end

    joystick = joystick and get_joystick_id(joystick) or self._parent._joystickId

    if not mash._data.joystick[joystick] then
        mash._data.joystick[joystick] = get_new_joystick_data()
    end

    local x = mash._data.joystick[joystick].left.x
    local y = mash._data.joystick[joystick].left.y
    return x, y
end

--- Gets the right analog stick position
-- @param joystick number|Joystick Optional specific joystick to query
-- @return number x The x-axis value (-1 to 1)
-- @return number y The y-axis value (-1 to 1)
function get_mt:right(joystick)
    if self._parent._mode == modes.keyboard then
        return 0, 0
    end

    joystick = joystick and get_joystick_id(joystick) or self._parent._joystickId

    if not mash._data.joystick[joystick] then
        mash._data.joystick[joystick] = get_new_joystick_data()
    end

    local x = mash._data.joystick[joystick].right.x
    local y = mash._data.joystick[joystick].right.y
    return x, y
end

--- Gets the left trigger value
-- @param joystick number|Joystick Optional specific joystick to query
-- @return number The trigger value (0 to 1)
function get_mt:lt(joystick)
    if self._parent._mode == modes.keyboard then
        return 0
    end

    joystick = joystick and get_joystick_id(joystick) or self._parent._joystickId

    if not mash._data.joystick[joystick] then
        mash._data.joystick[joystick] = get_new_joystick_data()
    end

    return mash._data.joystick[joystick].triggerleft or 0
end

-- Alias for left trigger
get_mt.triggerleft = get_mt.lt

--- Gets the right trigger value
-- @param joystick number|Joystick Optional specific joystick to query
-- @return number The trigger value (0 to 1)
function get_mt:rt(joystick)
    if self._parent._mode == modes.keyboard then
        return 0
    end

    joystick = joystick and get_joystick_id(joystick) or self._parent._joystickId

    if not mash._data.joystick[joystick] then
        mash._data.joystick[joystick] = get_new_joystick_data()
    end

    return mash._data.joystick[joystick].triggerright or 0
end

-- Alias for right trigger
get_mt.triggerright = get_mt.rt

--- Gets both trigger values
-- @param joystick number|Joystick Optional specific joystick to query
-- @return number left Left trigger value (0 to 1)
-- @return number right Right trigger value (0 to 1)
function get_mt:trigger(joystick)
    return self:lt(joystick), self:rt(joystick)
end

-- Global getter instance for direct access to input values
mash.get = setmetatable({ _parent = { _joystickId = 1, _mode = modes.both } }, get_mt)

--- Creates a new Mash input instance
-- @param config table Configuration table with the following optional fields:
--   - controls: table - Control definitions mapping names to triggers
--   - mode: string - Input mode ("both", "keyboard", "joystick", default: "both")
--   - autoSwitch: boolean - Enable automatic mode switching (default: false)
--   - transform: Transform - Transform for mouse coordinates (default: nil)
--   - joystick: number|Joystick - Joystick to use (default: 1)
-- @return table A new Mash input instance
function mash.new(config)
    assert(type(config) == "table", "Config must be a table")

    config = config or {}

    -- Validate mode if specified
    if config.mode then
        assert(type(config.mode) == "string", "Mode must be a string")
        assert(modes[config.mode], "Invalid mode: " .. config.mode)
    end

    -- Validate joystick if specified
    local joystickId = 1
    if config.joystick then
        joystickId = get_joystick_id(config.joystick)
    end

    -- Create the instance
    local instance = setmetatable({
        _mode = modes[config.mode] or modes.both,
        _autoSwitch = config.autoSwitch or false,
        _transform = config.transform,
        _joystickId = joystickId
    }, instance_mt)

    -- Initialize joystick data if needed
    if not mash._data.joystick[instance._joystickId] then
        mash._data.joystick[instance._joystickId] = get_new_joystick_data()
    end

    -- Set up controls if provided
    if config.controls then
        instance:setControls(config.controls)
    end

    -- Create getter instance for this input instance
    instance.get = setmetatable({ _parent = instance }, get_mt)

    return instance
end

return mash

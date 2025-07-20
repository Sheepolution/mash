# Mash

Mash is an input library for [LÖVE](https://love2d.org), allowing for inline checks on the different states (pressed, down, released), and for separate instances that have their own control configuration. Mash tries to cover most input-related needs, and allows the user to add their own with the use of functions.

Mash was inspired by [Baton](https://github.com/tesselode/baton).

## Design philosophy

While different system might use different types of input (it makes sense for a player and a menu to have two separate input configurations) a user ultimately only has one keyboard and mouse. It therefore makes sense that we keep track of this keyboard and mouse only once, and for all instances to pull from this data.

## Installation

The `mash.lua` file should be dropped into an existing project and required by it.

```lua
mash = require "mash"
```

Mash needs access to LÖVE's input callbacks. You can add these all at once by using `mash.inject()`, which will automatically insert all of its functions into the approriate callbacks (being called after the original, if it exists).

```lua
function love.keypressed(key, scancode)
    -- code
end

mash.inject()
```

Alternatively, you can insert these methods yourself.

```lua
function love.keypressed(key, scancode)
    -- code
    mash.keypressed(key, scancode)
end
```

At the end of your `love.update`, after your game's logic, you call `mash.reset()`. This resets all input until the start of the next frame (after which LÖVE's input callbacks have been called). If you want to use input when drawing, you should put it at the end of `love.draw`.

```lua
function love.update(dt)
    -- game logic
    mash.reset()
end
```

> [!WARNING]
> Mash depends on the fact that there shall only be one `mash` object. If you remove `mash` from `package.loaded` and reload it again, you may find unexpected behavior.

## Usage

You can now use  `mash` to get input. There are 5 types of input:
* `key` - Keyboard
* `sc` - Keyboard scancodes
* `mouse` - Mouse
* `button` - Joystick (specifically gamepads)
* `axis` - Joystick axes

For each input, there are three states:

* `pressed` - Was the input pressed?
* `down` - Is the input currently down?
* `released` - Was the input released?

To check if the user pressed the `right` arrow key, we use:

```lua
if mash.key.right.pressed then
    print("Pressed the right arrow key!")
end
```

### Instance

We can create a separate instance using `mash.new(config)`. We pass a configuration table, with most importantly the `controls`. We can deliver controls in three separate ways:

* String
* Table
* Function

We can use the syntax `[type]:[source]` to set the type of input. If no type is provided it defaults to `key:[source]`.

```lua
local input = mash.new({
    controls = {
        jump = "key:space",
        shoot = { "x", "button:x" }, -- "x" defaults to "key:x"
        crouch = function ()
            return not (mash.key.left.down or mash.key.right.down)
        end
    }
})
```

An instance must be updated, which you should do before accessing it.

```lua
function Player:update()
    input:update()
    -- player logic
end
```

We can then access the controls using `instance[name]`, where `instance` is the variable of your instance.

```lua
function Player:update()
    input:update()

    if input.jump.released then
        print("Released the jump key (space).")
    end

    if input.shoot.down then
        print("Either the key 'x' or the button 'x' on a joystick is being held down.")
    end

    if input.crouch.released then
        print("Either jump or shoot was pressed")
    end
end
```

**String**

Providing a string (e.g. `"key:space"`) is straightforward. The states of `input.jump` are based on whether the spacebar was pressed, is being held down, or was released.

**Table**

When providing a table of strings, the states are combined. With `shoot = {"key:z", "key:x"}`, we have `input.shoot.pressed` being `true` when either `z` or `x` was pressed. If both `z` and `x` are being held down, and the user lets go of `z`, then both `input.shoot.down` and `input.shoot.released` will be `true`.

**Functions**

Functions work like states. In the example above, the moment `left` or `right` is being held down, the function returns `false`, and the input exits the state. This causes `released` to be `true`. Once `left` or `right` are both let go off again, the function re-enters the state, causing `pressed` to be `true`. We use other inputs in this example, but the function can contain and return whatever you want. You could technically use Mash as a sort of state manager, though that is not recommended. This feature is to cover any shortcomings Mash might have, like actions on a specific axis value.

#### Joysticks

By default, instances will use the joystick with ID `1`. You can set a different joystick in the configuration table. or by using `input:setJoystick(joystick_or_id)`.

```lua
local input = mash.new({
    controls = {
        jump = "key:space",
        shoot = { "x", "button:x" }, -- "x" defaults to "key:x"
        crouch = function ()
            return not (mash.key.left.down or mash.key.right.down)
        end
    },
    joystick = 2
})

input:setJoystick(joystick_object)
```

#### Axes

We can use the syntax `axis:[name][x/y][+/-]` to set an axis. For example:

```lua
local input = mash.new({
    controls = {
        walk = "axis:lefty-",
        fire = "axis:lt"
        move = { "axis:leftx-", "axis:leftx+", "axis:lefty-", "axis:lefty+" }
        aim  = { "axis:lefty-", "axis:righty-" }
    }
})
```

This triggers `walk` when the left control stick is pointed upwards (giving it a negative value) past the threshold. This is a global threshold shared between all Mash instances, which can be set with `mash.setAxisThreshold(threshold)`, and is `0.5` by default.

`axis:lt` refers to the left trigger It does not need an axis nor a direction.

We can use `input.move.x` and `input.move.y` to get the exact axes, which default to `0` in case no axes are used in the control. In case multiple axes are used, like with `aim`, it takes the outer values. If `lefty` is `0.6` and `righty` is `-0.8`, then `input.aim.y` will be `-0.8`. Because `aim` does not use an axis with `x`, it defaults to `0`. In the case of the left and right trigger, it will use `x`, meaning `input.fire.x` will have a value, but `input.fire.y` will always be `0`.

In the case of functions we can return a second and third value which will set the `x` and `y` value respectively. 

#### Get

Both Mash and instances have a `get` object that can be used to get specific values. For example, we can get the `x` and `y` position of the mouse by using `input.get:mouse()`.

* `get:mouse()` - Get the mouse position. You can pass a transform object to apply `:inverseTransformPoint()` to the coordinates. This transform object can be set using the `transform` property in the configuration, or by using `input:setTransform(transform)`.
* `get:wheel()` - The x and y value of the scrolling done this frame.
* `get:left()` - Get the axes of the left control stick. You can pass a joystick object or id, otherwise the previously set joystick will be used (which defaults to 1).
* `get:right()` - Get the axes of the right control stick.
* `get:triggerleft()` - Get the value of the left trigger. Alternatively `get:lt()` can be used for short.
* `get:triggerright()` - Get the value of the right trigger. Alternatively `get:rt()` can be used for short.
* `get:trigger()` - Get the values of the left and right trigger respectively.

Using these values in combinations with functions grants us the ability to create input with specific tresholds.

```lua
local input = mash.new({
    controls = {
        walk_left = function ()
            local x, y = input.get:left()
            return x < -0.2, x, y
        end
    }
})
```

#### Modes and switching

A mash instance knows three modes:
* `keyboard`
* `joystick`
* `both`

Depending on which mode is active, an instance will behave differently. When in `keyboard` mode, the joystick axes will always return `1, 1`. Also, calling `instance:vibrate(.5, .5, 2)` won't do anything in `keyboard` mode. This prevents a vibrating controller falling off the table and hurting a cat as the user is using their keyboard to play your game.

You can set the `mode` in the configuration, or change it with `input:setMode(mode)`. You can also make it switch automatically by turning on auto-switching, which you can do with `autoSwitch` in the configuration, or by using `input:setAutoSwitch(state)`.

When auto-switching is on, the mode will change depending on the last type of input that was pressed. However, it will only switch to controller if that last used controller matches the ID of the configured controller of the input.

By default, the mode `both` is active, and autoswitching is *off*.

## API

### Mash

* `mash.get` - Use the [Get API](#get-1).
* `mash.new(config)` - Create a new [Instance](#instance-1). See [Configuration](#configuration).
* `mash.setThreshold(threshold)` - Set the global threshold for joystick axes.
* `mash.reset()` - Reset all input. Should be called at the end of a frame.
* `mash.inject()` - Inject all the required callbacks into the (existing) LÖVE callbacks.
    * The callbacks, in case you want to add them yourself: `mash.keypressed`, `mash.keyreleased`, `mash.mousepressed`, `mash.mousereleased`, `mash.mousemoved`, `mash.wheelmoved`, `mash.gamepadpressed`, `mash.gamepadreleased`, `mash.gamepadaxis`.

#### Configuration

* `controls` - See [Controls](#controls).
* `mode` - Set mode to `keyboard`, `joystick`, or `both`. Defaults to `both`.
* `autoSwitch` - Whether the mode should automatically switch based on the last input used. Defaults to `false`.
* `joystick` - The joystick (or its ID) used with this instance. Defaults to `1`.
* `transform` - A transform object to use `:inverseTransformPoint()` with when using `get:mouse()`.

##### Controls

Syntax: `[type][source]`

| Type    | Description                  | Source                                                                                                                                                                  |
| --------| -----------------------------| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `key`   | A keyboard key.              | Any LÖVE [KeyConstant](http://love2d.org/wiki/KeyConstant)                                                                                                              |
| `sc`    | A scancode.                  | Any LÖVE [KeyConstant](http://love2d.org/wiki/KeyConstant)                                                                                                              |
| `mouse` | A mouse button.              | A number representing a mouse button (see [love.mouse.isDown](https://love2d.org/wiki/love.mouse.isDown))                                                               |
| `button`| A joystick or gamepad button.| Either a number representing a joystick button or a LÖVE [GamepadButton](http://love2d.org/wiki/GamepadButton)                                                          |
| `axis`  | A joystick or gamepad axis.  | Either a number representing a joystick axis or a LÖVE [GamepadAxis](http://love2d.org/wiki/GamepadAxis). Add a '+' or '-' on the end to denote the direction to detect.|

*Table taken from [Baton](https://github.com/tesselode/baton) documentation.*

**Notes**
* We can use `mouse:wu`, `mouse:wd`, `mouse:wl`, and `mouse:wr` to the user scrolling up, down, left, and right respectively. Note that this will only activate `pressed` and never `down` and `released`.
* We can use `button:lb` and `button:rb` as alternatives to `button:leftbutton` and `button:rightbutton`.
* We can use `axis:lt` and `axis:rt` as alternatives to `axis:triggerleft` and `axis:triggerright`.

```lua
{
    name_string = string
    name_table = { string, ... }
    name_function = function ()
        return state, x, y
    end
}
```

### Instance

* `instance[name]` - The names used for the controls.
* `instance:update()` - Update the instance.
* `instance:vibrate(left, right, duration)` - Vibrates the controller, unless the current mode is `keyboard`. See [Joystick:setVibration](https://love2d.org/wiki/Joystick:setVibration).
* `instance:setControls(controls)` - Set new controls. See [Controls](#controls).
* `instance.setJoystick(joystick)` - Set the joystick this instance uses. `joystick` may either be a LÖVE object or an ID.
* `instance.getJoystick()` - Get the Joystick LÖVE object of the joystick that this instance uses.
* `instance.setMode("keyboard"|"joystick"|"both")` - Set the mode the instance should use.
* `instance.getMode()` - Get the mode the instance uses.
* `instance.setAutoSwitch(state)` - Set whether the instance should automatically switch modes based on the last input used.
* `instance.getAutoSwitch()` - Get whether auto-switching is set.
* `instance.setTransform(transform)` - Set the transform used to modify the coordinates that `get:mouse()` give you.
* `instance.getTransform()` - Get the set transform.

### Get

With the parameter `joystick` we can pass a joystick object or id, otherwise the previously set joystick will be used (which defaults to 1).

* `get:mouse()` - Get the mouse position.
* `get:wheel()` - The x and y value of the scrolling done this frame.
* `get:left(joystick)` - Get the axes of the left control stick. 
* `get:right(joystick)` - Get the axes of the right control stick.
* `get:triggerleft(joystick)` - Get the value of the left trigger. 
* `get:lt(joystick)` - Alias for `get:triggerleft()`
* `get:triggerright(joystick)` - Get the value of the right trigger. Alternatively `get:rt()` can be used for short.
* `get:rt(joystick)` - Alias for `get:triggerright()`
* `get:trigger(joystick)` - Get the values of the left and right trigger respectively.

## Disclaimer

Claude Sonnet 4 was used to clean up the code (not logic) and write the documentation in Lua file (not this README). This was done after writing all the logic without AI.

## License

This library is free software; you can redistribute it and/or modify it under the terms of the MIT license. See [LICENSE]() for details.
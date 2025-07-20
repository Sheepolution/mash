// Type definitions for Mash - LÖVE Input Library
// Project: https://github.com/Sheepolution/mash

declare namespace mash {
  // Input modes
  type InputMode = "both" | "keyboard" | "joystick";

  // Input state interface
  interface InputState {
    /** True only on the frame the input was pressed */
    pressed: boolean;
    /** True while the input is held down */
    down: boolean;
    /** True only on the frame the input was released */
    released: boolean;
    /** X-axis value for analog inputs (-1 to 1) */
    x: number;
    /** Y-axis value for analog inputs (-1 to 1) */
    y: number;
  }

  // Control definitions
  type TriggerString = string;
  type TriggerFunction = () => [boolean, number?, number?];
  type TriggerDefinition = TriggerString | TriggerString[] | TriggerFunction;

  // Configuration for mash.new()
  interface MashConfig {
    /** Control definitions mapping names to triggers */
    controls?: Record<string, TriggerDefinition>;
    /** Input mode: "both", "keyboard", or "joystick" (default: "both") */
    mode?: InputMode;
    /** Enable automatic mode switching (default: false) */
    autoSwitch?: boolean;
    /** Transform for mouse coordinates */
    transform?: any; // LÖVE Transform object
    /** Joystick to use (ID number or Joystick object, default: 1) */
    joystick?: number | any;
  }

  // Input getter interface
  interface InputGetter {
    /**
     * Gets the current mouse position, optionally transformed
     * @param transform Optional transform to apply
     * @returns Mouse x and y coordinates
     */
    mouse(transform?: any): [number, number];

    /**
     * Gets the current mouse wheel movement
     * @returns Horizontal and vertical wheel movement
     */
    wheel(): [number, number];

    /**
     * Gets the left analog stick position
     * @param joystick Optional specific joystick to query
     * @returns Left stick x and y values (-1 to 1)
     */
    left(joystick?: number | any): [number, number];

    /**
     * Gets the right analog stick position
     * @param joystick Optional specific joystick to query
     * @returns Right stick x and y values (-1 to 1)
     */
    right(joystick?: number | any): [number, number];

    /**
     * Gets the left trigger value
     * @param joystick Optional specific joystick to query
     * @returns Left trigger value (0 to 1)
     */
    lt(joystick?: number | any): number;

    /**
     * Gets the left trigger value (alias for lt)
     * @param joystick Optional specific joystick to query
     * @returns Left trigger value (0 to 1)
     */
    triggerleft(joystick?: number | any): number;

    /**
     * Gets the right trigger value
     * @param joystick Optional specific joystick to query
     * @returns Right trigger value (0 to 1)
     */
    rt(joystick?: number | any): number;

    /**
     * Gets the right trigger value (alias for rt)
     * @param joystick Optional specific joystick to query
     * @returns Right trigger value (0 to 1)
     */
    triggerright(joystick?: number | any): number;

    /**
     * Gets both trigger values
     * @param joystick Optional specific joystick to query
     * @returns Left and right trigger values (0 to 1)
     */
    trigger(joystick?: number | any): [number, number];
  }

  // Mash instance interface
  interface MashInstance {
    /** Input getter for this instance */
    readonly get: InputGetter;

    /** Dynamic control access - use the control names you defined */
    [controlName: string]: InputState | any;

    /**
     * Sets the control configuration for this instance
     * @param controls Control definitions mapping names to triggers
     */
    setControls(controls: Record<string, TriggerDefinition>): void;

    /**
     * Updates all controls - call once per frame
     */
    update(): void;

    /**
     * Sets the input mode
     * @param mode The input mode
     */
    setMode(mode: InputMode): void;

    /**
     * Gets the current input mode
     * @returns The current input mode
     */
    getMode(): InputMode;

    /**
     * Sets whether to automatically switch between input modes
     * @param state True to enable automatic switching
     */
    setAutoSwitch(state: boolean): void;

    /**
     * Gets the current auto-switch setting
     * @returns True if auto-switching is enabled
     */
    getAutoSwitch(): boolean;

    /**
     * Sets the joystick for this instance
     * @param joystick Either a joystick ID or LÖVE Joystick object
     */
    setJoystick(joystick: number | any): void;

    /**
     * Gets the LÖVE Joystick object for this instance
     * @returns The Joystick object, or undefined if not found
     */
    getJoystick(): any | undefined;

    /**
     * Sets a transform matrix for mouse coordinate conversion
     * @param transform A LÖVE Transform object or null
     */
    setTransform(transform: any | null): void;

    /**
     * Gets the current transform matrix
     * @returns The current transform or null
     */
    getTransform(): any | null;

    /**
     * Vibrates the gamepad associated with this instance
     * @param left Left motor strength (0-1)
     * @param right Right motor strength (0-1)
     * @param duration Duration in seconds (optional)
     */
    vibrate(left: number, right: number, duration?: number): void;
  }

  // Input category interfaces for direct access
  interface InputCategory {
    [inputName: string]: InputState;
  }

  // Main mash interface
  interface Mash {
    /** Direct access to keyboard inputs */
    readonly key: InputCategory;
    /** Direct access to scancode inputs */
    readonly sc: InputCategory;
    /** Direct access to mouse inputs */
    readonly mouse: InputCategory;
    /** Direct access to gamepad button inputs */
    readonly button: InputCategory;
    /** Direct access to gamepad axis inputs */
    readonly axis: InputCategory;

    /** Global input getter */
    readonly get: InputGetter;

    /**
     * Creates a new Mash input instance
     * @param config Configuration options
     * @returns A new Mash input instance
     */
    new(config: MashConfig): MashInstance;

    /**
     * Injects Mash's input handlers into LÖVE's callback system
     * Call this once during initialization
     */
    inject(): void;

    /**
     * Resets all input states for the next frame
     * Call at the end of each frame
     */
    reset(): void;

    /**
     * Sets the deadzone threshold for analog inputs
     * @param threshold The new threshold value (0-1, default 0.5)
     */
    setThreshold(threshold: number): void;

    // LÖVE callback functions (usually called automatically via inject())
    /**
     * Handles keyboard key press events
     * @param key The key that was pressed
     * @param sc The scancode of the pressed key
     */
    keypressed(key: string, sc: string): void;

    /**
     * Handles keyboard key release events
     * @param key The key that was released
     * @param sc The scancode of the released key
     */
    keyreleased(key: string, sc: string): void;

    /**
     * Handles mouse button press events
     * @param x Mouse x position when pressed
     * @param y Mouse y position when pressed
     * @param button Mouse button that was pressed
     */
    mousepressed(x: number, y: number, button: number): void;

    /**
     * Handles mouse button release events
     * @param x Mouse x position when released
     * @param y Mouse y position when released
     * @param button Mouse button that was released
     */
    mousereleased(x: number, y: number, button: number): void;

    /**
     * Handles mouse movement events
     * @param x New mouse x position
     * @param y New mouse y position
     */
    mousemoved(x: number, y: number): void;

    /**
     * Handles mouse wheel movement events
     * @param x Horizontal wheel movement
     * @param y Vertical wheel movement
     */
    wheelmoved(x: number, y: number): void;

    /**
     * Handles gamepad button press events
     * @param joystick The joystick object that generated the event
     * @param button The name of the button that was pressed
     */
    gamepadpressed(joystick: any, button: string): void;

    /**
     * Handles gamepad button release events
     * @param joystick The joystick object that generated the event
     * @param button The name of the button that was released
     */
    gamepadreleased(joystick: any, button: string): void;

    /**
     * Handles gamepad axis movement events
     * @param joystick The joystick object that generated the event
     * @param axis The name of the axis that moved
     * @param value The new axis value (-1 to 1 for sticks, 0 to 1 for triggers)
     */
    gamepadaxis(joystick: any, axis: string, value: number): void;
  }
}

declare const mash: mash.Mash;

export = mash;
export as namespace mash;

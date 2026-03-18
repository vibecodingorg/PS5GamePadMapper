# Requirements Document

## Introduction

PS5GamePadMapper 是一个面向开发者的 macOS 输入映射工具，用于将 PS5 DualSense 手柄输入高效、低延迟地映射为键盘/鼠标事件。该工具支持强大的宏与脚本能力，服务于游戏测试、开发调试等场景。本工具仅供内部使用，不考虑商业发布。

## Glossary

- **DualSense**: PS5 游戏手柄的官方名称
- **HID (Human Interface Device)**: 人机接口设备协议，用于手柄与系统通信
- **Mapping**: 输入映射，将手柄输入转换为其他输入事件
- **Profile**: 配置文件，包含一组完整的映射设置
- **Macro**: 宏，一系列预定义的输入动作序列
- **Axis**: 模拟轴，如摇杆、扳机等连续值输入
- **Button**: 数字按钮，如 X、O、R1 等离散输入
- **Deadzone**: 死区，摇杆中心区域的忽略范围
- **Turbo**: 连发模式，持续高频触发某个动作
- **Toggle**: 切换模式，按一次开启，再按一次关闭
- **IOHIDManager**: macOS 系统框架，用于读取 HID 设备输入
- **CGEventPost**: macOS 系统 API，用于注入键盘/鼠标事件
- **Accessibility Permission**: macOS 辅助功能权限，用于模拟输入事件

## Requirements

### Requirement 1: Controller Recognition

**User Story:** As a developer, I want the system to recognize my PS5 DualSense controller, so that I can use it as an input source for mapping.

#### Acceptance Criteria

1. WHEN a DualSense controller connects via USB, THE System SHALL detect the controller and display its device ID within 2 seconds
2. WHEN a DualSense controller connects via Bluetooth, THE System SHALL detect the controller and display its device ID within 3 seconds
3. WHEN a controller is detected, THE System SHALL display the connection type (USB or Bluetooth)
4. WHERE the HID protocol provides battery information, THE System SHALL display the current battery percentage
5. WHEN a connected controller disconnects, THE System SHALL update the UI to reflect the disconnection within 1 second
6. WHEN a previously disconnected controller reconnects, THE System SHALL restore the active profile mappings automatically

### Requirement 2: Button Input Reading

**User Story:** As a developer, I want the system to read all button inputs from my controller, so that I can map them to actions.

#### Acceptance Criteria

1. WHEN a button is pressed on the controller, THE System SHALL detect the press event within 10ms
2. WHEN a button is released on the controller, THE System SHALL detect the release event within 10ms
3. WHILE a button is held, THE System SHALL track the hold duration in milliseconds
4. WHEN reading button state, THE System SHALL support all DualSense buttons including X, O, Square, Triangle, L1, R1, L2, R2, L3, R3, D-pad, Share, Options, PS, and Touchpad click

### Requirement 3: Axis Input Reading

**User Story:** As a developer, I want the system to read analog axis inputs from my controller, so that I can map them to continuous actions.

#### Acceptance Criteria

1. WHEN an axis value changes on the controller, THE System SHALL read the new value within 10ms
2. WHEN reading axis values, THE System SHALL normalize values to a range of -1.0 to 1.0 for sticks and 0.0 to 1.0 for triggers
3. WHEN reading axis input, THE System SHALL support left stick (X/Y), right stick (X/Y), L2 trigger, and R2 trigger
4. WHEN an axis value falls within the configured deadzone, THE System SHALL treat the value as zero

### Requirement 4: Button to Keyboard Mapping

**User Story:** As a developer, I want to map controller buttons to keyboard keys, so that I can use my controller to trigger keyboard input.

#### Acceptance Criteria

1. WHEN a mapped button is pressed, THE System SHALL emit the corresponding keyboard key press event within 20ms
2. WHEN a mapped button is released, THE System SHALL emit the corresponding keyboard key release event within 20ms
3. WHEN configuring a button mapping, THE System SHALL support modifier key combinations (Cmd, Ctrl, Alt, Shift)
4. WHEN a button is mapped to a key combination, THE System SHALL emit all modifier keys before the primary key
5. WHEN configuring trigger mode, THE System SHALL support Press, Release, and Hold trigger types

### Requirement 5: Button to Mouse Mapping

**User Story:** As a developer, I want to map controller buttons to mouse actions, so that I can trigger mouse clicks and scrolls.

#### Acceptance Criteria

1. WHEN a mapped button is pressed for mouse click, THE System SHALL emit the corresponding mouse button event within 20ms
2. WHEN configuring mouse button mapping, THE System SHALL support left, right, and middle mouse buttons
3. WHEN a button is mapped to mouse scroll, THE System SHALL emit scroll events with configurable scroll amount
4. WHEN configuring scroll direction, THE System SHALL support up, down, left, and right scroll directions

### Requirement 6: Axis to Mouse Movement Mapping

**User Story:** As a developer, I want to map controller axes to mouse movement, so that I can control the cursor with analog sticks.

#### Acceptance Criteria

1. WHILE an axis is deflected beyond the deadzone, THE System SHALL emit continuous mouse movement events
2. WHEN configuring axis-to-mouse mapping, THE System SHALL support configurable sensitivity from 0.1 to 10.0
3. WHEN configuring axis-to-mouse mapping, THE System SHALL support configurable deadzone from 0.0 to 0.5
4. WHEN configuring axis-to-mouse mapping, THE System SHALL support linear and exponential response curves
5. WHEN the axis returns to neutral, THE System SHALL stop emitting mouse movement events within 10ms

### Requirement 7: Axis to Keyboard Mapping

**User Story:** As a developer, I want to map controller axes to keyboard keys, so that I can use analog sticks for WASD movement.

#### Acceptance Criteria

1. WHEN an axis exceeds the positive threshold, THE System SHALL emit the configured positive direction key press
2. WHEN an axis exceeds the negative threshold, THE System SHALL emit the configured negative direction key press
3. WHEN an axis returns below the threshold, THE System SHALL emit the corresponding key release event
4. WHEN configuring axis-to-key mapping, THE System SHALL support configurable activation threshold from 0.1 to 0.9

### Requirement 8: Sequence Macro

**User Story:** As a developer, I want to create sequence macros, so that I can trigger a series of inputs with one button press.

#### Acceptance Criteria

1. WHEN a sequence macro is triggered, THE System SHALL execute each step in order with configured delays
2. WHEN configuring a macro step, THE System SHALL support key press, key release, mouse click, and mouse move actions
3. WHEN configuring delay between steps, THE System SHALL support delays from 1ms to 10000ms
4. WHEN a macro is executing, THE System SHALL complete all steps before accepting new macro triggers on the same button
5. WHEN serializing a macro, THE System SHALL store it as a JSON structure that can be parsed back to the original macro
6. WHEN deserializing a macro from JSON, THE System SHALL reconstruct the exact same macro with all steps and delays preserved

### Requirement 9: Loop Macro (Turbo)

**User Story:** As a developer, I want to create loop macros, so that I can repeat actions at high frequency.

#### Acceptance Criteria

1. WHILE a loop macro trigger is held, THE System SHALL repeat the macro sequence continuously
2. WHEN configuring a loop macro, THE System SHALL support repeat intervals from 10ms to 5000ms
3. WHEN the trigger is released, THE System SHALL stop the loop within one interval period
4. WHEN configuring a loop macro, THE System SHALL support a maximum repeat count (0 for infinite)

### Requirement 10: Toggle Macro

**User Story:** As a developer, I want to create toggle macros, so that I can start and stop repeating actions with separate button presses.

#### Acceptance Criteria

1. WHEN a toggle macro trigger is pressed once, THE System SHALL start executing the macro
2. WHEN a toggle macro trigger is pressed again while running, THE System SHALL stop the macro execution
3. WHEN a toggle macro is stopped, THE System SHALL complete the current step before stopping
4. WHEN displaying toggle macro state, THE System SHALL indicate whether the macro is currently active

### Requirement 11: Macro Interruption

**User Story:** As a developer, I want to interrupt running macros, so that I can stop them immediately when needed.

#### Acceptance Criteria

1. WHEN an interrupt signal is received, THE System SHALL stop the macro within 50ms
2. WHEN a macro is interrupted, THE System SHALL release all keys that were pressed by the macro
3. WHEN configuring macro interruption, THE System SHALL support a dedicated interrupt button binding

### Requirement 12: Script Execution

**User Story:** As a developer, I want to execute scripts for complex input logic, so that I can implement conditional and stateful behaviors.

#### Acceptance Criteria

1. WHEN a script is triggered, THE System SHALL execute the script in a dedicated execution context
2. WHEN a script calls pressKey(key), THE System SHALL emit a key press event for the specified key
3. WHEN a script calls releaseKey(key), THE System SHALL emit a key release event for the specified key
4. WHEN a script calls tapKey(key, ms), THE System SHALL emit a key press, wait the specified milliseconds, then emit key release
5. WHEN a script calls mouseClick(button), THE System SHALL emit a mouse click event for the specified button
6. WHEN a script calls mouseMove(dx, dy), THE System SHALL emit a relative mouse movement event
7. WHEN a script calls sleep(ms), THE System SHALL pause script execution for the specified milliseconds
8. WHEN a script calls isButtonPressed(btn), THE System SHALL return the current pressed state of the specified controller button

### Requirement 13: Profile Management

**User Story:** As a developer, I want to manage multiple profiles, so that I can quickly switch between different mapping configurations.

#### Acceptance Criteria

1. WHEN saving a profile, THE System SHALL write the configuration to a local JSON file
2. WHEN loading a profile, THE System SHALL parse the JSON file and apply all mappings within 500ms
3. WHEN switching profiles, THE System SHALL deactivate all current mappings before activating new ones
4. WHEN cloning a profile, THE System SHALL create a new profile with identical mappings and a unique name
5. WHEN listing profiles, THE System SHALL display all available profiles with their names
6. WHEN serializing a profile, THE System SHALL produce valid JSON that can be deserialized back to the original profile
7. WHEN deserializing a profile from JSON, THE System SHALL reconstruct all mappings exactly as they were saved

### Requirement 14: Application-based Profile Switching (Optional)

**User Story:** As a developer, I want profiles to switch automatically based on the foreground application, so that I can have context-aware mappings.

#### Acceptance Criteria

1. WHERE application-based switching is enabled, WHEN a configured application becomes foreground, THE System SHALL switch to the associated profile within 1 second
2. WHEN configuring application association, THE System SHALL support selecting applications by bundle identifier
3. WHEN no application association matches, THE System SHALL maintain the current active profile

### Requirement 15: Real-time Debug Panel

**User Story:** As a developer, I want a real-time debug panel, so that I can verify inputs and mappings during development.

#### Acceptance Criteria

1. WHEN a controller input occurs, THE System SHALL display the input event in the debug panel within 50ms
2. WHEN a mapping action is executed, THE System SHALL display the action in the debug panel
3. WHEN a macro is running, THE System SHALL display the current macro state and step
4. WHEN displaying axis values, THE System SHALL show the current normalized value with 2 decimal precision

### Requirement 16: System Permissions

**User Story:** As a developer, I want the system to request necessary permissions, so that the application can function correctly.

#### Acceptance Criteria

1. WHEN the application starts without Accessibility permission, THE System SHALL prompt the user to grant permission
2. WHEN Accessibility permission is not granted, THE System SHALL display a clear message explaining the limitation
3. WHEN Bluetooth permission is required, THE System SHALL request permission before attempting Bluetooth operations

### Requirement 17: Performance and Stability

**User Story:** As a developer, I want the system to perform reliably, so that I can use it for extended testing sessions.

#### Acceptance Criteria

1. WHEN processing input events, THE System SHALL maintain end-to-end latency below 30ms under normal load
2. WHILE running high-frequency macros (10-50ms intervals), THE System SHALL maintain stable execution without event loss
3. WHILE running continuously for 12 hours, THE System SHALL maintain stable memory usage without significant growth
4. WHEN a controller disconnects unexpectedly, THE System SHALL handle the disconnection gracefully without crashing

### Requirement 18: Main Window UI

**User Story:** As a developer, I want a functional main window interface, so that I can view and configure mappings efficiently.

#### Acceptance Criteria

1. WHEN the main window opens, THE System SHALL display the connected controller status including device name, connection type, and battery level
2. WHEN the main window opens, THE System SHALL display a controller visualization showing all mappable inputs
3. WHEN a mappable input is clicked on the visualization, THE System SHALL open the mapping detail panel for that input
4. WHEN displaying the mapping detail panel, THE System SHALL show the current input name, type, configured action, and trigger mode
5. WHEN a profile selector is clicked, THE System SHALL display a dropdown list of available profiles

### Requirement 19: Mapping Editor

**User Story:** As a developer, I want a mapping editor, so that I can configure how each input is mapped.

#### Acceptance Criteria

1. WHEN editing a mapping, THE System SHALL provide options to select action type: Key, Mouse, Macro, or Script
2. WHEN a mapping is modified, THE System SHALL apply the change immediately without requiring a save action
3. WHEN configuring a key action, THE System SHALL provide a key capture interface to record the target key
4. WHEN configuring axis parameters, THE System SHALL provide input fields for deadzone, sensitivity, and curve type

### Requirement 20: Macro Editor

**User Story:** As a developer, I want a macro editor with recording and scripting modes, so that I can create macros efficiently.

#### Acceptance Criteria

1. WHEN in recording mode, THE System SHALL capture keyboard and mouse inputs as macro steps
2. WHEN recording, THE System SHALL capture timing between inputs as delay steps
3. WHEN in recording mode, THE System SHALL provide controls to start, stop, and clear the recording
4. WHEN editing recorded steps, THE System SHALL allow modifying delay values
5. WHEN editing recorded steps, THE System SHALL allow deleting individual steps
6. WHEN in script mode, THE System SHALL provide a text editor for entering macro scripts
7. WHEN a script contains syntax errors, THE System SHALL display an error indicator

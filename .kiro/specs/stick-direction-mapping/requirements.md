# Requirements Document

## Introduction

本功能为 PS5GamePadMapper 添加摇杆方向独立配置能力。当前系统仅支持将摇杆轴（X/Y）作为整体进行映射，无法为摇杆的各个方向（如上、下、左、右及对角方向）分别配置不同的动作。本功能将支持 8 方向独立配置，使用户能够将摇杆的每个方向映射到不同的键盘按键、鼠标动作、宏或脚本，满足游戏和开发测试的实际需求。

## Glossary

- **Stick**: 摇杆，DualSense 手柄上的模拟输入设备，包括左摇杆和右摇杆
- **Stick Direction**: 摇杆方向，摇杆偏移的方向，包括 8 个方向（上、下、左、右、左上、右上、左下、右下）
- **Cardinal Direction**: 基本方向，指上、下、左、右四个主方向
- **Diagonal Direction**: 对角方向，指左上、右上、左下、右下四个对角方向
- **Direction Threshold**: 方向阈值，摇杆偏移量超过此值时触发方向映射
- **Diagonal Angle**: 对角角度范围，用于判定对角方向的角度阈值（默认 45°±22.5°）
- **Stick Zone**: 摇杆区域，根据摇杆位置划分的方向区域
- **InputSource**: 输入源，表示手柄输入的数据类型，需扩展以支持方向性输入

## Requirements

### Requirement 1: 8-Direction Input Model

**User Story:** As a developer, I want the system to recognize 8 distinct directions from analog sticks, so that I can map each direction to different actions.

#### Acceptance Criteria

1. WHEN processing stick input, THE System SHALL recognize 8 distinct directions: Up, Down, Left, Right, UpLeft, UpRight, DownLeft, DownRight
2. WHEN the stick deflection exceeds the configured threshold, THE System SHALL determine the active direction based on the stick angle
3. WHEN the stick angle falls within ±22.5° of a cardinal axis (0°, 90°, 180°, 270°), THE System SHALL classify the input as a cardinal direction
4. WHEN the stick angle falls within the remaining 45° sectors, THE System SHALL classify the input as a diagonal direction
5. WHEN the stick returns to the deadzone, THE System SHALL emit direction release events for all previously active directions
6. WHEN serializing a direction input, THE System SHALL store it as a JSON structure that can be parsed back to the original direction
7. WHEN deserializing a direction input from JSON, THE System SHALL reconstruct the exact same direction configuration

### Requirement 2: Direction-based Mapping Configuration

**User Story:** As a developer, I want to configure mappings for each stick direction independently, so that I can assign different actions to different directions.

#### Acceptance Criteria

1. WHEN configuring a stick mapping, THE System SHALL allow selecting a specific direction (one of 8 directions) as the input source
2. WHEN a direction mapping is configured, THE System SHALL support all existing action types: Key, Mouse, Macro, and Script
3. WHEN multiple directions are active simultaneously (diagonal input), THE System SHALL trigger all corresponding direction mappings
4. WHEN a direction becomes inactive, THE System SHALL emit the appropriate release event for that direction's mapping
5. WHEN configuring direction threshold, THE System SHALL support values from 0.1 to 0.9

### Requirement 3: Direction Mapping UI

**User Story:** As a developer, I want a visual interface to configure stick direction mappings, so that I can easily set up and modify direction-based controls.

#### Acceptance Criteria

1. WHEN clicking on a stick in the controller visualization, THE System SHALL display a direction selector showing all 8 directions
2. WHEN a direction is selected in the UI, THE System SHALL open the mapping editor for that specific direction
3. WHEN displaying the direction selector, THE System SHALL visually indicate which directions have configured mappings
4. WHEN displaying the direction selector, THE System SHALL show the current stick position in real-time
5. WHEN editing a direction mapping, THE System SHALL display the direction name and allow configuration of action type, trigger mode, and parameters

### Requirement 4: Cardinal Direction Key Mapping (WASD Style)

**User Story:** As a developer, I want to quickly configure WASD-style mappings for stick directions, so that I can use the stick for movement in games.

#### Acceptance Criteria

1. WHEN configuring a cardinal direction (Up/Down/Left/Right), THE System SHALL allow mapping to a single keyboard key
2. WHEN the stick moves in a cardinal direction beyond the threshold, THE System SHALL emit the configured key press event
3. WHEN the stick returns from a cardinal direction below the threshold, THE System SHALL emit the configured key release event
4. WHEN moving diagonally, THE System SHALL emit key press events for both adjacent cardinal directions simultaneously

### Requirement 5: Diagonal Direction Mapping

**User Story:** As a developer, I want to configure specific actions for diagonal directions, so that I can trigger special actions when moving diagonally.

#### Acceptance Criteria

1. WHEN configuring a diagonal direction, THE System SHALL allow mapping to any supported action type
2. WHEN the stick moves in a diagonal direction, THE System SHALL trigger the diagonal direction mapping
3. WHEN a diagonal direction has no mapping but adjacent cardinals do, THE System SHALL trigger both adjacent cardinal mappings
4. WHEN a diagonal direction has a mapping, THE System SHALL trigger only the diagonal mapping (not the adjacent cardinals)

### Requirement 6: Direction Detection Algorithm

**User Story:** As a developer, I want accurate direction detection from stick input, so that my direction mappings trigger reliably.

#### Acceptance Criteria

1. WHEN calculating stick direction, THE System SHALL use the arctangent of Y/X coordinates to determine the angle
2. WHEN the stick magnitude is below the deadzone threshold, THE System SHALL report no active direction
3. WHEN the stick magnitude exceeds the deadzone but is below the direction threshold, THE System SHALL report no active direction
4. WHEN transitioning between directions, THE System SHALL emit release events for the old direction before press events for the new direction
5. WHEN the stick is held in a direction, THE System SHALL maintain the direction state without repeated press events

### Requirement 7: Profile Serialization with Directions

**User Story:** As a developer, I want direction mappings to be saved and loaded with profiles, so that my configurations persist across sessions.

#### Acceptance Criteria

1. WHEN saving a profile with direction mappings, THE System SHALL serialize all direction configurations to JSON
2. WHEN loading a profile with direction mappings, THE System SHALL restore all direction configurations exactly as saved
3. WHEN a profile contains both axis mappings and direction mappings for the same stick, THE System SHALL prioritize direction mappings
4. WHEN serializing direction mappings, THE System SHALL include direction type, threshold, and action configuration
5. WHEN deserializing direction mappings from JSON, THE System SHALL reconstruct the exact same mappings with all parameters preserved

### Requirement 8: Debug Panel Direction Display

**User Story:** As a developer, I want to see direction detection in the debug panel, so that I can verify my direction mappings are working correctly.

#### Acceptance Criteria

1. WHEN a stick direction is detected, THE System SHALL display the active direction name in the debug panel
2. WHEN displaying stick state, THE System SHALL show the current angle in degrees
3. WHEN displaying stick state, THE System SHALL show the current magnitude (0.0 to 1.0)
4. WHEN a direction mapping is triggered, THE System SHALL log the direction and action in the debug panel


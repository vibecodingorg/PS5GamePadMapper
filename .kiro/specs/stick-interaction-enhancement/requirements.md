# Requirements Document

## Introduction

本功能旨在优化 PS5GamePadMapper 的摇杆交互体验。当前摇杆的交互模式与其他按钮不一致：点击摇杆会直接弹出8方向映射设置弹窗，用户无法快速查看已设置的映射结果。此外，摇杆作为连续值输入设备，缺少鼠标移动模式的映射支持。本功能将统一摇杆与按钮的交互模式，增加摇杆的鼠标移动映射功能，并优化整体用户体验。

## Glossary

- **Stick**: 摇杆，DualSense 手柄上的模拟输入设备，包括左摇杆和右摇杆
- **Stick Mode**: 摇杆模式，摇杆的工作模式，包括方向模式（8方向映射）和鼠标模式（鼠标移动映射）
- **Direction Mode**: 方向模式，将摇杆的8个方向分别映射到不同动作的模式
- **Mouse Mode**: 鼠标模式，将摇杆的连续值映射到鼠标移动的模式
- **Mapping Detail Panel**: 映射详情面板，显示当前选中输入的映射配置的右侧面板
- **Direction Selector**: 方向选择器，用于配置8方向映射的弹窗界面
- **Continuous Input**: 连续输入，摇杆产生的连续模拟值（-1.0 到 1.0）
- **InputSource**: 输入源，表示手柄输入的数据类型

## Requirements

### Requirement 1: 统一摇杆选择交互

**User Story:** As a user, I want the stick interaction to be consistent with button interaction, so that I can have a unified and predictable user experience.

#### Acceptance Criteria

1. WHEN a user clicks on a stick in the controller visualization, THE System SHALL select the stick as the current input source and highlight it visually
2. WHEN a stick is selected, THE System SHALL display the stick's current mapping configuration in the mapping detail panel
3. WHEN a stick is selected and the user clicks "Edit Mapping" button, THE System SHALL open the stick mapping editor
4. WHEN displaying a selected stick, THE System SHALL show the same visual selection indicator as buttons (blue border)

### Requirement 2: 摇杆映射详情显示

**User Story:** As a user, I want to see the current stick mapping configuration in the detail panel, so that I can quickly review my settings without opening the editor.

#### Acceptance Criteria

1. WHEN a stick with direction mappings is selected, THE System SHALL display a summary of configured directions in the detail panel
2. WHEN a stick with mouse mode mapping is selected, THE System SHALL display the mouse movement parameters (sensitivity, deadzone, curve) in the detail panel
3. WHEN a stick has no mapping configured, THE System SHALL display a prompt indicating no mapping is set
4. WHEN displaying direction mapping summary, THE System SHALL show the count of configured directions and list the direction names

### Requirement 3: 摇杆模式选择

**User Story:** As a user, I want to choose between direction mode and mouse mode for stick mapping, so that I can use the stick for different purposes.

#### Acceptance Criteria

1. WHEN editing a stick mapping, THE System SHALL display a mode selector with options: Direction Mode and Mouse Mode
2. WHEN Direction Mode is selected, THE System SHALL display the 8-direction configuration interface
3. WHEN Mouse Mode is selected, THE System SHALL display the mouse movement parameter configuration interface
4. WHEN switching between modes, THE System SHALL preserve the previous mode's configuration until explicitly cleared
5. WHEN a stick has both direction and mouse mappings configured, THE System SHALL use the most recently configured mode as active

### Requirement 4: 摇杆鼠标移动映射

**User Story:** As a user, I want to map stick movement to mouse cursor movement, so that I can control the mouse with the analog stick.

#### Acceptance Criteria

1. WHEN configuring mouse mode, THE System SHALL allow setting sensitivity parameter with range 0.1 to 10.0
2. WHEN configuring mouse mode, THE System SHALL allow setting deadzone parameter with range 0.0 to 0.5
3. WHEN configuring mouse mode, THE System SHALL allow selecting response curve type: Linear or Exponential
4. WHEN Exponential curve is selected, THE System SHALL allow setting the exponential power parameter with range 1.0 to 4.0
5. WHEN the stick is moved in mouse mode, THE System SHALL emit mouse movement events proportional to the stick deflection
6. WHEN the stick deflection is within the deadzone, THE System SHALL emit no mouse movement events
7. WHEN serializing mouse mode configuration, THE System SHALL store all parameters in JSON format
8. WHEN deserializing mouse mode configuration from JSON, THE System SHALL reconstruct the exact same parameters

### Requirement 5: 摇杆映射编辑器

**User Story:** As a user, I want a unified editor for stick mappings, so that I can configure both direction and mouse modes in one place.

#### Acceptance Criteria

1. WHEN opening the stick mapping editor, THE System SHALL display the current mode (Direction or Mouse) as selected
2. WHEN in Direction Mode, THE System SHALL display the direction selector wheel with all 8 directions
3. WHEN in Direction Mode, THE System SHALL allow inline editing of each direction's mapping
4. WHEN in Mouse Mode, THE System SHALL display parameter sliders for sensitivity, deadzone, and curve
5. WHEN parameters are changed, THE System SHALL apply changes immediately without requiring a save action
6. WHEN the editor is closed, THE System SHALL persist all changes to the profile

### Requirement 6: 方向映射列表预览

**User Story:** As a user, I want to see a detailed list of all direction mappings in the detail panel, so that I can quickly review the complete configuration for each direction.

#### Acceptance Criteria

1. WHEN a stick with direction mappings is selected, THE System SHALL display a scrollable list of all configured direction mappings in the detail panel
2. WHEN displaying each direction mapping item, THE System SHALL show the direction name (e.g., "↑ 上", "↗ 右上")
3. WHEN displaying each direction mapping item, THE System SHALL show the action type icon (keyboard, mouse, macro, script)
4. WHEN displaying a key action mapping, THE System SHALL show the key name and any modifier keys (e.g., "W", "⌘+Shift+A")
5. WHEN displaying a mouse action mapping, THE System SHALL show the mouse button name (e.g., "鼠标左键")
6. WHEN displaying a macro action mapping, THE System SHALL show the macro name
7. WHEN displaying a script action mapping, THE System SHALL show the script name
8. WHEN a direction has no mapping configured, THE System SHALL either omit it from the list or show it as "未配置"
9. WHEN clicking on a direction mapping item in the list, THE System SHALL open the direction editor with that direction pre-selected

### Requirement 7: 摇杆可视化增强

**User Story:** As a user, I want clear visual feedback about stick mapping modes, so that I can understand the current configuration at a glance.

#### Acceptance Criteria

1. WHEN a stick has direction mode configured, THE System SHALL display a direction icon indicator on the stick visualization
2. WHEN a stick has mouse mode configured, THE System SHALL display a mouse cursor icon indicator on the stick visualization
3. WHEN a stick has no mapping configured, THE System SHALL display no mode indicator
4. WHEN the stick is being used, THE System SHALL show real-time position feedback in the visualization

### Requirement 8: 配置持久化

**User Story:** As a user, I want my stick mapping configurations to be saved with profiles, so that my settings persist across sessions.

#### Acceptance Criteria

1. WHEN saving a profile with stick mappings, THE System SHALL serialize both direction and mouse mode configurations
2. WHEN loading a profile with stick mappings, THE System SHALL restore all stick mapping configurations exactly as saved
3. WHEN a profile contains stick mappings, THE System SHALL validate the configuration on load and report errors for invalid data
4. WHEN serializing stick mappings, THE System SHALL use a JSON structure that includes mode type and all mode-specific parameters
5. WHEN deserializing stick mappings from JSON, THE System SHALL reconstruct the exact same configuration with all parameters preserved


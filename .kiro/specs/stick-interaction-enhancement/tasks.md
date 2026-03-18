# Implementation Plan

## Overview

本任务列表实现摇杆交互增强功能，包括统一摇杆与按钮的交互模式、增加鼠标移动映射、优化映射详情展示。

---

- [x] 1. 扩展 InputSource 支持摇杆选中状态
  - [x] 1.1 在 InputSource 枚举中添加 stick(StickType) case
    - 修改 `PS5GamePadMapper/Sources/Core/Models/Actions.swift`
    - 添加 `case stick(StickType)` 到 InputSource 枚举
    - 实现 Codable、Equatable、Hashable 协议支持
    - _Requirements: 1.1_

  - [x] 1.2 编写 InputSource.stick 序列化属性测试
    - **Property 11: Profile Stick Mapping Round-Trip**
    - **Validates: Requirements 8.1, 8.2, 8.4, 8.5**

- [x] 2. 更新 StickView 组件支持选中状态
  - [x] 2.1 修改 StickView 的点击行为
    - 修改 `PS5GamePadMapper/Sources/App/Views/ControllerVisualizationView.swift`
    - 将 `onTapGesture` 改为选中摇杆而非直接打开方向选择器
    - 调用 `onInputSelected(.stick(stickType))` 而非 `onDirectionTapped`
    - _Requirements: 1.1_

  - [x] 2.2 添加摇杆选中状态的视觉指示
    - 更新 `isSelected` 计算属性，检查 `InputSource.stick` case
    - 添加蓝色边框显示选中状态
    - _Requirements: 1.4_

  - [x] 2.3 添加摇杆模式指示器
    - 添加 `hasMouseMapping` 参数
    - 方向模式显示绿色方向图标 (已有)
    - 鼠标模式显示紫色鼠标图标 (新增)
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 3. 创建方向映射列表视图
  - [x] 3.1 创建 DirectionMappingListView 组件
    - 创建新文件 `PS5GamePadMapper/Sources/App/Views/DirectionMappingListView.swift`
    - 实现可滚动的方向映射列表
    - 遍历 StickDirection.allCases 显示所有8个方向
    - _Requirements: 6.1_

  - [x] 3.2 创建 DirectionMappingRow 组件
    - 显示方向图标和名称（如 "↑ 上"）
    - 显示动作类型图标（键盘/鼠标/宏/脚本）
    - 显示动作描述（键名、按钮名、宏名等）
    - 未配置时显示 "未配置"
    - _Requirements: 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8_

  - [x] 3.3 编写方向名称显示属性测试
    - **Property 8: Direction Name Display Correctness**
    - **Validates: Requirements 6.2**

  - [x] 3.4 编写动作类型图标选择属性测试
    - **Property 9: Action Type Icon Selection**
    - **Validates: Requirements 6.3**

  - [x] 3.5 编写按键动作显示格式属性测试
    - **Property 10: Key Action Display Formatting**
    - **Validates: Requirements 6.4**

- [x] 4. 创建摇杆映射详情视图
  - [x] 4.1 创建 StickMappingDetailView 组件
    - 创建新文件 `PS5GamePadMapper/Sources/App/Views/StickMappingDetailView.swift`
    - 显示摇杆名称和类型
    - 显示当前模式（方向模式/鼠标模式）
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 4.2 集成方向模式详情显示
    - 显示已配置方向数量（如 "4/8 方向"）
    - 嵌入 DirectionMappingListView 显示映射列表
    - _Requirements: 2.1, 2.4_

  - [x] 4.3 集成鼠标模式详情显示
    - 显示灵敏度、死区、曲线参数
    - 复用现有的参数显示格式
    - _Requirements: 2.2_

  - [x] 4.4 编写方向映射摘要正确性属性测试
    - **Property 1: Direction Mapping Summary Correctness**
    - **Validates: Requirements 2.1, 2.4**

- [x] 5. 更新 MappingDetailPanel 支持摇杆
  - [x] 5.1 修改 MappingDetailPanel 识别摇杆输入
    - 修改 `PS5GamePadMapper/Sources/App/Views/MappingDetailPanel.swift`
    - 在 `InputInfoSection` 中处理 `InputSource.stick` case
    - 显示摇杆名称和类型
    - _Requirements: 1.2_

  - [x] 5.2 集成 StickMappingDetailView
    - 当选中输入为摇杆时，显示 StickMappingDetailView
    - 传递方向映射和鼠标配置数据
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 6. Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

- [x] 7. 创建摇杆映射编辑器
  - [x] 7.1 创建 StickMappingEditorView 组件
    - 创建新文件 `PS5GamePadMapper/Sources/App/Views/StickMappingEditorView.swift`
    - 添加模式选择器（方向模式/鼠标模式）
    - 实现模式切换逻辑
    - _Requirements: 3.1, 5.1_

  - [x] 7.2 集成方向模式编辑
    - 复用现有的 DirectionSelectorView 组件
    - 传递方向映射数据和回调
    - _Requirements: 3.2, 5.2, 5.3_

  - [x] 7.3 创建鼠标模式配置视图
    - 复用现有的 AxisParameterEditor 组件
    - 添加灵敏度、死区、曲线参数配置
    - _Requirements: 3.3, 4.1, 4.2, 4.3, 4.4, 5.4_

  - [x] 7.4 实现即时保存功能
    - 参数变更时立即调用 onMappingChanged 回调
    - 无需显式保存按钮
    - _Requirements: 5.5, 5.6_

  - [x] 7.5 实现最近配置模式优先逻辑
    - 当摇杆同时有方向和鼠标映射时，根据最后修改时间确定默认显示模式
    - 在 StickMappingEditorView 初始化时判断当前活跃模式
    - _Requirements: 3.5_

  - [x] 7.6 编写模式切换保留配置属性测试
    - **Property 2: Mode Switching Preserves Configuration**
    - **Validates: Requirements 3.4**

  - [x] 7.7 编写鼠标模式参数验证属性测试
    - **Property 3: Mouse Mode Parameter Validation**
    - **Validates: Requirements 4.1, 4.2, 4.4**

  - [x] 7.8 编写即时参数应用属性测试
    - **Property 7: Immediate Parameter Application**
    - **Validates: Requirements 5.5**

- [x] 8. 更新 MainWindowView 集成摇杆编辑器
  - [x] 8.1 添加摇杆编辑器状态管理
    - 修改 `PS5GamePadMapper/Sources/App/Views/MainWindowView.swift`
    - 添加 `showStickMappingEditor` 状态
    - 添加 `editingStick: StickType?` 状态
    - _Requirements: 1.3_

  - [x] 8.2 更新编辑按钮逻辑
    - 当选中输入为摇杆时，点击编辑按钮打开 StickMappingEditorView
    - 传递当前摇杆的映射数据
    - _Requirements: 1.3_

  - [x] 8.3 添加摇杆编辑器 sheet
    - 使用 `.sheet` 修饰符显示 StickMappingEditorView
    - 处理映射变更回调
    - _Requirements: 5.6_

- [x] 9. 更新 MainWindowViewModel 支持摇杆映射
  - [x] 9.1 添加摇杆鼠标模式映射获取方法
    - 修改 `PS5GamePadMapper/Sources/App/Views/MainWindowView.swift`
    - 添加 `getMouseConfig(for stick: StickType) -> MouseMoveAction?` 方法
    - 从 profile.mappings 中查找轴映射的鼠标移动动作
    - _Requirements: 2.2_

  - [x] 9.2 添加摇杆模式判断方法
    - 添加 `hasMouseMapping(for stick: StickType) -> Bool` 方法
    - 检查是否存在轴映射的鼠标移动动作
    - _Requirements: 7.2_

  - [x] 9.3 更新 selectedMapping 计算属性
    - 处理 `InputSource.stick` case
    - 返回摇杆的主要映射（方向或鼠标）
    - _Requirements: 1.2_

- [x] 10. Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

- [x] 11. 实现鼠标移动映射功能
  - [x] 11.1 更新 ControllerVisualizationView 传递鼠标模式状态
    - 添加 `hasMouseMapping` 参数到 StickView
    - 从 ViewModel 获取鼠标模式状态
    - _Requirements: 7.2_

  - [x] 11.2 验证鼠标移动映射的事件发射
    - 确认 MappingEngine 正确处理轴到鼠标移动的映射
    - 验证死区过滤和灵敏度应用
    - _Requirements: 4.5, 4.6_

  - [x] 11.3 编写鼠标移动比例属性测试
    - **Property 4: Mouse Movement Proportionality**
    - **Validates: Requirements 4.5**

  - [x] 11.4 编写死区过滤属性测试
    - **Property 5: Deadzone Filtering**
    - **Validates: Requirements 4.6**

  - [x] 11.5 编写鼠标配置序列化属性测试
    - **Property 6: Mouse Config Serialization Round-Trip**
    - **Validates: Requirements 4.7, 4.8**

- [x] 12. 实现配置加载验证
  - [x] 12.1 添加摇杆映射配置验证逻辑
    - 在 ProfileManager 加载配置时验证摇杆映射数据
    - 对无效数据记录错误日志并使用默认值
    - _Requirements: 8.3_

- [x] 13. 添加方向映射列表点击交互
  - [x] 13.1 实现列表项点击打开编辑器
    - 在 DirectionMappingRow 添加点击手势
    - 点击时打开 StickMappingEditorView 并预选该方向
    - _Requirements: 6.9_

  - [x] 13.2 传递预选方向到编辑器
    - 在 StickMappingEditorView 添加 `preselectedDirection` 参数
    - 打开时自动选中该方向
    - _Requirements: 6.9_

- [x] 14. Final Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户


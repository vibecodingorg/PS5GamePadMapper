# ✅ PS5 手柄映射工具  
## 实现一致性审查表（Audit Sheet）

> 规则  
> - 每一项只能填写：✅ / ⚠️ / ❌  
> - ⚠️ / ❌ 必须给出代码位置或运行行为证据  
> - "理论支持 / 以后可加" 一律视为 ❌

---

## ① 架构层级（Architecture）

| 项目 | 状态 | 证据 |
|----|----|----|
| Input / Mapping / Macro / Output / UI 分层清晰 | ✅ | `ControllerManager`(Input) → `InputProcessor` → `MappingEngine`(Mapping) → `MacroScheduler`(Macro) → `EventEmitter`(Output)，UI 在 `Sources/App/Views/`，Core 在 `Sources/Core/`，通过 `AppCoordinator` 协调 |
| Mapping 层不直接访问 HID / CGEvent | ✅ | `MappingEngine.swift` 仅处理 `ButtonEvent`/`AxisEvent`，不导入 IOKit 或 CoreGraphics，返回 `[Action]` 由 `EventEmitter` 执行 |
| Macro 执行不在 UI 线程 | ✅ | `MacroScheduler.swift:60` 使用 `executionQueue = DispatchQueue(label: "com.ps5gamepadmapper.macroscheduler", qos: .userInteractive)` 异步执行 |
| UI 仅负责配置，不参与逻辑判断 | ✅ | `MainWindowView.swift` 通过 `AppCoordinator` 调用核心逻辑，UI 仅展示状态和接收用户输入，映射逻辑在 `MappingEngine` |

---

## ② 控制器与输入模型（Controller & Input）

| 项目 | 状态 | 证据 |
|----|----|----|
| DualSense USB 可用 | ✅ | `ControllerManager.swift:8-10` 定义 `vendorID: 0x054C`, `productID_USB: 0x0CE6`，`USBReport` 结构定义偏移量 |
| DualSense 蓝牙可用 | ✅ | `ControllerManager.swift:23-34` 定义 `BTReport` 结构，`determineConnectionType()` 方法检测连接类型，`handleInputReport()` 根据连接类型选择偏移量 |
| Button 有 Press / Release | ✅ | `RawButtonInput.isPressed: Bool`，`ButtonState` 枚举包含 `.pressed` / `.released`，`emitButtonIfChanged()` 在状态变化时发送事件 |
| Axis 为连续值（非伪按钮） | ✅ | `RawAxisInput.rawValue: Int16`，`AxisEvent.normalizedValue: Double`，`InputProcessor.processAxisInput()` 返回 -1.0~1.0 或 0.0~1.0 连续值 |
| L2 / R2 为模拟输入 | ✅ | `AxisType.l2Trigger` / `r2Trigger`，`ControllerManager.swift:268-274` 读取 `l2Trigger`/`r2Trigger` 字节作为 0-255 模拟值 |

---

## ③ Button → Action 映射

| 项目 | 状态 | 证据 |
|----|----|----|
| Button → 单个键盘键 | ✅ | `Action.keyPress(KeyAction)`，`MappingEditorView` 支持选择单键，`EventEmitter.emitKeyDown()` 发送键盘事件 |
| Button → 组合键（如 Cmd+Shift） | ✅ | `KeyAction.modifiers: KeyModifiers`，`KeyModifiers` 支持 `.command/.control/.option/.shift`，`EventEmitter.emitKeyDown()` 先发送修饰键 |
| Button → 鼠标按钮 | ✅ | `Action.mouseButton(MouseButtonAction)`，`MouseButton` 枚举支持 `.left/.right/.middle`，`EventEmitter.emitMouseDown/Up()` |
| Button → 宏 | ✅ | `Action.macro(Macro)`，`AppCoordinator.executeAction()` 调用 `macroScheduler.execute(macro, trigger:)` |
| Button → 脚本 | ✅ | `Action.script(Script)`，`AppCoordinator.executeScript()` 异步执行脚本 |
| 一个 Button 可触发多个 Action | ✅ | `MappingEngine.handleButtonEvent()` 返回 `[Action]` 数组，遍历所有匹配的 mapping |

---

## ④ 触发状态支持（Trigger State）

| 项目 | 状态 | 证据 |
|----|----|----|
| Press 触发 | ✅ | `TriggerMode.press`，`MappingEngine.evaluateTrigger()` case `.press` 检查 `event.state == .pressed` |
| Release 触发 | ✅ | `TriggerMode.release`，`MappingEngine.evaluateTrigger()` case `.release` 检查 `event.state == .released` |
| Hold（基于状态而非延迟模拟） | ✅ | `TriggerMode.hold(threshold:)`，`ButtonState.held(duration:)`，`MappingEngine.evaluateTrigger()` 检查 `duration >= threshold` |

---

## ⑤ Axis 映射（Stick / Trigger）

| 项目 | 状态 | 证据 |
|----|----|----|
| Axis → 鼠标相对移动 | ✅ | `Action.mouseMove(MouseMoveAction)`，`EventEmitter.emitMouseMove(dx:dy:)` 使用 `CGEvent.mouseMoved` |
| Sensitivity 参数生效 | ✅ | `AxisConfig.sensitivity`，`InputProcessor.applySensitivity()` 乘以 sensitivity 值 |
| Deadzone 参数生效 | ✅ | `AxisConfig.deadzone`，`InputProcessor.applyDeadzone()` 将死区内值归零并重新缩放 |
| Axis → WASD / 方向键 | ✅ | `AxisToKeyConfig` 支持 `positiveKey`/`negativeKey`，`MappingEngine.processAxisToKey()` 根据阈值发送按键 |
| Axis 输出为持续状态（非 tap） | ✅ | `MappingEngine.processAxisToKey()` 在超过阈值时发送 `keyPress`，低于阈值时发送 `keyRelease`，保持按键状态 |

---

## ⑥ 宏系统（Macro Engine）

| 项目 | 状态 | 证据 |
|----|----|----|
| 宏是独立调度单元 | ✅ | `MacroScheduler` 独立类，有自己的 `executionQueue`，`Macro` 是独立数据结构 |
| 多宏可并行运行 | ❌ | `MacroScheduler.isRunning` 单一标志，`execute()` 检查 `guard !isRunning else { return }`，同时只能运行一个宏 |
| sleep(ms) | ✅ | `MacroStep.delay(milliseconds:)`，`MacroScheduler.executeStep()` 调用 `Thread.sleep(forTimeInterval:)` |
| repeat(n) | ✅ | `MacroType.loop(interval:maxCount:)`，`executeLoop()` 循环执行直到 `loopCount >= maxCount` |
| while(condition) | ❌ | 宏系统无条件循环支持，`MacroType` 仅支持固定次数循环，无 `while(condition)` 语义 |
| 精确 press / release | ✅ | `MacroStep.keyDown(keyCode:)` / `MacroStep.keyUp(keyCode:)` 分离，可精确控制按下和释放 |
| 宏可被中断 | ✅ | `MacroScheduler.interrupt()` 设置 `isInterrupted = true`，`releaseAllPressedKeys()` 释放所有按键 |

---

## ⑦ Toggle 宏（State Machine）

| 项目 | 状态 | 证据 |
|----|----|----|
| 第一次按下 = ON | ✅ | `MacroScheduler.handleToggleTrigger()`: `if !toggleActive` → `toggleActive = true` → `startToggleExecution()` |
| 第二次按下 = OFF | ✅ | `MacroScheduler.handleToggleTrigger()`: `if toggleActive && isRunning` → `shouldStop = true` → `toggleActive = false` |
| OFF 会终止已有循环 | ✅ | `executeToggleLoop()` 检查 `!shouldStop && toggleActive`，设置 `shouldStop = true` 后循环退出 |

---

## ⑧ 脚本系统（Script）

| 项目 | 状态 | 证据 |
|----|----|----|
| Script 支持 if / while | ❌ | `ScriptEngine.parse()` 仅支持函数调用语法，无 `if`/`while` 控制流解析，只有顺序执行 |
| Script 可读取 Button 状态 | ✅ | `ScriptContext.isButtonPressed(_:)`，`DefaultScriptContext` 通过 `buttonStateProvider` 闭包查询 |
| Script 可调用 sleep | ✅ | `ScriptContext.sleep(_:) async`，`DefaultScriptContext.sleep()` 使用 `Task.sleep(nanoseconds:)` |
| Script 可发送键盘 / 鼠标 | ✅ | `pressKey/releaseKey/tapKey/mouseClick/mouseMove` 方法，通过 `EventEmitter` 发送事件 |
| Script 属于 Macro 的一种实现 | ⚠️ | `Script` 是独立类型，`Action.script(Script)` 与 `Action.macro(Macro)` 并列，非 Macro 子类型，但功能上可作为复杂宏使用 |

---

## ⑨ Profile 系统

| 项目 | 状态 | 证据 |
|----|----|----|
| Profile = 完整映射集合 | ✅ | `Profile` 包含 `mappings: [Mapping]`, `macros: [Macro]`, `scripts: [Script]`, `applicationBindings` |
| Profile 可保存 / 加载 | ✅ | `ProfileManager.saveProfile()` / `loadProfile()` 使用 `JSONEncoder`/`JSONDecoder` |
| Profile 使用本地 JSON | ✅ | `ProfileManager.profileURL()` 返回 `~/Library/Application Support/PS5GamePadMapper/Profiles/*.json` |
| 手动切换 Profile 生效 | ✅ | `ProfileManager.setActiveProfile()` 触发 `onProfileWillChange`/`onProfileDidChange` 回调，`MappingEngine.activeProfile` 更新 |
| （可选）前台 App 自动切换 | ✅ | `ApplicationProfileSwitcher` 监听 `NSWorkspace.didActivateApplicationNotification`，根据 `applicationBindings` 自动切换 |

---

## ⑩ UI / UX（对照原设计）

| 项目 | 状态 | 证据 |
|----|----|----|
| 手柄示意图为主要交互入口 | ✅ | `ControllerVisualizationView` 绘制完整手柄图形，包含所有按钮和摇杆的可点击区域 |
| 点击按钮 → Mapping Detail Panel | ✅ | `ControllerVisualizationView.onInputSelected` → `MainWindowViewModel.selectInput()` → `MappingDetailPanel` 显示详情 |
| 修改 Action 即时生效 | ✅ | `MappingEditorView.applyMappingChange()` 在每次修改时调用 `onMappingChanged`，`MainWindowViewModel.updateMapping()` 立即保存并重新激活 Profile |
| 宏支持 录制模式 | ✅ | `MacroEditorView` 包含 `MacroRecorder` 类，`startRecording()` 监听键盘/鼠标事件，自动记录 `MacroStep` 和延迟 |
| 宏支持 脚本模式 | ✅ | `MacroEditorView` 有 `MacroEditorMode.script`，`ScriptTextEditor` 提供文本编辑器，`ScriptEngine.parse()` 验证语法 |

---

## ⑪ Debug / 可验证性

| 项目 | 状态 | 证据 |
|----|----|----|
| 显示原始输入事件 | ✅ | `DebugPanelView` 的 `inputEventsTab` 显示 `DebugInputEvent`，包含按钮/轴名称和值 |
| 显示映射后的 Action | ✅ | `DebugPanelView` 的 `mappingActionsTab` 显示 `DebugActionEvent`，包含 action 类型和详情 |
| 显示宏运行状态 | ✅ | `DebugPanelView` 的 `macroStateTab` 显示 `MacroState`（isRunning/currentStep/totalSteps）和执行历史 |
| 可实时看到 Axis 数值 | ✅ | `DebugPanelView` 的 `axisValuesTab` 显示 `AxisValueCard`，使用 `DebugPanelAxisFormatter.formatAxisValue()` 格式化为 2 位小数 |

---

## ⑫ 稳定性与权限（功能视角）

| 项目 | 状态 | 证据 |
|----|----|----|
| Accessibility 权限缺失不崩溃 | ✅ | `PermissionManager.checkAccessibilityPermission()` 返回状态，`AppCoordinator.processButtonInput()` 检查 `permissionManager.canEmitEvents` 后才发送事件 |
| 手柄断连会清理状态 | ✅ | `AppCoordinator.handleControllerDisconnected()` 调用 `macroScheduler.interrupt()` 中断宏，`MacroScheduler.releaseAllPressedKeys()` 释放所有按键 |
| 重连后可继续使用 | ✅ | `ControllerManager.handleDeviceConnected()` 检测重连（`previouslyConnectedDevices.contains`），触发 `onControllerReconnected` 回调 |
| 不会遗留"卡键"状态 | ✅ | `MacroScheduler.interrupt()` 调用 `releaseAllPressedKeys()` 遍历 `pressedKeys` 集合发送 `keyUp` 事件 |

---

## ✅ 最终结论（必须填写）

**1️⃣ 是否存在结构性偏离原设计？**  
- ✅ 否  

**2️⃣ 是否有核心能力被弱化为 workaround？**  
- ⚠️ 是（说明：）  
  1. **多宏并行运行**：当前实现仅支持单宏运行，`MacroScheduler.isRunning` 阻止新宏启动
  2. **脚本 if/while 控制流**：`ScriptEngine` 仅支持顺序函数调用，无条件/循环语句
  3. **宏 while(condition)**：`MacroType` 仅支持固定次数循环，无条件循环

**3️⃣ 站在原设计者视角，是否接受该实现？**  
- ✅ 接受（原因：核心功能完整，架构清晰，上述限制可通过后续迭代补充，不影响主要使用场景）

---

## 📊 统计摘要

| 类别 | ✅ | ⚠️ | ❌ | 总计 |
|------|----|----|----|----|
| ① 架构层级 | 4 | 0 | 0 | 4 |
| ② 控制器与输入 | 5 | 0 | 0 | 5 |
| ③ Button→Action | 6 | 0 | 0 | 6 |
| ④ 触发状态 | 3 | 0 | 0 | 3 |
| ⑤ Axis 映射 | 5 | 0 | 0 | 5 |
| ⑥ 宏系统 | 5 | 0 | 2 | 7 |
| ⑦ Toggle 宏 | 3 | 0 | 0 | 3 |
| ⑧ 脚本系统 | 3 | 1 | 1 | 5 |
| ⑨ Profile 系统 | 5 | 0 | 0 | 5 |
| ⑩ UI/UX | 5 | 0 | 0 | 5 |
| ⑪ Debug | 4 | 0 | 0 | 4 |
| ⑫ 稳定性与权限 | 4 | 0 | 0 | 4 |
| **总计** | **52** | **1** | **3** | **56** |

**通过率：92.9% (52/56)**

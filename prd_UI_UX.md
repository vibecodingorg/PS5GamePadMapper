一、项目背景（内部自用）

本工具为开发者个人/小团队自用的 macOS 输入映射工具，不考虑对外商业发布、上架、市场推广、用户增长、社区、法律合规等内容。

核心目标是：在 macOS 上高效、低延迟地将 PS5（DualSense）手柄输入映射为键盘/鼠标事件，并支持强大的宏与脚本能力，服务于开发者本人游戏与测试需求。

⸻

二、产品目标（Product Goals）

2.1 必达目标
	•	稳定识别 PS5 手柄（USB / 蓝牙）
	•	任意手柄输入 → 键盘 / 鼠标事件
	•	支持高可控的宏（时间、重复、组合、toggle）
	•	支持脚本化（为复杂逻辑服务）
	•	配置可保存、可切换、可快速修改

2.2 非目标（明确不做）
	•	❌ 不考虑新手用户友好度
	•	❌ 不考虑商业 UI 美观度
	•	❌ 不考虑反作弊合规与免责声明
	•	❌ 不做云同步、社区、分享、商店
	•	❌ 不做多语言（中文即可）

⸻

三、使用场景（Developer-driven Use Cases）
	1.	FPS 调试/游玩：用右摇杆模拟鼠标，测试不同灵敏度/加速度曲线
	2.	技能连招测试：一个按钮触发复杂输入序列（用于 MMO / ARPG）
	3.	压力测试：高频宏（10–50ms）验证输入注入稳定性
	4.	开发辅助：手柄触发 IDE/系统快捷键组合
	5.	输入实验：验证不同映射逻辑、状态机、条件宏的可行性

⸻

四、功能需求（Functional Requirements）

4.1 控制器与输入层

4.1.1 控制器识别
	•	支持 DualSense（PS5）手柄
	•	USB 与 Bluetooth
	•	读取内容：
	•	设备 ID
	•	连接方式
	•	电量（若 HID 提供）

4.1.2 输入类型
	•	数字按钮（Button）
	•	模拟轴（Axis：摇杆、扳机）

⸻

4.2 映射系统（核心）

4.2.1 Button → Action

每个按钮可绑定一个或多个 Action：
	•	键盘按键（支持组合键）
	•	鼠标按钮
	•	鼠标滚轮
	•	宏
	•	脚本

支持触发状态：
	•	Press
	•	Release
	•	Hold（带阈值）

4.2.2 Axis → Action
	•	Axis → WASD / 方向键
	•	Axis → 鼠标移动（相对）
	•	Axis → 连续键输出

参数：
	•	死区（deadzone）
	•	灵敏度
	•	曲线（linear / exponential）

⸻

4.3 宏系统（重点）

4.3.1 宏类型
	•	顺序宏（Sequence）
	•	循环宏（Loop / Turbo）
	•	Toggle 宏
	•	并行宏

4.3.2 宏能力
	•	sleep(ms)
	•	repeat(n)
	•	while(condition)
	•	按键按下/释放精确控制
	•	宏可被中断

4.3.3 触发方式
	•	Button Press
	•	Button Hold
	•	Button Toggle

⸻

4.4 脚本系统（Developer Feature）

4.4.1 脚本定位
	•	用于：复杂逻辑、状态控制、条件输入
	•	不追求 sandbox 安全性，仅限本地执行

4.4.2 建议脚本 API（最小集）

pressKey(key)
releaseKey(key)
tapKey(key, ms)
mouseClick(button)
mouseMove(dx, dy)
sleep(ms)
isButtonPressed(btn)


⸻

4.5 Profile 管理
	•	Profile 本地保存（JSON）
	•	手动切换 Profile
	•	可绑定前台应用自动切换（可选）
	•	支持快速复制/克隆

⸻

五、非功能需求（NFR）

5.1 性能
	•	输入 → 输出延迟目标：< 30ms
	•	高频宏下保持稳定（不崩溃、不丢事件）

5.2 稳定性
	•	长时间运行（>12h）
	•	控制器断连/重连可恢复

5.3 权限
	•	Accessibility（必需）
	•	Input Monitoring（若监听系统输入）
	•	Bluetooth

⸻

六、数据结构（内部使用）

{
  "profile": "Dev_FPS",
  "mappings": [
    {
      "input": "RStick",
      "type": "axis",
      "action": {
        "kind": "mouse_move",
        "sensitivity": 1.4,
        "deadzone": 0.05
      }
    },
    {
      "input": "R1",
      "type": "button",
      "action": {
        "kind": "macro",
        "script": "while(isButtonPressed('R1')){mouseClick('left');sleep(120);}"
      }
    }
  ]
}


⸻

七、交互原型草案（Interaction Draft）

⚠️ 这是工程导向原型，不是视觉设计稿

7.1 主窗口结构

+--------------------------------------------------+
| Device: DualSense (BT, 78%)   [Profile ▼]        |
+-------------------+------------------------------+
|                   |                              |
|  Controller Map   |   Mapping Detail Panel       |
|  (Clickable SVG)  |                              |
|                   |  Input: R1                   |
|                   |  Type: Button                |
|                   |  Action: Macro               |
|                   |  Trigger: Hold               |
|                   |                              |
|                   |  [ Edit Macro ]              |
|                   |                              |
+-------------------+------------------------------+


⸻

7.2 映射编辑流程
	1.	点击手柄示意图某按钮
	2.	弹出 Mapping Panel
	3.	选择 Action 类型：
	•	Key
	•	Mouse
	•	Macro
	•	Script
	4.	配置参数
	5.	即时生效（无需 Apply）

⸻

7.3 宏编辑器（两模式）

A. 录制模式

[ Record ]  [ Stop ]

1. Key A (down)
2. +120ms
3. Key A (up)
4. +80ms
5. Mouse Left Click

	•	可修改延时
	•	可删除步骤

B. 脚本模式

while(isButtonPressed('R1')){
  mouseClick('left')
  sleep(120)
}


⸻

7.4 实时测试面板（Debug）

[ R1 ] pressed → Macro running
[ Axis RX ] 0.42 → mouse dx=3

用于：
	•	验证输入
	•	验证映射
	•	调试宏逻辑

⸻

八、MVP 划分（内部开发顺序）

MVP-1（可用）
	•	PS5 手柄识别
	•	Button → Key / Mouse
	•	简单 Turbo 宏
	•	Accessibility 权限

MVP-2（开发者可爽用）
	•	Axis → Mouse
	•	Toggle 宏
	•	Profile 保存
	•	简易宏编辑器

MVP-3（工程完成度高）
	•	脚本支持
	•	实时日志
	•	应用自动切换 Profile

⸻

九、技术实现备注（仅内部）
	•	输入层：IOHIDManager
	•	输出层：CGEventPost
	•	UI：SwiftUI 或 AppKit（优先调试效率）
	•	宏调度：高优先级串行队列 + 定时器
	•	所有逻辑默认本地、同步、可调试

⸻

十、后续可扩展（不承诺）
	•	其他手柄支持
	•	手柄灯效/震动实验
	•	Lua 替换 JS

（完）
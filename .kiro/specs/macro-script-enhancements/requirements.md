# Requirements Document

## Introduction

本规格文档定义了 PS5GamePadMapper 宏系统和脚本引擎的增强功能。根据实现一致性审查，当前系统存在三个核心能力缺失：多宏并行运行、脚本控制流语句（if/while）、以及宏条件循环（while condition）。这些增强将使工具更加灵活和强大，满足复杂游戏测试场景的需求。

## Glossary

- **Macro**: 宏，一系列预定义的输入动作序列
- **MacroScheduler**: 宏调度器，负责执行和管理宏的生命周期
- **Script**: 脚本，使用简单语法编写的复杂输入逻辑
- **ScriptEngine**: 脚本引擎，负责解析和执行脚本
- **Parallel Execution**: 并行执行，多个宏同时运行
- **Control Flow**: 控制流，程序执行的顺序控制（if/while）
- **Condition**: 条件，用于控制流判断的布尔表达式
- **MacroInstance**: 宏实例，正在执行的宏的运行时表示

## Requirements

### Requirement 1: Parallel Macro Execution

**User Story:** As a developer, I want to run multiple macros simultaneously, so that I can simulate complex multi-button input scenarios.

#### Acceptance Criteria

1. WHEN a new macro is triggered while another macro is running, THE MacroScheduler SHALL create a new execution instance and run both macros concurrently
2. WHEN multiple macros are running, THE MacroScheduler SHALL maintain independent state for each macro instance including current step and pressed keys
3. WHEN a macro completes, THE MacroScheduler SHALL remove only that macro instance while other running macros continue unaffected
4. WHEN interrupt is called with a specific macro ID, THE MacroScheduler SHALL stop only that macro instance and release its pressed keys
5. WHEN interrupt is called without a macro ID, THE MacroScheduler SHALL stop all running macro instances and release all pressed keys
6. WHEN querying running macros, THE MacroScheduler SHALL return a list of all currently executing macro instances with their states

### Requirement 2: Script Control Flow - If Statement

**User Story:** As a developer, I want to use if statements in scripts, so that I can implement conditional logic based on controller state.

#### Acceptance Criteria

1. WHEN parsing a script with an if statement, THE ScriptEngine SHALL recognize the syntax `if (condition) { ... }`
2. WHEN parsing a script with an if-else statement, THE ScriptEngine SHALL recognize the syntax `if (condition) { ... } else { ... }`
3. WHEN evaluating an if condition, THE ScriptEngine SHALL support button state checks using `isButtonPressed(button)`
4. WHEN evaluating an if condition, THE ScriptEngine SHALL support comparison operators (==, !=, <, >, <=, >=)
5. WHEN evaluating an if condition, THE ScriptEngine SHALL support logical operators (&&, ||, !)
6. WHEN the if condition evaluates to true, THE ScriptEngine SHALL execute the statements in the if block
7. WHEN the if condition evaluates to false and an else block exists, THE ScriptEngine SHALL execute the statements in the else block

### Requirement 3: Script Control Flow - While Loop

**User Story:** As a developer, I want to use while loops in scripts, so that I can repeat actions based on dynamic conditions.

#### Acceptance Criteria

1. WHEN parsing a script with a while loop, THE ScriptEngine SHALL recognize the syntax `while (condition) { ... }`
2. WHEN evaluating a while condition, THE ScriptEngine SHALL support the same condition expressions as if statements
3. WHILE the while condition evaluates to true, THE ScriptEngine SHALL continue executing the loop body
4. WHEN the while condition evaluates to false, THE ScriptEngine SHALL exit the loop and continue with subsequent statements
5. WHEN a break statement is encountered inside a while loop, THE ScriptEngine SHALL immediately exit the loop
6. WHEN a continue statement is encountered inside a while loop, THE ScriptEngine SHALL skip to the next iteration

### Requirement 4: Macro Conditional Loop (While Condition)

**User Story:** As a developer, I want to create macros that loop based on conditions, so that I can create adaptive input sequences.

#### Acceptance Criteria

1. WHEN defining a macro type, THE System SHALL support a `whileCondition` type with a condition expression
2. WHEN executing a whileCondition macro, THE MacroScheduler SHALL evaluate the condition before each iteration
3. WHILE the condition evaluates to true, THE MacroScheduler SHALL continue executing the macro steps
4. WHEN the condition evaluates to false, THE MacroScheduler SHALL stop the macro execution gracefully
5. WHEN the condition references a button state, THE MacroScheduler SHALL query the current controller state
6. WHEN serializing a whileCondition macro, THE System SHALL store the condition expression as a string that can be parsed back


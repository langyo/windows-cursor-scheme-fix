# Windows 11 自定义光标主题不生效（Arrow/Hand/忙碌等）或始终显示 Windows Aero 光标主题的问题修复

更新了 Windows 11 最新版后发现，在部分 Windows 11 环境中，自定义鼠标光标方案已经正确安装，注册表中的路径也完全正确，但屏幕实际显示的“正常选择”（Arrow）、“链接选择”（Hand）、“忙碌”（Wait）、“后台运行”（AppStarting）等光标仍然是 Windows 经典样式。

本项目提供一个无需管理员权限的临时修复：读取当前用户所选方案中全部 14 个受支持光标角色（`Arrow`、`Hand`、`Wait`、`AppStarting` 等）的文件，通过 Windows 官方 `SetSystemCursor` API 将它们重新装载到当前登录会话。

## 已复现环境

- Windows 11 25H2
- Windows Insider Beta
- Build `26220.9223`
- 第三方 `.cur` 光标方案（测试使用 Jepri Creations 光标包）

其他 Windows 11 构建也可能出现相同现象，但尚未验证。

## 症状

- `main.cpl` 的“指针”页面可以看到并选择第三方方案。
- `HKEY_CURRENT_USER\Control Panel\Cursors` 中的各光标角色已指向正确的第三方 `.cur`/`.ani` 文件。
- 光标文件存在，并且可以通过 `LoadCursorFromFileW` 正常加载。
- 点击“应用”、重启应用，甚至注销后重新登录，部分或全部光标角色仍可能显示为 Windows 经典样式。
- 其他光标状态可能正常，或因为外观接近而不容易发现异常。

## 调查结论

已确认的事实：

1. 光标包安装成功，文件和注册表路径均正确。
2. Windows 当前会话中的 `OCR_NORMAL`、`OCR_HAND`、`OCR_WAIT` 等系统光标槽位内容仍是经典样式，与注册表指定文件不一致。
3. 直接调用 `SetSystemCursor` 后，系统光标与注册表指定文件的像素内容完全一致，屏幕显示立即恢复正常。

因此，问题发生在“注册表方案 -> 当前登录会话的系统光标槽位”这一装载环节，而不是光标文件损坏或安装路径错误。

目前没有证据表明微软已公开确认该问题。它可能与 Insider 构建中的光标初始化、辅助功能指针设置或传统控制面板方案兼容性回归有关，具体内部原因仍待确认。

## 使用方法

### 方法一：直接双击

1. 先通过 Windows 设置或 `main.cpl` 选择所需的自定义光标方案。
2. 双击 `Apply-CurrentCursorScheme.cmd`。
3. 所有已配置的光标角色应立即变为当前方案中的样式。

不要使用“以管理员身份运行”。脚本必须在日常登录账户下执行，才能读取正确的 `HKEY_CURRENT_USER`。

### 方法二：从 PowerShell 运行

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Apply-CurrentCursorScheme.ps1"
```

## 自动运行

该修复作用于当前登录会话，注销、系统更新或某些设置变更后可能需要再次执行。

需要登录时自动应用：

1. 按 `Win + R`。
2. 输入 `shell:startup` 并回车。
3. 在打开的启动文件夹中创建 `Apply-CurrentCursorScheme.cmd` 的快捷方式。

建议保存脚本所在目录，不要在创建快捷方式后移动或删除脚本。

## 脚本行为

脚本只执行以下操作：

1. 读取 `HKEY_CURRENT_USER\Control Panel\Cursors` 中 14 个受支持的光标角色（`Arrow`、`Hand`、`Wait`、`AppStarting` 等）。
2. 展开路径里的 `%SYSTEMROOT%` 等环境变量。
3. 检查 `.cur`/`.ani` 文件是否存在。
4. 使用 `LoadCursorFromFileW` 加载光标。
5. 使用 `SetSystemCursor` 替换当前会话中对应的全部系统光标槽位（`OCR_NORMAL`、`OCR_HAND`、`OCR_WAIT`、`OCR_APPSTARTING` 等 14 项）。

方案中未配置（注册表值为空）的角色会被跳过；某个角色失败不会阻止其他角色应用，但脚本最后会以错误退出并列出失败的角色。

脚本不会修改注册表，不会下载文件，也不需要管理员权限。

## 恢复方法

可以使用任意一种方式恢复：

- 打开 `main.cpl`，重新选择并应用 Windows 默认方案。
- 注销当前账户后重新登录。
- 选择其他光标方案后再次运行脚本。

## 已知限制

- `NWPen`、`Person`、`Pin` 没有对应的 `SetSystemCursor` 槽位，暂无法通过本脚本恢复。
- 修复不是永久修改；Windows 重新初始化系统光标后可能失效。
- 注册表中未配置的角色会被跳过；如果某个角色的文件不存在或格式无效，其余角色仍会应用，但脚本最后会报错并列出失败的角色。

## 参考资料

- [SetSystemCursor function](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-setsystemcursor)
- [LoadCursorFromFileW function](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-loadcursorfromfilew)
- [SystemParametersInfoW function](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-systemparametersinfow)

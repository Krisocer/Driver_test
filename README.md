# MyStarterDriver

一个最小 Windows 内核 WDM 驱动 starter，适合在 VS Code 里继续扩展。

## 目录

- `src/driver.c`：驱动入口、卸载、IRP 分发和示例 IOCTL。
- `include/public.h`：用户态和内核态共享的 IOCTL 定义。
- `MyStarterDriver.inf`：测试安装用 INF。
- `scripts/check-env.ps1`：检查 VS Build Tools、Windows SDK/WDK、签名工具和测试签名状态。
- `.vscode/tasks.json`：VS Code 构建任务。

## 环境要求

- Visual Studio 2022 Build Tools，包含 C++ 工具链。
- Windows SDK。
- Windows Driver Kit (WDK)。
- Visual Studio 组件：Windows Driver Kit Build Tools。
- 管理员权限，用于安装驱动、开启测试签名、启动/停止服务。

先检查环境：

```powershell
.\scripts\check-env.ps1
```

如果检查里提示缺少 `WindowsKernelModeDriver10.0` / `WDK MSBuild props`，请用管理员 PowerShell 执行：

```powershell
& 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' modify --installPath 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' --add Component.Microsoft.Windows.DriverKit.BuildTools --passive --norestart --installWhileDownloading
```

构建：

```powershell
.\scripts\build.ps1
```

构建产物通常在：

```text
x64\Debug\MyStarterDriver.sys
```

如果 MSBuild 还缺 WDK 平台工具集，也可以先用备用脚本构建：

```powershell
.\scripts\build-manual.ps1
```

## 测试安装提示

内核驱动会影响系统稳定性。建议优先在 Hyper-V/VMware/VirtualBox 虚拟机里测试。

开启测试签名需要管理员 PowerShell：

```powershell
bcdedit /set testsigning on
```

如果命令提示被 Secure Boot policy 阻止，需要先在 BIOS/UEFI 里关闭 Secure Boot，或者使用微软认可的驱动签名流程。重启后再安装测试驱动。

测试签名：

```powershell
.\scripts\sign-test.ps1
```

管理员 PowerShell 下安装和启动：

```powershell
.\scripts\driver-service.ps1 install
.\scripts\driver-service.ps1 start
```

停止和删除：

```powershell
.\scripts\driver-service.ps1 stop
.\scripts\driver-service.ps1 remove
```

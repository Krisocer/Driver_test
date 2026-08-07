# Windows Driver Starter 开发说明

## 我已经帮你完成的内容

这个项目现在已经具备在 VS Code 里开发、构建、打包和测试签名一个 Windows 内核驱动的基础能力。

### 1. Starter 驱动代码

核心代码在：

```text
src/driver.c
```

当前驱动包含：

- `DriverEntry`
- 驱动卸载函数
- 设备对象创建
- DOS 符号链接创建
- `IRP_MJ_CREATE`
- `IRP_MJ_CLOSE`
- `IRP_MJ_DEVICE_CONTROL`
- 一个示例 IOCTL：`IOCTL_MYSTARTER_PING`

公共定义在：

```text
include/public.h
```

里面包含：

- 内核设备名
- 用户态访问路径
- 自定义 device type
- 示例 IOCTL 定义

### 2. WDK/MSBuild 项目文件

项目文件是：

```text
MyStarterDriver.vcxproj
```

它现在可以使用 WDK 的：

```text
WindowsKernelModeDriver10.0
```

工具集进行标准 MSBuild 构建。

### 3. INF 安装文件

驱动 INF 文件是：

```text
MyStarterDriver.inf
```

我已经补好了驱动打包需要的：

- `SourceDisksNames`
- `SourceDisksFiles`
- service install section
- driver copy section

### 4. VS Code Tasks

VS Code 任务配置在：

```text
.vscode/tasks.json
```

你可以在 VS Code 里直接运行：

- 环境检查
- 标准构建
- 手工 fallback 构建
- 测试签名

### 5. 辅助脚本

脚本都在：

```text
scripts/
```

包括：

```text
scripts/check-env.ps1
```

检查开发环境是否完整。

```text
scripts/build.ps1
```

使用 MSBuild 标准构建驱动。

```text
scripts/build-manual.ps1
```

备用手工 `cl.exe` / `link.exe` 构建脚本。

```text
scripts/sign-test.ps1
```

创建或复用测试证书，并签名 `.sys` 和 `.cat`。

```text
scripts/driver-service.ps1
```

安装、启动、停止、删除 kernel driver service。

### 6. 已补齐的本机环境

我已经帮你补齐并验证了：

- Visual Studio Build Tools 2022
- Windows Driver Kit
- WDK Visual Studio Build Tools
- Spectre x64 libraries
- `msbuild`
- `signtool`
- `inf2cat`
- `stampinf`
- `pnputil`
- `bcdedit`

### 7. 已验证通过的内容

当前已经验证：

- `scripts/check-env.ps1` 环境检查通过
- `scripts/build.ps1` 标准构建成功
- `MyStarterDriver.sys` 生成成功
- `mystarterdriver.cat` 生成成功
- `.sys` 和 `.cat` 测试签名成功
- 签名状态为 `Valid`

构建输出位置：

```text
x64/Debug/MyStarterDriver.sys
```

完整驱动包位置：

```text
x64/Debug/MyStarterDriver/
```

里面包含：

```text
MyStarterDriver.sys
MyStarterDriver.inf
mystarterdriver.cat
```

## 现在还剩下的事情

### 1. 关闭 Secure Boot

当前唯一阻止加载测试驱动的是 Secure Boot。

我尝试执行：

```powershell
bcdedit /set testsigning on
```

系统返回：

```text
The value is protected by Secure Boot policy and cannot be modified or deleted.
```

这说明 Secure Boot 正在阻止开启测试签名模式。

你需要进入 BIOS/UEFI，关闭 Secure Boot。

关闭后，回到管理员 PowerShell 执行：

```powershell
bcdedit /set testsigning on
```

然后重启电脑。

### 2. 构建驱动

```powershell
.\scripts\build.ps1
```

如果标准构建出了问题，可以使用备用构建：

```powershell
.\scripts\build-manual.ps1
```

### 3. 测试签名

```powershell
.\scripts\sign-test.ps1
```

这个脚本会签名：

```text
x64/Debug/MyStarterDriver.sys
x64/Debug/MyStarterDriver/mystarterdriver.cat
```

### 4. 安装驱动

需要管理员 PowerShell。

```powershell
.\scripts\driver-service.ps1 install
```

### 5. 启动驱动

```powershell
.\scripts\driver-service.ps1 start
```

### 6. 查看状态

```powershell
.\scripts\driver-service.ps1 status
```

### 7. 停止驱动

```powershell
.\scripts\driver-service.ps1 stop
```

### 8. 删除驱动服务

```powershell
.\scripts\driver-service.ps1 remove
```

## 后续开发建议

### 添加新的 IOCTL

先在：

```text
include/public.h
```

添加新的 IOCTL 定义，例如：

```c
#define IOCTL_MYSTARTER_EXAMPLE \
    CTL_CODE(FILE_DEVICE_MYSTARTER, 0x802, METHOD_BUFFERED, FILE_ANY_ACCESS)
```

然后在：

```text
src/driver.c
```

的 `MyStarterDeviceControl` 里添加新的 `case`。

### 添加用户态测试程序

后面可以加一个 console app，用来测试驱动：

- `CreateFile("\\\\.\\MyStarterDriver", ...)`
- `DeviceIoControl(...)`
- `CloseHandle(...)`

这样你就可以从用户态向驱动发送 IOCTL。

### 调试建议

内核驱动写错可能导致蓝屏，所以建议：

- 优先在虚拟机里测试
- 每次改动后先构建
- 再签名
- 再加载
- 出问题时先停止并删除服务

推荐开发流程：

```powershell
.\scripts\build.ps1
.\scripts\sign-test.ps1
.\scripts\driver-service.ps1 stop
.\scripts\driver-service.ps1 remove
.\scripts\driver-service.ps1 install
.\scripts\driver-service.ps1 start
```

如果驱动已经停止失败或系统不稳定，重启测试机。

## 当前项目状态总结

代码、构建链、签名链都已经准备好了。

现在真正剩下的系统级前置条件是：

```text
关闭 Secure Boot -> 开启 testsigning -> 重启
```

完成之后，就可以开始加载并调试这个 starter 驱动。

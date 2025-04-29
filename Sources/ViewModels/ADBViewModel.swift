import Foundation
import SwiftUI
import Combine

class ADBViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var installedApps: [String] = []
    @Published var isLoading: Bool = false
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    
    // ADB路径，添加更多常见路径
    private let commonADBPaths = [
        "/usr/local/bin/adb",
        "/opt/homebrew/bin/adb",
        "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
    ]
    
    @AppStorage("adbPath") private var adbPath: String = ""
    
    init() {
        // 如果没有设置ADB路径，尝试找到一个可用的路径
        if adbPath.isEmpty {
            findADBPath()
        }
    }
    
    private func findADBPath() {
        for path in commonADBPaths {
            if FileManager.default.fileExists(atPath: path) {
                adbPath = path
                print("自动发现ADB路径: \(path)")
                return
            }
        }
        
        // 尝试使用which命令查找
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["adb"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0, let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                adbPath = output
                print("which命令发现ADB路径: \(output)")
                return
            }
        } catch {
            print("which命令执行失败: \(error)")
        }
        
        // 默认设置，稍后让用户手动配置
        adbPath = "/usr/local/bin/adb"
    }
    
    // 刷新连接的设备列表
    func refreshDevices() async {
        await MainActor.run {
            isLoading = true
            devices = []
        }
        
        do {
            // 检查ADB服务状态
            _ = try? await runADBCommand(args: ["start-server"])
            
            print("正在使用ADB路径: \(adbPath)")
            
            let output = try await runADBCommand(args: ["devices", "-l"])
            print("ADB设备输出: \(output)")
            
            let lines = output.components(separatedBy: "\n")
                .filter { !$0.isEmpty && !$0.contains("List of devices attached") }
            
            print("找到设备行: \(lines.count)")
            
            var tempDevices = [Device]()
            
            for line in lines {
                print("处理设备行: \(line)")
                if let device = Device.parse(from: line) {
                    var updatedDevice = device
                    
                    // 获取设备更多信息
                    if device.status == "device" {
                        // 获取型号
                        if let model = try? await getDeviceProperty(deviceId: device.id, property: "ro.product.model") {
                            updatedDevice.model = model
                        }
                        
                        // 获取产品名称
                        if let product = try? await getDeviceProperty(deviceId: device.id, property: "ro.product.name") {
                            updatedDevice.product = product
                        }
                    }
                    
                    tempDevices.append(updatedDevice)
                }
            }
            
            // 使用局部变量而不是捕获的变量
            let finalDevices = tempDevices
            
            await MainActor.run {
                self.devices = finalDevices
                isLoading = false
            }
        } catch {
            print("设备刷新错误: \(error)")
            await MainActor.run {
                isLoading = false
                showAlert(title: "错误", message: "刷新设备列表失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 获取设备属性
    private func getDeviceProperty(deviceId: String, property: String) async throws -> String? {
        let output = try await runADBCommand(args: ["-s", deviceId, "shell", "getprop", property])
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedOutput.isEmpty ? nil : trimmedOutput
    }
    
    // 安装APK
    func installApp(deviceId: String, apkPath: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            _ = try await runADBCommand(args: ["-s", deviceId, "install", "-r", apkPath])
            await MainActor.run {
                isLoading = false
                showAlert(title: "成功", message: "应用安装成功")
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showAlert(title: "错误", message: "安装失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 卸载应用
    func uninstallApp(deviceId: String, packageName: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            _ = try await runADBCommand(args: ["-s", deviceId, "uninstall", packageName])
            await MainActor.run {
                isLoading = false
                showAlert(title: "成功", message: "应用卸载成功")
                
                // 刷新已安装的应用列表
                if !installedApps.isEmpty {
                    Task {
                        await getInstalledApps(deviceId: deviceId)
                    }
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showAlert(title: "错误", message: "卸载失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 获取已安装的应用列表
    func getInstalledApps(deviceId: String) async {
        await MainActor.run {
            isLoading = true
            installedApps = []
        }
        
        do {
            let output = try await runADBCommand(args: ["-s", deviceId, "shell", "pm", "list", "packages"])
            let packages = output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .map { $0.replacingOccurrences(of: "package:", with: "") }
                .sorted()
            
            await MainActor.run {
                installedApps = packages
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showAlert(title: "错误", message: "获取应用列表失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 截图
    func takeScreenshot(deviceId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // 创建临时文件路径
            let tempDir = FileManager.default.temporaryDirectory
            let timestamp = Int(Date().timeIntervalSince1970)
            let remoteScreenshotPath = "/sdcard/screenshot_\(timestamp).png"
            let localScreenshotPath = tempDir.appendingPathComponent("screenshot_\(timestamp).png").path
            
            // 在设备上截图
            _ = try await runADBCommand(args: ["-s", deviceId, "shell", "screencap", "-p", remoteScreenshotPath])
            
            // 将截图拉到本地
            _ = try await runADBCommand(args: ["-s", deviceId, "pull", remoteScreenshotPath, localScreenshotPath])
            
            // 删除设备上的临时文件
            _ = try? await runADBCommand(args: ["-s", deviceId, "shell", "rm", remoteScreenshotPath])
            
            // 用系统默认程序打开截图
            let url = URL(fileURLWithPath: localScreenshotPath)
            NSWorkspace.shared.open(url)
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showAlert(title: "错误", message: "截图失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 重启设备
    func rebootDevice(deviceId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            _ = try await runADBCommand(args: ["-s", deviceId, "reboot"])
            await MainActor.run {
                isLoading = false
                showAlert(title: "成功", message: "设备正在重启")
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showAlert(title: "错误", message: "重启失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 打开终端并连接到设备的shell
    func openShell(deviceId: String) {
        // 打开终端并运行ADB shell命令
        let script = """
        tell application "Terminal"
            do script "\(adbPath) -s \(deviceId) shell"
            activate
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            showAlert(title: "错误", message: "打开终端失败: \(error["NSAppleScriptErrorMessage"] as? String ?? "未知错误")")
        }
    }
    
    // 打开终端并查看设备日志
    func openLogcat(deviceId: String) {
        // 打开终端并运行ADB logcat命令
        let script = """
        tell application "Terminal"
            do script "\(adbPath) -s \(deviceId) logcat"
            activate
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            showAlert(title: "错误", message: "打开日志失败: \(error["NSAppleScriptErrorMessage"] as? String ?? "未知错误")")
        }
    }
    
    // 配置ADB路径
    func configureADBPath() {
        let alert = NSAlert()
        alert.messageText = "设置ADB路径"
        alert.informativeText = "请输入ADB可执行文件的完整路径"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = adbPath
        
        alert.accessoryView = textField
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "自动检测")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 确定按钮
            let newPath = textField.stringValue
            
            // 测试新路径是否有效
            let task = Process()
            task.executableURL = URL(fileURLWithPath: newPath)
            task.arguments = ["version"]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    adbPath = newPath
                    showAlert(title: "成功", message: "ADB路径已更新")
                } else {
                    showAlert(title: "错误", message: "无效的ADB路径")
                }
            } catch {
                showAlert(title: "错误", message: "无效的ADB路径: \(error.localizedDescription)")
            }
        } else if response == .alertThirdButtonReturn {
            // 自动检测按钮
            findADBPath()
            showAlert(title: "信息", message: "ADB路径已设置为: \(adbPath)")
        }
    }
    
    // 运行ADB命令
    private func runADBCommand(args: [String]) async throws -> String {
        if !FileManager.default.fileExists(atPath: adbPath) {
            throw NSError(domain: "ADBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "ADB路径无效: \(adbPath), 请在设置中配置正确的路径"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: adbPath)
            task.arguments = args
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                
                let handle = pipe.fileHandleForReading
                let data = handle.readDataToEndOfFile()
                
                task.waitUntilExit()
                
                if let output = String(data: data, encoding: .utf8) {
                    if task.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        print("ADB命令失败: \(args.joined(separator: " "))")
                        print("错误输出: \(output)")
                        continuation.resume(throwing: NSError(domain: "ADBError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "命令失败: \(output)"]))
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "ADBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取命令输出"]))
                }
            } catch {
                print("ADB命令执行异常: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    // 显示警告
    func showAlert(title: String, message: String) {
        print("\(title): \(message)")
        
        alertTitle = title
        alertMessage = message
        showAlert = true
        
        // 在主UI上显示警告
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
        }
    }
    
    // 检查ADB版本
    func checkADBVersion() async throws -> String {
        if !FileManager.default.fileExists(atPath: adbPath) {
            throw NSError(domain: "ADBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "ADB路径无效: \(adbPath)"])
        }
        
        let output = try await runADBCommand(args: ["version"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 连接到指定地址的设备
    func connectToDevice(address: String) async throws -> String {
        print("尝试连接设备: \(address)")
        
        // 首先检查地址格式是否正确
        let components = address.components(separatedBy: ":")
        if components.count != 2 {
            throw NSError(domain: "ADBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的设备地址，格式应为 IP地址:端口号"])
        }
        
        // 尝试连接设备
        let output = try await runADBCommand(args: ["connect", address])
        print("连接设备输出: \(output)")
        
        // 如果连接成功，需要等待片刻让ADB识别设备
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 断开指定地址的设备
    func disconnectDevice(address: String) async throws -> String {
        print("断开设备连接: \(address)")
        
        let output = try await runADBCommand(args: ["disconnect", address])
        print("断开设备输出: \(output)")
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 
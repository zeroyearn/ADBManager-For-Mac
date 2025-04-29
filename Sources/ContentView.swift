import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ADBViewModel()
    @State private var selectedDevice: Device?
    @State private var showingFileImporter = false
    @State private var appInstallPath: String = ""
    @State private var showingHelpView = false
    @State private var errorMessage: String = ""
    @State private var showingErrorAlert = false
    @State private var showingConnectDialog = false
    @State private var deviceAddress: String = ""
    
    var body: some View {
        NavigationView {
            // 左侧设备列表
            VStack {
                List {
                    Section(header: Text("已连接设备")) {
                        if viewModel.isLoading {
                            ProgressView("正在加载设备...")
                                .padding()
                        } else if viewModel.devices.isEmpty {
                            VStack {
                                Text("没有已连接的设备")
                                    .foregroundColor(.secondary)
                                    .padding()
                                
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding()
                                        .multilineTextAlignment(.center)
                                }
                            }
                        } else {
                            ForEach(viewModel.devices) { device in
                                DeviceRow(device: device)
                                    .onTapGesture {
                                        selectedDevice = device
                                    }
                            }
                        }
                    }
                }
                
                VStack {
                    Button("刷新设备") {
                        Task {
                            errorMessage = ""
                            await viewModel.refreshDevices()
                        }
                    }
                    .padding(.top, 5)
                    
                    Button("连接网络设备") {
                        showConnectDeviceAlert()
                    }
                    .padding(.top, 5)
                    
                    Button("设置ADB路径") {
                        viewModel.configureADBPath()
                    }
                    .padding(.vertical)
                }
            }
            .frame(minWidth: 250)
            
            // 右侧设备详情
            if let device = selectedDevice {
                DeviceDetailView(device: device, viewModel: viewModel)
            } else {
                VStack {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding()
                    
                    Text("请选择一个设备")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("或者点击刷新设备按钮检测连接的设备")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Divider()
                        .padding()
                    
                    VStack(alignment: .leading) {
                        Text("常见问题:")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Text("• 确保设备已连接到电脑")
                        Text("• 确保设备已开启USB调试")
                        Text("• 确保ADB路径设置正确")
                        Text("• 在设备上授权此电脑的USB调试")
                        
                        Button("检查ADB安装状态") {
                            Task {
                                do {
                                    let version = try await viewModel.checkADBVersion()
                                    errorMessage = "ADB版本: \(version)"
                                } catch {
                                    errorMessage = "ADB检查失败: \(error.localizedDescription)"
                                    showingErrorAlert = true
                                }
                            }
                        }
                        .padding(.top)
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("ADB 设备管理器")
        // 添加顶部的按钮
        .overlay(
            HStack {
                Spacer()
                HStack(spacing: 20) {
                    Button(action: {
                        viewModel.configureADBPath()
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                    
                    Button(action: {
                        showingHelpView = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                    }
                }
                .padding()
            }, alignment: .topTrailing
        )
        .onAppear {
            Task {
                await viewModel.refreshDevices()
            }
        }
        .sheet(isPresented: $showingHelpView) {
            HelpView()
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("错误"),
                message: Text(errorMessage),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    // 显示连接设备的提示窗口
    private func showConnectDeviceAlert() {
        let alert = NSAlert()
        alert.messageText = "连接网络设备"
        alert.informativeText = "请输入需要连接的安卓设备的IP地址和端口号\n\n设备需要开启无线调试功能，操作步骤：\n1. 打开设备开发者选项\n2. 打开USB调试\n3. 打开无线调试\n4. 查看IP和端口\n\n注意：设备需要和电脑在同一网络下"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "例如: 192.168.1.100:5555"
        
        alert.accessoryView = textField
        alert.addButton(withTitle: "连接")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let address = textField.stringValue
            if !address.isEmpty {
                Task {
                    do {
                        let result = try await viewModel.connectToDevice(address: address)
                        errorMessage = "连接结果: \(result)"
                        // 连接后刷新设备列表
                        await viewModel.refreshDevices()
                    } catch {
                        errorMessage = "连接失败: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device
    
    var body: some View {
        HStack {
            Image(systemName: "iphone")
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text(device.id)
                    .font(.headline)
                Text(device.status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

struct DeviceDetailView: View {
    let device: Device
    @ObservedObject var viewModel: ADBViewModel
    @State private var showingFileImporter = false
    @State private var packageToUninstall = ""
    
    // 判断是否为网络设备
    private var isNetworkDevice: Bool {
        return device.id.contains(":")
    }
    
    var body: some View {
        VStack {
            // 设备信息
            GroupBox(label: Text("设备信息")) {
                VStack(alignment: .leading) {
                    InfoRow(label: "设备ID:", value: device.id)
                    InfoRow(label: "状态:", value: device.status)
                    if !device.model.isEmpty {
                        InfoRow(label: "型号:", value: device.model)
                    }
                    if !device.product.isEmpty {
                        InfoRow(label: "产品:", value: device.product)
                    }
                    
                    // 如果是网络设备，添加断开连接按钮
                    if isNetworkDevice {
                        Button("断开设备连接") {
                            Task {
                                do {
                                    let result = try await viewModel.disconnectDevice(address: device.id)
                                    viewModel.showAlert(title: "断开连接", message: result)
                                    // 刷新设备列表
                                    await viewModel.refreshDevices()
                                } catch {
                                    viewModel.showAlert(title: "错误", message: "断开连接失败: \(error.localizedDescription)")
                                }
                            }
                        }
                        .foregroundColor(.red)
                        .padding(.top, 10)
                    }
                }
                .padding()
            }
            .padding()
            
            // 应用管理
            GroupBox(label: Text("应用管理")) {
                VStack {
                    // 安装应用
                    Button("安装应用 (APK)") {
                        showingFileImporter = true
                    }
                    .padding()
                    
                    // 卸载应用
                    HStack {
                        TextField("输入包名", text: $packageToUninstall)
                        Button("卸载应用") {
                            Task {
                                if !packageToUninstall.isEmpty {
                                    await viewModel.uninstallApp(deviceId: device.id, packageName: packageToUninstall)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    // 查看已安装应用
                    Button("查看已安装应用") {
                        Task {
                            await viewModel.getInstalledApps(deviceId: device.id)
                        }
                    }
                    .padding()
                    
                    if viewModel.isLoading {
                        ProgressView("正在加载...")
                    } else if !viewModel.installedApps.isEmpty {
                        List {
                            ForEach(viewModel.installedApps, id: \.self) { app in
                                Text(app)
                                    .contextMenu {
                                        Button("复制包名") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(app, forType: .string)
                                        }
                                        Button("卸载") {
                                            packageToUninstall = app
                                            Task {
                                                await viewModel.uninstallApp(deviceId: device.id, packageName: app)
                                            }
                                        }
                                    }
                            }
                        }
                        .frame(height: 200)
                    }
                }
                .padding()
            }
            .padding()
            
            // 功能按钮
            GroupBox(label: Text("设备操作")) {
                VStack {
                    HStack {
                        Button("截图") {
                            Task {
                                await viewModel.takeScreenshot(deviceId: device.id)
                            }
                        }
                        
                        Button("重启") {
                            Task {
                                await viewModel.rebootDevice(deviceId: device.id)
                            }
                        }
                        
                        Button("Shell") {
                            viewModel.openShell(deviceId: device.id)
                        }
                        
                        Button("日志") {
                            viewModel.openLogcat(deviceId: device.id)
                        }
                    }
                    .padding()
                    
                    // 为网络设备添加无线调试相关功能
                    if isNetworkDevice {
                        Button("重新连接设备") {
                            Task {
                                do {
                                    let _ = try await viewModel.disconnectDevice(address: device.id)
                                    let result = try await viewModel.connectToDevice(address: device.id)
                                    viewModel.showAlert(title: "重新连接", message: result)
                                    await viewModel.refreshDevices()
                                } catch {
                                    viewModel.showAlert(title: "错误", message: "重新连接失败: \(error.localizedDescription)")
                                }
                            }
                        }
                        .padding(.bottom)
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.installApp(deviceId: device.id, apkPath: url.path)
                    }
                }
            case .failure(let error):
                viewModel.showAlert(title: "错误", message: "选择文件失败: \(error.localizedDescription)")
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.bold)
            Text(value)
            Spacer()
        }
    }
} 
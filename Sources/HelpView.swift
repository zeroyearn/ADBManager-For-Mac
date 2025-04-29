import SwiftUI

struct HelpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            HStack {
                Text("ADB 常用命令帮助")
                    .font(.title)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.title2)
                }
                .padding()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(title: "设备管理", commands: [
                        "adb devices - 列出所有已连接的设备",
                        "adb -s <设备ID> <命令> - 对特定设备执行命令",
                        "adb connect <IP地址>:<端口> - 通过网络连接设备",
                        "adb disconnect - 断开所有网络连接"
                    ])
                    
                    helpSection(title: "应用管理", commands: [
                        "adb install <apk路径> - 安装应用",
                        "adb install -r <apk路径> - 重新安装应用",
                        "adb uninstall <包名> - 卸载应用",
                        "adb shell pm list packages - 列出所有已安装的应用包名",
                        "adb shell pm clear <包名> - 清除应用数据和缓存"
                    ])
                    
                    helpSection(title: "文件传输", commands: [
                        "adb push <本地路径> <设备路径> - 将文件或目录推送到设备",
                        "adb pull <设备路径> <本地路径> - 从设备拉取文件或目录"
                    ])
                    
                    helpSection(title: "设备操作", commands: [
                        "adb reboot - 重启设备",
                        "adb shell screencap -p <路径> - 截取屏幕并保存到指定路径",
                        "adb shell screenrecord <路径> - 录制屏幕并保存到指定路径(最高3分钟)"
                    ])
                    
                    helpSection(title: "常见问题", commands: [
                        "连接设备但不显示 - 检查USB调试是否开启，尝试重新插拔USB线",
                        "ADB设备显示未授权 - 在设备上点击允许USB调试",
                        "设备无响应 - 尝试 adb kill-server 然后 adb start-server 重启ADB服务"
                    ])
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func helpSection(title: String, commands: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
            
            ForEach(commands, id: \.self) { command in
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .padding(.leading)
                    .contextMenu {
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(command, forType: .string)
                        }
                    }
            }
            
            Divider()
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
} 
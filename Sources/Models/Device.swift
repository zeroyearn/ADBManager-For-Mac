import Foundation

struct Device: Identifiable {
    let id: String
    let status: String
    var model: String = ""
    var product: String = ""
    
    static func parse(from deviceLine: String) -> Device? {
        print("解析设备行: \(deviceLine)")
        
        // 尝试解析常见格式
        // 常见格式: "DEVICE_ID\tDEVICE_STATUS"
        // 扩展格式: "DEVICE_ID       device product:PRODUCT_NAME model:MODEL_NAME device:DEVICE_NAME transport_id:ID"
        
        // 首先按制表符分割获取设备ID和状态
        let tabComponents = deviceLine.components(separatedBy: "\t")
        
        if tabComponents.count >= 2 {
            // 标准格式
            let id = tabComponents[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let status = tabComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("检测到标准格式设备 - ID: \(id), 状态: \(status)")
            return Device(id: id, status: status)
        }
        
        // 尝试空格分割
        let spaceComponents = deviceLine.split(separator: " ", omittingEmptySubsequences: true)
        
        if spaceComponents.count >= 2 {
            let id = String(spaceComponents[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let status = String(spaceComponents[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("检测到空格分隔设备 - ID: \(id), 状态: \(status)")
            
            // 尝试提取更多信息
            var model = ""
            var product = ""
            
            for component in spaceComponents.dropFirst(2) {
                let comp = String(component)
                if comp.starts(with: "model:") {
                    model = String(comp.dropFirst(6))
                } else if comp.starts(with: "product:") {
                    product = String(comp.dropFirst(8))
                }
            }
            
            var device = Device(id: id, status: status)
            device.model = model
            device.product = product
            
            return device
        }
        
        print("无法解析设备行")
        return nil
    }
} 
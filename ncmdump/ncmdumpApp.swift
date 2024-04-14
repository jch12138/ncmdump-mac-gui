//
//  ncmdumpApp.swift
//  ncmdump
//
//  Created by 蒋晨辉 on 10/4/23.
//

import SwiftUI

import Foundation
import CryptoSwift

// Unpad function
func unpad(_ array: [UInt8]) -> [UInt8] {
    guard let lastValue = array.last else { return array }
    let endIndex = array.count - Int(lastValue)
    return Array(array[..<endIndex])
}

// Helper function to convert bytes to UInt32
func bytesToUInt32(_ bytes: [UInt8]) -> UInt32 {
    return UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
}

// Main function to decrypt file
func dump(filePath: String) -> String {
    print(filePath)
    let coreKey = Array(hex: "687A4852416D736F356B496E62617857")
    let metaKey = Array(hex: "2331346C6A6B5F215C5D2630553C2728")
    
    guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        fatalError("Couldn't read the file")
    }
    
    let header = fileData[0..<8]
    assert(header.hexString == "4354454e4644414d")
    
    var offset = 10
    let keyLength = bytesToUInt32(Array(fileData[offset..<offset+4]))

    offset += 4
    let keyData = Data(fileData[offset..<offset+Int(keyLength)]).map { $0 ^ 0x64 }
    offset += Int(keyLength)
    
    let decryptedKeyData = try! unpad(AES(key: coreKey, blockMode: ECB(), padding: .noPadding).decrypt([UInt8](keyData))).dropFirst(17)
    let keyBox = calculateKeyBox(keyData: Data(decryptedKeyData))
    
    let metaLength = bytesToUInt32(Array(fileData[offset..<offset+4]))
    offset += 4
    var metaData = Data(fileData[offset..<offset+Int(metaLength)]).map { $0 ^ 0x63 }
    offset += Int(metaLength)

    let base64EncodedData = metaData.dropFirst(22)
    let base64String = String(decoding: base64EncodedData, as: UTF8.self)
    if let data = Data(base64Encoded: base64String) {
        metaData = Array<UInt8>(data)
    } else {
        print("Invalid base64 string")
    }
    let decryptedMetaData = try! unpad(AES(key: metaKey, blockMode: ECB(), padding: .noPadding).decrypt([UInt8](metaData)))
    
    let metaDataString = String(data: Data(decryptedMetaData)[6...], encoding: .utf8)!
    let metaDataJson = try! JSONSerialization.jsonObject(with: metaDataString.data(using: .utf8)!, options: []) as! [String: Any]
    
    offset += 9
    let imageSize = bytesToUInt32(Array(fileData[offset..<offset+4]))

    offset += 4
    _ = fileData[offset..<offset+Int(imageSize)]
    offset += Int(imageSize)
    let fileName = (filePath as NSString).lastPathComponent.replacingOccurrences(of: ".ncm", with: ".\(metaDataJson["format"] as! String)")
    let outputPath = (filePath as NSString).deletingLastPathComponent + "/" + fileName
    
    let fileManager = FileManager.default

    // Create an empty file
    fileManager.createFile(atPath: outputPath, contents: nil, attributes: nil)

    // Open the file for writing
    if let fileHandle = FileHandle(forWritingAtPath: outputPath) {
        defer {
            fileHandle.closeFile()
        }
        
        var chunk = Data()
        while offset < fileData.count {
            chunk = Data(fileData[offset..<min(offset+0x8000, fileData.count)])
            offset += chunk.count
            for i in 1...chunk.count {
                let j = i & 0xff
                let innerIndex = (Int(keyBox[j]) + j) & 0xff
                let outerIndex = (Int(keyBox[j]) + Int(keyBox[innerIndex])) & 0xff

                chunk[i-1] ^= keyBox[Int(outerIndex)]
            }
            fileHandle.write(chunk)
        }

        print("Data successfully written to file at \(outputPath)")
    } else {
        print("Error: Unable to open file for writing at \(outputPath)")
    }
    
    print("done")
    return fileName
}

extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }
            .joined()
    }
}

func calculateKeyBox(keyData: Data) -> [UInt8] {
    var keyBox = Array(UInt8(0)...UInt8(255))
    var lastByte = 0
    var keyOffset = 0
    for i in 0..<256 {
        let swap = keyBox[i]
        lastByte = (Int(swap) + lastByte + Int(keyData[keyOffset])) & 0xff
        keyOffset += 1
        if keyOffset >= keyData.count {
            keyOffset = 0
        }
        keyBox[i] = keyBox[lastByte]
        keyBox[lastByte] = swap
    }
    return keyBox
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: NSViewRepresentableContext<VisualEffectView>) -> NSVisualEffectView {
        let view = NSVisualEffectView()

        view.material = .fullScreenUI
        
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: NSViewRepresentableContext<VisualEffectView>) {
        // Leave this empty
    }
}


func makeNSView(context: NSViewRepresentableContext<VisualEffectView>) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    
    view.material = .fullScreenUI
    
    view.blendingMode = .behindWindow
    view.state = .active
    return view
}



struct ContentView: View {
    @State private var fileName: String = ""
    @State private var fileStatus: String = "就绪"

    var body: some View {
        ZStack {
            VStack {
                Button("选择文件") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = true
                    panel.canChooseDirectories = false
                    panel.canCreateDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedFileTypes = ["ncm"]
                    
                    if (panel.runModal() == NSApplication.ModalResponse.OK) {
                        let result = panel.urls // 这是一个包含所有选定文件 URL 的数组

                        if (result.count > 0) {
                            for path in result {
                                print(path)
                                self.fileName = path.lastPathComponent
                                self.fileStatus = "处理中"
                                DispatchQueue.global().async {
                                    self.handleFile(at: path)
                                    DispatchQueue.main.async {
                                        self.fileStatus = "完成"
                                    }
                                }
                            }
                        }
                    }
                }
                
                Text("\(fileName) \(fileStatus)").padding()            }

        }
    }
    
    func handleFile(at url: URL) {
        _ = dump(filePath: url.path)
    }
}

    


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

@main
struct YourApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 可能需要检查是否有通过特定方式传递的文件路径等
        // 设置所有窗口的大小
        for window in NSApplication.shared.windows {
            window.setContentSize(NSSize(width: 300, height: 200))
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            print("开始处理文件：\(url.path)")
            let result = handleFile(at: url)
            print("文件处理完成：\(result)")
        }
        NSApplication.shared.terminate(nil) // 处理完毕后退出应用
    }

    private func handleFile(at url: URL) -> String {
        // 调用之前定义的 dump 函数处理文件
        return dump(filePath: url.path)
    }
}


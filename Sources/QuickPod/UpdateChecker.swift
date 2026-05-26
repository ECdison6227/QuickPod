import Foundation
import AppKit

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var releaseNotes: String?
    @Published var downloadURL: URL?
    @Published var isChecking = false
    @Published var checkError: String?
    
    // GitHub 配置
    private let repoOwner = "edison"  // TODO: 修改为你的 GitHub 用户名
    private let repoName = "QuickPod"  // TODO: 修改为你的仓库名
    
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.quickpod.app"
    }
    
    // 检查更新
    func checkForUpdates(showAlert: Bool = false) {
        isChecking = true
        checkError = nil
        updateAvailable = false
        
        let releasesURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("QuickPod/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false
                
                if let error = error {
                    self?.checkError = "检查更新失败: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.checkError = "解析更新信息失败"
                    return
                }
                
                // 获取最新版本号
                if let tagName = json["tag_name"] as? String {
                    self?.latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                } else if let tagName = json["tag_name"] {
                    self?.latestVersion = "\(tagName)"
                }
                
                // 获取发布说明
                if let body = json["body"] as? String {
                    self?.releaseNotes = body
                }
                
                // 获取下载链接
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           name.hasSuffix(".dmg"),
                           let browserDownloadURL = asset["browser_download_url"] as? String {
                            self?.downloadURL = URL(string: browserDownloadURL)
                            break
                        }
                    }
                }
                
                // 比较版本
                if let latestVersion = self?.latestVersion {
                    self?.updateAvailable = self?.compareVersions(current: self?.currentVersion ?? "0.0.0", latest: latestVersion) == .older
                }
                
                if showAlert {
                    self?.showUpdateAlert()
                }
            }
        }.resume()
    }
    
    // 版本比较
    private enum VersionComparison {
        case older, same, newer
    }
    
    private func compareVersions(current: String, latest: String) -> VersionComparison {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(currentParts.count, latestParts.count)
        
        for i in 0..<maxLength {
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            let latestPart = i < latestParts.count ? latestParts[i] : 0
            
            if currentPart < latestPart {
                return .older
            } else if currentPart > latestPart {
                return .newer
            }
        }
        
        return .same
    }
    
    // 显示更新提示
    private func showUpdateAlert() {
        guard updateAvailable, let version = latestVersion else {
            if checkError != nil {
                // 检查出错，提示用户但不需要升级
                return
            }
            // 已是最新版本，不需要提示
            return
        }
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "发现新版本"
        alert.informativeText = "QuickPod \(version) 现已可用。你当前使用的是 \(currentVersion)。\n\n是否下载新版本？"
        alert.addButton(withTitle: "下载")
        alert.addButton(withTitle: "稍后")
        alert.addButton(withTitle: "跳过此版本")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let url = downloadURL {
                NSWorkspace.shared.open(url)
            }
        case .alertThirdButtonReturn:
            // 记住跳过版本
            UserDefaults.standard.set(version, forKey: "QuickPod.skippedVersion")
        default:
            break
        }
    }
    
    // 下载最新版本
    func downloadLatestVersion() {
        if let url = downloadURL {
            NSWorkspace.shared.open(url)
        }
    }
    
    // 打开 GitHub 发布页面
    func openReleasesPage() {
        let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!
        NSWorkspace.shared.open(url)
    }
}

import Foundation
import AppKit

class UpdateChecker: ObservableObject {
    enum CheckSource: String {
        case githubAPI
        case githubWebFallback

        var displayName: String {
            switch self {
            case .githubAPI:
                return QuickPodText.text(zh: "GitHub API", en: "GitHub API")
            case .githubWebFallback:
                return QuickPodText.text(zh: "网页兜底", en: "Web fallback")
            }
        }
    }

    static let shared = UpdateChecker()
    
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var releaseNotes: String?
    @Published var downloadURL: URL?
    @Published var isChecking = false
    @Published var checkError: String?
    @Published var lastCheckedAt: Date?
    @Published var lastCheckSource: CheckSource?
    
    // GitHub 配置
    private let repoOwner = "ECdison6227"
    private let repoName = "QuickPod"
    
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
        print("[QuickPod] 检查更新: \(releasesURL), 当前版本: \(currentVersion)")
        
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("QuickPod/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            self?.handleAPIResponse(data: data, response: response, error: error, showAlert: showAlert)
        }.resume()
    }

    private func handleAPIResponse(data: Data?, response: URLResponse?, error: Error?, showAlert: Bool) {
        if let error {
            print("[QuickPod] 更新检查失败: \(error.localizedDescription)")
            fallbackToLatestReleaseRedirect(showAlert: showAlert, reason: error.localizedDescription)
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            print("[QuickPod] HTTP 状态码: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 403 {
                fallbackToLatestReleaseRedirect(showAlert: showAlert, reason: "GitHub API rate limit")
                return
            }
            if httpResponse.statusCode != 200 {
                finishCheck(
                    error: QuickPodText.text(
                        zh: "服务器返回错误: \(httpResponse.statusCode)",
                        en: "Server returned HTTP \(httpResponse.statusCode)"
                    ),
                    showAlert: showAlert
                )
                return
            }
        }

        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[QuickPod] 解析更新信息失败")
            fallbackToLatestReleaseRedirect(showAlert: showAlert, reason: "Invalid JSON")
            return
        }

        DispatchQueue.main.async {
            self.latestVersion = self.normalizedVersion(from: json["tag_name"])
            self.releaseNotes = json["body"] as? String
            self.downloadURL = self.extractBestDownloadURL(from: json) ?? URL(string: "https://github.com/\(self.repoOwner)/\(self.repoName)/releases/latest")
            self.updateAvailable = self.shouldOfferUpdate(for: self.latestVersion)
            self.lastCheckSource = .githubAPI
            self.finishCheck(error: nil, showAlert: showAlert)
        }
    }

    private func fallbackToLatestReleaseRedirect(showAlert: Bool, reason: String) {
        let fallbackURL = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")!
        print("[QuickPod] 使用网页重定向兜底检查更新，原因: \(reason)")

        var request = URLRequest(url: fallbackURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 12

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.downloadURL = fallbackURL
                    self.finishCheck(
                        error: QuickPodText.text(
                            zh: "检查更新失败: \(error.localizedDescription)",
                            en: "Update check failed: \(error.localizedDescription)"
                        ),
                        showAlert: showAlert
                    )
                }
                return
            }

            let redirectLocation = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Location")
            let latestVersion = redirectLocation
                .flatMap { URL(string: $0)?.lastPathComponent }
                .flatMap { self.normalizedVersion(from: $0) }

            DispatchQueue.main.async {
                self.latestVersion = latestVersion
                self.releaseNotes = QuickPodText.text(
                    zh: "当前使用 GitHub 网页重定向作为兜底检查，详细更新说明请打开发布页面查看。",
                    en: "Update checking is using the GitHub web redirect fallback. Open the releases page for full notes."
                )
                self.downloadURL = fallbackURL
                self.updateAvailable = self.shouldOfferUpdate(for: latestVersion)
                self.lastCheckSource = .githubWebFallback
                self.finishCheck(error: nil, showAlert: showAlert)
            }
        }.resume()
    }

    private func finishCheck(error: String?, showAlert: Bool) {
        isChecking = false
        checkError = error
        lastCheckedAt = Date()
        if showAlert {
            showUpdateAlert()
        }
    }

    private func normalizedVersion(from anyValue: Any?) -> String? {
        guard let anyValue else { return nil }
        return String(describing: anyValue).replacingOccurrences(of: "v", with: "")
    }

    private func extractBestDownloadURL(from json: [String: Any]) -> URL? {
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String,
                   (name.hasSuffix(".dmg") || name.hasSuffix(".zip")),
                   let browserDownloadURL = asset["browser_download_url"] as? String,
                   let url = URL(string: browserDownloadURL) {
                    return url
                }
            }
        }

        if let htmlURL = json["html_url"] as? String {
            return URL(string: htmlURL)
        }

        return nil
    }

    private func shouldOfferUpdate(for latestVersion: String?) -> Bool {
        guard let latestVersion else { return false }
        if UserDefaults.standard.string(forKey: "QuickPod.skippedVersion") == latestVersion {
            return false
        }
        return compareVersions(current: currentVersion, latest: latestVersion) == .older
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
        if let checkError {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = QuickPodText.text(zh: "无法完成更新检查", en: "Update check failed")
            alert.informativeText = checkError
            alert.addButton(withTitle: QuickPodText.text(zh: "打开发布页", en: "Open releases"))
            alert.addButton(withTitle: QuickPodText.text(zh: "关闭", en: "Close"))
            if alert.runModal() == .alertFirstButtonReturn {
                openReleasesPage()
            }
            return
        }

        guard updateAvailable, let version = latestVersion else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = QuickPodText.text(zh: "已经是最新版本", en: "You're up to date")
            alert.informativeText = QuickPodText.text(
                zh: "当前版本 \(currentVersion) 已经是可检测到的最新版本。",
                en: "Current version \(currentVersion) is the latest version we could detect."
            )
            alert.addButton(withTitle: QuickPodText.text(zh: "好", en: "OK"))
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = QuickPodText.text(zh: "发现新版本", en: "New version available")
        alert.informativeText = QuickPodText.text(
            zh: "QuickPod \(version) 现已可用。你当前使用的是 \(currentVersion)。\n\n是否打开下载页面？",
            en: "QuickPod \(version) is available. You're currently on \(currentVersion).\n\nOpen the download page now?"
        )
        alert.addButton(withTitle: QuickPodText.text(zh: "打开下载页", en: "Open download"))
        alert.addButton(withTitle: QuickPodText.text(zh: "稍后", en: "Later"))
        alert.addButton(withTitle: QuickPodText.text(zh: "跳过此版本", en: "Skip this version"))
        
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

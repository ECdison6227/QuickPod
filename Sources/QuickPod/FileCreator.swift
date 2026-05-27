import AppKit
import UserNotifications

class FileCreator {
    enum CreationResult {
        case success(URL)
        case failure(FileCreatorError)
    }

    enum FileCreatorError: LocalizedError {
        case desktopUnavailable
        case createFailed(String)
        case templateFailed(String)

        var errorDescription: String? {
            switch self {
            case .desktopUnavailable:
                return "无法找到桌面目录"
            case .createFailed(let fileName):
                return "\(fileName) 创建失败"
            case .templateFailed(let fileName):
                return "\(fileName) 模板生成失败"
            }
        }
    }

    enum FileType: String, CaseIterable {
        case txt = "文本文档.txt"
        case md = "Markdown.md"
        case docx = "Word文档.docx"
        case xlsx = "Excel表格.xlsx"
        case pptx = "PPT演示.pptx"
        case custom = "自定义"

        var displayName: String {
            switch self {
            case .txt: return "空白 TXT"
            case .md: return "空白 MD"
            case .docx: return "空白 Word"
            case .xlsx: return "空白 Excel"
            case .pptx: return "空白 PPT"
            case .custom:
                let ext = FileCreator.customFileExtension
                return ext.isEmpty ? "自定义后缀" : "自定义 .\(ext)"
            }
        }

        var shortName: String {
            switch self {
            case .txt: return "TXT"
            case .md: return "MD"
            case .docx: return "Word"
            case .xlsx: return "Excel"
            case .pptx: return "PPT"
            case .custom:
                let ext = FileCreator.customFileExtension
                return ext.isEmpty ? "自定义" : ".\(ext)"
            }
        }
    }

    /// 用户默认文件名（通过 UserDefaults 持久化）
    static let defaultFileNameKey = "QuickPod.defaultFileName"
    static let customFileExtensionKey = "QuickPod.customFileExtension"
    static var defaultFileName: String {
        get { UserDefaults.standard.string(forKey: defaultFileNameKey) ?? "新建文件" }
        set { UserDefaults.standard.set(newValue, forKey: defaultFileNameKey) }
    }
    static var customFileExtension: String {
        get { sanitizeExtension(UserDefaults.standard.string(forKey: customFileExtensionKey) ?? "log") }
        set { UserDefaults.standard.set(sanitizeExtension(newValue), forKey: customFileExtensionKey) }
    }
    static var availableFileTypes: [FileType] {
        FileType.allCases.filter { type in
            type != .custom || !customFileExtension.isEmpty
        }
    }

    func create(_ type: FileType, completion: @escaping (CreationResult) -> Void = { _ in }) {
        create(type, customBaseName: nil, completion: completion)
    }

    func create(_ type: FileType, customBaseName: String?, completion: @escaping (CreationResult) -> Void = { _ in }) {
        guard let desktopURL = FileManager.default.urls(
            for: .desktopDirectory, in: .userDomainMask
        ).first else {
            DispatchQueue.main.async {
                completion(.failure(.desktopUnavailable))
            }
            return
        }

        let baseName = normalizedBaseName(customBaseName)
        let ext = resolvedExtension(for: type)
        if type == .custom && ext.isEmpty {
            DispatchQueue.main.async {
                completion(.failure(.templateFailed("自定义文件后缀为空")))
            }
            return
        }
        let fileName = ext.isEmpty ? baseName : "\(baseName).\(ext)"
        let fileURL = desktopURL.appendingPathComponent(fileName)
        let uniqueURL = makeUnique(url: fileURL)

        let content = templateContent(for: type)
        if content.isEmpty && type != .txt && type != .custom {
            DispatchQueue.main.async {
                completion(.failure(.templateFailed(uniqueURL.lastPathComponent)))
            }
            return
        }

        let created = FileManager.default.createFile(
            atPath: uniqueURL.path,
            contents: content,
            attributes: nil
        )

        guard created else {
            DispatchQueue.main.async {
                completion(.failure(.createFailed(uniqueURL.lastPathComponent)))
            }
            return
        }

        sendCreationNotification(for: uniqueURL)
        DispatchQueue.main.async {
            completion(.success(uniqueURL))
        }
    }

    private func resolvedExtension(for type: FileType) -> String {
        switch type {
        case .custom:
            return Self.customFileExtension
        default:
            return (type.rawValue as NSString).pathExtension
        }
    }

    static func sanitizeExtension(_ rawValue: String) -> String {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let withoutDot = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
        return withoutDot.replacingOccurrences(
            of: "[^a-z0-9_-]",
            with: "",
            options: .regularExpression
        )
    }

    private func normalizedBaseName(_ customBaseName: String?) -> String {
        let trimmed = customBaseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            Self.defaultFileName = trimmed
            return trimmed
        }
        return Self.defaultFileName
    }

    private func sendCreationNotification(for fileURL: URL) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.scheduleCreationNotification(for: fileURL)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        self.scheduleCreationNotification(for: fileURL)
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func scheduleCreationNotification(for fileURL: URL) {
        let notifContent = UNMutableNotificationContent()
        notifContent.title = "文件已创建"
        notifContent.body = "\(fileURL.lastPathComponent) 已保存到桌面"
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notifContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func makeUnique(url: URL) -> URL {
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var target = url
        var counter = 1
        while FileManager.default.fileExists(atPath: target.path) {
            target = url
                .deletingLastPathComponent()
                .appendingPathComponent("\(base) \(counter)")
                .appendingPathExtension(ext)
            counter += 1
        }
        return target
    }

    private func templateContent(for type: FileType) -> Data {
        switch type {
        case .txt:
            return Data()
        case .md:
            return "# \n\n".data(using: .utf8) ?? Data()
        case .docx:
            return minimalDocx()
        case .xlsx:
            return minimalXlsx()
        case .pptx:
            return minimalPptx()
        case .custom:
            return Data()
        }
    }

    // MARK: - OOXML helpers

    private func minimalDocx() -> Data {
        return createOOXML(
            contentTypes: docxContentTypes,
            rels: docxRels,
            document: docxDocument
        )
    }

    private func minimalXlsx() -> Data {
        return createOOXML(
            contentTypes: xlsxContentTypes,
            rels: xlsxRels,
            document: xlsxDocument
        )
    }

    private func minimalPptx() -> Data {
        return createOOXML(
            contentTypes: pptxContentTypes,
            rels: pptxRels,
            document: pptxDocument
        )
    }

    private func createOOXML(contentTypes: String, rels: String, document: String) -> Data {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try? contentTypes.data(using: .utf8)?.write(
            to: tempDir.appendingPathComponent("[Content_Types].xml")
        )

        let relsDir = tempDir.appendingPathComponent("_rels")
        try? FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try? rels.data(using: .utf8)?.write(to: relsDir.appendingPathComponent(".rels"))

        let docDir: String
        let docName: String
        if document.contains("w:document") {
            docDir = "word"
            docName = "document.xml"
        } else if document.contains("workbook") {
            docDir = "xl"
            docName = "workbook.xml"
        } else {
            docDir = "ppt"
            docName = "presentation.xml"
        }
        let dir = tempDir.appendingPathComponent(docDir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? document.data(using: .utf8)?.write(to: dir.appendingPathComponent(docName))

        let zipPath = tempDir.appendingPathComponent("output.zip")
        let task = Process()
        task.currentDirectoryURL = tempDir
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        task.arguments = ["-q", "-r", zipPath.path,
            "[Content_Types].xml", "_rels", docDir]
        try? task.run()
        task.waitUntilExit()

        let data = try? Data(contentsOf: zipPath)
        try? FileManager.default.removeItem(at: tempDir)
        return data ?? Data()
    }

    // MARK: - OOXML Templates

    private var docxContentTypes: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
    }

    private var docxRels: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private var docxDocument: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r></w:r></w:p></w:body>
        </w:document>
        """
    }

    private var xlsxContentTypes: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        </Types>
        """
    }

    private var xlsxRels: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private var xlsxDocument: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """
    }

    private var pptxContentTypes: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
        </Types>
        """
    }

    private var pptxRels: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """
    }

    private var pptxDocument: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:sldIdLst/>
        </p:presentation>
        """
    }
}

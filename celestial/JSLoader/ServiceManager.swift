//
//  ServiceManager.swift
//  celestial
//
//  Created by Francesco on 09/08/25.
//

import Foundation

class ServiceManager: ObservableObject {
    static let shared = ServiceManager()
    
    @Published var services: [Services] = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadMessage: String = ""
    
    private let documentsDirectory: URL
    private let servicesDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        servicesDirectory = documentsDirectory.appendingPathComponent("Services")
        
        createServicesDirectoryIfNeeded()
        loadExistingServices()
    }
    
    // MARK: - Public Methods
    
    func handlePotentialServiceURL(_ text: String) async -> Bool {
        guard isValidJSONURL(text) else { return false }
        
        await downloadService(from: text)
        return true
    }
    
    func downloadService(from jsonURL: String) async {
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            downloadMessage = "Downloading service..."
        }
        
        do {
            await updateProgress(0.2, "Downloading metadata...")
            let metadata = try await downloadAndParseMetadata(from: jsonURL)
            
            await updateProgress(0.5, "Downloading JavaScript...")
            let jsContent = try await downloadJavaScript(from: metadata.scriptUrl)
            
            await updateProgress(0.8, "Saving files...")
            let service = try await saveService(metadata: metadata, jsContent: jsContent, metadataUrl: jsonURL)
            
            await MainActor.run {
                self.services.append(service)
                self.downloadProgress = 1.0
                self.downloadMessage = "Service downloaded successfully!"
            }
            
            Logger.shared.log("Successfully downloaded service: \(metadata.sourceName)", type: "ServiceManager")
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.downloadMessage = ""
            }
            
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.downloadMessage = ""
            }
            Logger.shared.log("Failed to download service from \(jsonURL): \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    func removeService(_ service: Services) {
        do {
            let servicePath = servicesDirectory.appendingPathComponent(service.localPath)
            if FileManager.default.fileExists(atPath: servicePath.path) {
                try FileManager.default.removeItem(at: servicePath)
            }
            
            services.removeAll { $0.id == service.id }
            Logger.shared.log("Removed service: \(service.metadata.sourceName)", type: "ServiceManager")
        } catch {
            Logger.shared.log("Failed to remove service \(service.metadata.sourceName): \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    func toggleServiceState(_ service: Services) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index].isActive.toggle()
            Logger.shared.log("Toggled service \(service.metadata.sourceName) to \(services[index].isActive ? "active" : "inactive")", type: "ServiceManager")
            
            let updatedServices = services
            services = updatedServices
        }
    }
    
    var activeServices: [Services] {
        return services.filter { $0.isActive }
    }
    
    // MARK: Search Methods
    func searchInActiveServices(query: String) async -> [(service: Services, results: [SearchItem])] {
        let activeServicesList = activeServices
        
        Logger.shared.log("Starting search for '\(query)' across \(activeServicesList.count) active services", type: "ServiceManager")
        
        guard !activeServicesList.isEmpty else {
            Logger.shared.log("No active services found for search", type: "ServiceManager")
            return []
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            downloadMessage = "Searching..."
        }
        
        var allResults: [(service: Services, results: [SearchItem])] = []
        let totalServices = activeServicesList.count
        
        for (index, service) in activeServicesList.enumerated() {
            let progress = Double(index) / Double(totalServices)
            await updateProgress(progress, "Searching \(service.metadata.sourceName)...")
            
            Logger.shared.log("Searching in service: \(service.metadata.sourceName)", type: "ServiceManager")
            
            let results = await searchInService(service: service, query: query)
            allResults.append((service: service, results: results))
            
            Logger.shared.log("Found \(results.count) results in \(service.metadata.sourceName)", type: "ServiceManager")
        }
        
        await MainActor.run {
            self.isDownloading = false
            self.downloadProgress = 0.0
            self.downloadMessage = ""
        }
        
        let totalResults = allResults.reduce(0) { $0 + $1.results.count }
        Logger.shared.log("Search completed: \(totalResults) total results from \(allResults.count) services", type: "ServiceManager")
        
        return allResults
    }
    
    private func searchInService(service: Services, query: String) async -> [SearchItem] {
        let jsController = JSController()
        
        let servicePath = servicesDirectory.appendingPathComponent(service.localPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        
        guard FileManager.default.fileExists(atPath: jsPath.path) else {
            Logger.shared.log("JavaScript file not found for service: \(service.metadata.sourceName)", type: "ServiceManager")
            return []
        }
        
        do {
            let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
            jsController.loadScript(jsContent)
            
            return await withCheckedContinuation { continuation in
                jsController.fetchJsSearchResults(keyword: query, module: service) { results in
                    continuation.resume(returning: results)
                }
            }
        } catch {
            Logger.shared.log("Failed to load JavaScript for service \(service.metadata.sourceName): \(error.localizedDescription)", type: "ServiceManager")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidJSONURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        
        return url.scheme != nil &&
        (url.pathExtension.lowercased() == "json" ||
         text.lowercased().contains(".json"))
    }
    
    private func downloadAndParseMetadata(from urlString: String) async throws -> ServicesMetadata {
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.custom.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.downloadFailed
        }
        
        do {
            let metadata = try JSONDecoder().decode(ServicesMetadata.self, from: data)
            return metadata
        } catch {
            throw ServiceError.invalidJSON
        }
    }
    
    private func downloadJavaScript(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidScriptURL
        }
        
        let (data, response) = try await URLSession.custom.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.scriptDownloadFailed
        }
        
        guard let jsContent = String(data: data, encoding: .utf8) else {
            throw ServiceError.invalidScriptContent
        }
        
        return jsContent
    }
    
    private func saveService(metadata: ServicesMetadata, jsContent: String, metadataUrl: String) async throws -> Services {
        let serviceId = UUID()
        let serviceFolderName = "\(metadata.sourceName.replacingOccurrences(of: " ", with: "_"))_\(serviceId.uuidString.prefix(8))"
        let servicePath = servicesDirectory.appendingPathComponent(serviceFolderName)
        try FileManager.default.createDirectory(at: servicePath, withIntermediateDirectories: true)
        
        let jsonData = try JSONEncoder().encode(metadata)
        let jsonPath = servicePath.appendingPathComponent("metadata.json")
        try jsonData.write(to: jsonPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        try jsContent.write(to: jsPath, atomically: true, encoding: .utf8)
        
        let service = Services(
            id: serviceId,
            metadata: metadata,
            localPath: serviceFolderName,
            metadataUrl: metadataUrl,
            isActive: false
        )
        
        return service
    }
    
    private func createServicesDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: servicesDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: servicesDirectory, withIntermediateDirectories: true)
                Logger.shared.log("Created Services directory", type: "ServiceManager")
            } catch {
                Logger.shared.log("Failed to create Services directory: \(error.localizedDescription)", type: "ServiceManager")
            }
        }
    }
    
    private func loadExistingServices() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: servicesDirectory, includingPropertiesForKeys: nil)
            
            for folder in contents where folder.hasDirectoryPath {
                if let service = loadService(from: folder) {
                    services.append(service)
                }
            }
            
            Logger.shared.log("Loaded \(services.count) existing services", type: "ServiceManager")
        } catch {
            Logger.shared.log("Failed to load existing services: \(error.localizedDescription)", type: "ServiceManager")
        }
    }
    
    private func loadService(from folderURL: URL) -> Services? {
        let metadataPath = folderURL.appendingPathComponent("metadata.json")
        
        guard FileManager.default.fileExists(atPath: metadataPath.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: metadataPath)
            let metadata = try JSONDecoder().decode(ServicesMetadata.self, from: data)
            
            return Services(
                metadata: metadata,
                localPath: folderURL.lastPathComponent,
                metadataUrl: "",
                isActive: false
            )
        } catch {
            Logger.shared.log("Failed to load service from \(folderURL.lastPathComponent): \(error.localizedDescription)", type: "ServiceManager")
            return nil
        }
    }
    
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            self.downloadProgress = progress
            self.downloadMessage = message
        }
    }
}

// MARK: - Service Errors

enum ServiceError: LocalizedError {
    case invalidURL
    case invalidScriptURL
    case downloadFailed
    case scriptDownloadFailed
    case invalidJSON
    case invalidScriptContent
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidScriptURL:
            return "Invalid script URL in metadata"
        case .downloadFailed:
            return "Failed to download metadata"
        case .scriptDownloadFailed:
            return "Failed to download JavaScript file"
        case .invalidJSON:
            return "Invalid JSON format"
        case .invalidScriptContent:
            return "Invalid JavaScript content"
        case .saveFailed:
            return "Failed to save service files"
        }
    }
}

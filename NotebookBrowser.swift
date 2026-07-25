//
//  NotebookBrowser.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import Foundation
import Observation

/// Observable model for browsing and managing notebooks and folders.
/// This uses the real filesystem — the Files app structure IS the organization system.
@Observable
final class NotebookBrowser {
    
    // MARK: - Properties
    
    /// Current directory being browsed
    private(set) var currentDirectory: URL
    
    /// Items (folders and notebooks) in the current directory
    private(set) var items: [BrowserItem] = []
    
    /// Error to display if operations fail
    var errorMessage: String?
    
    // MARK: - Initialization
    
    init() {
        // Use Documents directory for Files app visibility
        self.currentDirectory = Self.documentsDirectory
        loadItems()
    }
    
    // MARK: - Documents Directory
    
    /// The app's Documents directory (visible in Files app with proper Info.plist keys)
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Navigation
    
    /// Navigate into a folder
    func navigateInto(folder: URL) {
        currentDirectory = folder
        loadItems()
    }
    
    /// Navigate up one level (if not already at root)
    func navigateUp() {
        let parent = currentDirectory.deletingLastPathComponent()
        // Only navigate up if we're not already at documents root
        if currentDirectory != Self.documentsDirectory {
            currentDirectory = parent
            loadItems()
        }
    }
    
    /// Whether we can navigate up (i.e., not at root)
    var canNavigateUp: Bool {
        currentDirectory != Self.documentsDirectory
    }
    
    // MARK: - Loading Items
    
    /// Reload items in current directory
    func loadItems() {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: currentDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            var folders: [BrowserItem] = []
            var notebooks: [BrowserItem] = []
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = resourceValues.isDirectory ?? false
                
                if url.pathExtension == "notebook" {
                    // It's a notebook bundle
                    notebooks.append(BrowserItem(url: url, type: .notebook))
                } else if isDirectory {
                    // It's a folder
                    folders.append(BrowserItem(url: url, type: .folder))
                }
            }
            
            // Sort: folders first (alphabetically), then notebooks (alphabetically)
            folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            notebooks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            self.items = folders + notebooks
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load items: \(error.localizedDescription)"
            self.items = []
        }
    }
    
    // MARK: - Create Operations
    
    /// Create a new folder in the current directory
    func createFolder(name: String) throws {
        let folderURL = currentDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        loadItems()
    }
    
    /// Create a new notebook in the current directory
    func createNotebook(name: String) throws {
        var notebookName = name
        if !notebookName.hasSuffix(".notebook") {
            notebookName += ".notebook"
        }
        
        let notebookURL = currentDirectory.appendingPathComponent(notebookName)
        
        // Create empty notebook using NotebookEngine
        let document = NotebookDocument(
            cells: [],
            metadata: NotebookMetadata(
                title: name,
                createdAt: Date(),
                modifiedAt: Date()
            ),
            links: []
        )
        
        try NotebookEngine.createNotebook(at: notebookURL, document: document)
        loadItems()
    }
    
    // MARK: - Delete Operation
    
    /// Delete a folder or notebook
    func delete(item: BrowserItem) throws {
        try FileManager.default.removeItem(at: item.url)
        loadItems()
    }
    
    // MARK: - Rename Operation
    
    /// Rename a folder or notebook
    func rename(item: BrowserItem, to newName: String) throws {
        var finalName = newName
        
        // Preserve .notebook extension for notebooks
        if item.type == .notebook && !finalName.hasSuffix(".notebook") {
            finalName += ".notebook"
        }
        
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(finalName)
        try FileManager.default.moveItem(at: item.url, to: newURL)
        
        // If it's a notebook, update its metadata title too
        if item.type == .notebook {
            do {
                var document = try NotebookEngine.loadNotebook(from: newURL)
                document.metadata.title = newName.replacingOccurrences(of: ".notebook", with: "")
                document.metadata.modifiedAt = Date()
                try NotebookEngine.saveNotebook(document, to: newURL)
            } catch {
                // Non-fatal: the rename succeeded, just couldn't update metadata
                print("Warning: renamed notebook but couldn't update metadata: \(error)")
            }
        }
        
        loadItems()
    }
    
    // MARK: - Move Operation
    
    /// Move a folder or notebook to a different directory
    func move(item: BrowserItem, to destinationDirectory: URL) throws {
        let destinationURL = destinationDirectory.appendingPathComponent(item.url.lastPathComponent)
        try FileManager.default.moveItem(at: item.url, to: destinationURL)
        loadItems()
    }
}

// MARK: - Browser Item

/// Represents a folder or notebook in the browser
struct BrowserItem: Identifiable, Equatable {
    let url: URL
    let type: ItemType
    
    var id: URL { url }
    
    var name: String {
        if type == .notebook {
            // Remove .notebook extension for display
            return url.deletingPathExtension().lastPathComponent
        }
        return url.lastPathComponent
    }
    
    enum ItemType {
        case folder
        case notebook
    }
}

//
//  NotebookEngine.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import Foundation

/// Engine for persisting and loading notebook bundles from disk.
/// Handles the manifest.json + cells/ + assets/ bundle format.
struct NotebookEngine {
    
    // MARK: - Bundle Structure
    
    private static let manifestFilename = "manifest.json"
    private static let cellsDirectoryName = "cells"
    private static let assetsDirectoryName = "assets"
    
    // MARK: - Errors
    
    enum NotebookError: Error, LocalizedError {
        case bundleNotFound
        case manifestReadFailed(Error)
        case manifestWriteFailed(Error)
        case cellContentReadFailed(String, Error)
        case cellContentWriteFailed(String, Error)
        case invalidBundleStructure
        
        var errorDescription: String? {
            switch self {
            case .bundleNotFound:
                return "Notebook bundle not found"
            case .manifestReadFailed(let error):
                return "Failed to read manifest: \(error.localizedDescription)"
            case .manifestWriteFailed(let error):
                return "Failed to write manifest: \(error.localizedDescription)"
            case .cellContentReadFailed(let filename, let error):
                return "Failed to read cell content '\(filename)': \(error.localizedDescription)"
            case .cellContentWriteFailed(let filename, let error):
                return "Failed to write cell content '\(filename)': \(error.localizedDescription)"
            case .invalidBundleStructure:
                return "Invalid notebook bundle structure"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Create a new notebook bundle at the specified URL.
    /// - Parameters:
    ///   - bundleURL: URL ending in .notebook where the bundle will be created
    ///   - document: The notebook document to save
    /// - Throws: NotebookError if creation fails
    static func createNotebook(at bundleURL: URL, document: NotebookDocument) throws {
        let fileManager = FileManager.default
        
        // Create bundle directory
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        
        // Create cells/ and assets/ subdirectories
        let cellsURL = bundleURL.appendingPathComponent(cellsDirectoryName)
        let assetsURL = bundleURL.appendingPathComponent(assetsDirectoryName)
        try fileManager.createDirectory(at: cellsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        
        // Save the document
        try saveNotebook(document, to: bundleURL)
    }
    
    /// Save a notebook document to an existing bundle.
    /// - Parameters:
    ///   - document: The notebook document to save
    ///   - bundleURL: URL of the .notebook bundle
    /// - Throws: NotebookError if save fails
    static func saveNotebook(_ document: NotebookDocument, to bundleURL: URL) throws {
        // Write manifest.json
        let manifestURL = bundleURL.appendingPathComponent(manifestFilename)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)
            try data.write(to: manifestURL)
        } catch {
            throw NotebookError.manifestWriteFailed(error)
        }
    }
    
    /// Load a notebook document from a bundle.
    /// - Parameter bundleURL: URL of the .notebook bundle
    /// - Returns: The loaded notebook document
    /// - Throws: NotebookError if loading fails
    static func loadNotebook(from bundleURL: URL) throws -> NotebookDocument {
        let fileManager = FileManager.default
        
        // Verify bundle exists
        guard fileManager.fileExists(atPath: bundleURL.path) else {
            throw NotebookError.bundleNotFound
        }
        
        // Read manifest.json
        let manifestURL = bundleURL.appendingPathComponent(manifestFilename)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw NotebookError.invalidBundleStructure
        }
        
        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(NotebookDocument.self, from: data)
            return document
        } catch {
            throw NotebookError.manifestReadFailed(error)
        }
    }
    
    /// Write cell content to the cells/ directory.
    /// - Parameters:
    ///   - content: The content data to write
    ///   - filename: The filename within cells/ (e.g., "cell-01.md")
    ///   - bundleURL: URL of the .notebook bundle
    /// - Throws: NotebookError if write fails
    static func writeCellContent(_ content: Data, filename: String, to bundleURL: URL) throws {
        let cellsURL = bundleURL.appendingPathComponent(cellsDirectoryName)
        let fileURL = cellsURL.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL)
        } catch {
            throw NotebookError.cellContentWriteFailed(filename, error)
        }
    }
    
    /// Read cell content from the cells/ directory.
    /// - Parameters:
    ///   - filename: The filename within cells/ (e.g., "cell-01.md")
    ///   - bundleURL: URL of the .notebook bundle
    /// - Returns: The cell content data
    /// - Throws: NotebookError if read fails
    static func readCellContent(filename: String, from bundleURL: URL) throws -> Data {
        let cellsURL = bundleURL.appendingPathComponent(cellsDirectoryName)
        let fileURL = cellsURL.appendingPathComponent(filename)
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw NotebookError.cellContentReadFailed(filename, error)
        }
    }
    
    /// Delete a notebook bundle from disk.
    /// - Parameter bundleURL: URL of the .notebook bundle to delete
    /// - Throws: Error if deletion fails
    static func deleteNotebook(at bundleURL: URL) throws {
        try FileManager.default.removeItem(at: bundleURL)
    }
}

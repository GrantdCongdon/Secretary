//
//  NotebookEditor.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import Foundation
import Observation
import PDFKit
import PencilKit

/// Observable model for editing a notebook's cells.
/// Manages cell CRUD operations and persistence via NotebookEngine.
@Observable
final class NotebookEditor {
    
    // MARK: - Properties
    
    /// The notebook being edited
    private(set) var document: NotebookDocument
    
    /// URL of the notebook bundle on disk
    let notebookURL: URL
    
    /// Error message to display if operations fail
    var errorMessage: String?
    
    /// Cached PDF documents by cell ID (loaded once, shared between views)
    private var pdfDocumentCache: [UUID: PDFDocument] = [:]
    
    /// Cached PencilKit drawings by cell ID (loaded once, shared between views)
    private var drawingCache: [UUID: PKDrawing] = [:]
    
    // MARK: - Initialization
    
    init(notebookURL: URL) throws {
        self.notebookURL = notebookURL
        self.document = try NotebookEngine.loadNotebook(from: notebookURL)
    }
    
    // MARK: - Computed Properties
    
    /// The ordered list of cells
    var cells: [Cell] {
        document.cells
    }
    
    /// The notebook's title
    var title: String {
        document.metadata.title
    }
    
    // MARK: - Cell Operations
    
    /// Add a new cell of the specified type
    func addCell(type: CellType) {
        let cellNumber = document.cells.count + 1
        let paddedNumber = String(format: "%02d", cellNumber)
        
        let filename: String
        switch type {
        case .markdown:
            filename = "cell-\(paddedNumber).md"
        case .pdf:
            filename = "cell-\(paddedNumber).pdf"
        case .code:
            filename = "cell-\(paddedNumber).py"
        }
        
        let newCell = Cell(type: type, contentFilename: filename)
        document.cells.append(newCell)
        
        // Create empty content file for the cell
        let cellURL = notebookURL.appendingPathComponent("cells").appendingPathComponent(filename)
        do {
            try Data().write(to: cellURL)
        } catch {
            errorMessage = "Failed to create cell file: \(error.localizedDescription)"
        }
        
        save()
    }
    
    /// Remove a cell at the specified index
    func removeCell(at index: Int) {
        guard index >= 0 && index < document.cells.count else { return }
        
        let cell = document.cells[index]
        document.cells.remove(at: index)
        
        // Optionally delete the cell's content file from disk
        let cellURL = notebookURL.appendingPathComponent("cells").appendingPathComponent(cell.contentFilename)
        try? FileManager.default.removeItem(at: cellURL)
        
        save()
    }
    
    /// Move a cell from one position to another
    func moveCell(from source: IndexSet, to destination: Int) {
        // Convert IndexSet to array of indices and sort in reverse to safely remove
        let sortedIndices = source.sorted(by: >)
        
        // Extract cells to move
        var cellsToMove: [Cell] = []
        for index in sortedIndices {
            if index < document.cells.count {
                cellsToMove.insert(document.cells[index], at: 0)
            }
        }
        
        // Remove cells from original positions (in reverse order)
        for index in sortedIndices {
            if index < document.cells.count {
                document.cells.remove(at: index)
            }
        }
        
        // Calculate adjusted destination (accounting for removed items)
        var adjustedDestination = destination
        for index in sortedIndices {
            if index < destination {
                adjustedDestination -= 1
            }
        }
        
        // Insert cells at new position
        document.cells.insert(contentsOf: cellsToMove, at: adjustedDestination)
        
        save()
    }
    
    /// Update metadata for a specific cell
    func updateCellMetadata(cellID: UUID, metadata: [String: String]) {
        guard let index = document.cells.firstIndex(where: { $0.id == cellID }) else { return }
        var cell = document.cells[index]
        cell.metadata = metadata
        document.cells[index] = cell
        save()
    }
    
    // MARK: - PDF Document and Drawing Cache
    
    /// Get or load PDF document for a cell
    func pdfDocument(for cell: Cell) -> PDFDocument? {
        // Return cached if available
        if let cached = pdfDocumentCache[cell.id] {
            return cached
        }
        
        // Load from disk
        do {
            let data = try NotebookEngine.readCellContent(filename: cell.contentFilename, from: notebookURL)
            if let document = PDFDocument(data: data) {
                pdfDocumentCache[cell.id] = document
                return document
            }
        } catch {
            print("Failed to load PDF document: \(error)")
        }
        
        return nil
    }
    
    /// Get or load PencilKit drawing for a cell
    func drawing(for cell: Cell) -> PKDrawing {
        // Return cached if available
        if let cached = drawingCache[cell.id] {
            return cached
        }
        
        // Load from .ink sidecar file
        let inkFilename = cell.contentFilename.replacingOccurrences(of: ".pdf", with: ".ink")
        
        do {
            let data = try NotebookEngine.readCellContent(filename: inkFilename, from: notebookURL)
            if let drawing = try? PKDrawing(data: data) {
                drawingCache[cell.id] = drawing
                return drawing
            }
        } catch {
            // No ink file exists yet - this is normal for new cells
        }
        
        // Return empty drawing and cache it
        let emptyDrawing = PKDrawing()
        drawingCache[cell.id] = emptyDrawing
        return emptyDrawing
    }
    
    /// Update drawing for a cell and save to disk
    func updateDrawing(_ drawing: PKDrawing, for cell: Cell) {
        // Update cache
        drawingCache[cell.id] = drawing
        
        // Save to .ink sidecar file
        let inkFilename = cell.contentFilename.replacingOccurrences(of: ".pdf", with: ".ink")
        let drawingData = drawing.dataRepresentation()
        
        do {
            try NotebookEngine.writeCellContent(drawingData, filename: inkFilename, to: notebookURL)
        } catch {
            errorMessage = "Failed to save drawing: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Persistence
    
    /// Save the current document state to disk
    private func save() {
        do {
            document.metadata.modifiedAt = Date()
            try NotebookEngine.saveNotebook(document, to: notebookURL)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save notebook: \(error.localizedDescription)"
        }
    }
}

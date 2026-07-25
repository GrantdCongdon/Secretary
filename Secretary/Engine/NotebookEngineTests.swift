//
//  NotebookEngineTests.swift
//  SecretaryTests
//
//  Created by Grant Congdon on 7/25/26.
//

import Testing
import Foundation
@testable import Secretary

@Suite("Notebook Engine Round-Trip Tests")
struct NotebookEngineTests {
    
    /// Get a temporary directory for test notebooks
    private func temporaryNotebookURL() -> URL {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("TestNotebook-\(UUID().uuidString).notebook")
    }
    
    @Test("Create and load empty notebook")
    func emptyNotebookRoundTrip() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create a new empty notebook
        let originalDocument = NotebookDocument(
            cells: [],
            metadata: NotebookMetadata(title: "Empty Test Notebook"),
            links: []
        )
        
        // Save it
        try NotebookEngine.createNotebook(at: bundleURL, document: originalDocument)
        
        // Verify bundle structure exists
        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: bundleURL.path))
        #expect(fileManager.fileExists(atPath: bundleURL.appendingPathComponent("manifest.json").path))
        #expect(fileManager.fileExists(atPath: bundleURL.appendingPathComponent("cells").path))
        #expect(fileManager.fileExists(atPath: bundleURL.appendingPathComponent("assets").path))
        
        // Load it back
        let loadedDocument = try NotebookEngine.loadNotebook(from: bundleURL)
        
        // Verify round-trip fidelity
        #expect(loadedDocument.cells.count == 0)
        #expect(loadedDocument.metadata.title == "Empty Test Notebook")
        #expect(loadedDocument.links.isEmpty)
    }
    
    @Test("Create and load notebook with cells")
    func notebookWithCellsRoundTrip() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create a notebook with multiple cells
        let cell1 = Cell(type: .markdown, contentFilename: "cell-01.md")
        let cell2 = Cell(type: .pdf, contentFilename: "cell-02.pdf")
        let cell3 = Cell(type: .code, contentFilename: "cell-03.py")
        
        let originalDocument = NotebookDocument(
            cells: [cell1, cell2, cell3],
            metadata: NotebookMetadata(title: "Multi-Cell Notebook"),
            links: ["[[other-note]]", "[[another-note]]"]
        )
        
        // Save it
        try NotebookEngine.createNotebook(at: bundleURL, document: originalDocument)
        
        // Load it back
        let loadedDocument = try NotebookEngine.loadNotebook(from: bundleURL)
        
        // Verify round-trip fidelity
        #expect(loadedDocument.cells.count == 3)
        #expect(loadedDocument.cells[0].type == .markdown)
        #expect(loadedDocument.cells[0].contentFilename == "cell-01.md")
        #expect(loadedDocument.cells[1].type == .pdf)
        #expect(loadedDocument.cells[1].contentFilename == "cell-02.pdf")
        #expect(loadedDocument.cells[2].type == .code)
        #expect(loadedDocument.cells[2].contentFilename == "cell-03.py")
        #expect(loadedDocument.metadata.title == "Multi-Cell Notebook")
        #expect(loadedDocument.links.count == 2)
        #expect(loadedDocument.links.contains("[[other-note]]"))
        #expect(loadedDocument.links.contains("[[another-note]]"))
    }
    
    @Test("Cell content persistence")
    func cellContentRoundTrip() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create a notebook with a markdown cell
        let cell = Cell(type: .markdown, contentFilename: "cell-01.md")
        let document = NotebookDocument(
            cells: [cell],
            metadata: NotebookMetadata(title: "Content Test")
        )
        
        try NotebookEngine.createNotebook(at: bundleURL, document: document)
        
        // Write cell content
        let markdownContent = "# Hello World\n\nThis is a test markdown cell with **bold** and *italic*."
        let contentData = markdownContent.data(using: .utf8)!
        try NotebookEngine.writeCellContent(contentData, filename: "cell-01.md", to: bundleURL)
        
        // Read it back
        let loadedData = try NotebookEngine.readCellContent(filename: "cell-01.md", from: bundleURL)
        let loadedContent = String(data: loadedData, encoding: .utf8)
        
        // Verify round-trip
        #expect(loadedContent == markdownContent)
    }
    
    @Test("Multiple cell contents persistence")
    func multipleCellContentsRoundTrip() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create notebook with multiple cells
        let cells = [
            Cell(type: .markdown, contentFilename: "cell-01.md"),
            Cell(type: .markdown, contentFilename: "cell-02.md"),
            Cell(type: .code, contentFilename: "cell-03.py")
        ]
        let document = NotebookDocument(cells: cells, metadata: NotebookMetadata(title: "Multi-Content Test"))
        
        try NotebookEngine.createNotebook(at: bundleURL, document: document)
        
        // Write different content to each cell
        let content1 = "# First Cell\n\nMarkdown content here."
        let content2 = "# Second Cell\n\nMore markdown."
        let content3 = "print('Hello from Python')\nx = 42"
        
        try NotebookEngine.writeCellContent(content1.data(using: .utf8)!, filename: "cell-01.md", to: bundleURL)
        try NotebookEngine.writeCellContent(content2.data(using: .utf8)!, filename: "cell-02.md", to: bundleURL)
        try NotebookEngine.writeCellContent(content3.data(using: .utf8)!, filename: "cell-03.py", to: bundleURL)
        
        // Read all back
        let loaded1 = String(data: try NotebookEngine.readCellContent(filename: "cell-01.md", from: bundleURL), encoding: .utf8)
        let loaded2 = String(data: try NotebookEngine.readCellContent(filename: "cell-02.md", from: bundleURL), encoding: .utf8)
        let loaded3 = String(data: try NotebookEngine.readCellContent(filename: "cell-03.py", from: bundleURL), encoding: .utf8)
        
        // Verify all round-trips
        #expect(loaded1 == content1)
        #expect(loaded2 == content2)
        #expect(loaded3 == content3)
    }
    
    @Test("Cell metadata persistence")
    func cellMetadataRoundTrip() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create a cell with custom metadata
        let cell = Cell(
            type: .pdf,
            contentFilename: "cell-01.pdf",
            metadata: ["author": "Grant", "version": "1.0"]
        )
        
        let document = NotebookDocument(
            cells: [cell],
            metadata: NotebookMetadata(title: "Metadata Test")
        )
        
        try NotebookEngine.createNotebook(at: bundleURL, document: document)
        
        // Load and verify metadata survived
        let loaded = try NotebookEngine.loadNotebook(from: bundleURL)
        #expect(loaded.cells.count == 1)
        #expect(loaded.cells[0].metadata["author"] == "Grant")
        #expect(loaded.cells[0].metadata["version"] == "1.0")
    }
    
    @Test("Notebook metadata dates persistence")
    func metadataDatesRoundTrip() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create notebook with specific dates
        let createdDate = Date(timeIntervalSince1970: 1721865600) // 2024-07-25 00:00:00 UTC
        let modifiedDate = Date(timeIntervalSince1970: 1721952000) // 2024-07-26 00:00:00 UTC
        
        let metadata = NotebookMetadata(
            title: "Date Test",
            createdAt: createdDate,
            modifiedAt: modifiedDate
        )
        
        let document = NotebookDocument(metadata: metadata)
        try NotebookEngine.createNotebook(at: bundleURL, document: document)
        
        // Load and verify dates
        let loaded = try NotebookEngine.loadNotebook(from: bundleURL)
        
        // Compare timestamps (allowing small floating-point differences from JSON encoding)
        let createdDiff = abs(loaded.metadata.createdAt.timeIntervalSince1970 - createdDate.timeIntervalSince1970)
        let modifiedDiff = abs(loaded.metadata.modifiedAt.timeIntervalSince1970 - modifiedDate.timeIntervalSince1970)
        
        #expect(createdDiff < 1.0, "Created date should round-trip within 1 second")
        #expect(modifiedDiff < 1.0, "Modified date should round-trip within 1 second")
        #expect(loaded.metadata.title == "Date Test")
    }
    
    @Test("Update existing notebook")
    func updateNotebook() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create initial notebook
        var document = NotebookDocument(
            cells: [Cell(type: .markdown, contentFilename: "cell-01.md")],
            metadata: NotebookMetadata(title: "Original Title")
        )
        
        try NotebookEngine.createNotebook(at: bundleURL, document: document)
        
        // Modify and save again
        document.metadata.title = "Updated Title"
        document.cells.append(Cell(type: .pdf, contentFilename: "cell-02.pdf"))
        try NotebookEngine.saveNotebook(document, to: bundleURL)
        
        // Load and verify updates persisted
        let loaded = try NotebookEngine.loadNotebook(from: bundleURL)
        #expect(loaded.metadata.title == "Updated Title")
        #expect(loaded.cells.count == 2)
        #expect(loaded.cells[1].type == .pdf)
    }
    
    @Test("Cell ID persistence and uniqueness")
    func cellIDRoundTrip() throws {
        let bundleURL = temporaryNotebookURL()
        defer { try? NotebookEngine.deleteNotebook(at: bundleURL) }
        
        // Create cells with explicit IDs
        let id1 = UUID()
        let id2 = UUID()
        let cell1 = Cell(id: id1, type: .markdown, contentFilename: "cell-01.md")
        let cell2 = Cell(id: id2, type: .pdf, contentFilename: "cell-02.pdf")
        
        let document = NotebookDocument(
            cells: [cell1, cell2],
            metadata: NotebookMetadata(title: "ID Test")
        )
        
        try NotebookEngine.createNotebook(at: bundleURL, document: document)
        
        // Load and verify IDs preserved
        let loaded = try NotebookEngine.loadNotebook(from: bundleURL)
        #expect(loaded.cells[0].id == id1)
        #expect(loaded.cells[1].id == id2)
        #expect(loaded.cells[0].id != loaded.cells[1].id, "Cell IDs should be unique")
    }
}

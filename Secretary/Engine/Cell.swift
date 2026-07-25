//
//  Cell.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import Foundation

/// A single cell within a notebook. Plain Swift type, no UI framework imports.
struct Cell: Codable, Identifiable, Equatable, Hashable {
    /// Unique identifier for this cell.
    let id: UUID
    
    /// The type of content this cell contains.
    let type: CellType
    
    /// The filename (within cells/) where this cell's content is stored.
    /// e.g., "cell-01.md", "cell-02.pdf"
    let contentFilename: String
    
    /// Optional metadata specific to this cell (reserved for future use).
    var metadata: [String: String]
    
    init(id: UUID = UUID(), type: CellType, contentFilename: String, metadata: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.contentFilename = contentFilename
        self.metadata = metadata
    }
}

/// The type of content a cell can contain.
enum CellType: String, Codable, Equatable, Hashable {
    /// Markdown + LaTeX cell (stored as .md)
    case markdown
    
    /// PDF cell with optional annotation layer (stored as .pdf + optional .ink sidecar)
    case pdf
    
    /// Python code cell (stored as .py + .out.json for output)
    case code
}

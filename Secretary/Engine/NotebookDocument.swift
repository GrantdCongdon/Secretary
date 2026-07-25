//
//  NotebookDocument.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import Foundation

/// A notebook document. Plain Swift type that manages the bundle format on disk.
/// No SwiftUI/UIKit imports — this is the framework-agnostic model layer.
struct NotebookDocument: Codable, Equatable {
    /// Ordered list of cells in this notebook.
    var cells: [Cell]
    
    /// Metadata about this notebook (title, creation date, etc.)
    var metadata: NotebookMetadata
    
    /// Cross-note links parsed from markdown cells (reserved for future sessions).
    var links: [String]
    
    init(cells: [Cell] = [], metadata: NotebookMetadata = NotebookMetadata(), links: [String] = []) {
        self.cells = cells
        self.metadata = metadata
        self.links = links
    }
}

/// Metadata for a notebook.
struct NotebookMetadata: Codable, Equatable {
    /// User-visible title of the notebook.
    var title: String
    
    /// When this notebook was created.
    var createdAt: Date
    
    /// Last modification time.
    var modifiedAt: Date
    
    init(title: String = "Untitled Notebook", createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

//
//  NotebookEditorView.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import SwiftUI
import UniformTypeIdentifiers
// MARK: - Notebook Editor View

/// View for editing a notebook's cells.
/// Displays cells as an ordered, scrollable vertical list in their minimized state.
struct NotebookEditorView: View {
    @State private var editor: NotebookEditor
    @State private var showingAddCellMenu = false
    @State private var selectedCell: Cell?
    @State private var showingPDFImporter = false
    @Namespace private var cellNamespace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode
    
    init(notebookURL: URL) throws {
        let editor = try NotebookEditor(notebookURL: notebookURL)
        _editor = State(initialValue: editor)
    }
    
    /// Whether the list is currently in edit mode
    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }
    
    var body: some View {
        List {
            ForEach(Array(editor.cells.enumerated()), id: \.element.id) { index, cell in
                Group {
                    if isEditing {
                        // Edit mode: show compact view for all cell types
                        CellCompactView(cell: cell)
                    } else if cell.type == .pdf {
                        // Normal mode: PDF cells handle their own tap gesture
                        cellMinimizedView(for: cell, onTap: {
                            selectedCell = cell
                        })
                        .matchedTransitionSource(id: cell.id, in: cellNamespace)
                    } else {
                        // Normal mode: Other cells use Button wrapper
                        Button {
                            selectedCell = cell
                        } label: {
                            cellMinimizedView(for: cell, onTap: nil)
                                .matchedTransitionSource(id: cell.id, in: cellNamespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        editor.removeCell(at: index)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onMove { source, destination in
                editor.moveCell(from: source, to: destination)
            }
        }
        .navigationTitle(editor.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCell) { cell in
            cellMaximizedView(for: cell)
                .navigationTitle(cellTypeLabel(for: cell))
                .navigationBarTitleDisplayMode(.inline)
                .navigationTransition(.zoom(sourceID: cell.id, in: cellNamespace))
        }
        .fileImporter(
            isPresented: $showingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result: result)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editor.addCell(type: .markdown)
                    } label: {
                        Label("Markdown Cell", systemImage: "text.alignleft")
                    }
                    
                    Button {
                        showingPDFImporter = true
                    } label: {
                        Label("PDF Cell", systemImage: "doc.fill")
                    }
                    
                    Button {
                        editor.addCell(type: .code)
                    } label: {
                        Label("Code Cell", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } label: {
                    Label("Add Cell", systemImage: "plus")
                }
            }
        }
        .alert("Error", isPresented: .constant(editor.errorMessage != nil)) {
            Button("OK") {
                editor.errorMessage = nil
            }
        } message: {
            if let error = editor.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Helper
    
    private func cellTypeLabel(for cell: Cell) -> String {
        switch cell.type {
        case .markdown:
            return "Markdown Cell"
        case .pdf:
            return "PDF Cell"
        case .code:
            return "Code Cell"
        }
    }
    
    @ViewBuilder
    private func cellMinimizedView(for cell: Cell, onTap: (() -> Void)?) -> some View {
        switch cell.type {
        case .pdf:
            PDFCellMinimizedView(cell: cell, notebookURL: editor.notebookURL, editor: editor, onTap: onTap)
        default:
            CellPlaceholderView(cell: cell)
        }
    }
    
    @ViewBuilder
    private func cellMaximizedView(for cell: Cell) -> some View {
        switch cell.type {
        case .pdf:
            PDFCellMaximizedView(cell: cell, notebookURL: editor.notebookURL, editor: editor)
        default:
            CellPlaceholderMaximizedView(cell: cell)
        }
    }
    
    private func handlePDFImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Read PDF data from selected file
            guard url.startAccessingSecurityScopedResource() else {
                editor.errorMessage = "Failed to access PDF file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                
                // Create the cell first
                editor.addCell(type: .pdf)
                
                // Get the newly created cell (it's the last one)
                guard let newCell = editor.cells.last else { return }
                
                // Write the PDF data using NotebookEngine
                try NotebookEngine.writeCellContent(
                    data,
                    filename: newCell.contentFilename,
                    to: editor.notebookURL
                )
            } catch {
                editor.errorMessage = "Failed to import PDF: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            // User cancelled or error occurred
            print("PDF import cancelled or failed: \(error)")
        }
    }
}

// MARK: - Cell Placeholder View

/// Placeholder view for a cell, showing just its type for now.
/// Real content (PDF, markdown) comes in later sessions.
struct CellPlaceholderView: View {
    let cell: Cell
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon based on cell type
            Image(systemName: cellIcon)
                .font(.title2)
                .foregroundStyle(cellColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cellTypeLabel)
                    .font(.headline)
                
                Text(cell.contentFilename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var cellTypeLabel: String {
        switch cell.type {
        case .markdown:
            return "Markdown Cell"
        case .pdf:
            return "PDF Cell"
        case .code:
            return "Code Cell"
        }
    }
    
    private var cellIcon: String {
        switch cell.type {
        case .markdown:
            return "text.alignleft"
        case .pdf:
            return "doc.fill"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    private var cellColor: Color {
        switch cell.type {
        case .markdown:
            return .blue
        case .pdf:
            return .red
        case .code:
            return .green
        }
    }
}

// MARK: - Cell Compact View

/// Compact view for cells in edit/reorder mode.
/// Shared by all cell types regardless of their normal minimized appearance.
/// Shows just enough to identify the cell (icon + type + filename) at a fixed compact height.
struct CellCompactView: View {
    let cell: Cell
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon based on cell type
            Image(systemName: cellIcon)
                .font(.title2)
                .foregroundStyle(cellColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cellTypeLabel)
                    .font(.headline)
                
                Text(cell.contentFilename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var cellTypeLabel: String {
        switch cell.type {
        case .markdown:
            return "Markdown Cell"
        case .pdf:
            return "PDF Cell"
        case .code:
            return "Code Cell"
        }
    }
    
    private var cellIcon: String {
        switch cell.type {
        case .markdown:
            return "text.alignleft"
        case .pdf:
            return "doc.fill"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    private var cellColor: Color {
        switch cell.type {
        case .markdown:
            return .blue
        case .pdf:
            return .red
        case .code:
            return .green
        }
    }
}

// MARK: - Cell Placeholder Maximized View

/// Maximized (full-screen) placeholder view for a cell.
/// Shows the same content as minimized but larger, in a dedicated view.
/// Real PDF/markdown content will replace this in later sessions.
struct CellPlaceholderMaximizedView: View {
    let cell: Cell
    
    var body: some View {
        VStack(spacing: 24) {
            // Large icon
            Image(systemName: cellIcon)
                .font(.system(size: 80))
                .foregroundStyle(cellColor)
            
            VStack(spacing: 8) {
                Text(cellTypeLabel)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(cell.contentFilename)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Text("Maximized View")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var cellTypeLabel: String {
        switch cell.type {
        case .markdown:
            return "Markdown Cell"
        case .pdf:
            return "PDF Cell"
        case .code:
            return "Code Cell"
        }
    }
    
    private var cellIcon: String {
        switch cell.type {
        case .markdown:
            return "text.alignleft"
        case .pdf:
            return "doc.fill"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    private var cellColor: Color {
        switch cell.type {
        case .markdown:
            return .blue
        case .pdf:
            return .red
        case .code:
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        // Create a temporary notebook for preview
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Preview.notebook")
        let _ = try? NotebookEngine.createNotebook(
            at: tempURL,
            document: NotebookDocument(
                cells: [
                    Cell(type: .markdown, contentFilename: "cell-01.md"),
                    Cell(type: .pdf, contentFilename: "cell-02.pdf")
                ],
                metadata: NotebookMetadata(title: "Preview Notebook")
            )
        )
        
        return try! NotebookEditorView(notebookURL: tempURL)
    }
}

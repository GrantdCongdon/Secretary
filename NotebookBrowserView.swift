//
//  NotebookBrowserView.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import SwiftUI

/// Root browser view for navigating folders and notebooks.
/// This replaces the placeholder ContentView from Session 1.
struct NotebookBrowserView: View {
    @State private var browser = NotebookBrowser()
    @State private var showingCreateMenu = false
    @State private var showingCreateFolderAlert = false
    @State private var showingCreateNotebookAlert = false
    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var newItemName = ""
    @State private var itemToRename: BrowserItem?
    @State private var itemToDelete: BrowserItem?
    @State private var selectedNotebook: URL?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(browser.items) { item in
                    BrowserItemRow(item: item) {
                        handleItemTap(item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            itemToRename = item
                            newItemName = item.name
                            showingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle(browser.currentDirectory == NotebookBrowser.documentsDirectory ? "Secretary" : currentDirectoryName)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedNotebook) { notebookURL in
                if let editorView = try? NotebookEditorView(notebookURL: notebookURL) {
                    editorView
                } else {
                    Text("Failed to open notebook")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if browser.canNavigateUp {
                        Button {
                            browser.navigateUp()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingCreateNotebookAlert = true
                        } label: {
                            Label("New Notebook", systemImage: "book")
                        }
                        
                        Button {
                            showingCreateFolderAlert = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .alert("New Notebook", isPresented: $showingCreateNotebookAlert) {
                TextField("Notebook Name", text: $newItemName)
                Button("Cancel", role: .cancel) {
                    newItemName = ""
                }
                Button("Create") {
                    createNotebook()
                }
                .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a name for the new notebook.")
            }
            .alert("New Folder", isPresented: $showingCreateFolderAlert) {
                TextField("Folder Name", text: $newItemName)
                Button("Cancel", role: .cancel) {
                    newItemName = ""
                }
                Button("Create") {
                    createFolder()
                }
                .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a name for the new folder.")
            }
            .alert("Rename", isPresented: $showingRenameAlert) {
                TextField("New Name", text: $newItemName)
                Button("Cancel", role: .cancel) {
                    newItemName = ""
                    itemToRename = nil
                }
                Button("Rename") {
                    renameItem()
                }
                .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                if let item = itemToRename {
                    Text("Enter a new name for '\(item.name)'.")
                }
            }
            .alert("Delete", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    itemToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } message: {
                if let item = itemToDelete {
                    Text("Are you sure you want to delete '\(item.name)'? This action cannot be undone.")
                }
            }
            .alert("Error", isPresented: .constant(browser.errorMessage != nil)) {
                Button("OK") {
                    browser.errorMessage = nil
                }
            } message: {
                if let error = browser.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var currentDirectoryName: String {
        browser.currentDirectory.lastPathComponent
    }
    
    private func handleItemTap(_ item: BrowserItem) {
        switch item.type {
        case .folder:
            browser.navigateInto(folder: item.url)
        case .notebook:
            selectedNotebook = item.url
        }
    }
    
    private func createNotebook() {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        do {
            try browser.createNotebook(name: name)
            newItemName = ""
        } catch {
            browser.errorMessage = "Failed to create notebook: \(error.localizedDescription)"
        }
    }
    
    private func createFolder() {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        do {
            try browser.createFolder(name: name)
            newItemName = ""
        } catch {
            browser.errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }
    
    private func renameItem() {
        guard let item = itemToRename else { return }
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        do {
            try browser.rename(item: item, to: name)
            newItemName = ""
            itemToRename = nil
        } catch {
            browser.errorMessage = "Failed to rename: \(error.localizedDescription)"
        }
    }
    
    private func deleteItem() {
        guard let item = itemToDelete else { return }
        
        do {
            try browser.delete(item: item)
            itemToDelete = nil
        } catch {
            browser.errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}

// MARK: - Browser Item Row

struct BrowserItemRow: View {
    let item: BrowserItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.type == .folder ? "folder.fill" : "book.closed.fill")
                    .font(.title2)
                    .foregroundStyle(item.type == .folder ? .blue : .orange)
                    .frame(width: 32)
                
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if item.type == .folder {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NotebookBrowserView()
}

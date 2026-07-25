//
//  PDFCellView.swift
//  Secretary
//
//  Created by Grant Congdon on 7/25/26.
//

import SwiftUI
import PDFKit
import PencilKit

// MARK: - PDF View State

/// Represents the scroll and zoom state of a PDF view
struct PDFViewState: Codable, Equatable {
    var pageIndex: Int
    var normalizedOffsetX: Double  // 0.0 to 1.0
    var normalizedOffsetY: Double  // 0.0 to 1.0
    var scaleFactor: Double
    
    init(pageIndex: Int = 0, normalizedOffsetX: Double = 0, normalizedOffsetY: Double = 0, scaleFactor: Double = 1.0) {
        self.pageIndex = pageIndex
        self.normalizedOffsetX = normalizedOffsetX
        self.normalizedOffsetY = normalizedOffsetY
        self.scaleFactor = scaleFactor
    }
    
    /// Create from Cell metadata
    static func from(metadata: [String: String]) -> PDFViewState? {
        guard let pageIndexStr = metadata["pdfPageIndex"],
              let pageIndex = Int(pageIndexStr),
              let offsetXStr = metadata["pdfOffsetX"],
              let offsetX = Double(offsetXStr),
              let offsetYStr = metadata["pdfOffsetY"],
              let offsetY = Double(offsetYStr),
              let scaleStr = metadata["pdfScale"],
              let scale = Double(scaleStr) else {
            return nil
        }
        return PDFViewState(pageIndex: pageIndex, normalizedOffsetX: offsetX, normalizedOffsetY: offsetY, scaleFactor: scale)
    }
    
    /// Write to Cell metadata
    func toMetadata() -> [String: String] {
        return [
            "pdfPageIndex": String(pageIndex),
            "pdfOffsetX": String(normalizedOffsetX),
            "pdfOffsetY": String(normalizedOffsetY),
            "pdfScale": String(scaleFactor)
        ]
    }
}

// MARK: - PDF View Wrapper with Annotation Layer

/// UIViewRepresentable wrapper combining PDFView with PKCanvasView overlay
///
/// Architecture:
/// - PDFView for rendering PDF pages with scroll/zoom
/// - PKCanvasView overlaid for Apple Pencil annotations
/// - Canvas anchored to PDF coordinate space (not screen space)
/// - drawingPolicy = .pencilOnly so finger touches still scroll/zoom
///
/// Coordinate Anchoring:
/// - Canvas frame must track PDFView's page bounds as user scrolls/zooms
/// - Uses PDFView's page-to-view coordinate conversion
/// - Ensures ink stays attached to correct page location
struct PDFKitView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    let displayMode: DisplayMode
    @Binding var viewState: PDFViewState
    @Binding var drawing: PKDrawing
    var onTap: (() -> Void)?
    var onStateChange: ((PDFViewState) -> Void)?
    var onDrawingChange: ((PKDrawing) -> Void)?
    
    enum DisplayMode {
        case minimized  // Single page continuous, bounded, with annotations
        case maximized  // Scrollable multi-page with annotations
    }
    
    func makeUIView(context: Context) -> UIView {
        // Container view to hold both PDFView and PKCanvasView
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Set up PDFView
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.isUserInteractionEnabled = true
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Set up PKCanvasView
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .pencilOnly  // Only Apple Pencil draws, fingers scroll
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Configure based on display mode
        switch displayMode {
        case .minimized:
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
            pdfView.autoScales = false
            pdfView.maxScaleFactor = 4.0
            pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            
            // Add tap gesture for maximize
            if onTap != nil {
                let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
                tapGesture.delegate = context.coordinator
                containerView.addGestureRecognizer(tapGesture)
            }
            
        case .maximized:
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
            pdfView.autoScales = true
        }
        
        // Add views to container
        containerView.addSubview(pdfView)
        containerView.addSubview(canvasView)
        
        // Set frames
        pdfView.frame = containerView.bounds
        canvasView.frame = containerView.bounds
        
        // Store references in coordinator
        context.coordinator.pdfView = pdfView
        context.coordinator.canvasView = canvasView
        context.coordinator.containerView = containerView
        
        // Restore PDF state
        context.coordinator.restoreState(viewState, to: pdfView)
        
        // Set up scroll view delegation for state capture
        if let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.delegate = context.coordinator
            
            if displayMode == .minimized {
                scrollView.panGestureRecognizer.cancelsTouchesInView = false
                scrollView.panGestureRecognizer.delaysTouchesBegan = false
                if let pinchGesture = scrollView.pinchGestureRecognizer {
                    pinchGesture.cancelsTouchesInView = false
                }
            }
        }
        
        // Set up notifications for PDF page changes to update canvas alignment
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pdfViewPageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onStateChange = onStateChange
        context.coordinator.onDrawingChange = onDrawingChange
        
        // Update canvas drawing if it changed externally
        if let canvasView = context.coordinator.canvasView,
           canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            viewState: viewState,
            drawing: drawing,
            onTap: onTap,
            onStateChange: onStateChange,
            onDrawingChange: onDrawingChange
        )
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate, PKCanvasViewDelegate {
        weak var containerView: UIView?
        weak var pdfView: PDFView?
        weak var canvasView: PKCanvasView?
        
        var viewState: PDFViewState
        var drawing: PKDrawing
        let onTap: (() -> Void)?
        var onStateChange: ((PDFViewState) -> Void)?
        var onDrawingChange: ((PKDrawing) -> Void)?
        
        private var isRestoringState = false
        
        init(viewState: PDFViewState, drawing: PKDrawing, onTap: (() -> Void)?, onStateChange: ((PDFViewState) -> Void)?, onDrawingChange: ((PKDrawing) -> Void)?) {
            self.viewState = viewState
            self.drawing = drawing
            self.onTap = onTap
            self.onStateChange = onStateChange
            self.onDrawingChange = onDrawingChange
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            onTap?()
        }
        
        // Allow tap gesture to recognize simultaneously
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        // MARK: - PDF Page Change Notification
        
        @objc func pdfViewPageChanged(_ notification: Notification) {
            // Update canvas alignment when PDF page changes
            updateCanvasAlignment()
        }
        
        /// Update canvas frame to match current PDF page bounds in view coordinates
        private func updateCanvasAlignment() {
            guard let pdfView = pdfView,
                  let canvasView = canvasView,
                  let currentPage = pdfView.currentPage else { return }
            
            // Get the page's bounds in PDF coordinate space
            let pageBounds = currentPage.bounds(for: .mediaBox)
            
            // Convert to view coordinates (accounts for scroll position and zoom)
            let pageRectInView = pdfView.convert(pageBounds, from: currentPage)
            
            // Update canvas frame to match
            canvasView.frame = pageRectInView
        }
        
        // MARK: - State Management
        
        func restoreState(_ state: PDFViewState, to pdfView: PDFView) {
            guard let document = pdfView.document else { return }
            
            isRestoringState = true
            defer { isRestoringState = false }
            
            let pageIndex = min(state.pageIndex, document.pageCount - 1)
            if let page = document.page(at: pageIndex) {
                pdfView.go(to: page)
                pdfView.scaleFactor = state.scaleFactor
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak pdfView] in
                    guard let pdfView = pdfView,
                          let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else { return }
                    
                    let contentSize = scrollView.contentSize
                    let offsetX = state.normalizedOffsetX * (contentSize.width - scrollView.bounds.width)
                    let offsetY = state.normalizedOffsetY * (contentSize.height - scrollView.bounds.height)
                    
                    let clampedX = max(0, min(offsetX, contentSize.width - scrollView.bounds.width))
                    let clampedY = max(0, min(offsetY, contentSize.height - scrollView.bounds.height))
                    
                    scrollView.contentOffset = CGPoint(x: clampedX, y: clampedY)
                    
                    // Update canvas alignment after scroll restore
                    self.updateCanvasAlignment()
                }
            }
        }
        
        func captureState(from pdfView: PDFView) -> PDFViewState {
            guard let document = pdfView.document,
                  let currentPage = pdfView.currentPage,
                  let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
                return viewState
            }
            
            let pageIndex = document.index(for: currentPage)
            let contentSize = scrollView.contentSize
            let offset = scrollView.contentOffset
            
            let normalizedX = contentSize.width > scrollView.bounds.width
                ? offset.x / (contentSize.width - scrollView.bounds.width)
                : 0
            let normalizedY = contentSize.height > scrollView.bounds.height
                ? offset.y / (contentSize.height - scrollView.bounds.height)
                : 0
            
            return PDFViewState(
                pageIndex: pageIndex,
                normalizedOffsetX: max(0, min(1, normalizedX)),
                normalizedOffsetY: max(0, min(1, normalizedY)),
                scaleFactor: pdfView.scaleFactor
            )
        }
        
        // MARK: - UIScrollViewDelegate
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isRestoringState, let pdfView = pdfView else { return }
            
            // Update canvas alignment as user scrolls
            updateCanvasAlignment()
            
            // Capture and save state
            let newState = captureState(from: pdfView)
            viewState = newState
            onStateChange?(newState)
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard !isRestoringState, let pdfView = pdfView else { return }
            
            // Update canvas alignment as user zooms
            updateCanvasAlignment()
            
            // Capture and save state
            let newState = captureState(from: pdfView)
            viewState = newState
            onStateChange?(newState)
        }
        
        // MARK: - PKCanvasViewDelegate
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
            onDrawingChange?(canvasView.drawing)
        }
    }
}

// MARK: - PDF Cell Minimized View

/// Minimized view for a PDF cell with PencilKit annotation layer
struct PDFCellMinimizedView: View {
    let cell: Cell
    let notebookURL: URL
    let editor: NotebookEditor
    var onTap: (() -> Void)?
    
    @State private var pdfDocument: PDFDocument?
    @State private var viewState: PDFViewState
    @State private var drawing: PKDrawing
    
    init(cell: Cell, notebookURL: URL, editor: NotebookEditor, onTap: (() -> Void)? = nil) {
        self.cell = cell
        self.notebookURL = notebookURL
        self.editor = editor
        self.onTap = onTap
        
        // Initialize state from cell metadata or default
        _viewState = State(initialValue: PDFViewState.from(metadata: cell.metadata) ?? PDFViewState())
        _drawing = State(initialValue: PKDrawing())  // Will be loaded in loadDrawing()
    }
    
    var body: some View {
        Group {
            if let pdfDocument {
                GeometryReader { geometry in
                    PDFKitView(
                        pdfDocument: pdfDocument,
                        displayMode: .minimized,
                        viewState: $viewState,
                        drawing: $drawing,
                        onTap: onTap,
                        onStateChange: { newState in
                            handleStateChange(newState)
                        },
                        onDrawingChange: { newDrawing in
                            handleDrawingChange(newDrawing)
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .frame(height: calculateCellHeight(for: pdfDocument))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Fallback while loading or if PDF fails to load
                CellPlaceholderView(cell: cell)
            }
        }
        .task {
            await loadPDF()
            await loadDrawing()
        }
    }
    
    /// Calculate cell height to show approximately one page at the list's width
    private func calculateCellHeight(for document: PDFDocument) -> CGFloat {
        guard let page = document.page(at: 0) else { return 400 }
        let pageRect = page.bounds(for: .mediaBox)
        let aspectRatio = pageRect.height / pageRect.width
        let estimatedWidth: CGFloat = 400
        return estimatedWidth * aspectRatio
    }
    
    private func loadPDF() async {
        do {
            let data = try NotebookEngine.readCellContent(filename: cell.contentFilename, from: notebookURL)
            if let document = PDFDocument(data: data) {
                await MainActor.run {
                    self.pdfDocument = document
                }
            }
        } catch {
            print("Failed to load PDF: \(error)")
        }
    }
    
    private func loadDrawing() async {
        // Construct .ink sidecar filename from PDF filename
        let inkFilename = cell.contentFilename.replacingOccurrences(of: ".pdf", with: ".ink")
        
        do {
            let data = try NotebookEngine.readCellContent(filename: inkFilename, from: notebookURL)
            if let loadedDrawing = try? PKDrawing(data: data) {
                await MainActor.run {
                    self.drawing = loadedDrawing
                }
            }
        } catch {
            // No ink file exists yet, or failed to load - use empty drawing
            print("No ink file or failed to load (this is normal for new cells): \(error)")
        }
    }
    
    private func handleStateChange(_ newState: PDFViewState) {
        viewState = newState
        editor.updateCellMetadata(cellID: cell.id, metadata: newState.toMetadata())
    }
    
    private func handleDrawingChange(_ newDrawing: PKDrawing) {
        drawing = newDrawing
        
        // Save drawing to .ink sidecar file
        let inkFilename = cell.contentFilename.replacingOccurrences(of: ".pdf", with: ".ink")
        let drawingData = newDrawing.dataRepresentation()
        
        do {
            try NotebookEngine.writeCellContent(drawingData, filename: inkFilename, to: notebookURL)
        } catch {
            print("Failed to save drawing: \(error)")
        }
    }
}

// MARK: - PDF Cell Maximized View

/// Maximized view for a PDF cell - full scrollable PDF viewer with persistent scroll/zoom state
struct PDFCellMaximizedView: View {
    let cell: Cell
    let notebookURL: URL
    let editor: NotebookEditor
    
    @State private var pdfDocument: PDFDocument?
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var viewState: PDFViewState
    
    init(cell: Cell, notebookURL: URL, editor: NotebookEditor) {
        self.cell = cell
        self.notebookURL = notebookURL
        self.editor = editor
        
        // Initialize state from cell metadata or default
        _viewState = State(initialValue: PDFViewState.from(metadata: cell.metadata) ?? PDFViewState())
    }
    
    var body: some View {
        Group {
            if let pdfDocument {
                PDFKitView(
                    pdfDocument: pdfDocument,
                    displayMode: .maximized,
                    viewState: $viewState,
                    onStateChange: { newState in
                        handleStateChange(newState)
                    }
                )
            } else {
                // Fallback while loading
                ProgressView("Loading PDF...")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if pdfDocument != nil {
                    Button {
                        exportPDF()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .task {
            await loadPDF()
        }
    }
    
    private func loadPDF() async {
        do {
            let data = try NotebookEngine.readCellContent(filename: cell.contentFilename, from: notebookURL)
            if let document = PDFDocument(data: data) {
                await MainActor.run {
                    self.pdfDocument = document
                }
            }
        } catch {
            print("Failed to load PDF: \(error)")
        }
    }
    
    private func exportPDF() {
        do {
            // Read the PDF data directly (no re-encoding)
            let data = try NotebookEngine.readCellContent(filename: cell.contentFilename, from: notebookURL)
            
            // Write to temporary file for sharing
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(cell.contentFilename)
            try data.write(to: tempURL)
            
            exportURL = tempURL
            showingExportSheet = true
        } catch {
            print("Failed to export PDF: \(error)")
        }
    }
    
    private func handleStateChange(_ newState: PDFViewState) {
        viewState = newState
        // Persist to cell metadata
        editor.updateCellMetadata(cellID: cell.id, metadata: newState.toMetadata())
    }
}

// MARK: - Share Sheet

/// UIActivityViewController wrapper for sharing files
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

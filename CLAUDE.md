# Project: Secretary

## One-paragraph description
Secretary is an iPadOS notetaking app that combines Notability-style PDF
annotation with a Jupyter-notebook-style cell system. Notes are documents
made of cells: PDF cells (import/annotate PDFs and templates with Apple
Pencil) and Markdown+LaTeX cells (math/circuitikz-focused), with Python code
cells as a P1 addition. Notes live in a nested folder structure with
Obsidian-style cross-note linking. Target platform is iPadOS 26/27+, built
with Xcode 27, Swift, and SwiftUI. Built primarily for personal/solo use —
optimize for what makes the app good to use daily, not for scale, multi-user
concerns, or App Store polish beyond what's needed to run well.

---

## Architecture

**Pattern: MV (Observation framework) + a plain-Swift Document/Engine layer.**
Do not introduce a ViewModel-per-screen convention and do not introduce TCA.

- `NotebookDocument` and `Cell` types are plain Swift, framework-agnostic
  (no SwiftUI/UIKit imports). This layer owns cell ordering, undo/redo,
  persistence, and cross-cell recomputation (e.g. markdown cell rendering,
  code cell execution results).
- SwiftUI views are thin: `@Observable` model objects feed views directly.
  Only introduce a ViewModel for a specific screen if it has genuinely
  non-trivial async/validation logic — state that reason in the file if you do.
- Treat the cell engine like a small text-editor "buffer" model: correctness
  and testability there matter more than in view code, so write unit tests
  against `NotebookDocument`/`Cell` directly, without rendering UI.

**Storage: file-based notebook bundles, not a database.**
Each notebook is a folder/package on disk, not a Core Data or SQLite blob.
This is deliberate — it's what makes Obsidian-style linking, universal
backup, and PDF export "free" instead of special-cased features.

```
MyNotebook.notebook/
  manifest.json        # cell order, cell types, metadata, links
  cells/
    cell-01.md          # markdown/LaTeX cell source
    cell-02.pdf          # PDF cell: the annotated PDF itself
    cell-02.ink          # PDF cell: editable PencilKit strokes (sidecar)
    cell-03.py            # code cell source
    cell-03.out.json     # code cell last output (immutable, regenerated)
  assets/
    img-01.png
```

- v1 storage location: local app sandbox / on-device only, exposed to the
  Files app so folders and files are directly visible and exportable
  (no iCloud/CloudKit sync in v1 — that's an explicit non-goal for now,
  see below).
- Folder hierarchy in the Files app *is* the notebook organization system —
  don't build a separate in-app-only folder abstraction.
- Cross-note links: parse `[[note-name]]`-style links out of markdown cell
  source at index time, maintain a lightweight link graph (in-memory,
  rebuilt from files on launch, optionally cached). Date-proximity
  color-coding (Obsidian-style) reads file creation/modified dates directly
  — no separate metadata database needed for v1.

---

## Cell view states

Every cell (PDF or markdown) has three view states:

- **Minimized (embedded)**: the cell renders inline as part of the
  note-wide scroll, alongside all other cells. Content is viewable and
  editable here, but bounded to the cell's natural size (e.g. a PDF cell's
  actual page dimensions) — no unbounded growth in this state.
- **Maximized (expanded)**: a dedicated full-editing view for a single
  cell. This is where the unbounded/ever-expanding writing surface applies
  for PDF cells — you can write past any edge without hitting a boundary.
- **Compact (edit mode)**: see "Edit-mode compact state" below.

The note-wide view itself is always a **vertically-ordered, scrollable list
of cells** in their minimized state, not a freeform 2D canvas — both PDF
and markdown cells scroll through in this note-wide view like any other
list content. "Unbounded canvas" refers only to a PDF cell's maximized
view, never to the notebook layout as a whole.

**Presentation mechanism: `NavigationStack` + `navigationDestination` push
navigation. Never `.sheet()`, `.fullScreenCover()`, or any other modal
presentation for the minimize/maximize transition.**

- Opening a cell **pushes** a full-screen page onto the stack — it is not
  a floating modal, card, or popover.
- **Back button, top-left.** Not a "Done"/"Close" button top-right — that's
  modal-presentation convention and doesn't apply here.
- Returning to minimized uses the standard **swipe-from-the-left-screen-
  edge-to-go-back** gesture (`interactivePopGestureRecognizer`), which
  push navigation gives for free. Do not hand-build a custom edge-swipe
  gesture, and do not add a swipe-down-to-dismiss gesture — that's sheet
  behavior and shouldn't exist on this screen at all.
- This was a real bug in Session 5 (sheet presentation caused a stuck
  "Done" button, a competing dismiss-gesture glitch, and a centered-card
  layout instead of a full page) — if a future session's maximize/minimize
  behavior looks similar to any of those three symptoms, the cause is
  almost certainly a modal presentation creeping back in, not three
  separate bugs.
- Returning from maximized to minimized must preserve scroll position in
  the note-wide list — this is a correctness requirement, not a nice-to-
  have, and should be re-verified any time this mechanism is touched.
- **Transition animation: zoom, not the default slide.** Use SwiftUI's
  zoom navigation transition (stable since iOS 18, well within reach on
  iPadOS 26/27) so the tapped cell visually expands from its position in
  the list into the full-screen page, and collapses back to that same
  position on the way back:
  - A shared `@Namespace` lives in the parent view that owns the cell list.
  - `.matchedTransitionSource(id: cell.id, in: namespace)` on each
    minimized cell card.
  - `.navigationTransition(.zoom(sourceID: cell.id, in: namespace))` on
    the maximized destination view.
  - This only changes the animation — it layers on top of the
    NavigationStack push above, not a replacement for it. Back button,
    edge-swipe-to-go-back, and scroll-position preservation all still apply.

**Edit-mode compact state.** While the note-wide list is in edit/reorder
mode, every cell — regardless of type — renders at a single shared, fixed,
uniform row height, short enough to make drag-to-reorder practical
regardless of a cell's normal minimized size. Content-heavy detail (PDF
page, rendered markdown, code) is not shown here — just enough to identify
the cell (type icon + label).

- This must be a **shared, type-agnostic mechanism** living at the
  cell-container level, not implemented per cell type. Each cell type's
  real content view should not need to know edit mode exists — the
  container swaps in the shared compact row, or doesn't, based on edit
  mode state (e.g. `@Environment(\.editMode)` if using SwiftUI's native
  mechanism).
- Why this matters beyond the PDF cell: markdown (Session 12+) and code
  cells will eventually grow well past a compact row height once they
  render real content, exactly like the PDF cell did in Session 6. This
  mechanism must already be in place and generic before that happens —
  don't let a future session reinvent this per cell type.
- Exiting edit mode returns each cell to its normal minimized appearance.

---

## Feature priorities

Treat these tiers as binding scope guidance — do not add P1/P2/Future items
while P0 items are incomplete, and do not gold-plate P0 items instead of
moving to the next one. **The core of v1 is PDF editing with markdown
integration and the Apple Pencil gestures that drive both — everything else
is secondary.**

### P0 — core, must work well
- Cell engine + notebook document format (foundation for everything else)
- Unbounded/infinite canvas (all directions) for the notebook view
- PDF cell: import PDF or PDF-based template, PencilKit annotation layer
  (pen, highlighter, pencil, eraser, ruler, laser pointer), minimized and
  maximized view states with maximize-to-write unbounded canvas (see Cell
  view states above), easy PDF import/export
- Markdown cell: markdown + LaTeX rendering (typed/rendered, not
  handwriting-recognized — see Future section), circuitikz support,
  "scribble" tool as default input (handwritten strokes recognized and
  converted to typed text), minimized/maximized view states (no unbounded
  canvas needed here — normal scrolling text)
- Pencil gestures (see dedicated section below) — these apply to both PDF
  and markdown cells and are part of the core, not an add-on

### P1 — important, after P0 is solid
- Python code cells: interpreted (embedded interpreter, not compiled),
  sandboxed, editable source, output-only result cells. See Code Execution
  section.
- Obsidian-style note linking (`[[links]]`) and nested folder navigation
- Photo import (from Photos or camera) into its own cell or into a PDF cell

### P2 — nice to have, lower priority
- Convert-to-ink: imported images → editable native pencil strokes
  (this is a vectorization/tracing problem — scope it as its own spike,
  don't let it block P0/P1)

### Future / explicitly out of scope for v1
- **Handwriting → math recognition, handwriting → LaTeX, and
  handwriting → math → solve → insert-solution-in-handwriting
  (Apple Math Notes-style).** These are "nice to have," not required for
  v1, and are good candidates to build as **separate standalone projects**
  (e.g. a handwriting-to-LaTeX script/model trained on open datasets)
  before ever being wired into Secretary. If one of those projects matures,
  integrate it into a markdown or PDF cell as its own later milestone —
  don't build this recognition pipeline inside Secretary's v1 codebase.
- C/C++ (or any other non-Python) code cells — do not attempt in-app native
  compilation. If revisited, this is its own architecture spike
  (WASM-targeting compiler + WASM interpreter), not an extension of the
  Python cell work.
- iCloud/CloudKit sync across devices
- Any on-device model fine-tuning / AI study features
- Universal markdown-based backup export beyond what the file-based
  storage format already gives for free

---

## Apple Pencil gestures

Implemented via `UIPencilInteraction` (delegate methods for double-tap and
squeeze; both have SwiftUI equivalents). Requires Apple Pencil Pro for
squeeze; double-tap also works on Apple Pencil (USB-C)/2nd gen.

- **Double-tap** (while in a PDF cell): swap between the active tool and
  the eraser. Standard, well-supported gesture — no ambiguity here.
- **Squeeze**: toggle the tool-selection menu open/closed (squeeze again
  to close, not squeeze-and-hold). Note: squeeze has a system-level default
  behavior (undo/redo slider, or whatever the user set in Settings > Apple
  Pencil > Squeeze) — the app must install its own `UIPencilInteraction`
  squeeze delegate to override this, or the app's action won't fire.
- **Default tool per cell type**:
  - PDF cell: pen
  - Markdown cell: "scribble" tool — handwritten input in a markdown cell
    is recognized and converted to typed text, not left as ink

---

## Key frameworks and where they map to features

- **PDFKit** (`PDFView`/`PDFDocument`) — PDF cell rendering, import/export.
- **PencilKit** (`PKCanvasView`, `PKDrawing`) — the annotation layer overlaid
  per PDF page; also powers the markdown cell's "scribble" input.
- **PencilKit handwriting recognition API** (new in iPadOS 27, on-device,
  29 languages) — use this for the markdown "scribble" → typed text
  conversion. Note: this is general text recognition, not math-aware — it
  does not solve the math recognition/solving requirement below.
- **PaperKit** (built on PencilKit) — shapes, images, text boxes alongside
  ink; use for stickers and image placement rather than building a custom
  overlay system.
- **Code execution (Python, P1)** — embed a signed Python interpreter in
  the app bundle (established App-Store-safe pattern; no JIT, no
  downloading/executing remote code, no sandbox exceptions needed). Code
  cell source is editable; output cells are regenerated, not hand-edited.
- **Math recognition/solving — not part of v1.** If/when the separate
  handwriting-to-math project (see Future section above) matures enough to
  integrate, build it behind a small `MathRecognitionProvider` protocol
  boundary rather than wiring it directly into cell code, so it can be
  swapped or upgraded without touching the rest of the app. Not worth
  designing further until that project exists.

---

## Build/test

```
xcodebuild build -scheme <SchemeName> -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
xcodebuild test -scheme <SchemeName> -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```
(Fill in actual scheme name once the project is scaffolded.)

---

## Style conventions
- SwiftUI only; UIKit only where a feature requires it (PDFKit/PencilKit
  interop, `UIPencilInteraction`), wrapped via `UIViewRepresentable`.
- No force-unwraps (`!`) outside of tests and truly-impossible-to-fail cases
  with a comment explaining why.
- `@Observable` for model/service objects; `@State` for local view-only state.
- One feature/screen per session where possible — don't sprawl a single
  session across the whole cell engine, PDF layer, and math recognition at
  once.
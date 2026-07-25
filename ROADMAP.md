# Roadmap — Secretary (P0 build sequence)

This is the session-by-session build order for P0, meant to be fed to
Claude Code **one session at a time**, each referencing CLAUDE.md for
conventions/scope. Don't paste the whole roadmap into one prompt — start a
session, confirm its "Done when" criteria, then move to the next.

## Working model (read this first — see CLAUDE.md "Cell view states")
- The notebook is a **vertically-ordered, scrollable list of cells** — not
  a freeform 2D canvas.
- Every cell has two states: **minimized** (embedded inline in the
  note-wide scroll, editable but bounded to its natural size) and
  **maximized** (a dedicated full-editing view for that one cell).
- The unbounded/ever-expanding writing surface applies **only** to a PDF
  cell's maximized view — never to the minimized view or the notebook
  layout as a whole.

---

### Session 1 — Project scaffold
Xcode project setup: SwiftUI app, iPadOS 26/27 min target, folder structure
matching CLAUDE.md (`Models/`, `Engine/`, `Views/`). No real features yet.
**Done when:** app builds and runs on simulator showing an empty shell.

### Session 2 — Notebook document format + cell engine
`NotebookDocument`, `Cell` model, manifest read/write, matching the bundle
format in CLAUDE.md. Pure Swift, no UI. Unit tests: create/save/reload a
notebook, assert round-trip fidelity.
**Done when:** tests pass proving a notebook bundle can be created, saved
to disk, and reloaded correctly with no UI involved.

### Session 3 — Notebook browser
Folder/notebook browser UI: nested folders, create/rename/delete/move
notebooks, Files-app visibility.
**Done when:** you can create a notebook from the UI, see the resulting
bundle in the Files app, and navigate folders.

### Session 4 — Cell list UI shell
Render a notebook's cells as an ordered, scrollable sequence in their
**minimized** state, using placeholder cards per type; add/remove/reorder
cells; wire to the Session 2 engine for real persistence.
**Done when:** add a PDF cell placeholder + markdown cell placeholder,
reorder them, close and reopen the notebook, confirm order and presence
persisted.

### Session 5 — Cell minimize/maximize interaction
Generic expand/collapse mechanism: tapping a cell (still placeholder
content at this point) transitions it from minimized (inline in the list)
to maximized (dedicated full view), and back. This is the container later
PDF/markdown sessions plug real content into — build it once, generically.
**Done when:** tapping a placeholder cell expands it to a dedicated view
and back; note-wide scroll position is preserved when returning to
minimized view.

### Session 6 — PDF cell: import & display
PDFKit import via file picker, render in `PDFView` in both minimized and
maximized states, store per the bundle format. No annotation yet — just
import/view/export round-trip.
**Done when:** import a PDF, see it rendered in both view states, export
it back out byte-identical.

### Session 7 — PDF cell: PencilKit annotation layer
Overlay `PKCanvasView` on the PDF, default tool = pen, persist ink to the
`.ink` sidecar, flatten ink+PDF into an exportable annotated PDF. Editing
works in both minimized (bounded to page size) and maximized states.
**Done when:** draw on an imported PDF in either view state, close/reopen
with ink preserved, export a flattened version.

### Session 8 — PDF cell: full toolset
Pen, highlighter, pencil, eraser, ruler, laser pointer (laser pointer is
ephemeral — don't persist its strokes).
**Done when:** all six tools are selectable and behave correctly.

### Session 9 — Apple Pencil gestures (PDF context)
`UIPencilInteraction` double-tap (swap tool/eraser) and squeeze (toggle
tool menu), per the CLAUDE.md gesture spec.
**Note:** squeeze and double-tap behavior may not be fully testable in
Simulator — budget time on a physical iPad + Pencil Pro for this session.
**Done when:** both gestures work correctly on real hardware, in both
minimized and maximized views.

### Session 10 — PDF templates
Save a PDF (or blank page at a given size) as a reusable template; create
new PDF cells from a template picker; handle multiple template sizes.
**Done when:** at least two saved templates are selectable when creating a
new PDF cell.

### Session 11 — Maximize-to-write unbounded canvas
In the maximized PDF cell view specifically, the writable area expands in
any direction as strokes approach an edge, without a hard boundary or
perceptible lag. Builds on Session 5's expand mechanism.
**Flag:** this is likely the riskiest session technically (custom
scroll/coordinate-space virtualization). Worth a short throwaway spike in a
scratch Xcode project before committing to an approach.
**Done when:** you can write past any edge of a maximized PDF cell and the
surface grows seamlessly; the minimized view remains correctly bounded.

### Session 12 — Markdown cell: text rendering
Editable markdown input with rendered preview (headers, lists, emphasis),
in both minimized and maximized states, persisted as `.md` per the bundle
format.
**Done when:** create a markdown cell, type markdown, see it rendered in
both view states, confirm it persists correctly.

### Session 13 — LaTeX + circuitikz rendering
Math typesetting inside markdown cells, plus circuitikz specifically.
**Flag:** this is the other high-risk session — there's no native iOS
LaTeX/TikZ renderer, so this needs its own research spike (bundled TeX
engine, WASM-based TeX, or MathJax-via-WKWebView for math, with a separate
approach for circuitikz diagrams) before writing real cell code against it.
**Done when:** typed LaTeX renders inline; a basic circuitikz diagram
renders correctly.

### Session 14 — Scribble tool + gesture completion
Wire the PencilKit handwriting recognition API as the markdown cell's
default "scribble" input (handwriting → typed text, inserted into markdown
source); finish the default-tool-per-cell-type behavior from the gesture
spec.
**Done when:** handwriting in a markdown cell correctly inserts recognized
text at the right position.

---

## Notes on using this roadmap
- Sessions 6–11 (PDF) and 12–14 (markdown) are largely independent once
  Session 5 exists — interleave them or do markdown first if that's more
  motivating; the dependency graph doesn't force this exact order.
- Sessions 11 and 13 are the two worth genuinely de-risking with a
  standalone spike (a scratch Xcode project, not Secretary itself) before
  writing real code against them.
- Update "Done when" criteria as you go if reality diverges from the plan
  — this file is a working plan, not a fixed contract.

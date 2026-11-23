# Oth Requirements

A native Flutter requirements management workspace for folders, requirements,
comments, relationships, and hierarchical variants.

## Features

- Create a project in a location selected with the Windows Save dialog
- VS Code-style explorer with folders, requirements, and comments
- Optional uppercase folder tags inherited by contained requirements; tags stack
  from the project root and open their owning folder when clicked. The explorer
  tree shows the base requirement ID without tags.
- Drag the divider beside the explorer to resize its width, or the divider
  above the folder/requirement/comment editor to resize its height
- Hover over a folder to rename it or delete it if empty; drag folders or
  requirements onto another folder to move them
- Search by ID, variant (`version:`), or free text
- Orthogonal relationship graph with separate ports and routing lanes for
  Derived, Related, and Contained links (lines may cross but do not overlap)
- Selected graph nodes are centered, with incoming links on the left and
  outgoing links on the right
- Titled comments shown in the diagram and related to one or more requirements
- Editable requirement title, description, rationale, variant, and relations
- Folder name, description, and tag editing in the lower editor panel
- Change outgoing relationship types and confirm before removing relationships
- Dirty-state indicators and explicit project saving
- Tree-structured variant creation, editing, and protected deletion
- A single JSON project database with monotonically increasing requirement IDs

## Run

```powershell
flutter pub get
flutter run -d windows
```

On first launch, open an existing project or create one. The application
remembers the last opened project and restores it on subsequent launches.
Press **Ctrl+S** or choose **File > Save Project** to save all project,
requirement, and comment changes. The requirement Save button remains scoped to
that requirement. The project root cannot be moved or deleted, and folders
cannot be moved into themselves or their descendants.

## Example project

Open `example_jsons/complex_warehouse_robot.json` from the File menu to explore
a 48-requirement project with nested folders, variants, comments, and all three
relationship types.

## Validate

```powershell
dart format lib test
flutter analyze
flutter test
flutter build windows
```

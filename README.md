# Oth Requirements

A native Flutter requirements management workspace for folders, requirements,
comments, relationships, and hierarchical variants.

## Features

- Create a project in a location selected with the Windows Save dialog
- VS Code-style explorer with folders, requirements, and comments
- Search by ID, variant (`version:`), or free text
- Orthogonal relationship graph with Derived, Related, and Contained links
- Titled comments shown in the diagram and related to one or more requirements
- Editable requirement title, description, rationale, variant, and relations
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

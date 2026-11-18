# Oth Requirements

A native Flutter requirements management workspace for folders, requirements,
comments, relationships, and hierarchical variants.

## Features

- Create a project in a location selected with the Windows Save dialog
- VS Code-style explorer with folders, requirements, and comments
- Search by ID, variant (`version:`), or free text
- Orthogonal relationship graph with incoming and outgoing `specifies` links
- Editable requirement title, description, rationale, variant, and relations
- Dirty-state indicators and explicit project saving
- Tree-structured variant creation, editing, and protected deletion
- A single JSON project database with monotonically increasing requirement IDs

## Run

```powershell
flutter pub get
flutter run -d windows
```

The Windows application stores its project at
`%USERPROFILE%\Documents\OthRequirements\project.json`. A sample project is
created on first launch.

## Validate

```powershell
dart format lib test
flutter analyze
flutter test
flutter build windows
```

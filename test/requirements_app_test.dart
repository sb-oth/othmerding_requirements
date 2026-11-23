import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oth_requirements/models.dart';
import 'package:oth_requirements/project_repository.dart';
import 'package:oth_requirements/requirements_app.dart';

void main() {
  testWidgets('resizes workspace panels and clamps them to the window', (
    tester,
  ) async {
    final project = _relationshipProject();
    project.createComment(1, 2).title = 'Review note';
    await _openProject(tester, project);
    await tester.tap(find.text('REQ-001  Source'));
    await tester.pumpAndSettle();

    final explorer = find.byKey(const ValueKey('explorer-panel'));
    final editor = find.byKey(const ValueKey('editor-panel'));
    final explorerHandle = find.byKey(const ValueKey('explorer-resize-handle'));
    final editorHandle = find.byKey(const ValueKey('editor-resize-handle'));
    expect(tester.getSize(explorer).width, 286);
    expect(tester.getSize(editor).height, 280);

    final gesture = await tester.startGesture(tester.getCenter(explorerHandle));
    await gesture.moveBy(const Offset(50, 0));
    await gesture.moveBy(const Offset(50, 0));
    await gesture.moveBy(const Offset(50, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.drag(editorHandle, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getSize(explorer).width, greaterThan(386));
    expect(tester.getSize(editor).height, greaterThan(280));
    expect(find.text('Source'), findsWidgets);

    await tester.drag(explorerHandle, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    await tester.drag(editorHandle, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(tester.getSize(explorer).width, 200);
    expect(tester.getSize(editor).height, 200);
    expect(tester.takeException(), isNull);

    await tester.drag(explorerHandle, const Offset(2000, 0));
    await tester.pumpAndSettle();
    await tester.drag(editorHandle, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getSize(explorer).width, 842);
    expect(tester.getSize(editor).height, 698);
    expect(tester.takeException(), isNull);
    await tester.enterText(_editorField('Title'), 'Edited while resized');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(960, 600));
    await tester.pumpAndSettle();
    expect(tester.getSize(explorer).width, 202);
    expect(tester.getSize(editor).height, 398);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Review note').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-panel')), findsOneWidget);
    expect(tester.getSize(editor).height, 398);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1600, 900));
    await tester.pumpAndSettle();
    expect(tester.getSize(explorer).width, 842);
    expect(tester.getSize(editor).height, 698);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+S saves all project changes while editing a requirement', (
    tester,
  ) async {
    final project = _relationshipProject();
    project.createComment(1, 2).title = 'Review note';
    final destination = project.createFolder(1)..name = 'Destination folder';
    final repository = await _openProject(tester, project);

    await tester.tap(find.text('REQ-001  Source'));
    await tester.pumpAndSettle();
    await tester.enterText(_editorField('Title'), 'Updated source');
    await tester.pump();
    await tester.tap(find.text('REQ-002  Target'));
    await tester.pumpAndSettle();
    await tester.enterText(_editorField('Title'), 'Updated target');
    await tester.pump();
    await tester.tap(find.text('Review note').first);
    await tester.pumpAndSettle();
    await tester.enterText(_editorField('Comment'), 'Updated comment');
    await tester.pump();
    await _dragToFolder(tester, 'requirement-drag-1', destination.id);

    final beforeSave = await tester.runAsync(repository.load);
    expect(beforeSave!.requirement(1).title, 'Source');
    expect(beforeSave.requirement(2).title, 'Target');
    expect(beforeSave.comments.single.description, isEmpty);
    expect(beforeSave.containingFolder(1)!.id, 1);

    await tester.tap(find.text('REQ-002  Updated target'));
    await tester.pumpAndSettle();
    await tester.tap(_editorField('Title'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _waitForText(tester, 'Project saved');

    final saved = await tester.runAsync(repository.load);
    expect(saved!.requirement(1).title, 'Updated source');
    expect(saved.requirement(2).title, 'Updated target');
    expect(saved.comments.single.description, 'Updated comment');
    expect(saved.containingFolder(1)!.id, destination.id);
    expect(_requirementSaveButton(tester).onPressed, isNull);
    await tester.tap(find.text('Review note').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Ctrl+S works without an editor field focused', (tester) async {
    final repository = await _openProject(tester, _relationshipProject());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _waitForText(tester, 'Project saved');
    final saved = await tester.runAsync(repository.load);
    expect(saved!.requirements, hasLength(2));
  });

  testWidgets('Ctrl+S works while the File menu is open', (tester) async {
    await _openProject(tester, _relationshipProject());
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(find.text('Save Project'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _waitForText(tester, 'Project saved');
  });

  testWidgets('edits made during Ctrl+S remain unsaved', (tester) async {
    late _PausingLastProjectStore store;
    final repository = await _openProject(
      tester,
      _relationshipProject(),
      storeFactory: (path) => store = _PausingLastProjectStore(path),
    );
    await tester.tap(find.text('REQ-001  Source'));
    await tester.pumpAndSettle();
    await tester.enterText(_editorField('Title'), 'Saved snapshot');
    await tester.pump();
    store.pause = true;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.runAsync(() async {
      for (
        var attempt = 0;
        attempt < 200 && !store.started.isCompleted;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    expect(store.started.isCompleted, isTrue);

    await tester.enterText(_editorField('Title'), 'Later edit');
    await tester.pump();
    await tester.tap(find.byTooltip('Add folder'));
    await tester.pumpAndSettle();
    store.resume.complete();
    await _waitForText(tester, 'Project saved');

    final saved = await tester.runAsync(repository.load);
    expect(saved!.requirement(1).title, 'Saved snapshot');
    expect(saved.folders, hasLength(1));
    await tester.tap(find.text('REQ-001  Later edit'));
    await tester.pumpAndSettle();
    expect(_requirementSaveButton(tester).onPressed, isNotNull);
    await tester.tap(find.byTooltip('Revert requirement changes'));
    await tester.pumpAndSettle();
    expect(find.text('REQ-001  Saved snapshot'), findsOneWidget);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Project'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('long variant names do not overflow the requirement editor', (
    tester,
  ) async {
    const longName = 'A very long variant name that does not fit the selector';
    late Directory directory;
    late LastProjectStore store;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('requirements_test_');
      final projectPath =
          '${directory.path}${Platform.pathSeparator}project.json';
      store = LastProjectStore(
        path: '${directory.path}${Platform.pathSeparator}last_project.txt',
      );
      final project = RequirementProject.empty(name: 'Test project');
      project.createRequirement(1).title = 'Test requirement';
      project.variants.add(
        RequirementVariant(
          id: 200,
          parentId: project.variants.first.id,
          name: longName,
          description: '',
        ),
      );
      await ProjectRepository(path: projectPath).save(project);
      await store.save(projectPath);
    });
    addTearDown(() => directory.delete(recursive: true));

    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await tester.pumpWidget(RequirementsApp(lastProjectStore: store));
      for (var attempt = 0; attempt < 200; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.text('REQ-001  Test requirement').evaluate().isNotEmpty) {
          break;
        }
      }
    });
    expect(find.text('REQ-001  Test requirement'), findsOneWidget);
    await tester.tap(find.text('REQ-001  Test requirement'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(longName).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(longName), findsOneWidget);
    expect(
      tester
          .state<FormFieldState<int>>(find.byType(DropdownButtonFormField<int>))
          .value,
      200,
    );
    expect(find.byTooltip(longName), findsOneWidget);
  });

  testWidgets(
    'edits folder tags and opens tagged folders from graph suffixes',
    (tester) async {
      final project = _relationshipProject();
      final communications = project.createFolder(1)
        ..name = 'Communications'
        ..tag = 'COM';
      final telemetry = project.createFolder(communications.id)
        ..name = 'Telemetry'
        ..tag = 'TEL';
      final nested = project.createRequirement(telemetry.id)
        ..title = 'Nested telemetry';
      final repository = await _openProject(tester, project);

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Search: id:, version:, or text',
        ),
        'Nested telemetry',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('REQ-003  Nested telemetry'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('graph-tag-${communications.id}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('graph-tag-${telemetry.id}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('graph-tag-${communications.id}')));
      await tester.pumpAndSettle();
      expect(_editorField('Folder name'), findsOneWidget);
      expect(
        tester.widget<TextField>(_editorField('Tag')).controller!.text,
        'COM',
      );

      await tester.enterText(_editorField('Folder name'), 'Communications bus');
      await tester.enterText(_editorField('Tag'), 'bus');
      await tester.enterText(
        _editorField('Description'),
        'Communication requirements.',
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(_editorField('Tag')).controller!.text,
        'BUS',
      );
      await tester.tap(find.byTooltip('Save folder'));
      await _waitForText(tester, 'Project saved');

      final saved = await tester.runAsync(repository.load);
      expect(saved!.folder(communications.id).name, 'Communications bus');
      expect(saved.folder(communications.id).tag, 'BUS');
      expect(
        saved.folder(communications.id).description,
        'Communication requirements.',
      );
      expect(saved.displayIdForRequirement(nested.id), 'REQ-003-BUS-TEL');
    },
  );

  testWidgets('explorer rows omit tags and keep long titles at normal size', (
    tester,
  ) async {
    final project = _relationshipProject();
    final folder = project.createFolder(1)
      ..name = 'Communications'
      ..tag = 'COM';
    final short = project.createRequirement(folder.id)..title = 'Short';
    final long = project.createRequirement(folder.id)
      ..title = 'A very long requirement title that does not fit the explorer';
    await _openProject(tester, project);

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search: id:, version:, or text',
      ),
      'id:com',
    );
    await tester.pumpAndSettle();

    final shortRow = find.byKey(ValueKey('requirement-drag-${short.id}'));
    final longRow = find.byKey(ValueKey('requirement-drag-${long.id}'));
    final shortLabel = find.descendant(
      of: shortRow,
      matching: find.text('REQ-003  Short'),
    );
    final longLabel = find.descendant(
      of: longRow,
      matching: find.text(
        'REQ-004  A very long requirement title that does not fit the explorer',
      ),
    );
    expect(shortLabel, findsOneWidget);
    expect(longLabel, findsOneWidget);
    expect(
      find.descendant(of: longRow, matching: find.byType(FittedBox)),
      findsNothing,
    );
    expect(tester.widget<Text>(longLabel).overflow, TextOverflow.ellipsis);
    expect(
      tester.widget<Text>(longLabel).style,
      tester.widget<Text>(shortLabel).style,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('changes relationship type and supports revert and save', (
    tester,
  ) async {
    final project = _relationshipProject();
    final repository = await _openProject(tester, project);
    await tester.tap(find.text('REQ-001  Source'));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _chooseRelationType(tester, 'Derived');
    expect(_requirementSaveButton(tester).onPressed, isNull);
    await _chooseRelationType(tester, 'Contained');
    expect(find.text('Contained · Target'), findsOneWidget);
    expect(_requirementSaveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byTooltip('Revert requirement changes'));
    await tester.pumpAndSettle();
    expect(find.text('Derived · Target'), findsOneWidget);
    expect(_requirementSaveButton(tester).onPressed, isNull);

    await _chooseRelationType(tester, 'Related');
    expect(find.text('Related · Target'), findsOneWidget);
    await tester.tap(find.byTooltip('Save requirement'));
    await _waitForText(tester, 'Requirement saved');
    final saved = await tester.runAsync(repository.load);
    expect(
      saved!.requirement(1).relations.single.type,
      RequirementRelationType.related,
    );
    expect(saved.requirement(1).relations.single.targetId, 2);
    expect(saved.requirement(2).relations, isEmpty);
  });

  testWidgets('confirms relationship removal before editing the requirement', (
    tester,
  ) async {
    final project = _relationshipProject();
    final repository = await _openProject(tester, project);
    await tester.tap(find.text('REQ-001  Source'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove relation'));
    await tester.pumpAndSettle();
    expect(find.text('Remove relationship?'), findsOneWidget);
    expect(
      find.text('Remove the Derived relationship from REQ-001 to REQ-002?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Derived · Target'), findsOneWidget);
    expect(_requirementSaveButton(tester).onPressed, isNull);

    await _confirmRelationRemoval(tester, 'Remove relation');
    expect(find.text('Derived · Target'), findsNothing);
    expect(_requirementSaveButton(tester).onPressed, isNotNull);
    final beforeSave = await tester.runAsync(repository.load);
    expect(beforeSave!.requirement(1).relations, hasLength(1));
    await tester.tap(find.byTooltip('Revert requirement changes'));
    await tester.pumpAndSettle();
    expect(find.text('Derived · Target'), findsOneWidget);

    await _confirmRelationRemoval(tester, 'Remove relation');
    await tester.tap(find.byTooltip('Save requirement'));
    await _waitForText(tester, 'Requirement saved');
    final saved = await tester.runAsync(repository.load);
    expect(saved!.requirement(1).relations, isEmpty);
  });

  testWidgets('confirms removal of comment relationships', (tester) async {
    final project = _relationshipProject();
    project.createComment(1, 2).title = 'Review note';
    final repository = await _openProject(tester, project);
    await tester.tap(find.text('Review note').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove relationship'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Remove the Related relationship from "Review note" to REQ-002?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove relationship'), findsOneWidget);

    await _confirmRelationRemoval(tester, 'Remove relationship');
    expect(find.byTooltip('Remove relationship'), findsNothing);
    final beforeSave = await tester.runAsync(repository.load);
    expect(beforeSave!.comments.single.relatedRequirementIds, [2]);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _waitForText(tester, 'Comment saved');
    final saved = await tester.runAsync(repository.load);
    expect(saved!.comments.single.relatedRequirementIds, isEmpty);
  });

  testWidgets(
    'deletes only empty folders and saves the change with the project',
    (tester) async {
      final project = _relationshipProject();
      final occupied = project.createFolder(1)..name = 'Occupied folder';
      project.createRequirement(occupied.id);
      final empty = project.createFolder(1)..name = 'Empty folder';
      final repository = await _openProject(tester, project);

      expect(find.byTooltip('Delete folder'), findsNothing);
      expect(find.byTooltip('Rename folder'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1500, 100));
      addTearDown(mouse.removePointer);
      await _hoverFolder(tester, mouse, 1);
      expect(_folderAction(tester, 1, 'Delete folder').onPressed, isNull);
      expect(find.byTooltip('Rename folder'), findsOneWidget);

      await _hoverFolder(tester, mouse, occupied.id);
      expect(
        _folderAction(tester, occupied.id, 'Delete folder').onPressed,
        isNotNull,
      );
      expect(find.byTooltip('Delete folder'), findsOneWidget);
      expect(find.byTooltip('Rename folder'), findsOneWidget);
      await _tapFolderAction(tester, mouse, occupied.id, 'Delete folder');
      expect(find.text('Only empty folders can be deleted.'), findsOneWidget);
      expect(find.text('Delete folder?'), findsNothing);

      await _hoverFolder(tester, mouse, empty.id);
      expect(
        tester.getRect(_folderActionFinder(empty.id, 'Rename folder')).right,
        lessThanOrEqualTo(
          tester.getRect(_folderActionFinder(empty.id, 'Delete folder')).left,
        ),
      );
      await _tapFolderAction(tester, mouse, empty.id, 'Rename folder');
      expect(find.text('Rename folder'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Renamed empty',
      );
      await tester.pump();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed empty'), findsOneWidget);

      await _hoverFolder(tester, mouse, empty.id);
      await _tapFolderAction(tester, mouse, empty.id, 'Delete folder');
      expect(
        find.text('Delete the empty folder "Renamed empty"?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed empty'), findsOneWidget);

      await _hoverFolder(tester, mouse, empty.id);
      await _tapFolderAction(tester, mouse, empty.id, 'Delete folder');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed empty'), findsNothing);
      await mouse.moveTo(const Offset(1500, 100));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete folder'), findsNothing);
      expect(find.byTooltip('Rename folder'), findsNothing);
      final beforeSave = await tester.runAsync(repository.load);
      expect(beforeSave!.folder(empty.id).name, 'Empty folder');
      await _saveProject(tester);
      final saved = await tester.runAsync(repository.load);
      expect(saved!.folders.any((folder) => folder.id == empty.id), isFalse);
      expect(saved.folder(1).childFolderIds, isNot(contains(empty.id)));
      expect(saved.folder(occupied.id).requirementIds, isNotEmpty);
    },
  );

  testWidgets(
    'drags a requirement into another folder and saves its location',
    (tester) async {
      final project = _relationshipProject();
      final destination = project.createFolder(1)..name = 'Destination folder';
      final repository = await _openProject(tester, project);
      await tester.tap(find.text('REQ-001  Source'));
      await tester.pumpAndSettle();

      await _dragToFolder(tester, 'requirement-drag-1', destination.id);
      expect(find.text('REQ-001  Source'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('requirement-drag-1'))).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.byKey(ValueKey('folder-target-${destination.id}')),
              )
              .dy,
        ),
      );
      expect(find.byTooltip('Save requirement'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Title',
        ),
        'Updated source',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Save requirement'));
      await _waitForText(tester, 'Requirement saved');
      final beforeSave = await tester.runAsync(repository.load);
      expect(beforeSave!.containingFolder(1)!.id, 1);
      expect(beforeSave.requirement(1).title, 'Updated source');
      await _saveProject(tester);
      final saved = await tester.runAsync(repository.load);
      expect(saved!.containingFolder(1)!.id, destination.id);
      expect(saved.folder(1).requirementIds, isNot(contains(1)));
      expect(saved.requirement(1).title, 'Updated source');
      expect(saved.requirement(1).relations.single.targetId, 2);
    },
  );

  testWidgets('drags folder trees and rejects drops onto their descendants', (
    tester,
  ) async {
    final project = _relationshipProject();
    final source = project.createFolder(1)..name = 'Source folder';
    final child = project.createFolder(source.id)..name = 'Nested folder';
    final destination = project.createFolder(1)..name = 'Destination folder';
    final nestedRequirement = project.createRequirement(child.id);
    final repository = await _openProject(tester, project);

    expect(find.byKey(const ValueKey('folder-drag-1')), findsNothing);
    final expandFinder = find.descendant(
      of: find.byKey(ValueKey('folder-target-${source.id}')),
      matching: find.byTooltip('Expand folder'),
    );
    await tester.tap(expandFinder);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Nested folder'), findsOneWidget);
    await _dragToFolder(tester, 'folder-drag-${source.id}', child.id);
    expect(find.text('Source folder'), findsOneWidget);
    expect(find.text('Nested folder'), findsOneWidget);
    await _saveProject(tester);
    var saved = await tester.runAsync(repository.load);
    expect(saved!.folder(source.id).parentId, 1);
    expect(saved.folder(child.id).parentId, source.id);

    await _dragToFolder(tester, 'folder-drag-${source.id}', destination.id);
    expect(find.text('Source folder'), findsOneWidget);
    await _saveProject(tester);
    saved = await tester.runAsync(repository.load);
    expect(saved!.folder(source.id).parentId, destination.id);
    expect(saved.folder(destination.id).childFolderIds, [source.id]);
    expect(saved.folder(1).childFolderIds, isNot(contains(source.id)));
    expect(saved.folder(child.id).requirementIds, [nestedRequirement.id]);
  });
}

RequirementProject _relationshipProject() {
  final project = RequirementProject.empty(name: 'Test project');
  final source = project.createRequirement(1)..title = 'Source';
  final target = project.createRequirement(1)..title = 'Target';
  source.relations.add(
    RequirementRelation(
      type: RequirementRelationType.derived,
      targetId: target.id,
    ),
  );
  return project;
}

Finder _editorField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<ProjectRepository> _openProject(
  WidgetTester tester,
  RequirementProject project, {
  LastProjectStore Function(String path)? storeFactory,
}) async {
  late Directory directory;
  late ProjectRepository repository;
  late LastProjectStore store;
  await tester.runAsync(() async {
    directory = await Directory.systemTemp.createTemp('requirements_test_');
    repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final storePath =
        '${directory.path}${Platform.pathSeparator}last_project.txt';
    store = storeFactory?.call(storePath) ?? LastProjectStore(path: storePath);
    await repository.save(project);
    await store.save(repository.path);
  });
  addTearDown(() => directory.delete(recursive: true));
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    await tester.pumpWidget(RequirementsApp(lastProjectStore: store));
    for (var attempt = 0; attempt < 200; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      if (find.text('REQ-001  Source').evaluate().isNotEmpty) break;
    }
  });
  expect(find.text('REQ-001  Source'), findsOneWidget);
  return repository;
}

class _PausingLastProjectStore extends LastProjectStore {
  _PausingLastProjectStore(String path) : super(path: path);

  bool pause = false;
  final started = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<void> save(String projectPath) async {
    if (pause) {
      if (!started.isCompleted) started.complete();
      await resume.future;
    }
    await super.save(projectPath);
  }
}

Future<void> _chooseRelationType(WidgetTester tester, String type) async {
  await tester.tap(find.byTooltip('Change relationship type'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.ancestor(
      of: find.text(type).last,
      matching: find.byType(CheckedPopupMenuItem<RequirementRelationType>),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmRelationRemoval(
  WidgetTester tester,
  String tooltip,
) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Remove'));
  await tester.pumpAndSettle();
}

IconButton _requirementSaveButton(WidgetTester tester) =>
    tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Save requirement',
      ),
    );

Future<void> _waitForText(WidgetTester tester, String text) async {
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text(text).evaluate().isNotEmpty) break;
    }
  });
  expect(find.text(text), findsOneWidget);
}

Finder _folderActionFinder(int folderId, String tooltip) => find.descendant(
  of: find.byKey(ValueKey('folder-target-$folderId')),
  matching: find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip,
  ),
);

IconButton _folderAction(WidgetTester tester, int folderId, String tooltip) =>
    tester.widget<IconButton>(_folderActionFinder(folderId, tooltip));

Future<void> _hoverFolder(
  WidgetTester tester,
  TestGesture mouse,
  int folderId,
) async {
  await mouse.moveTo(const Offset(1500, 100));
  await tester.pump();
  await mouse.moveTo(
    tester.getCenter(find.byKey(ValueKey('folder-target-$folderId'))),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapFolderAction(
  WidgetTester tester,
  TestGesture mouse,
  int folderId,
  String tooltip,
) async {
  await mouse.moveTo(tester.getCenter(_folderActionFinder(folderId, tooltip)));
  await tester.pump();
  await mouse.down(tester.getCenter(_folderActionFinder(folderId, tooltip)));
  await mouse.up();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> _dragToFolder(
  WidgetTester tester,
  String dragKey,
  int destinationId,
) async {
  final start = tester.getCenter(find.byKey(ValueKey(dragKey)));
  final end = tester.getCenter(
    find.byKey(ValueKey('folder-target-$destinationId')),
  );
  final gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(15, 0));
  await tester.pump();
  await gesture.moveTo(end);
  await tester.pump();
  await gesture.up();
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

Future<void> _saveProject(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save Project'));
  await _waitForText(tester, 'Project saved');
}

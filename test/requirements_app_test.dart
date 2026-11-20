import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oth_requirements/models.dart';
import 'package:oth_requirements/project_repository.dart';
import 'package:oth_requirements/requirements_app.dart';

void main() {
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

Future<ProjectRepository> _openProject(
  WidgetTester tester,
  RequirementProject project,
) async {
  late Directory directory;
  late ProjectRepository repository;
  late LastProjectStore store;
  await tester.runAsync(() async {
    directory = await Directory.systemTemp.createTemp('requirements_test_');
    repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    store = LastProjectStore(
      path: '${directory.path}${Platform.pathSeparator}last_project.txt',
    );
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

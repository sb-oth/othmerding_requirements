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
}

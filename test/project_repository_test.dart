import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oth_requirements/models.dart';
import 'package:oth_requirements/project_repository.dart';

void main() {
  test(
    'does not create a sample project when a project file is missing',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'oth_requirements_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = ProjectRepository(
        path: '${directory.path}${Platform.pathSeparator}missing.json',
      );

      await expectLater(repository.load(), throwsA(isA<FileSystemException>()));
      expect(File(repository.path).existsSync(), isFalse);
    },
  );

  test('persists one complete project JSON document', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final project = RequirementProject.sample();
    project.requirement(128).title = 'Updated title';

    await repository.save(project);
    final restored = await repository.load();

    expect(File(repository.path).existsSync(), isTrue);
    expect(restored.requirement(128).title, 'Updated title');
    expect(restored.folders.length, project.folders.length);
  });

  test('saves only the selected requirement', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final project = RequirementProject.sample();
    await repository.save(project);

    final unsavedProject = await repository.load();
    unsavedProject.name = 'Unsaved name';
    unsavedProject.requirement(129).title = 'Unsaved requirement';
    unsavedProject.requirement(128).title = 'Saved requirement';

    await repository.saveRequirement(
      unsavedProject.requirement(128),
      nextEntityId: unsavedProject.nextEntityId,
    );
    final restored = await repository.load();

    expect(restored.requirement(128).title, 'Saved requirement');
    expect(restored.requirement(129).title, 'Synchronize telemetry');
    expect(restored.name, 'Vehicle Control System');
  });

  test('saves a new requirement into an existing saved folder', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final project = RequirementProject.empty(name: 'New project');
    await repository.save(project);

    final unsavedProject = await repository.load();
    final requirement = unsavedProject.createRequirement(1);
    await repository.saveRequirement(
      requirement,
      folderId: 1,
      nextEntityId: unsavedProject.nextEntityId,
    );
    final restored = await repository.load();

    expect(restored.requirements.single.id, requirement.id);
    expect(restored.folder(1).requirementIds, [requirement.id]);
    expect(restored.nextRequirementNumber, requirement.id + 1);
  });

  test('remembers the last opened project path', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = LastProjectStore(
      path: '${directory.path}${Platform.pathSeparator}last_project.txt',
    );
    const projectPath = r'C:\projects\requirements.json';

    expect(await store.load(), isNull);
    await store.save(projectPath);

    expect(await store.load(), projectPath);
  });
}

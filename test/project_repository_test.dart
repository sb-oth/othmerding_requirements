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

  test(
    'loads the complex example project with all relationship types',
    () async {
      final repository = ProjectRepository(
        path:
            'example_jsons${Platform.pathSeparator}complex_warehouse_robot.json',
      );

      final project = await repository.load();
      final relationTypes = project.requirements
          .expand((requirement) => requirement.relations)
          .map((relation) => relation.type)
          .toSet();

      expect(project.requirements.length, greaterThanOrEqualTo(40));
      expect(
        project.folders.where((folder) => folder.parentId != null),
        isNotEmpty,
      );
      expect(relationTypes, containsAll(RequirementRelationType.values));
      expect(
        project.requirements.every(
          (requirement) => project.containingFolder(requirement.id) != null,
        ),
        isTrue,
      );
      for (final requirement in project.requirements) {
        for (final relation in requirement.relations) {
          expect(
            project.requirements.any((item) => item.id == relation.targetId),
            isTrue,
          );
        }
      }
    },
  );

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

  test('saves only the selected comment', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final project = RequirementProject.empty(name: 'Comment save');
    final firstRequirement = project.createRequirement(1);
    final secondRequirement = project.createRequirement(1);
    final firstComment = project.createComment(1, firstRequirement.id);
    final secondComment = project.createComment(1, secondRequirement.id);
    await repository.save(project);

    final unsavedProject = await repository.load();
    unsavedProject.name = 'Unsaved project name';
    final selectedComment = unsavedProject.comments.first;
    selectedComment.title = 'Updated review title';
    selectedComment.relatedRequirementIds.add(secondRequirement.id);
    unsavedProject.comments.last.description = 'Unsaved other comment';

    await repository.saveComment(
      selectedComment,
      folderId: 1,
      nextEntityId: unsavedProject.nextEntityId,
    );
    final restored = await repository.load();

    expect(restored.comments.first.title, 'Updated review title');
    expect(restored.comments.first.relatedRequirementIds, [
      firstRequirement.id,
      secondRequirement.id,
    ]);
    expect(restored.comments.last.description, '');
    expect(restored.name, 'Comment save');
    expect(restored.comments.last.id, secondComment.id);
    expect(restored.comments.first.id, firstComment.id);
  });

  test(
    'prevents deleting requirements with incoming or outgoing relations',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'oth_requirements_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = ProjectRepository(
        path: '${directory.path}${Platform.pathSeparator}project.json',
      );
      final project = RequirementProject.empty(name: 'Linked requirements');
      final source = project.createRequirement(1);
      final target = project.createRequirement(1);
      source.relations.add(
        RequirementRelation(
          type: RequirementRelationType.derived,
          targetId: target.id,
        ),
      );
      await repository.save(project);

      await expectLater(
        repository.deleteRequirement(source.id),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.deleteRequirement(target.id),
        throwsA(isA<StateError>()),
      );

      final restored = await repository.load();
      expect(restored.requirements, hasLength(2));
      expect(
        restored.requirement(source.id).relations.single.targetId,
        target.id,
      );
    },
  );

  test('deletes an unreferenced requirement and its folder entry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final project = RequirementProject.empty(name: 'Single requirement');
    final requirement = project.createRequirement(1);
    await repository.save(project);

    await repository.deleteRequirement(requirement.id);

    final restored = await repository.load();
    expect(restored.requirements, isEmpty);
    expect(restored.folder(1).requirementIds, isEmpty);
  });

  test('prevents deleting requirements related to comments', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final project = RequirementProject.empty(name: 'Commented requirement');
    final requirement = project.createRequirement(1);
    project.createComment(1, requirement.id);
    await repository.save(project);

    await expectLater(
      repository.deleteRequirement(requirement.id),
      throwsA(isA<StateError>()),
    );
    expect((await repository.load()).requirements, hasLength(1));
  });

  test('deletes a comment and removes its folder entry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oth_requirements_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = ProjectRepository(
      path: '${directory.path}${Platform.pathSeparator}project.json',
    );
    final project = RequirementProject.empty(name: 'Comment deletion');
    final requirement = project.createRequirement(1);
    final comment = project.createComment(1, requirement.id);
    await repository.save(project);

    await repository.deleteComment(comment.id);

    final restored = await repository.load();
    expect(restored.comments, isEmpty);
    expect(restored.folder(1).commentIds, isEmpty);
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

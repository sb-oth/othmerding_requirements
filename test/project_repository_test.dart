import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oth_requirements/models.dart';
import 'package:oth_requirements/project_repository.dart';

void main() {
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
}

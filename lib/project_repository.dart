import 'dart:convert';
import 'dart:io';

import 'models.dart';

class ProjectRepository {
  ProjectRepository({String? path}) : path = path ?? _defaultProjectPath();

  final String path;

  Future<RequirementProject> load() async {
    final file = File(path);
    if (!await file.exists()) {
      final project = RequirementProject.sample();
      await save(project);
      return project;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'The project database must be a JSON object.',
      );
    }
    return RequirementProject.fromJson(decoded);
  }

  Future<void> save(RequirementProject project) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(project.toPrettyJson(), flush: true);
  }

  static String _defaultProjectPath() {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}'
        'OthRequirements${Platform.pathSeparator}project.json';
  }
}

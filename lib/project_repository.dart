import 'dart:convert';
import 'dart:io';

import 'models.dart';

class ProjectRepository {
  ProjectRepository({required this.path});

  final String path;

  Future<RequirementProject> load() async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Project file does not exist', path);
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

  Future<void> saveRequirement(
    Requirement requirement, {
    int? folderId,
    required int nextEntityId,
  }) async {
    final project = await load();
    final requirementIndex = project.requirements.indexWhere(
      (item) => item.id == requirement.id,
    );
    if (requirementIndex == -1) {
      if (folderId == null ||
          !project.folders.any((folder) => folder.id == folderId)) {
        throw StateError(
          'Save the containing folder before saving this requirement.',
        );
      }
      project.requirements.add(requirement.copy());
      project.folder(folderId).requirementIds.add(requirement.id);
      if (project.nextRequirementNumber <= requirement.id) {
        project.nextRequirementNumber = requirement.id + 1;
      }
      if (project.nextEntityId < nextEntityId) {
        project.nextEntityId = nextEntityId;
      }
    } else {
      project.requirements[requirementIndex] = requirement.copy();
    }

    if (!project.variants.any(
      (variant) => variant.id == requirement.variantId,
    )) {
      throw StateError(
        'Save the requirement variant before saving this requirement.',
      );
    }
    final requirementIds = project.requirements.map((item) => item.id).toSet();
    if (requirement.outgoingIds.any((id) => !requirementIds.contains(id))) {
      throw StateError(
        'Save related requirements before saving this requirement.',
      );
    }
    await save(project);
  }

  Future<void> deleteRequirement(int requirementId) async {
    final project = await load();
    final requirementIndex = project.requirements.indexWhere(
      (item) => item.id == requirementId,
    );
    if (requirementIndex == -1) {
      throw StateError('Requirement $requirementId does not exist.');
    }

    final requirement = project.requirements[requirementIndex];
    if (requirement.outgoingIds.isNotEmpty) {
      throw StateError(
        'Remove all outgoing relations before deleting this requirement.',
      );
    }
    if (project.requirements.any(
      (item) =>
          item.id != requirementId && item.outgoingIds.contains(requirementId),
    )) {
      throw StateError(
        'Remove all incoming relations before deleting this requirement.',
      );
    }
    if (project.comments.any(
      (comment) => comment.attachedToId == requirementId,
    )) {
      throw StateError(
        'Remove comments attached to this requirement before deleting it.',
      );
    }

    final folder = project.containingFolder(requirementId);
    if (folder == null) {
      throw StateError('Requirement $requirementId is not in a folder.');
    }
    folder.requirementIds.remove(requirementId);
    project.requirements.removeAt(requirementIndex);
    await save(project);
  }
}

class LastProjectStore {
  LastProjectStore({String? path}) : path = path ?? _defaultPath();

  final String path;

  Future<String?> load() async {
    final file = File(path);
    if (!await file.exists()) return null;
    final projectPath = (await file.readAsString()).trim();
    return projectPath.isEmpty ? null : projectPath;
  }

  Future<void> save(String projectPath) async {
    if (projectPath.trim().isEmpty) {
      throw ArgumentError.value(
        projectPath,
        'projectPath',
        'Must not be empty',
      );
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(projectPath, flush: true);
  }

  static String _defaultPath() {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final appData =
        Platform.environment['APPDATA'] ??
        '$home${Platform.pathSeparator}AppData${Platform.pathSeparator}'
            'Roaming';
    return '$appData${Platform.pathSeparator}OthRequirements'
        '${Platform.pathSeparator}last_project.txt';
  }
}

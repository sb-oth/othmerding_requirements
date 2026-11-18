import 'dart:convert';

class Requirement {
  Requirement({
    required this.id,
    required this.title,
    required this.description,
    required this.rationale,
    required this.variantId,
    required this.outgoingIds,
  });

  final int id;
  String title;
  String description;
  String rationale;
  int variantId;
  List<int> outgoingIds;

  String get displayId => 'REQ-${id.toString().padLeft(3, '0')}';

  Requirement copy() => Requirement.fromJson(toJson());

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'rationale': rationale,
    'variant': variantId,
    'relations': outgoingIds
        .map((target) => {'type': 'specifies', 'target': target})
        .toList(),
  };

  factory Requirement.fromJson(Map<String, Object?> json) => Requirement(
    id: json['id'] as int,
    title: (json['title'] as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    rationale: (json['rationale'] as String?) ?? '',
    variantId: json['variant'] as int,
    outgoingIds: ((json['relations'] as List<dynamic>?) ?? const [])
        .map((entry) => (entry as Map<String, Object?>)['target'] as int)
        .toList(),
  );
}

class RequirementFolder {
  RequirementFolder({
    required this.id,
    required this.name,
    required this.description,
    this.parentId,
    this.requirementIds = const [],
    this.commentIds = const [],
    this.childFolderIds = const [],
  });

  final int id;
  String name;
  String description;
  int? parentId;
  List<int> requirementIds;
  List<int> commentIds;
  List<int> childFolderIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'parent': parentId,
    'contents': {
      'requirements': requirementIds,
      'comments': commentIds,
      'folders': childFolderIds,
    },
  };

  factory RequirementFolder.fromJson(Map<String, Object?> json) {
    final contents =
        (json['contents'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    return RequirementFolder(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      parentId: json['parent'] as int?,
      requirementIds: _intList(contents['requirements']),
      commentIds: _intList(contents['comments']),
      childFolderIds: _intList(contents['folders']),
    );
  }
}

class RequirementComment {
  RequirementComment({
    required this.id,
    required this.description,
    required this.attachedToId,
  });

  final int id;
  String description;
  int attachedToId;

  Map<String, Object?> toJson() => {
    'id': id,
    'comment': description,
    'attaches_too': [
      {'type': 'requirement', 'id': attachedToId},
    ],
  };

  factory RequirementComment.fromJson(Map<String, Object?> json) {
    final attachments = json['attaches_too'] as List<dynamic>? ?? const [];
    return RequirementComment(
      id: json['id'] as int,
      description: (json['comment'] as String?) ?? '',
      attachedToId: attachments.isEmpty
          ? 0
          : (attachments.first as Map<String, Object?>)['id'] as int,
    );
  }
}

class RequirementVariant {
  RequirementVariant({
    required this.id,
    required this.parentId,
    required this.name,
    required this.description,
  });

  final int id;
  int parentId;
  String name;
  String description;

  Map<String, Object?> toJson() => {
    'id': id,
    'parent': parentId,
    'name': name,
    'description': description,
  };

  factory RequirementVariant.fromJson(Map<String, Object?> json) =>
      RequirementVariant(
        id: json['id'] as int,
        parentId: json['parent'] as int,
        name: (json['name'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
      );
}

class RequirementProject {
  RequirementProject({
    required this.name,
    required this.nextRequirementNumber,
    required this.nextEntityId,
    required this.requirements,
    required this.folders,
    required this.comments,
    required this.variants,
  });

  String name;
  int nextRequirementNumber;
  int nextEntityId;
  List<Requirement> requirements;
  List<RequirementFolder> folders;
  List<RequirementComment> comments;
  List<RequirementVariant> variants;

  RequirementFolder folder(int id) =>
      folders.firstWhere((folder) => folder.id == id);

  Requirement requirement(int id) =>
      requirements.firstWhere((requirement) => requirement.id == id);

  RequirementVariant variant(int id) =>
      variants.firstWhere((variant) => variant.id == id);

  RequirementFolder? containingFolder(int requirementId) {
    for (final folder in folders) {
      if (folder.requirementIds.contains(requirementId)) return folder;
    }
    return null;
  }

  Requirement createRequirement(int folderId) {
    final requirement = Requirement(
      id: nextRequirementNumber++,
      title: 'New requirement',
      description: '',
      rationale: '',
      variantId: variants.first.id,
      outgoingIds: [],
    );
    requirements.add(requirement);
    folder(folderId).requirementIds.add(requirement.id);
    nextEntityId++;
    return requirement;
  }

  RequirementFolder createFolder(int parentId) {
    final child = RequirementFolder(
      id: nextEntityId++,
      name: 'New folder',
      description: '',
      parentId: parentId,
    );
    folders.add(child);
    folder(parentId).childFolderIds.add(child.id);
    return child;
  }

  RequirementComment createComment(int folderId, int requirementId) {
    final comment = RequirementComment(
      id: nextEntityId++,
      description: 'New comment',
      attachedToId: requirementId,
    );
    comments.add(comment);
    folder(folderId).commentIds.add(comment.id);
    return comment;
  }

  bool canDeleteVariant(int variantId) =>
      !requirements.any((requirement) => requirement.variantId == variantId);

  List<int> ancestorsOfFolder(int folderId) {
    final ancestors = <int>[];
    var current = folder(folderId).parentId;
    while (current != null) {
      ancestors.add(current);
      current = folder(current).parentId;
    }
    return ancestors;
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'name': name,
    'nextRequirementNumber': nextRequirementNumber,
    'nextEntityId': nextEntityId,
    'folders': folders.map((item) => item.toJson()).toList(),
    'requirements': requirements.map((item) => item.toJson()).toList(),
    'comments': comments.map((item) => item.toJson()).toList(),
    'variants': variants.map((item) => item.toJson()).toList(),
  };

  factory RequirementProject.fromJson(Map<String, Object?> json) =>
      RequirementProject(
        name: (json['name'] as String?) ?? 'Requirements project',
        nextRequirementNumber: json['nextRequirementNumber'] as int,
        nextEntityId: json['nextEntityId'] as int,
        requirements: ((json['requirements'] as List<dynamic>?) ?? const [])
            .map((value) => Requirement.fromJson(value as Map<String, Object?>))
            .toList(),
        folders: ((json['folders'] as List<dynamic>?) ?? const [])
            .map(
              (value) =>
                  RequirementFolder.fromJson(value as Map<String, Object?>),
            )
            .toList(),
        comments: ((json['comments'] as List<dynamic>?) ?? const [])
            .map(
              (value) =>
                  RequirementComment.fromJson(value as Map<String, Object?>),
            )
            .toList(),
        variants: ((json['variants'] as List<dynamic>?) ?? const [])
            .map(
              (value) =>
                  RequirementVariant.fromJson(value as Map<String, Object?>),
            )
            .toList(),
      );

  static RequirementProject sample() => RequirementProject(
    name: 'Vehicle Control System',
    nextRequirementNumber: 132,
    nextEntityId: 1000,
    folders: [
      RequirementFolder(
        id: 1,
        name: 'Project root',
        description: '',
        requirementIds: [128],
        childFolderIds: [2, 3],
      ),
      RequirementFolder(
        id: 2,
        name: 'System',
        description: '',
        parentId: 1,
        requirementIds: [129, 130],
      ),
      RequirementFolder(
        id: 3,
        name: 'Safety',
        description: '',
        parentId: 1,
        requirementIds: [131],
      ),
    ],
    requirements: [
      Requirement(
        id: 128,
        title: 'Display vehicle state',
        description:
            'The system shall display the current operational state of the vehicle.',
        rationale:
            'Operators must be able to verify the state without external tooling.',
        variantId: 101,
        outgoingIds: [129, 130],
      ),
      Requirement(
        id: 129,
        title: 'Synchronize telemetry',
        description:
            'The system shall synchronize telemetry values at least every 100 ms.',
        rationale:
            'A predictable update interval supports closed-loop control.',
        variantId: 101,
        outgoingIds: [131],
      ),
      Requirement(
        id: 130,
        title: 'Report connection loss',
        description:
            'The system shall report a loss of communication within two seconds.',
        rationale: 'Connection faults must be visible to the operator.',
        variantId: 102,
        outgoingIds: [],
      ),
      Requirement(
        id: 131,
        title: 'Enter safe state',
        description:
            'The system shall enter a safe state when critical telemetry is unavailable.',
        rationale: 'A safe fallback limits the impact of invalid vehicle data.',
        variantId: 103,
        outgoingIds: [],
      ),
    ],
    comments: [
      RequirementComment(
        id: 900,
        description:
            'The telemetry interval was agreed during the architecture review.',
        attachedToId: 129,
      ),
    ],
    variants: [
      RequirementVariant(
        id: 101,
        parentId: 0,
        name: 'All vehicles',
        description: 'Requirements shared by all supported vehicles.',
      ),
      RequirementVariant(
        id: 102,
        parentId: 101,
        name: 'Electric',
        description: 'Electric vehicle product family.',
      ),
      RequirementVariant(
        id: 103,
        parentId: 101,
        name: 'Hybrid',
        description: 'Hybrid vehicle product family.',
      ),
    ],
  );
}

List<int> _intList(Object? value) =>
    (value as List<dynamic>? ?? const []).map((id) => id as int).toList();

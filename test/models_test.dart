import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oth_requirements/models.dart';

void main() {
  group('RequirementProject', () {
    test('creates an empty project with required root items', () {
      final project = RequirementProject.empty(name: 'Safety program');

      expect(project.name, 'Safety program');
      expect(project.requirements, isEmpty);
      expect(project.folders.single.parentId, isNull);
      expect(project.variants.single.parentId, 0);
      expect(project.nextRequirementNumber, 1);
    });

    test('adds content to an empty project root', () {
      final project = RequirementProject.empty(name: 'New project');

      final requirement = project.createRequirement(1);
      final folder = project.createFolder(1);
      final comment = project.createComment(1, requirement.id);

      expect(project.folder(1).requirementIds, [requirement.id]);
      expect(project.folder(1).childFolderIds, [folder.id]);
      expect(project.folder(1).commentIds, [comment.id]);
    });

    test(
      'moves requirements between folders without changing their content',
      () {
        final project = RequirementProject.empty(name: 'Moves');
        final source = project.createFolder(1);
        final target = project.createFolder(1);
        final requirement = project.createRequirement(source.id)
          ..title = 'Moved';
        final comment = project.createComment(source.id, requirement.id);

        expect(project.canMoveRequirement(requirement.id, source.id), isFalse);
        expect(
          () => project.moveRequirement(requirement.id, source.id),
          throwsStateError,
        );
        project.moveRequirement(requirement.id, target.id);
        expect(source.requirementIds, isEmpty);
        expect(target.requirementIds, [requirement.id]);
        expect(project.containingFolder(requirement.id), target);
        expect(project.requirement(requirement.id).title, 'Moved');
        expect(comment.relatedRequirementIds, [requirement.id]);
        final restored = RequirementProject.fromJson(
          jsonDecode(project.toPrettyJson()) as Map<String, Object?>,
        );
        expect(restored.folder(target.id).requirementIds, [requirement.id]);
      },
    );

    test(
      'moves folder trees and rejects root, same-parent and cyclic moves',
      () {
        final project = RequirementProject.empty(name: 'Folders');
        final source = project.createFolder(1);
        final child = project.createFolder(source.id);
        final destination = project.createFolder(1);
        final requirement = project.createRequirement(child.id);

        for (final (folderId, destinationId) in [
          (1, destination.id),
          (source.id, 1),
          (source.id, source.id),
          (source.id, child.id),
        ]) {
          expect(project.canMoveFolder(folderId, destinationId), isFalse);
          expect(
            () => project.moveFolder(folderId, destinationId),
            throwsStateError,
          );
        }
        project.moveFolder(source.id, destination.id);
        expect(project.folder(1).childFolderIds, [destination.id]);
        expect(destination.childFolderIds, [source.id]);
        expect(source.parentId, destination.id);
        expect(child.parentId, source.id);
        expect(child.requirementIds, [requirement.id]);
        expect(project.ancestorsOfFolder(child.id), [
          source.id,
          destination.id,
          1,
        ]);
        final restored = RequirementProject.fromJson(
          jsonDecode(project.toPrettyJson()) as Map<String, Object?>,
        );
        expect(restored.folder(source.id).parentId, destination.id);
        expect(restored.folder(destination.id).childFolderIds, [source.id]);
      },
    );

    test('only deletes empty non-root folders', () {
      final project = RequirementProject.empty(name: 'Folders');
      final requirementFolder = project.createFolder(1);
      final commentFolder = project.createFolder(1);
      final parentFolder = project.createFolder(1);
      final empty = project.createFolder(parentFolder.id);
      final requirement = project.createRequirement(requirementFolder.id);
      project.createComment(commentFolder.id, requirement.id);

      for (final id in [
        1,
        requirementFolder.id,
        commentFolder.id,
        parentFolder.id,
      ]) {
        expect(() => project.deleteFolder(id), throwsStateError);
      }
      project.deleteFolder(empty.id);
      expect(parentFolder.childFolderIds, isEmpty);
      expect(project.folders.any((folder) => folder.id == empty.id), isFalse);
      project.deleteFolder(parentFolder.id);
      expect(
        project.folder(1).childFolderIds,
        isNot(contains(parentFolder.id)),
      );
    });

    test('round trips the complete JSON database', () {
      final project = RequirementProject.sample();

      final restored = RequirementProject.fromJson(
        jsonDecode(project.toPrettyJson()) as Map<String, Object?>,
      );

      expect(restored.requirements.length, project.requirements.length);
      expect(restored.folders.length, project.folders.length);
      expect(restored.comments.length, project.comments.length);
      expect(restored.variants.length, project.variants.length);
      expect(
        restored.requirements.first.relations.map(
          (relation) => relation.targetId,
        ),
        [129, 130],
      );
      expect(
        restored.requirements.first.relations.map((relation) => relation.type),
        [RequirementRelationType.derived, RequirementRelationType.derived],
      );
    });

    test('normalizes folder tags and stacks them from root to leaf', () {
      final project = RequirementProject.empty(name: 'Tagged folders');
      final communications = project.createFolder(1)
        ..name = 'Communications'
        ..tag = 'com';
      final telemetry = project.createFolder(communications.id)
        ..name = 'Telemetry'
        ..tag = ' tel ';
      final requirement = project.createRequirement(telemetry.id);

      expect(communications.tag, 'COM');
      expect(telemetry.tag, 'TEL');
      expect(project.tagsForRequirement(requirement.id), [
        (folderId: communications.id, value: 'COM'),
        (folderId: telemetry.id, value: 'TEL'),
      ]);
      expect(project.displayIdForRequirement(requirement.id), 'REQ-001-COM-TEL');

      final restored = RequirementProject.fromJson(
        jsonDecode(project.toPrettyJson()) as Map<String, Object?>,
      );
      expect(restored.folder(telemetry.id).tag, 'TEL');
      expect(restored.displayIdForRequirement(requirement.id), 'REQ-001-COM-TEL');
    });

    test('supports relationship types and migrates legacy specifies links', () {
      final requirement = Requirement.fromJson({
        'id': 1,
        'title': 'Source',
        'description': '',
        'rationale': '',
        'variant': 101,
        'relations': [
          {'type': 'specifies', 'target': 2},
          {'type': 'related', 'target': 3},
          {'type': 'contained', 'target': 4},
        ],
      });

      expect(requirement.relations.map((relation) => relation.type), [
        RequirementRelationType.derived,
        RequirementRelationType.related,
        RequirementRelationType.contained,
      ]);
      expect(requirement.toJson()['relations'], [
        {'type': 'derived', 'target': 2},
        {'type': 'related', 'target': 3},
        {'type': 'contained', 'target': 4},
      ]);
    });

    test('migrates legacy comment attachments to Related relationships', () {
      final comment = RequirementComment.fromJson({
        'id': 12,
        'comment': 'Legacy review note',
        'attaches_too': [
          {'type': 'requirement', 'id': 4},
        ],
      });

      expect(comment.title, 'Comment');
      expect(comment.relatedRequirementIds, [4]);
      expect(comment.toJson()['relations'], [
        {'type': 'related', 'target': 4},
      ]);
    });

    test('serializes titled comments with Related requirement links', () {
      final project = RequirementProject.empty(name: 'Comment links');
      final first = project.createRequirement(1);
      final second = project.createRequirement(1);
      final comment = project.createComment(1, first.id, title: 'Review note')
        ..description = 'Check both affected requirements.'
        ..relatedRequirementIds.add(second.id);
      expect(comment.title, 'Review note');

      final restored = RequirementProject.fromJson(
        jsonDecode(project.toPrettyJson()) as Map<String, Object?>,
      );
      final restoredComment = restored.comments.single;

      expect(restoredComment.title, 'Review note');
      expect(restoredComment.description, 'Check both affected requirements.');
      expect(restoredComment.relatedRequirementIds, [first.id, second.id]);
      expect(restoredComment.toJson()['relations'], [
        {'type': 'related', 'target': first.id},
        {'type': 'related', 'target': second.id},
      ]);
    });

    test('allocates monotonically increasing requirement IDs', () {
      final project = RequirementProject.sample();
      final firstNumber = project.nextRequirementNumber;

      final created = project.createRequirement(1);
      final next = project.createRequirement(1);

      expect(created.id, firstNumber);
      expect(next.id, firstNumber + 1);
      expect(
        project.folder(1).requirementIds,
        containsAll([created.id, next.id]),
      );
      expect(project.nextRequirementNumber, firstNumber + 2);
    });

    test('does not allow a variant in use to be deleted', () {
      final project = RequirementProject.sample();

      expect(project.canDeleteVariant(101), isFalse);
      expect(project.canDeleteVariant(999), isTrue);
    });
  });
}

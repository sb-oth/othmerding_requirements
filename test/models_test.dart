import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oth_requirements/models.dart';

void main() {
  group('RequirementProject', () {
    test('round trips the complete JSON database', () {
      final project = RequirementProject.sample();

      final restored = RequirementProject.fromJson(
        jsonDecode(project.toPrettyJson()) as Map<String, Object?>,
      );

      expect(restored.requirements.length, project.requirements.length);
      expect(restored.folders.length, project.folders.length);
      expect(restored.comments.length, project.comments.length);
      expect(restored.variants.length, project.variants.length);
      expect(restored.requirements.first.outgoingIds, [129, 130]);
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

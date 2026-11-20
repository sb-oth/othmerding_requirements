import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oth_requirements/models.dart';
import 'package:oth_requirements/project_repository.dart';
import 'package:oth_requirements/requirements_graph.dart';

void main() {
  test('routes neighboring requirements directly without perimeter loops', () {
    const incoming = (isComment: false, id: 2);
    const selected = (isComment: false, id: 3);
    const outgoing = (isComment: false, id: 24);
    final layout = layoutGraph(
      selected: selected,
      nodeIds: [selected, incoming, outgoing],
      connections: [
        const GraphConnection(
          source: incoming,
          target: selected,
          type: RequirementRelationType.related,
        ),
        const GraphConnection(
          source: selected,
          target: outgoing,
          type: RequirementRelationType.derived,
        ),
      ],
    );

    expect(layout.nodes[selected]!.center, layout.size.center(Offset.zero));
    for (final route in layout.routes) {
      final source = layout.nodes[route.connection.source]!;
      final target = layout.nodes[route.connection.target]!;
      expect(route.points, hasLength(2));
      expect(route.points.first.dx, source.right);
      expect(route.points.last.dx, target.left);
      expect(route.points.first.dy, route.points.last.dy);
    }
    _expectValidLayout(layout);
  });

  test(
    'centers the selection with incoming and outgoing nodes on either side',
    () {
      const selected = (isComment: false, id: 1);
      const incoming = (isComment: false, id: 2);
      const outgoing = (isComment: false, id: 3);
      const reciprocal = (isComment: false, id: 4);
      const comment = (isComment: true, id: 1);
      final layout = layoutGraph(
        selected: selected,
        nodeIds: [selected, incoming, outgoing, reciprocal, comment],
        connections: [
          const GraphConnection(
            source: incoming,
            target: selected,
            type: RequirementRelationType.derived,
          ),
          const GraphConnection(
            source: selected,
            target: outgoing,
            type: RequirementRelationType.contained,
          ),
          const GraphConnection(
            source: selected,
            target: reciprocal,
            type: RequirementRelationType.related,
          ),
          const GraphConnection(
            source: reciprocal,
            target: selected,
            type: RequirementRelationType.derived,
          ),
          const GraphConnection(
            source: comment,
            target: selected,
            type: RequirementRelationType.related,
          ),
        ],
      );

      expect(layout.nodes[selected]!.center, layout.size.center(Offset.zero));
      expect(
        layout.nodes[incoming]!.center.dx,
        lessThan(layout.size.width / 2),
      );
      expect(
        layout.nodes[reciprocal]!.center.dx,
        lessThan(layout.size.width / 2),
      );
      expect(layout.nodes[comment]!.center.dx, lessThan(layout.size.width / 2));
      expect(
        layout.nodes[outgoing]!.center.dx,
        greaterThan(layout.size.width / 2),
      );
      _expectValidLayout(layout);
    },
  );

  test('separates mixed, reciprocal, duplicate, and comment relationships', () {
    const first = (isComment: false, id: 1);
    const second = (isComment: false, id: 2);
    const comment = (isComment: true, id: 1);
    final connections = [
      for (final type in RequirementRelationType.values)
        GraphConnection(source: first, target: second, type: type),
      const GraphConnection(
        source: second,
        target: first,
        type: RequirementRelationType.derived,
      ),
      const GraphConnection(
        source: comment,
        target: first,
        type: RequirementRelationType.related,
      ),
      const GraphConnection(
        source: first,
        target: first,
        type: RequirementRelationType.contained,
      ),
      const GraphConnection(
        source: first,
        target: second,
        type: RequirementRelationType.derived,
      ),
    ];
    final layout = layoutGraph(
      nodeIds: [first, second, comment],
      connections: connections,
    );

    expect(layout.routes, hasLength(connections.length));
    _expectValidLayout(layout);
  });

  test('keeps ports separated on a highly connected selected node', () {
    const selected = (isComment: false, id: 1);
    final neighbors = [
      for (var id = 2; id <= 31; id++) (isComment: false, id: id),
    ];
    final layout = layoutGraph(
      selected: selected,
      nodeIds: [selected, ...neighbors],
      connections: [
        for (final neighbor in neighbors)
          GraphConnection(
            source: neighbor,
            target: selected,
            type: RequirementRelationType.derived,
          ),
      ],
    );
    expect(layout.nodes[selected]!.height, greaterThan(72));
    expect(layout.nodes[selected]!.center, layout.size.center(Offset.zero));
    _expectValidLayout(layout);
  });

  test('keeps varied cross-column routes clear and monotonic', () {
    final random = math.Random(17);
    final nodes = [for (var id = 1; id <= 12; id++) (isComment: false, id: id)];
    for (var graph = 0; graph < 8; graph++) {
      final connections = [
        for (var edge = 0; edge < 30; edge++)
          GraphConnection(
            source: nodes[random.nextInt(nodes.length)],
            target: nodes[random.nextInt(nodes.length)],
            type: RequirementRelationType
                .values[random.nextInt(RequirementRelationType.values.length)],
          ),
      ];
      _expectValidLayout(
        layoutGraph(
          nodeIds: nodes,
          connections: connections,
          selected: graph.isEven ? nodes[graph] : null,
        ),
      );
    }
  });

  test('routes the complex example without overlaps', () async {
    final project = await ProjectRepository(
      path:
          'example_jsons${Platform.pathSeparator}complex_warehouse_robot.json',
    ).load();
    final layout = layoutGraph(
      nodeIds: [
        for (final requirement in project.requirements)
          (isComment: false, id: requirement.id),
        for (final comment in project.comments)
          (isComment: true, id: comment.id),
      ],
      connections: [
        for (final requirement in project.requirements)
          for (final relation in requirement.relations)
            GraphConnection(
              source: (isComment: false, id: requirement.id),
              target: (isComment: false, id: relation.targetId),
              type: relation.type,
            ),
        for (final comment in project.comments)
          for (final target in comment.relatedRequirementIds)
            GraphConnection(
              source: (isComment: true, id: comment.id),
              target: (isComment: false, id: target),
              type: RequirementRelationType.related,
            ),
      ],
    );
    expect(layout.routes.length, greaterThan(60));
    _expectValidLayout(layout);
    _expectValidLayout(
      layoutGraph(
        nodeIds: layout.nodes.keys.toList(),
        connections: layout.routes.map((route) => route.connection).toList(),
        selected: (isComment: false, id: project.requirements.first.id),
      ),
    );
  });

  testWidgets(
    'centers the selected node in the viewport on selection changes',
    (tester) async {
      final project = RequirementProject.empty(name: 'Diagram');
      final first = project.createRequirement(1)..title = 'First requirement';
      final second = project.createRequirement(1)..title = 'Second requirement';
      first.relations.add(
        RequirementRelation(
          type: RequirementRelationType.derived,
          targetId: second.id,
        ),
      );
      var selectedId = first.id;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return RequirementsGraph(
                project: project,
                requirementIds: [first.id, second.id],
                commentIds: const [],
                selectedId: selectedId,
                selectedCommentId: null,
                highlightedId: null,
                onSelect: (_) {},
                onSelectComment: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      Offset nodeCenter(String text) => tester.getCenter(
        find
            .ancestor(of: find.text(text), matching: find.byType(InkWell))
            .first,
      );

      final viewportCenter = tester.getCenter(find.byType(RequirementsGraph));
      expect(nodeCenter('First requirement'), viewportCenter);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = controller.value.clone()..setTranslationRaw(50, 50, 0);
      await tester.pump();
      update(() {});
      await tester.pumpAndSettle();
      expect(controller.value.getTranslation().x, 50);
      expect(controller.value.getTranslation().y, 50);
      update(() => selectedId = second.id);
      await tester.pumpAndSettle();
      expect(nodeCenter('Second requirement'), viewportCenter);
    },
  );

  testWidgets('renders comments as diagram nodes', (tester) async {
    final project = RequirementProject.empty(name: 'Diagram');
    final requirement = project.createRequirement(1)..title = 'Pick inventory';
    final comment = project.createComment(1, requirement.id)
      ..title = 'Review note'
      ..description = 'Check aisle clearance.';

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 600,
          child: RequirementsGraph(
            project: project,
            requirementIds: [requirement.id],
            commentIds: [comment.id],
            selectedId: requirement.id,
            selectedCommentId: null,
            highlightedId: null,
            onSelect: (_) {},
            onSelectComment: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pick inventory'), findsOneWidget);
    expect(find.text('Review note'), findsOneWidget);
    expect(find.text('Check aisle clearance.'), findsOneWidget);
  });
}

void _expectValidLayout(GraphLayout layout) {
  final routes = layout.routes;
  final ports = <Offset>{};
  final rects = layout.nodes.values.toList();
  for (var i = 0; i < rects.length; i++) {
    expect(rects[i].left, greaterThanOrEqualTo(0));
    expect(rects[i].top, greaterThanOrEqualTo(0));
    expect(rects[i].right, lessThanOrEqualTo(layout.size.width));
    expect(rects[i].bottom, lessThanOrEqualTo(layout.size.height));
    for (var j = i + 1; j < rects.length; j++) {
      expect(rects[i].overlaps(rects[j]), isFalse);
    }
  }
  for (final route in routes) {
    final source = layout.nodes[route.connection.source]!;
    final target = layout.nodes[route.connection.target]!;
    expect(
      route.points.first.dx == source.left ||
          route.points.first.dx == source.right,
      isTrue,
    );
    expect(route.points.first.dy, inExclusiveRange(source.top, source.bottom));
    expect(
      route.points.last.dx == target.left ||
          route.points.last.dx == target.right,
      isTrue,
    );
    expect(route.points.last.dy, inExclusiveRange(target.top, target.bottom));
    expect(ports.add(route.points.first), isTrue);
    expect(ports.add(route.points.last), isTrue);
    for (final point in route.points) {
      expect(point.dx, inInclusiveRange(0, layout.size.width));
      expect(point.dy, inInclusiveRange(0, layout.size.height));
    }
    if (source.center.dx != target.center.dx) {
      final left = math.min(source.left, target.left);
      final right = math.max(source.right, target.right);
      for (final point in route.points) {
        expect(point.dx, inInclusiveRange(left, right));
      }
      for (var i = 0; i < route.points.length - 1; i++) {
        final delta = route.points[i + 1].dx - route.points[i].dx;
        if (source.center.dx < target.center.dx) {
          expect(delta, greaterThanOrEqualTo(0));
        } else {
          expect(delta, lessThanOrEqualTo(0));
        }
      }
    }
    for (final rect in layout.nodes.values) {
      for (var i = 0; i < route.points.length - 1; i++) {
        expect(
          route.points[i].dx == route.points[i + 1].dx ||
              route.points[i].dy == route.points[i + 1].dy,
          isTrue,
        );
        expect(
          _crossesInterior(route.points[i], route.points[i + 1], rect),
          isFalse,
        );
      }
    }
  }
  for (var firstIndex = 0; firstIndex < routes.length; firstIndex++) {
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < routes.length;
      secondIndex++
    ) {
      final first = routes[firstIndex];
      final second = routes[secondIndex];
      for (var i = 0; i < first.points.length - 1; i++) {
        for (var j = 0; j < second.points.length - 1; j++) {
          expect(
            _segmentsOverlap(
              first.points[i],
              first.points[i + 1],
              second.points[j],
              second.points[j + 1],
            ),
            isFalse,
            reason: 'Routes $firstIndex and $secondIndex overlap',
          );
        }
      }
    }
  }
}

bool _crossesInterior(Offset a, Offset b, Rect rect) {
  if (a.dy == b.dy && a.dy > rect.top && a.dy < rect.bottom) {
    return math.max(math.min(a.dx, b.dx), rect.left) <
        math.min(math.max(a.dx, b.dx), rect.right);
  }
  if (a.dx == b.dx && a.dx > rect.left && a.dx < rect.right) {
    return math.max(math.min(a.dy, b.dy), rect.top) <
        math.min(math.max(a.dy, b.dy), rect.bottom);
  }
  return false;
}

bool _segmentsOverlap(Offset a, Offset b, Offset c, Offset d) {
  if (a.dy == b.dy && c.dy == d.dy && a.dy == c.dy) {
    return math.max(math.min(a.dx, b.dx), math.min(c.dx, d.dx)) <
        math.min(math.max(a.dx, b.dx), math.max(c.dx, d.dx));
  }
  if (a.dx == b.dx && c.dx == d.dx && a.dx == c.dx) {
    return math.max(math.min(a.dy, b.dy), math.min(c.dy, d.dy)) <
        math.min(math.max(a.dy, b.dy), math.max(c.dy, d.dy));
  }
  return false;
}

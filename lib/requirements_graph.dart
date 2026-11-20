import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

typedef GraphNodeId = ({bool isComment, int id});

class GraphConnection {
  const GraphConnection({
    required this.source,
    required this.target,
    required this.type,
  });

  final GraphNodeId source;
  final GraphNodeId target;
  final RequirementRelationType type;
}

class GraphConnectionRoute {
  const GraphConnectionRoute({required this.connection, required this.points});

  final GraphConnection connection;
  final List<Offset> points;
}

class GraphLayout {
  const GraphLayout({
    required this.nodes,
    required this.routes,
    required this.size,
  });

  final Map<GraphNodeId, Rect> nodes;
  final List<GraphConnectionRoute> routes;
  final Size size;
}

GraphLayout layoutGraph({
  required List<GraphNodeId> nodeIds,
  required List<GraphConnection> connections,
  GraphNodeId? selected,
}) {
  const nodeWidth = 208.0;
  const minNodeHeight = 72.0;
  const margin = 24.0;
  const laneSpacing = 12.0;
  const portSpacing = 12.0;
  final visibleNodes = nodeIds.toSet();
  final visibleConnections = connections
      .where(
        (edge) =>
            visibleNodes.contains(edge.source) &&
            visibleNodes.contains(edge.target),
      )
      .toList();
  final columns = List.generate(3, (_) => <GraphNodeId>[]);
  if (selected != null && visibleNodes.contains(selected)) {
    columns[1].add(selected);
    final incoming = visibleConnections
        .where((edge) => edge.target == selected && edge.source != selected)
        .map((edge) => edge.source)
        .toSet();
    final outgoing = visibleConnections
        .where((edge) => edge.source == selected && edge.target != selected)
        .map((edge) => edge.target)
        .toSet();
    for (final id in visibleNodes) {
      if (id == selected) continue;
      if (incoming.contains(id)) {
        columns[0].add(id);
      } else if (outgoing.contains(id)) {
        columns[2].add(id);
      } else {
        columns[columns[0].length <= columns[2].length ? 0 : 2].add(id);
      }
    }
  } else {
    for (final (index, id) in visibleNodes.indexed) {
      columns[index % 3].add(id);
    }
    selected = null;
  }

  final rowCount = math.max(
    1,
    columns.map((column) => column.length).reduce(math.max),
  );
  final rowOf = <GraphNodeId, int>{};
  final columnOf = <GraphNodeId, int>{};
  for (var column = 0; column < columns.length; column++) {
    final items = columns[column];
    for (var i = 0; i < items.length; i++) {
      final row = items[i] == selected ? rowCount ~/ 2 : i;
      rowOf[items[i]] = row;
      columnOf[items[i]] = column;
    }
  }

  final rowPorts = List<int>.filled(rowCount, 0);
  final rowCrossings = List<int>.filled(rowCount, 0);
  final gapCounts = [0, 0];
  final edgeGaps = <(int, int?)>[];
  for (final edge in visibleConnections) {
    final sourceColumn = columnOf[edge.source]!;
    final targetColumn = columnOf[edge.target]!;
    final sourceRow = rowOf[edge.source]!;
    final targetRow = rowOf[edge.target]!;
    rowPorts[sourceRow] += 1;
    if (sourceRow != targetRow || edge.source == edge.target) {
      rowPorts[targetRow] += 1;
    }
    if ((sourceColumn - targetColumn).abs() == 2) {
      edgeGaps.add(sourceColumn == 0 ? (0, 1) : (1, 0));
      gapCounts[0]++;
      gapCounts[1]++;
      rowCrossings[sourceRow]++;
    } else {
      final gap = sourceColumn == targetColumn
          ? (sourceColumn == 0
                ? 0
                : sourceColumn == 2
                ? 1
                : (gapCounts[0] <= gapCounts[1] ? 0 : 1))
          : math.min(sourceColumn, targetColumn);
      edgeGaps.add((gap, null));
      if (sourceRow != targetRow || edge.source == edge.target) {
        gapCounts[gap]++;
      }
    }
  }
  final columnGap = math.max(
    48.0,
    margin + math.max(gapCounts[0], gapCounts[1]) * laneSpacing,
  );
  final contentWidth = 3 * nodeWidth + 2 * columnGap;
  final width = math.max(850.0, contentWidth + 2 * margin);
  final contentLeft = (width - contentWidth) / 2;

  final nodes = <GraphNodeId, Rect>{};
  final rowTops = <double>[];
  final rowHeights = <double>[];
  final rowBottoms = <double>[];
  var y = margin;
  for (var row = 0; row < rowCount; row++) {
    final nodeHeight = math.max(
      minNodeHeight,
      margin + rowPorts[row] * portSpacing,
    );
    rowTops.add(y);
    rowHeights.add(nodeHeight);
    for (var column = 0; column < columns.length; column++) {
      for (final id in columns[column].where((id) => rowOf[id] == row)) {
        nodes[id] = Rect.fromLTWH(
          contentLeft + column * (nodeWidth + columnGap),
          y,
          nodeWidth,
          nodeHeight,
        );
      }
    }
    rowBottoms.add(y + nodeHeight);
    y += nodeHeight + margin + rowCrossings[row] * laneSpacing;
  }

  var height = math.max(420.0, y + margin);
  if (selected != null) {
    final selectedY = nodes[selected]!.center.dy;
    final extraTop = math.max(0.0, height - 2 * selectedY);
    final extraBottom = math.max(0.0, 2 * selectedY - height);
    if (extraTop > 0) {
      nodes.updateAll((_, rect) => rect.shift(Offset(0, extraTop)));
      for (var i = 0; i < rowBottoms.length; i++) {
        rowTops[i] += extraTop;
        rowBottoms[i] += extraTop;
      }
    }
    height += extraTop + extraBottom;
  }

  final usedRowPorts = List<int>.filled(rowCount, 0);
  final usedRowLanes = List<int>.filled(rowCount, 0);
  final edgePortHeights = <(int, int), double>{};
  Offset nextPort(
    GraphNodeId id,
    int edgeIndex, {
    required bool right,
    required bool selfLoop,
  }) {
    final rect = nodes[id]!;
    final row = rowOf[id]!;
    double allocateHeight() =>
        rowTops[row] +
        rowHeights[row] / 2 -
        (rowPorts[row] - 1) * portSpacing / 2 +
        usedRowPorts[row]++ * portSpacing;
    final portY = selfLoop
        ? allocateHeight()
        : edgePortHeights.putIfAbsent((edgeIndex, row), allocateHeight);
    return Offset(right ? rect.right : rect.left, portY);
  }

  final usedGapLanes = [0, 0];
  double nextGapLane(int gap) {
    final left = contentLeft + (gap + 1) * nodeWidth + gap * columnGap;
    return left + columnGap * (++usedGapLanes[gap]) / (gapCounts[gap] + 1);
  }

  // Distinct port heights and gap lanes keep parallel segments separate.
  final routes = <GraphConnectionRoute>[];
  for (var index = 0; index < visibleConnections.length; index++) {
    final edge = visibleConnections[index];
    final (sourceGap, targetGap) = edgeGaps[index];
    final sourceColumn = columnOf[edge.source]!;
    final targetColumn = columnOf[edge.target]!;
    final selfLoop = edge.source == edge.target;
    final start = nextPort(
      edge.source,
      index,
      right: sourceGap == sourceColumn,
      selfLoop: selfLoop,
    );
    final end = nextPort(
      edge.target,
      index,
      right: (targetGap ?? sourceGap) == targetColumn,
      selfLoop: selfLoop,
    );
    final points = <Offset>[start];
    if (targetGap == null && start.dy == end.dy) {
      points.add(end);
    } else if (targetGap != null) {
      final sourceLane = nextGapLane(sourceGap);
      final row = rowOf[edge.source]!;
      final crossLane =
          rowBottoms[row] + 12 + usedRowLanes[row]++ * laneSpacing;
      final targetLane = nextGapLane(targetGap);
      points.addAll([
        Offset(sourceLane, start.dy),
        Offset(sourceLane, crossLane),
        Offset(targetLane, crossLane),
        Offset(targetLane, end.dy),
        end,
      ]);
    } else {
      final sourceLane = nextGapLane(sourceGap);
      points.addAll([
        Offset(sourceLane, start.dy),
        Offset(sourceLane, end.dy),
        end,
      ]);
    }
    routes.add(GraphConnectionRoute(connection: edge, points: points));
  }
  return GraphLayout(nodes: nodes, routes: routes, size: Size(width, height));
}

class RequirementsGraph extends StatefulWidget {
  const RequirementsGraph({
    super.key,
    required this.project,
    required this.requirementIds,
    required this.commentIds,
    required this.selectedId,
    required this.selectedCommentId,
    required this.highlightedId,
    required this.onSelect,
    required this.onSelectComment,
  });

  final RequirementProject project;
  final List<int> requirementIds;
  final List<int> commentIds;
  final int? selectedId;
  final int? selectedCommentId;
  final int? highlightedId;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onSelectComment;

  @override
  State<RequirementsGraph> createState() => _RequirementsGraphState();
}

class _RequirementsGraphState extends State<RequirementsGraph> {
  final TransformationController _controller = TransformationController();
  (GraphNodeId?, Offset, Size)? _centerTarget;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.requirementIds;
    final commentIds = widget.commentIds;
    if (ids.isEmpty && commentIds.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 40),
            SizedBox(height: 12),
            Text('Select a requirement or folder to display its graph.'),
          ],
        ),
      );
    }
    final layout = layoutGraph(
      selected: widget.selectedId != null
          ? (isComment: false, id: widget.selectedId!)
          : widget.selectedCommentId != null
          ? (isComment: true, id: widget.selectedCommentId!)
          : null,
      nodeIds: [
        for (final id in ids) (isComment: false, id: id),
        for (final id in commentIds) (isComment: true, id: id),
      ],
      connections: [
        for (final requirement in widget.project.requirements)
          for (final relation in requirement.relations)
            GraphConnection(
              source: (isComment: false, id: requirement.id),
              target: (isComment: false, id: relation.targetId),
              type: relation.type,
            ),
        for (final comment in widget.project.comments)
          for (final targetId in comment.relatedRequirementIds)
            GraphConnection(
              source: (isComment: true, id: comment.id),
              target: (isComment: false, id: targetId),
              type: RequirementRelationType.related,
            ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final selected = widget.selectedId != null
            ? (isComment: false, id: widget.selectedId!)
            : widget.selectedCommentId != null
            ? (isComment: true, id: widget.selectedCommentId!)
            : null;
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final target = (
          selected,
          layout.nodes[selected]?.center ?? layout.size.center(Offset.zero),
          viewport,
        );
        if (_centerTarget != target) {
          _centerTarget = target;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _centerTarget != target) return;
            final scale = _controller.value.getMaxScaleOnAxis();
            _controller.value = Matrix4.diagonal3Values(scale, scale, 1)
              ..setTranslationRaw(
                viewport.width / 2 - target.$2.dx * scale,
                viewport.height / 2 - target.$2.dy * scale,
                0,
              );
          });
        }
        return InteractiveViewer(
          transformationController: _controller,
          minScale: 0.45,
          maxScale: 2.5,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(120),
          child: SizedBox(
            width: layout.size.width,
            height: layout.size.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GraphConnectionsPainter(routes: layout.routes),
                  ),
                ),
                for (final id in ids)
                  if (layout.nodes[(isComment: false, id: id)] case final rect?)
                    Positioned.fromRect(
                      rect: rect,
                      child: _RequirementNode(
                        requirement: widget.project.requirement(id),
                        selected: widget.selectedId == id,
                        highlighted: widget.highlightedId == id,
                        onTap: () => widget.onSelect(id),
                      ),
                    ),
                for (final id in commentIds)
                  if (layout.nodes[(isComment: true, id: id)] case final rect?)
                    Positioned.fromRect(
                      rect: rect,
                      child: _CommentNode(
                        comment: widget.project.comments.firstWhere(
                          (comment) => comment.id == id,
                        ),
                        selected: widget.selectedCommentId == id,
                        onTap: () => widget.onSelectComment(id),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentNode extends StatelessWidget {
  const _CommentNode({
    required this.comment,
    required this.selected,
    required this.onTap,
  });

  final RequirementComment comment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: selected ? 4 : 1,
      color: selected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 208,
          height: 72,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        comment.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequirementNode extends StatelessWidget {
  const _RequirementNode({
    required this.requirement,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final Requirement requirement;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? colorScheme.primary
        : highlighted
        ? Colors.teal
        : colorScheme.outlineVariant;
    return Material(
      elevation: selected ? 4 : 1,
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: borderColor,
          width: selected || highlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: onTap,
        child: SizedBox(
          width: 208,
          height: 72,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.displayId,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 3),
                Text(
                  requirement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphConnectionsPainter extends CustomPainter {
  _GraphConnectionsPainter({required this.routes});

  final List<GraphConnectionRoute> routes;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF748091)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xFF748091)
      ..style = PaintingStyle.fill;
    for (final route in routes) {
      final path = Path()..moveTo(route.points.first.dx, route.points.first.dy);
      for (final point in route.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      switch (route.connection.type) {
        case RequirementRelationType.derived:
          canvas.drawPath(path, linePaint);
          _drawArrowhead(canvas, route.points, arrowPaint, diamond: false);
        case RequirementRelationType.related:
          _drawDottedPath(canvas, path, linePaint.color);
        case RequirementRelationType.contained:
          canvas.drawPath(path, linePaint);
          _drawArrowhead(canvas, route.points, arrowPaint, diamond: true);
      }
    }
  }

  void _drawArrowhead(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    required bool diamond,
  }) {
    final end = points.last;
    final previous = points[points.length - 2];
    final direction = (end - previous) / (end - previous).distance;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final path = Path()..moveTo(end.dx, end.dy);
    if (diamond) {
      final middle = end - direction * 5;
      final back = end - direction * 10;
      path
        ..lineTo(
          middle.dx + perpendicular.dx * 5,
          middle.dy + perpendicular.dy * 5,
        )
        ..lineTo(back.dx, back.dy)
        ..lineTo(
          middle.dx - perpendicular.dx * 5,
          middle.dy - perpendicular.dy * 5,
        )
        ..close();
    } else {
      final back = end - direction * 8;
      path
        ..lineTo(back.dx + perpendicular.dx * 5, back.dy + perpendicular.dy * 5)
        ..lineTo(back.dx - perpendicular.dx * 5, back.dy - perpendicular.dy * 5)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  void _drawDottedPath(Canvas canvas, Path path, Color color) {
    final dotPaint = Paint()..color = color;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 6) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) canvas.drawCircle(tangent.position, 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphConnectionsPainter oldDelegate) =>
      oldDelegate.routes != routes;
}

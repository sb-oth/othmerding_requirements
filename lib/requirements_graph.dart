import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

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
    final primary = widget.selectedId;
    final incoming = primary == null ? <int>[] : _incomingIds(primary, ids);
    final outgoing = primary == null
        ? <int>[]
        : widget.project
              .requirement(primary)
              .relations
              .map((relation) => relation.targetId)
              .where(ids.contains)
              .toList();
    final remainder = ids
        .where(
          (id) =>
              id != primary && !incoming.contains(id) && !outgoing.contains(id),
        )
        .toList();
    final graphWidth = math
        .max(850, 240.0 * (incoming.length + outgoing.length + 2))
        .toDouble();
    final commentColumns = math.max(1, (graphWidth / 240).floor());
    final commentRows = (commentIds.length / commentColumns).ceil();
    final requirementHeight = math
        .max(420, 130.0 * (remainder.length + 4))
        .toDouble();

    return InteractiveViewer(
      transformationController: _controller,
      minScale: 0.45,
      maxScale: 2.5,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(120),
      child: SizedBox(
        width: graphWidth,
        height: requirementHeight + commentRows * 115,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final positions = <int, Offset>{};
            final commentPositions = <int, Offset>{};
            final center = Offset(
              constraints.maxWidth / 2,
              requirementHeight / 2,
            );
            if (primary != null) positions[primary] = center;
            for (var i = 0; i < incoming.length; i++) {
              positions[incoming[i]] = Offset(
                constraints.maxWidth * 0.18,
                _verticalPosition(i, incoming.length, requirementHeight),
              );
            }
            for (var i = 0; i < outgoing.length; i++) {
              positions[outgoing[i]] = Offset(
                constraints.maxWidth * 0.82,
                _verticalPosition(i, outgoing.length, requirementHeight),
              );
            }
            for (var i = 0; i < remainder.length; i++) {
              positions[remainder[i]] = Offset(
                constraints.maxWidth * (i.isEven ? 0.35 : 0.65),
                70.0 + (i ~/ 2) * 120,
              );
            }
            final actualCommentColumns = math.max(
              1,
              (constraints.maxWidth / 240).floor(),
            );
            for (var i = 0; i < commentIds.length; i++) {
              commentPositions[commentIds[i]] = Offset(
                120 + (i % actualCommentColumns) * 240,
                requirementHeight + 50 + (i ~/ actualCommentColumns) * 115,
              );
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GraphConnectionsPainter(
                      project: widget.project,
                      positions: positions,
                      commentPositions: commentPositions,
                    ),
                  ),
                ),
                for (final id in ids)
                  if (positions[id] case final position?)
                    Positioned(
                      left: position.dx - 108,
                      top: position.dy - 43,
                      child: _RequirementNode(
                        requirement: widget.project.requirement(id),
                        selected: widget.selectedId == id,
                        highlighted: widget.highlightedId == id,
                        onTap: () => widget.onSelect(id),
                      ),
                    ),
                for (final id in commentIds)
                  if (commentPositions[id] case final position?)
                    Positioned(
                      left: position.dx - 108,
                      top: position.dy - 43,
                      child: _CommentNode(
                        comment: widget.project.comments.firstWhere(
                          (comment) => comment.id == id,
                        ),
                        selected: widget.selectedCommentId == id,
                        onTap: () => widget.onSelectComment(id),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<int> _incomingIds(int selectedId, List<int> ids) => ids
      .where(
        (id) => widget.project
            .requirement(id)
            .relations
            .any((relation) => relation.targetId == selectedId),
      )
      .toList();

  double _verticalPosition(int index, int count, double height) {
    if (count == 1) return height / 2;
    return 85 + index * ((height - 170) / (count - 1));
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
  _GraphConnectionsPainter({
    required this.project,
    required this.positions,
    required this.commentPositions,
  });

  final RequirementProject project;
  final Map<int, Offset> positions;
  final Map<int, Offset> commentPositions;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF748091)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xFF748091)
      ..style = PaintingStyle.fill;
    for (final requirement in project.requirements) {
      final start = positions[requirement.id];
      if (start == null) continue;
      for (final relation in requirement.relations) {
        final targetId = relation.targetId;
        final end = positions[targetId];
        if (end == null) continue;
        final direction = end.dx >= start.dx ? 1.0 : -1.0;
        final startPoint = Offset(start.dx + direction * 108, start.dy);
        final endPoint = Offset(end.dx - direction * 108, end.dy);
        final midX = (startPoint.dx + endPoint.dx) / 2;
        final path = Path()
          ..moveTo(startPoint.dx, startPoint.dy)
          ..lineTo(midX, startPoint.dy)
          ..lineTo(midX, endPoint.dy)
          ..lineTo(endPoint.dx, endPoint.dy);
        switch (relation.type) {
          case RequirementRelationType.derived:
            canvas.drawPath(path, linePaint);
            canvas.drawPath(
              Path()
                ..moveTo(endPoint.dx, endPoint.dy)
                ..lineTo(endPoint.dx - direction * 8, endPoint.dy - 5)
                ..lineTo(endPoint.dx - direction * 8, endPoint.dy + 5)
                ..close(),
              arrowPaint,
            );
          case RequirementRelationType.related:
            _drawDottedPath(canvas, path, linePaint.color);
          case RequirementRelationType.contained:
            canvas.drawPath(path, linePaint);
            canvas.drawPath(
              Path()
                ..moveTo(endPoint.dx, endPoint.dy)
                ..lineTo(endPoint.dx - direction * 5, endPoint.dy - 5)
                ..lineTo(endPoint.dx - direction * 10, endPoint.dy)
                ..lineTo(endPoint.dx - direction * 5, endPoint.dy + 5)
                ..close(),
              arrowPaint,
            );
        }
      }
    }
    for (final comment in project.comments) {
      final start = commentPositions[comment.id];
      if (start == null) continue;
      for (final targetId in comment.relatedRequirementIds) {
        final end = positions[targetId];
        if (end == null) continue;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);
        _drawDottedPath(canvas, path, linePaint.color);
      }
    }
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
      oldDelegate.positions != positions ||
      oldDelegate.commentPositions != commentPositions ||
      oldDelegate.project != project;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

class RequirementsGraph extends StatefulWidget {
  const RequirementsGraph({
    super.key,
    required this.project,
    required this.requirementIds,
    required this.selectedId,
    required this.highlightedId,
    required this.onSelect,
  });

  final RequirementProject project;
  final List<int> requirementIds;
  final int? selectedId;
  final int? highlightedId;
  final ValueChanged<int> onSelect;

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
    if (ids.isEmpty) {
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
              .outgoingIds
              .where(ids.contains)
              .toList();
    final remainder = ids
        .where(
          (id) =>
              id != primary && !incoming.contains(id) && !outgoing.contains(id),
        )
        .toList();

    return InteractiveViewer(
      transformationController: _controller,
      minScale: 0.45,
      maxScale: 2.5,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(120),
      child: SizedBox(
        width: math.max(850, 240.0 * (incoming.length + outgoing.length + 2)),
        height: math.max(420, 130.0 * (remainder.length + 4)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final positions = <int, Offset>{};
            final center = Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2,
            );
            if (primary != null) positions[primary] = center;
            for (var i = 0; i < incoming.length; i++) {
              positions[incoming[i]] = Offset(
                constraints.maxWidth * 0.18,
                _verticalPosition(i, incoming.length, constraints.maxHeight),
              );
            }
            for (var i = 0; i < outgoing.length; i++) {
              positions[outgoing[i]] = Offset(
                constraints.maxWidth * 0.82,
                _verticalPosition(i, outgoing.length, constraints.maxHeight),
              );
            }
            for (var i = 0; i < remainder.length; i++) {
              positions[remainder[i]] = Offset(
                constraints.maxWidth * (i.isEven ? 0.35 : 0.65),
                70.0 + (i ~/ 2) * 120,
              );
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GraphConnectionsPainter(
                      project: widget.project,
                      positions: positions,
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
              ],
            );
          },
        ),
      ),
    );
  }

  List<int> _incomingIds(int selectedId, List<int> ids) => ids
      .where(
        (id) => widget.project.requirement(id).outgoingIds.contains(selectedId),
      )
      .toList();

  double _verticalPosition(int index, int count, double height) {
    if (count == 1) return height / 2;
    return 85 + index * ((height - 170) / (count - 1));
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 216,
          height: 86,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.displayId,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  requirement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
  _GraphConnectionsPainter({required this.project, required this.positions});

  final RequirementProject project;
  final Map<int, Offset> positions;

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
      for (final targetId in requirement.outgoingIds) {
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
        canvas.drawPath(path, linePaint);
        canvas.drawPath(
          Path()
            ..moveTo(endPoint.dx, endPoint.dy)
            ..lineTo(endPoint.dx - direction * 8, endPoint.dy - 5)
            ..lineTo(endPoint.dx - direction * 8, endPoint.dy + 5)
            ..close(),
          arrowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphConnectionsPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.project != project;
}

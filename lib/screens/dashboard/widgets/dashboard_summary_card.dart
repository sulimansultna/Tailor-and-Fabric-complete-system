import 'package:flutter/material.dart';

class DashboardSummaryCard extends StatefulWidget {
  const DashboardSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.direction = TextDirection.ltr,
  });

  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final TextDirection direction;

  @override
  State<DashboardSummaryCard> createState() => _DashboardSummaryCardState();
}

class _DashboardSummaryCardState extends State<DashboardSummaryCard> {
  bool hovered = false;
  bool focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused
              ? widget.accent
              : Theme.of(context).colorScheme.outlineVariant,
          width: focused ? 1.5 : 1,
        ),
        boxShadow: hovered
            ? const [
                BoxShadow(
                  color: Color(0x120d1b2a),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ]
            : const [],
      ),
      child: Focus(
        onFocusChange: (value) => setState(() => focused = value),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          widget.icon,
                          color: widget.accent,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: widget.direction,
                  child: Text(
                    widget.value,
                    softWrap: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

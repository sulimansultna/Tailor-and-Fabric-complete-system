import 'package:flutter/material.dart';

import 'premium_illustration.dart';

class DashboardSummaryCard extends StatefulWidget {
  const DashboardSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    required this.mark,
    required this.accent,
    required this.onTap,
    this.badge,
    this.valueColor,
  });

  final String label;
  final String value;
  final String description;
  final PremiumMark mark;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
  final Color? valueColor;

  @override
  State<DashboardSummaryCard> createState() => _DashboardSummaryCardState();
}

class _DashboardSummaryCardState extends State<DashboardSummaryCard> {
  bool hovered = false;
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final surface = Color.alphaBlend(
      widget.accent.withValues(alpha: dark ? .14 : .07),
      scheme.surface,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(
          0,
          hovered && !reduceMotion ? -2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focused ? widget.accent : scheme.outlineVariant,
            width: focused ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: hovered ? (dark ? .34 : .10) : (dark ? .22 : .05),
              ),
              blurRadius: hovered ? 16 : 10,
              offset: Offset(0, hovered ? 6 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            focusColor: widget.accent.withValues(alpha: .12),
            onFocusChange: (value) => setState(() => focused = value),
            child: Semantics(
              button: true,
              label: '${widget.label}. ${widget.value}. ${widget.description}',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      PremiumMarkIcon(
                        mark: widget.mark,
                        accent: widget.accent,
                        size: 48,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                if (widget.badge != null) ...[
                                  _Badge(
                                    label: widget.badge!,
                                    color: widget.accent,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  widget.value,
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    color: widget.valueColor ?? scheme.onSurface,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class DashboardMiniMetric extends StatelessWidget {
  const DashboardMiniMetric({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    required this.mark,
    required this.accent,
    required this.onTap,
    this.valueColor,
  });

  final String label;
  final String value;
  final String description;
  final PremiumMark mark;
  final Color accent;
  final VoidCallback onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                PremiumMarkIcon(mark: mark, accent: accent, size: 36),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          value,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: valueColor ?? scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

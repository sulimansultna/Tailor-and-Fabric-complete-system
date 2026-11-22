import 'package:flutter/material.dart';

/// A recognizable icon and color for a shop cost.
class ExpenseVisual {
  const ExpenseVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// Maps the shop's saved category names to pictures a tailor can recognize
/// without reading the English name.
ExpenseVisual expenseVisualFor(String? raw) {
  final name = (raw ?? '').trim().toLowerCase();
  bool has(String part) => name.contains(part);
  if (has('electric')) {
    return const ExpenseVisual(Icons.bolt_rounded, Color(0xfff59e0b));
  }
  if (has('water')) {
    return const ExpenseVisual(Icons.water_drop_rounded, Color(0xff0284c7));
  }
  if (has('needle') || has('button') || has('zipper')) {
    return const ExpenseVisual(Icons.checkroom_rounded, Color(0xffdb2777));
  }
  if (has('thread') || has('sewing')) {
    return const ExpenseVisual(Icons.content_cut_rounded, Color(0xffbe185d));
  }
  if (has('repair')) {
    return const ExpenseVisual(Icons.build_rounded, Color(0xffb45309));
  }
  if (has('maintenance') || has('machine')) {
    return const ExpenseVisual(Icons.settings_rounded, Color(0xff0f766e));
  }
  if (has('transport')) {
    return const ExpenseVisual(Icons.local_shipping_rounded, Color(0xff2563eb));
  }
  if (has('clean')) {
    return const ExpenseVisual(
      Icons.cleaning_services_rounded,
      Color(0xff059669),
    );
  }
  if (has('food') || has('tea')) {
    return const ExpenseVisual(Icons.emoji_food_beverage, Color(0xffc2410c));
  }
  if (has('internet') || has('phone')) {
    return const ExpenseVisual(Icons.smartphone_rounded, Color(0xff4f46e5));
  }
  if (has('rent')) {
    return const ExpenseVisual(Icons.home_rounded, Color(0xff7c3aed));
  }
  if (has('utilit')) {
    return const ExpenseVisual(Icons.lightbulb_rounded, Color(0xffd97706));
  }
  if (has('suppli')) {
    return const ExpenseVisual(Icons.inventory_2_rounded, Color(0xff0f766e));
  }
  if (name == 'other' || has('other')) {
    return const ExpenseVisual(Icons.more_horiz_rounded, Color(0xff64748b));
  }
  return const ExpenseVisual(Icons.receipt_long_rounded, Color(0xff087f8c));
}

/// Shows the built-in category names in Pashto or Dari. A name the shop
/// typed itself is left unchanged.
String expenseCategoryLabel(BuildContext context, String name) {
  final language = Localizations.localeOf(context).languageCode;
  if (language == 'en') return name;
  const labels = <String, (String, String)>{
    'shop rent': ('د دوکان کرایه', 'کرایه دکان'),
    'rent': ('کرایه', 'کرایه'),
    'electricity': ('برېښنا', 'برق'),
    'water': ('اوبه', 'آب'),
    'thread and sewing supplies': ('تار او ګنډلو سامان', 'نخ و لوازم خیاطی'),
    'needles, buttons, and zippers': ('ستنې، ګڼۍ او زېپ', 'سوزن، دکمه و زیپ'),
    'machine repairs': ('د ماشین جوړول', 'ترمیم ماشین'),
    'machine maintenance': ('د ماشین ساتنه', 'نگهداری ماشین'),
    'transport': ('کرایه موټر', 'کرایه موتر'),
    'cleaning': ('پاکول', 'نظافت'),
    'shop food and tea': ('چای او خواړه', 'چای و غذا'),
    'internet and phone': ('انټرنېټ او تلیفون', 'انترنت و تلفن'),
    'other': ('نور', 'سایر'),
    'utilities': ('اسانتیاوې', 'خدمات'),
    'supplies': ('سامان', 'لوازم'),
  };
  final translated = labels[name.trim().toLowerCase()];
  if (translated == null) return name;
  return language == 'ps' ? translated.$1 : translated.$2;
}

ExpenseVisual paymentVisual(String method) => switch (method) {
  'Cash' => const ExpenseVisual(Icons.payments_rounded, Color(0xff059669)),
  'Bank transfer' => const ExpenseVisual(
    Icons.account_balance_rounded,
    Color(0xff2563eb),
  ),
  'Card' => const ExpenseVisual(Icons.credit_card_rounded, Color(0xff7c3aed)),
  _ => const ExpenseVisual(Icons.more_horiz_rounded, Color(0xff64748b)),
};

Color expenseStatusColor(String status, ColorScheme scheme) => switch (status) {
  'Posted' => const Color(0xff059669),
  'Reversed' => scheme.error,
  'Reversal' => const Color(0xffd97706),
  _ => scheme.primary,
};

class ExpenseIconBadge extends StatelessWidget {
  const ExpenseIconBadge({super.key, this.name, this.visual, this.size = 42});

  final String? name;
  final ExpenseVisual? visual;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = visual ?? expenseVisualFor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: mark.color,
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [
          BoxShadow(
            color: mark.color.withValues(alpha: .28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(mark.icon, color: Colors.white, size: size * .52),
    );
  }
}

class ExpenseChoice extends StatelessWidget {
  const ExpenseChoice({
    super.key,
    required this.label,
    required this.visual,
    required this.selected,
    required this.onTap,
    this.expandLabel = false,
  });

  final String label;
  final ExpenseVisual visual;
  final bool selected;
  final VoidCallback onTap;
  final bool expandLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected
        ? visual.color
        : visual.color.withValues(alpha: .12);
    final iconColor = selected ? Colors.white : visual.color;
    final textColor = selected ? Colors.white : scheme.onSurface;
    final text = Text(
      label,
      maxLines: expandLabel ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
    );
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: expandLabel ? 220 : 180,
            minHeight: 44,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(visual.icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Flexible(child: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExpenseMetricCard extends StatelessWidget {
  const ExpenseMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.visual,
    this.caption,
  });

  final String label;
  final String value;
  final ExpenseVisual visual;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = Color.alphaBlend(
      visual.color.withValues(alpha: dark ? .18 : .09),
      scheme.surface,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: visual.color.withValues(alpha: .28)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 92),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ExpenseIconBadge(visual: visual, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: visual.color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseQuickFilter extends StatelessWidget {
  const ExpenseQuickFilter({
    super.key,
    required this.label,
    required this.visual,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ExpenseVisual visual;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: selected ? visual.color.withValues(alpha: .14) : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? visual.color : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 104,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                children: [
                  ExpenseIconBadge(visual: visual, size: 36),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: scheme.onSurface,
                      ),
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
}

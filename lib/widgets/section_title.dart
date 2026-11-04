import 'package:flutter/material.dart';

Widget sectionTitle(BuildContext context, String title, {Widget? trailing}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );

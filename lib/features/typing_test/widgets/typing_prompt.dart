import 'package:flutter/material.dart';

class TypingPrompt extends StatelessWidget {
  final String prompt;
  final String typed;
  const TypingPrompt({super.key, required this.prompt, required this.typed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);
    final bright =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        children: [
          for (var i = 0; i < prompt.length; i++)
            TextSpan(
              text: prompt[i],
              style: TextStyle(
                color: i < typed.length
                    ? (typed[i] == prompt[i] ? bright : const Color(0xFFE53E3E))
                    : muted,
                backgroundColor: i < typed.length && typed[i] != prompt[i]
                    ? const Color(0xFFFFE0E0)
                    : i < typed.length
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08)
                    : null,
                decoration: i == typed.length ? TextDecoration.underline : null,
                decorationColor: Theme.of(context).colorScheme.primary,
                decorationThickness: 2,
              ),
            ),
          // cursor after prompt when complete
          if (typed.length >= prompt.length)
            TextSpan(
              text: ' ',
              style: TextStyle(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
        ],
      ),
    );
  }
}

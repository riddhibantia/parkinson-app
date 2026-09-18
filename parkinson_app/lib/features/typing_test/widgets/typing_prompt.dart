import 'package:flutter/material.dart';

class TypingPrompt extends StatelessWidget {
  final String prompt;
  final String typed;
  const TypingPrompt({super.key, required this.prompt, required this.typed});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge,
        children: [
          for (var i = 0; i < prompt.length; i++)
            TextSpan(
              text: prompt[i],
              style: TextStyle(
                color: i < typed.length
                    ? (typed[i] == prompt[i] ? Colors.teal : Colors.orange)
                    : Theme.of(context).textTheme.bodyLarge?.color,
                backgroundColor: i < typed.length
                    ? Colors.teal.withValues(alpha: 0.08)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

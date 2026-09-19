import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton shimmer for loading states (dashboard/insights).
class LoadingShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  const LoadingShimmer({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class CardShimmer extends StatelessWidget {
  const CardShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LoadingShimmer(height: 96),
        SizedBox(height: 12),
        LoadingShimmer(height: 96),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class Refreshable extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const Refreshable({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child is ScrollView
          ? child
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [child],
            ),
    );
  }
}

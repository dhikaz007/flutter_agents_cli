import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

enum SpacingSize {
  size_0(0),
  size_4(4),
  size_8(8),
  size_12(12),
  size_16(16),
  size_20(20),
  size_24(24),
  size_28(28),
  size_32(32),
  size_36(36),
  size_40(40);

  final double value;
  const SpacingSize(this.value);
}

class AppSpacing extends StatelessWidget {
  final SpacingSize size;
  const AppSpacing({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Gap(size.value);
  }
}

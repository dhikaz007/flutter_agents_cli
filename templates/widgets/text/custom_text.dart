import 'package:flutter/material.dart';

enum FontAppSize {
  h7(10),
  h6(12),
  h5(14),
  h4(16),
  h3(20),
  h2(24),
  h1(32),
  title(40);

  final double value;
  const FontAppSize(this.value);
}

enum FontAppWeight {
  normal(FontWeight.w400),
  medium(FontWeight.w500),
  semiBold(FontWeight.w600),
  bold(FontWeight.w700);

  final FontWeight value;
  const FontAppWeight(this.value);
}

class CustomText extends StatelessWidget {
  final String text;
  final FontAppSize size;
  final FontAppWeight weight;
  final Color? color;
  final int? maxLines;
  final TextAlign? align;
  final TextOverflow? overflow;
  final bool selectable;
  final TextDecoration? decoration;
  final FontStyle? fontStyle;
  final List<FontFeature>? fontFeature;
  final double? letterSpacing;
  const CustomText({
    super.key,
    required this.text,
    this.size = FontAppSize.h5,
    this.weight = FontAppWeight.normal,
    this.color,
    this.maxLines,
    this.align,
    this.overflow,
    this.decoration,
    this.fontStyle,
    this.fontFeature,
    this.letterSpacing,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size.value,
      fontWeight: weight.value,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      decoration: decoration,
      fontStyle: fontStyle,
      fontFeatures: fontFeature,
      letterSpacing: letterSpacing,
    );
    if (selectable) {
      return SelectableText(
        text,
        style: style,
        maxLines: maxLines,
        textAlign: align,
      );
    }
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      textAlign: align,
      overflow: overflow,
    );
  }
}

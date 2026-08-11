import 'package:flutter/material.dart';

class MuffinMascotIcon extends StatelessWidget {
  const MuffinMascotIcon({
    this.size = 34,
    this.semanticLabel = 'Muffin mascot',
    super.key,
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: Text(
          '\u{1F436}',
          style: TextStyle(fontSize: size, height: 1),
        ),
      ),
    );
  }
}

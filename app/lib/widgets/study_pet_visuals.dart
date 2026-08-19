import 'package:flutter/material.dart';

import '../models/study_pet.dart';

class StudyEggAvatar extends StatelessWidget {
  const StudyEggAvatar({
    required this.egg,
    this.size = 92,
    this.selected = false,
    super.key,
  });

  final StudyEggDefinition egg;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.11),
      decoration: BoxDecoration(
        color: Color(egg.secondaryColor),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Color(egg.primaryColor) : const Color(0xFFE2E8E3),
          width: selected ? 3 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Color(egg.primaryColor).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFFFFF),
              Color(egg.secondaryColor),
              Color(egg.primaryColor),
            ],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size),
            topRight: Radius.circular(size),
            bottomLeft: Radius.circular(size * 0.72),
            bottomRight: Radius.circular(size * 0.72),
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: size * 0.18,
            height: size * 0.18,
            margin: EdgeInsets.only(bottom: size * 0.18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class StudyPetAvatar extends StatelessWidget {
  const StudyPetAvatar({
    required this.pet,
    this.size = 92,
    super.key,
  });

  final StudyPetDefinition pet;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(pet.primaryColor).withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8E3)),
      ),
      alignment: Alignment.center,
      child: Text(
        pet.icon,
        style: TextStyle(fontSize: size * 0.48),
      ),
    );
  }
}

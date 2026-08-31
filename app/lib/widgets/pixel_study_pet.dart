import 'package:flutter/material.dart';

import '../models/study_pet.dart';

enum PixelPetMotion { idle, walk, hop }

class PixelPetFrame {
  const PixelPetFrame(this.rows);

  final List<String> rows;

  int get width =>
      rows.fold<int>(0, (max, row) => row.length > max ? row.length : max);
  int get height => rows.length;
}

class PixelPetSpriteSet {
  const PixelPetSpriteSet({
    required this.petId,
    required this.idleFrames,
    required this.moveFrames,
    required this.palette,
    required this.movement,
  });

  final StudyPetId petId;
  final List<PixelPetFrame> idleFrames;
  final List<PixelPetFrame> moveFrames;
  final Map<String, Color> palette;
  final PixelPetMotion movement;

  List<PixelPetFrame> framesFor(PixelPetMotion motion) {
    if (motion == PixelPetMotion.idle) return idleFrames;
    return moveFrames;
  }
}

class PixelStudyPet extends StatelessWidget {
  const PixelStudyPet({
    required this.pet,
    required this.motion,
    required this.frame,
    this.growthStage = StudyPetGrowthStage.hatchling,
    this.facingRight = true,
    this.size = 48,
    this.groundShadow = true,
    super.key,
  });

  final StudyPetDefinition pet;
  final PixelPetMotion motion;
  final int frame;
  final StudyPetGrowthStage growthStage;
  final bool facingRight;
  final double size;
  final bool groundShadow;

  PixelPetSpriteSet get spriteSet => pixelSpriteSetFor(
        pet.id,
        growthStage: growthStage,
      );

  @override
  Widget build(BuildContext context) {
    final set = spriteSet;
    final frames = set.framesFor(motion);
    final selectedFrame = frames[frame % frames.length];
    return SizedBox(
      width: size,
      height: size,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(facingRight ? 1.0 : -1.0, 1.0),
        child: CustomPaint(
          painter: _PixelPetPainter(
            frame: selectedFrame,
            palette: set.palette,
            shadowColor: Theme.of(context).colorScheme.shadow.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.28
                    : 0.16),
            groundShadow: groundShadow,
          ),
        ),
      ),
    );
  }
}

PixelPetSpriteSet pixelSpriteSetFor(
  StudyPetId petId, {
  StudyPetGrowthStage growthStage = StudyPetGrowthStage.hatchling,
}) {
  final base = switch (petId) {
    StudyPetId.fox => _foxSprites,
    StudyPetId.bunny => _bunnySprites,
    StudyPetId.cat => _catSprites,
  };
  if (growthStage == StudyPetGrowthStage.hatchling) return base;
  return _growthSpriteSet(base, growthStage);
}

PixelPetSpriteSet _growthSpriteSet(
  PixelPetSpriteSet base,
  StudyPetGrowthStage growthStage,
) {
  final accent = switch (base.petId) {
    StudyPetId.fox => const Color(0xFFFFD76A),
    StudyPetId.bunny => const Color(0xFFD9F0AF),
    StudyPetId.cat => const Color(0xFFFFE78A),
  };
  return PixelPetSpriteSet(
    petId: base.petId,
    idleFrames: _decorateFrames(base.idleFrames, growthStage, base.petId),
    moveFrames: _decorateFrames(base.moveFrames, growthStage, base.petId),
    palette: {
      ...base.palette,
      'a': accent,
      'b': Color.lerp(accent, Colors.white, 0.35)!,
    },
    movement: base.movement,
  );
}

List<PixelPetFrame> _decorateFrames(
  List<PixelPetFrame> frames,
  StudyPetGrowthStage growthStage,
  StudyPetId petId,
) {
  return [
    for (final frame in frames) _decorateFrame(frame, growthStage, petId),
  ];
}

PixelPetFrame _decorateFrame(
  PixelPetFrame frame,
  StudyPetGrowthStage growthStage,
  StudyPetId petId,
) {
  final rows = frame.rows.toList();
  if (petId == StudyPetId.bunny) {
    if (growthStage.index >= StudyPetGrowthStage.young.index) {
      _put(rows, 5, 4, 'a');
      _put(rows, 5, 11, 'a');
      _put(rows, 8, 13, 'c');
      _put(rows, 10, 4, 'c');
      _put(rows, 10, 11, 'c');
    }
    if (growthStage.index >= StudyPetGrowthStage.evolved.index) {
      _put(rows, 0, 5, 'b');
      _put(rows, 0, 9, 'b');
      _put(rows, 4, 5, 'b');
      _put(rows, 4, 9, 'b');
      _put(rows, 7, 2, 'a');
      _put(rows, 7, 13, 'a');
    }
    if (growthStage.index >= StudyPetGrowthStage.adult.index) {
      _put(rows, 1, 4, 'b');
      _put(rows, 1, 10, 'b');
      _put(rows, 9, 4, 'b');
      _put(rows, 9, 11, 'b');
      _put(rows, 11, 12, 'a');
    }
    return PixelPetFrame(rows);
  }
  if (growthStage.index >= StudyPetGrowthStage.young.index) {
    _put(rows, 1, 6, 'a');
    _put(rows, 2, petId == StudyPetId.cat ? 8 : 9, 'a');
  }
  if (growthStage.index >= StudyPetGrowthStage.evolved.index) {
    _put(rows, 0, 5, 'b');
    _put(rows, 0, 10, 'b');
    _put(rows, 6, petId == StudyPetId.fox ? 14 : 2, 'a');
  }
  if (growthStage.index >= StudyPetGrowthStage.adult.index) {
    _put(rows, 3, 3, 'b');
    _put(rows, 3, 12, 'b');
    _put(rows, 9, petId == StudyPetId.bunny ? 12 : 13, 'a');
  }
  return PixelPetFrame(rows);
}

void _put(List<String> rows, int y, int x, String value) {
  if (y < 0 || y >= rows.length) return;
  final row = rows[y];
  if (x < 0 || x >= row.length) return;
  rows[y] = row.substring(0, x) + value + row.substring(x + 1);
}

const _transparent = '.';

final _foxSprites = PixelPetSpriteSet(
  petId: StudyPetId.fox,
  movement: PixelPetMotion.walk,
  palette: const {
    'o': Color(0xFFE88755),
    'd': Color(0xFF9D4E35),
    'c': Color(0xFFFFE3C4),
    'e': Color(0xFF2E2B28),
    's': Color(0xFFFFD76A),
  },
  idleFrames: const [
    PixelPetFrame([
      '................',
      '.....o...o......',
      '....ooo.ooo.....',
      '....ooooooo.....',
      '..oooeooeooo....',
      '.ooooocooooo....',
      'ooooooccoooo.c..',
      '.ooooooooodccc..',
      '..oo.ooooodcc...',
      '..d...d.........',
      '......s.........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '.....o...o......',
      '....ooo.ooo.....',
      '....ooooooo.....',
      '..oooeooeooo....',
      '.ooooocooooo....',
      'ooooooccoooo..c.',
      '.ooooooooodcccc.',
      '..oo.ooooodcc...',
      '..d...d.........',
      '................',
      '......s.........',
    ]),
  ],
  moveFrames: const [
    PixelPetFrame([
      '................',
      '.....o...o......',
      '....ooo.ooo.....',
      '....ooooooo.....',
      '..oooeooeooo....',
      '.ooooocooooo....',
      'ooooooccoooo.c..',
      '.ooooooooodccc..',
      '..o..ooooodcc...',
      '.d....d.........',
      '......s.........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '.....o...o......',
      '....ooo.ooo.....',
      '....ooooooo.....',
      '..oooeooeooo....',
      '.ooooocooooo....',
      'ooooooccoooo..c.',
      '.ooooooooodcccc.',
      '..oo.ooooodcc...',
      '..d.d...........',
      '................',
      '......s.........',
    ]),
    PixelPetFrame([
      '................',
      '.....o...o......',
      '....ooo.ooo.....',
      '....ooooooo.....',
      '..oooeooeooo....',
      '.ooooocooooo....',
      'ooooooccoooo.c..',
      '.ooooooooodccc..',
      '..oo..ooodcc....',
      '...d...d........',
      '......s.........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '.....o...o......',
      '....ooo.ooo.....',
      '....ooooooo.....',
      '..oooeooeooo....',
      '.ooooocooooo....',
      'ooooooccoooo..c.',
      '.ooooooooodcccc.',
      '..oo.ooooodcc...',
      '.d..d...........',
      '................',
      '......s.........',
    ]),
  ],
);

final _bunnySprites = PixelPetSpriteSet(
  petId: StudyPetId.bunny,
  movement: PixelPetMotion.hop,
  palette: const {
    'g': Color(0xFF82B58D),
    'd': Color(0xFF4B7C5A),
    'c': Color(0xFFEAF6DF),
    'e': Color(0xFF27352D),
    'i': Color(0xFFFFC7D8),
    'l': Color(0xFFB7D957),
  },
  idleFrames: const [
    PixelPetFrame([
      '................',
      '....gg...gg.....',
      '....ii...ii.....',
      '....ggg.ggg.....',
      '...ggggggggg....',
      '..gggegggegg....',
      '.gggggccgggg....',
      '..gggccccgg.....',
      '..ggggggggg.....',
      '...gggggg.......',
      '...dd..dd.......',
      '.......l........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '....gg...gg.....',
      '....ii...ii.....',
      '....ggg.ggg.....',
      '...ggggggggg....',
      '..gggegggegg....',
      '.gggggccgggg....',
      '..gggccccgg.....',
      '..ggggggggg.....',
      '...gggggg.......',
      '....dddd........',
      '.......l........',
      '................',
    ]),
  ],
  moveFrames: const [
    PixelPetFrame([
      '................',
      '....gg...gg.....',
      '....ii...ii.....',
      '....ggg.ggg.....',
      '...ggggggggg....',
      '..gggegggegg....',
      '.gggggccgggg....',
      '..gggccccgg.....',
      '..ggggggggg.....',
      '...gggggg.......',
      '...dd..dd.......',
      '.......l........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '................',
      '....gg...gg.....',
      '....ii...ii.....',
      '....ggg.ggg.....',
      '...ggggggggg....',
      '..gggegggegg....',
      '.gggggccgggg....',
      '..gggccccgg.....',
      '..ggggggggg.....',
      '...d....d.l.....',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '................',
      '....gg...gg.....',
      '....ii...ii.....',
      '....ggg.ggg.....',
      '..ggggggggg.....',
      '.gggegggegg.....',
      '.gggggccgggg....',
      '..gggccccgg.....',
      '...gggggg.......',
      '....d..d.l......',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '....gg...gg.....',
      '....ii...ii.....',
      '....ggg.ggg.....',
      '...ggggggggg....',
      '..gggegggegg....',
      '.gggggccgggg....',
      '..gggccccgg.....',
      '..ggggggggg.....',
      '..dd....dd......',
      '.......l........',
      '................',
    ]),
  ],
);

final _catSprites = PixelPetSpriteSet(
  petId: StudyPetId.cat,
  movement: PixelPetMotion.walk,
  palette: const {
    'p': Color(0xFF8F96D6),
    'd': Color(0xFF5F66A8),
    'c': Color(0xFFEDEBFF),
    'e': Color(0xFF29283A),
    'm': Color(0xFFFFE78A),
  },
  idleFrames: const [
    PixelPetFrame([
      '................',
      '....p.....p.....',
      '....pp...pp.....',
      '....ppppppp.....',
      '..pppeppepp.....',
      '.pppppcpppp.....',
      '.ppppccc.ppp....',
      '..ppppppppdp....',
      '....pppppddp....',
      '...d....d.......',
      '.....m..........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '....p.....p.....',
      '....pp...pp.....',
      '....ppppppp.....',
      '..pppeppepp.....',
      '.pppppcpppp.....',
      '.ppppccc.ppp....',
      '..ppppppppddp...',
      '....ppppp.ddp...',
      '...d....d.......',
      '................',
      '.....m..........',
    ]),
  ],
  moveFrames: const [
    PixelPetFrame([
      '................',
      '....p.....p.....',
      '....pp...pp.....',
      '....ppppppp.....',
      '..pppeppepp.....',
      '.pppppcpppp.....',
      '.ppppccc.ppp....',
      '..ppppppppdp....',
      '....pppppddp....',
      '..d.....d.......',
      '.....m..........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '....p.....p.....',
      '....pp...pp.....',
      '....ppppppp.....',
      '..pppeppepp.....',
      '.pppppcpppp.....',
      '.ppppccc.ppp....',
      '..ppppppppddp...',
      '....ppppp.ddp...',
      '...d..d.........',
      '................',
      '.....m..........',
    ]),
    PixelPetFrame([
      '................',
      '....p.....p.....',
      '....pp...pp.....',
      '....ppppppp.....',
      '..pppeppepp.....',
      '.pppppcpppp.....',
      '.ppppccc.ppp....',
      '..ppppppppdp....',
      '....pppppddp....',
      '...d.....d......',
      '.....m..........',
      '................',
    ]),
    PixelPetFrame([
      '................',
      '....p.....p.....',
      '....pp...pp.....',
      '....ppppppp.....',
      '..pppeppepp.....',
      '.pppppcpppp.....',
      '.ppppccc.ppp....',
      '..ppppppppddp...',
      '....ppppp.ddp...',
      '..d..d..........',
      '................',
      '.....m..........',
    ]),
  ],
);

class _PixelPetPainter extends CustomPainter {
  const _PixelPetPainter({
    required this.frame,
    required this.palette,
    required this.shadowColor,
    required this.groundShadow,
  });

  final PixelPetFrame frame;
  final Map<String, Color> palette;
  final Color shadowColor;
  final bool groundShadow;

  @override
  void paint(Canvas canvas, Size size) {
    final block = (size.width / frame.width).floorToDouble().clamp(1.0, 8.0);
    final spriteWidth = block * frame.width;
    final spriteHeight = block * frame.height;
    final left = ((size.width - spriteWidth) / 2).roundToDouble();
    final top = (size.height - spriteHeight - block).roundToDouble();
    if (groundShadow) {
      final shadowBlock = block.roundToDouble();
      final shadowTop = size.height - shadowBlock * 1.3;
      final paint = Paint()..color = shadowColor;
      canvas.drawRect(
        Rect.fromLTWH(
          left + shadowBlock * 4,
          shadowTop,
          shadowBlock * 8,
          shadowBlock,
        ),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          left + shadowBlock * 6,
          shadowTop - shadowBlock,
          shadowBlock * 4,
          shadowBlock,
        ),
        paint,
      );
    }

    final paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;
    for (var y = 0; y < frame.rows.length; y += 1) {
      final row = frame.rows[y];
      for (var x = 0; x < row.length; x += 1) {
        final key = row[x];
        if (key == _transparent) continue;
        final color = palette[key];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            left + x * block,
            top + y * block,
            block,
            block,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPetPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.palette != palette ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.groundShadow != groundShadow;
  }
}

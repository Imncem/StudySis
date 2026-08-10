import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/muffin.dart';
import '../models/page_translation.dart';
import '../screens/muffin_screen.dart';
import '../services/muffin_context_registry.dart';
import 'muffin_assist_sheet.dart';
import 'page_translation_scope.dart';

class FloatingMuffinShell extends StatefulWidget {
  const FloatingMuffinShell({
    required this.child,
    this.enabled = true,
    this.navigatorKey,
    this.translationController,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final GlobalKey<NavigatorState>? navigatorKey;
  final PageTranslationController? translationController;

  @override
  State<FloatingMuffinShell> createState() => _FloatingMuffinShellState();
}

class _FloatingMuffinShellState extends State<FloatingMuffinShell> {
  static const _edgeKey = 'floating_muffin_edge';
  static const _topKey = 'floating_muffin_top';
  static const _size = 56.0;
  static const _margin = 14.0;
  static const _tapMovementThreshold = 8.0;

  bool _rightEdge = true;
  double? _top;
  double? _dragLeft;
  double? _pointerStartLeft;
  double _pointerMovement = 0;
  bool _pointerDragging = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _restorePosition();
  }

  Future<void> _restorePosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rightEdge = prefs.getString(_edgeKey) != 'left';
      _top = prefs.getDouble(_topKey);
    });
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_edgeKey, _rightEdge ? 'right' : 'left');
    if (_top != null) await prefs.setDouble(_topKey, _top!);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final keyboardOpen = media.viewInsets.bottom > 0;
        final minTop = media.padding.top + _margin;
        final maxTop =
            constraints.maxHeight - media.padding.bottom - _size - _margin;
        final top = (_top ?? constraints.maxHeight * 0.72)
            .clamp(minTop, maxTop)
            .toDouble();
        final edgeLeft =
            _rightEdge ? constraints.maxWidth - _size - _margin : _margin;
        final left = (_dragLeft ?? edgeLeft)
            .clamp(_margin, constraints.maxWidth - _size - _margin)
            .toDouble();
        return Stack(
          children: [
            widget.child,
            if (!keyboardOpen && !_sheetOpen)
              Positioned(
                key: const ValueKey('floating-muffin-positioned'),
                top: top,
                left: left,
                child: Semantics(
                  container: true,
                  button: true,
                  label: 'Open Muffin learning assistant',
                  onTap: _handleTap,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleTap,
                    onPanStart: (_) => _startPointerGesture(left),
                    onPanUpdate: (details) => _movePointerGesture(
                      details.delta,
                      left: left,
                      top: top,
                      minTop: minTop,
                      maxTop: maxTop,
                      maxLeft: constraints.maxWidth - _size - _margin,
                    ),
                    onPanEnd: (_) => _endPointerGesture(constraints.maxWidth),
                    onPanCancel: _cancelPointerGesture,
                    child: Material(
                      color: const Color(0xFFFFE6D5),
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: const SizedBox(
                        width: _size,
                        height: _size,
                        child: Icon(
                          Icons.psychology_rounded,
                          color: Color(0xFFA45E37),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _startPointerGesture(double left) {
    _pointerStartLeft = left;
    _pointerMovement = 0;
    _pointerDragging = false;
    _dragLeft = left;
  }

  void _movePointerGesture(
    Offset delta, {
    required double left,
    required double top,
    required double minTop,
    required double maxTop,
    required double maxLeft,
  }) {
    _pointerMovement += delta.distance;
    if (_pointerMovement <= _tapMovementThreshold && !_pointerDragging) {
      return;
    }

    _pointerDragging = true;
    setState(() {
      _dragLeft = ((_dragLeft ?? _pointerStartLeft ?? left) + delta.dx)
          .clamp(_margin, maxLeft)
          .toDouble();
      _top = ((_top ?? top) + delta.dy).clamp(minTop, maxTop).toDouble();
    });
  }

  void _endPointerGesture(double maxWidth) {
    if (_pointerDragging) {
      final center = (_dragLeft ?? _pointerStartLeft ?? 0) + _size / 2;
      setState(() {
        _rightEdge = center >= maxWidth / 2;
        _dragLeft = null;
      });
      _savePosition();
    } else {
      _handleTap();
    }
    _cancelPointerGesture();
  }

  void _cancelPointerGesture() {
    _pointerStartLeft = null;
    _pointerMovement = 0;
    _pointerDragging = false;
  }

  void _handleTap() {
    if (kDebugMode) debugPrint('Floating Muffin tapped');
    _openMenu();
  }

  BuildContext? _navigatorContext() {
    final navigatorContext =
        widget.navigatorKey?.currentState?.overlay?.context ??
            widget.navigatorKey?.currentContext ??
            widget.navigatorKey?.currentState?.context;
    if (navigatorContext != null &&
        Navigator.maybeOf(navigatorContext, rootNavigator: true) != null) {
      return navigatorContext;
    }
    if (Navigator.maybeOf(context, rootNavigator: true) != null) {
      return context;
    }
    if (kDebugMode) debugPrint('Unable to find Navigator context');
    return null;
  }

  Future<void> _openMenu() async {
    if (_sheetOpen) return;
    final navigatorContext = _navigatorContext();
    if (navigatorContext == null) return;

    final registered = MuffinContextRegistry.instance.current.value;
    final current = registered ?? MuffinContextRegistry.home();
    if (kDebugMode) {
      if (registered == null) {
        debugPrint('No registered context, opening default menu');
      } else {
        debugPrint(
          'Opening Muffin for context: ${current.context.currentScreen ?? current.mode.name}',
        );
      }
    }

    setState(() => _sheetOpen = true);
    try {
      final action = await showModalBottomSheet<MuffinActionConfig>(
        context: navigatorContext,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _FloatingMuffinMenu(
          current: current,
          translationController: widget.translationController,
        ),
      );
      if (action == null || !navigatorContext.mounted) return;
      await _openAction(navigatorContext, current, action);
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  Future<void> _openAction(
    BuildContext navigatorContext,
    MuffinScreenContext current,
    MuffinActionConfig action,
  ) async {
    if (action.action == MuffinAction.askMuffin) {
      await Navigator.of(navigatorContext, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => const MuffinScreen()),
      );
      return;
    }
    if (_isPageTranslationAction(action)) {
      await _translatePage(navigatorContext);
      return;
    }
    await showModalBottomSheet<void>(
      context: navigatorContext,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MuffinAssistSheet(
        title: 'Muffin',
        subtitle: current.subtitle,
        mode: current.mode,
        context: current.context,
        actions: current.actions,
        initialAction: action,
      ),
    );
  }

  bool _isPageTranslationAction(MuffinActionConfig action) {
    return action.action == MuffinAction.translate &&
        (action.label.contains('page') || action.label.contains('halaman'));
  }

  Future<void> _translatePage(BuildContext navigatorContext) async {
    final controller =
        widget.translationController ?? PageTranslationScope.maybeOf(context);
    final content = controller?.state.originalContent;
    if (controller == null || content == null) {
      if (kDebugMode) {
        debugPrint(
          'Floating Muffin translation failed: no active page registration.',
        );
      }
      ScaffoldMessenger.maybeOf(navigatorContext)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Muffin could not find translatable content on this page.',
          ),
        ),
      );
      return;
    }
    if (kDebugMode) {
      debugPrint(
        'Floating Muffin translating active page: pageId=${content.pageId} '
        'pageType=${content.pageType} fields=${content.fields.length}',
      );
    }
    String? targetLanguage;
    if (content.sourceLanguage == TranslationLanguage.unknown) {
      targetLanguage = await showModalBottomSheet<String>(
        context: navigatorContext,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translate this page',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('Bahasa Melayu'),
                  onTap: () => Navigator.of(context, rootNavigator: true)
                      .pop(TranslationLanguage.malay),
                ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('English'),
                  onTap: () => Navigator.of(context, rootNavigator: true)
                      .pop(TranslationLanguage.english),
                ),
              ],
            ),
          ),
        ),
      );
      if (targetLanguage == null) return;
    }
    await controller.translateCurrentPage(targetLanguage: targetLanguage);
  }
}

class _FloatingMuffinMenu extends StatelessWidget {
  const _FloatingMuffinMenu({
    required this.current,
    this.translationController,
  });

  final MuffinScreenContext current;
  final PageTranslationController? translationController;

  @override
  Widget build(BuildContext context) {
    final pageTranslationAction = _pageTranslationAction();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Muffin', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(current.subtitle),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context, rootNavigator: true)
                    .pop(pageTranslationAction),
                icon: const Icon(Icons.translate_rounded),
                label: Text(pageTranslationAction.label),
              ),
            ),
            const SizedBox(height: 12),
            for (final action in current.actions.where(
                (action) => action.action != MuffinAction.translate)) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(action),
                  child: Text(action.label),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  MuffinActionConfig _pageTranslationAction() {
    final sourceLanguage =
        translationController?.state.originalContent?.sourceLanguage;
    final label = switch (sourceLanguage) {
      TranslationLanguage.malay => 'Translate page to English',
      TranslationLanguage.english => 'Terjemah halaman ke Bahasa Melayu',
      _ => 'Translate this page',
    };
    return MuffinActionConfig(action: MuffinAction.translate, label: label);
  }
}

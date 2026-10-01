import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../models/muffin_wallet.dart';

abstract class MuffinWalletService {
  Stream<MuffinWallet> watchWallet();
}

class MuffinWalletServiceFactory {
  MuffinWalletServiceFactory._();

  static MuffinWalletService? _override;

  static void override(MuffinWalletService? service) {
    _override = service;
  }

  static MuffinWalletService create() {
    if (_override != null) return _override!;
    const useMock = bool.fromEnvironment(
      'MUFFIN_USE_MOCK',
      defaultValue: true,
    );
    if (useMock) return const StaticMuffinWalletService();
    return FirestoreMuffinWalletService();
  }
}

class FirestoreMuffinWalletService implements MuffinWalletService {
  FirestoreMuffinWalletService({
    FirebaseFirestore? firestore,
    DateTime Function()? nowProvider,
    Duration refreshInterval = const Duration(minutes: 1),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _nowProvider = nowProvider ?? DateTime.now,
        _refreshInterval = refreshInterval;

  final FirebaseFirestore _firestore;
  final DateTime Function() _nowProvider;
  final Duration _refreshInterval;

  DocumentReference<Map<String, dynamic>> get _state =>
      _firestore.doc('students/qidah/muffin/state');

  @override
  Stream<MuffinWallet> watchWallet() {
    return _EffectiveWalletStream(
      snapshots: _state.snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) return MuffinWallet.full;
        return MuffinWallet.fromJson(data);
      }),
      nowProvider: _nowProvider,
      refreshInterval: _refreshInterval,
    ).stream;
  }
}

class _EffectiveWalletStream with WidgetsBindingObserver {
  _EffectiveWalletStream({
    required this.snapshots,
    required this.nowProvider,
    required this.refreshInterval,
  });

  final Stream<MuffinWallet> snapshots;
  final DateTime Function() nowProvider;
  final Duration refreshInterval;
  final _controller = StreamController<MuffinWallet>.broadcast();
  StreamSubscription<MuffinWallet>? _subscription;
  Timer? _timer;
  MuffinWallet? _latestStored;
  bool _started = false;

  Stream<MuffinWallet> get stream {
    _controller
      ..onListen = _start
      ..onCancel = _stop;
    return _controller.stream;
  }

  void _start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _subscription = snapshots.listen(
      (wallet) {
        _latestStored = wallet;
        _emit();
      },
      onError: _controller.addError,
    );
    _timer = Timer.periodic(refreshInterval, (_) => _emit());
  }

  Future<void> _stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _emit();
    }
  }

  void _emit() {
    final latest = _latestStored;
    if (latest == null || _controller.isClosed) return;
    _controller.add(latest.effectiveAt(nowProvider()));
  }
}

class StaticMuffinWalletService implements MuffinWalletService {
  const StaticMuffinWalletService([this.wallet = MuffinWallet.full]);

  final MuffinWallet wallet;

  @override
  Stream<MuffinWallet> watchWallet() => Stream.value(
        wallet.effectiveAt(DateTime.now()),
      );
}

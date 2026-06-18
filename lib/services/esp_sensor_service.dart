import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/movement_thresholds.dart';
import '../repositories/movement_repository.dart';
import 'belt_message_parser.dart';

class EspSensorState {
  const EspSensorState({
    required this.connected,
    required this.connecting,
    required this.userMoving,
    required this.movementActive,
    required this.status,
    required this.peak,
    required this.elapsed,
  });

  factory EspSensorState.initial() => const EspSensorState(
        connected: false,
        connecting: false,
        userMoving: false,
        movementActive: false,
        status: '복부 센서 자동 수신 준비 중',
        peak: 0,
        elapsed: Duration.zero,
      );

  final bool connected;
  final bool connecting;
  final bool userMoving;
  final bool movementActive;
  final String status;
  final int peak;
  final Duration elapsed;

  EspSensorState copyWith({
    bool? connected,
    bool? connecting,
    bool? userMoving,
    bool? movementActive,
    String? status,
    int? peak,
    Duration? elapsed,
  }) {
    return EspSensorState(
      connected: connected ?? this.connected,
      connecting: connecting ?? this.connecting,
      userMoving: userMoving ?? this.userMoving,
      movementActive: movementActive ?? this.movementActive,
      status: status ?? this.status,
      peak: peak ?? this.peak,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

class EspMovementEvent {
  const EspMovementEvent({
    required this.createdAt,
    required this.intensity,
    required this.measuredDuringUserMotion,
  });

  final DateTime createdAt;
  final int intensity;
  final bool measuredDuringUserMotion;
}

class EspSensorService {
  EspSensorService._();

  static final EspSensorService instance = EspSensorService._();

  static const Duration sensorSampleInterval = Duration(milliseconds: 100);
  static const Duration uiEmitInterval = Duration(milliseconds: 100);
  static const Duration httpTimeout = Duration(milliseconds: 800);

  static const _webSocketUrl = 'ws://192.168.4.1:81/';
  static const _httpFallbackUrl = 'http://192.168.4.1/data';

  MovementThresholds _movementThresholds = MovementThresholds.defaults;

  void setMovementThresholds(MovementThresholds thresholds) {
    _movementThresholds = thresholds.normalized();
  }

  static const _watchdogInterval = Duration(seconds: 5);
  static const _reconnectInterval = Duration(seconds: 10);

  static String prefKey(String userId, String name) => 'monitoring.$userId.$name';

  final MovementRepository _movementRepository = MovementRepository();
  final BeltMovementDetector _movementDetector = BeltMovementDetector();
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);
  final StreamController<EspSensorState> _stateController =
      StreamController<EspSensorState>.broadcast();
  final StreamController<EspMovementEvent> _movementController =
      StreamController<EspMovementEvent>.broadcast();

  Stream<EspSensorState> get stateStream => _stateController.stream;
  Stream<EspMovementEvent> get movementStream => _movementController.stream;
  EspSensorState get currentState => _state;

  EspSensorState _state = EspSensorState.initial();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _httpPollTimer;
  Timer? _elapsedTimer;
  Timer? _watchdogTimer;
  Timer? _reconnectTimer;

  String? _userId;
  DateTime? _sessionStartedAt;
  DateTime _activeDate = DateTime.now();
  DateTime _lastMessageAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastStateEmitAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSampleHandledAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool _started = false;
  bool _httpRequestInFlight = false;

  Future<void> start({required String userId}) async {
    if (_started && _userId == userId) {
      _emitState(force: true);
      return;
    }

    if (_started) {
      await stop();
    }

    _started = true;
    _userId = userId;
    _movementDetector.reset();
    await _restoreElapsed(userId);
    _setState(
      _state.copyWith(connecting: true, status: 'WS 연결 시도'),
      force: true,
    );
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) => _checkWatchdog());
    _reconnectTimer = Timer.periodic(
      _reconnectInterval,
      (_) => unawaited(_tryReconnectWebSocket()),
    );
    unawaited(_connectWebSocket(force: true));
  }

  Future<void> stop() async {
    _started = false;
    final userId = _userId;
    _userId = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHttpFallback();
    await _closeWebSocket();
    if (userId != null) {
      await _finishDeviceSession(userId);
      await _clearSavedSession(userId);
    }
    _movementDetector.reset();
    _setState(EspSensorState.initial(), force: true);
  }

  Future<void> _restoreElapsed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final savedDate = DateTime.fromMillisecondsSinceEpoch(
      prefs.getInt(prefKey(userId, 'activeDate')) ?? now.millisecondsSinceEpoch,
    );
    _activeDate = _isSameDay(savedDate, now) ? savedDate : now;
    final elapsed = _isSameDay(savedDate, now)
        ? Duration(seconds: prefs.getInt(prefKey(userId, 'pausedElapsed')) ?? 0)
        : Duration.zero;
    _sessionStartedAt = null;
    _state = _state.copyWith(elapsed: elapsed);
  }

  Future<void> _connectWebSocket({bool force = false}) async {
    if (!_started || _socketSubscription != null) return;
    if (_state.connecting && !force) return;
    _setState(
      _state.copyWith(connecting: true, status: 'WS 연결 시도'),
      force: true,
    );
    try {
      final socket = await WebSocket.connect(
        _webSocketUrl,
        compression: CompressionOptions.compressionOff,
      ).timeout(const Duration(seconds: 8));
      if (!_started) {
        await socket.close();
        return;
      }
      _socket = socket;
      _stopHttpFallback();
      _socketSubscription = socket.listen(
        _handleSensorMessage,
        onError: (_) => _switchToHttpFallback(),
        onDone: _switchToHttpFallback,
        cancelOnError: true,
      );
      _setState(
        _state.copyWith(connecting: false, status: '기기 수신 중'),
        force: true,
      );
    } catch (_) {
      await _closeWebSocket();
      if (_started) _switchToHttpFallback();
    }
  }

  Future<void> _tryReconnectWebSocket() async {
    if (!_started || _socketSubscription != null || _state.connecting) return;
    await _connectWebSocket();
  }

  void _switchToHttpFallback() {
    unawaited(_closeWebSocket());
    if (!_started || _httpPollTimer != null) return;
    _setConnected(false);
    _setState(
      _state.copyWith(connecting: false, status: 'HTTP fallback 수신 중'),
      force: true,
    );
    _httpPollTimer = Timer.periodic(
      sensorSampleInterval,
      (_) => unawaited(_pollSensorHttp()),
    );
    unawaited(_pollSensorHttp());
  }

  Future<void> _pollSensorHttp() async {
    if (!_started) return;

    // 100ms마다 호출되더라도 이전 HTTP 요청이 끝나기 전이면 새 요청을 막음
    if (_httpRequestInFlight) return;

    _httpRequestInFlight = true;

    try {
      final request = await _httpClient.getUrl(Uri.parse(_httpFallbackUrl));
      final response = await request.close().timeout(httpTimeout);

      final body = await response.transform(utf8.decoder).join();
      _handleSensorMessage(body);
    } catch (_) {
      _setConnected(false);
      _setState(
        _state.copyWith(status: '수신 대기'),
        force: true,
      );
    } finally {
      _httpRequestInFlight = false;
    }
  }

  Future<void> _closeWebSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
  }

  void _stopHttpFallback() {
    _httpPollTimer?.cancel();
    _httpPollTimer = null;
  }

  void _handleSensorMessage(dynamic message) {
    final sample = parseBeltSensorSample(message);

    if (sample == null) {
      _setState(_state.copyWith(status: '파싱 실패'), force: true);
      return;
    }

    final now = DateTime.now();

    final movementActive = sample.isMovementActiveFor(_movementThresholds);
    // WebSocket 데이터가 더 자주 들어와도 앱에서는 100ms마다 1번만 처리
    // 즉, 최대 1초에 10번 처리
    if (now.difference(_lastSampleHandledAt) < sensorSampleInterval) {
      return;
    }

    _lastSampleHandledAt = now;
    _lastMessageAt = now;

    _setConnected(true);

    final event = _movementDetector.addSample(
      sample,
      now,
      thresholds: _movementThresholds,
    );

    final status = sample.isUserMoving
        ? '센서가 흔들리는 중'
        : '센서 수신 중 peak ${sample.peak}';

    _setState(
      _state.copyWith(
        connecting: false,
        userMoving: sample.isUserMoving,
        movementActive: movementActive,
        status: status,
        peak: sample.peak,
      ),
    );

    if (event != null) {
      unawaited(_recordSensorMovement(event));
    }
  }

  Future<void> _recordSensorMovement(BeltMovementEvent event) async {
    final userId = _userId;
    if (userId == null) return;
    await _movementRepository.addRecord(
      userId: userId,
      measuredAt: event.measuredAt,
      intensity: event.intensity,
      measuredDuringUserMotion: event.measuredDuringUserMotion,
    );
    _setState(
      _state.copyWith(movementActive: true, status: '태동 감지됨'),
      force: true,
    );
    _movementController.add(
      EspMovementEvent(
        createdAt: event.measuredAt,
        intensity: event.intensity,
        measuredDuringUserMotion: event.measuredDuringUserMotion,
      ),
    );
  }

  void _setConnected(bool value) {
    if (_state.connected == value) return;
    final userId = _userId;
    final now = DateTime.now();
    if (value) {
      _sessionStartedAt = now;
      _setState(
        _state.copyWith(
          connected: true,
          connecting: false,
          elapsed: Duration.zero,
        ),
        force: true,
      );
      if (userId != null) unawaited(_saveSession(userId));
      return;
    }

    if (userId != null) {
      unawaited(_finishDeviceSession(userId));
    }
    _sessionStartedAt = null;
    _setState(
      _state.copyWith(
        connected: false,
        elapsed: Duration.zero,
        userMoving: false,
        movementActive: false,
      ),
      force: true,
    );
    if (userId != null) unawaited(_clearSavedSession(userId));
  }

  void _tick() {
    final now = DateTime.now();
    if (!_isSameDay(now, _activeDate)) {
      _activeDate = now;
      _sessionStartedAt = _state.connected ? now : null;
      _setState(_state.copyWith(elapsed: Duration.zero), force: true);
      final userId = _userId;
      if (userId != null) unawaited(_saveSession(userId));
      return;
    }
    if (_state.connected && _sessionStartedAt != null) {
      _setState(
        _state.copyWith(elapsed: now.difference(_sessionStartedAt!)),
        force: true,
      );
    }
  }

  void _checkWatchdog() {
    if (!_started || !_state.connected) return;
    if (DateTime.now().difference(_lastMessageAt) > _watchdogInterval * 2) {
      _setConnected(false);
      _setState(_state.copyWith(status: '수신 대기'), force: true);
    }
  }

  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey(userId, 'deviceOn'), _state.connected);
    await prefs.setInt(prefKey(userId, 'pausedElapsed'), _state.elapsed.inSeconds);
    await prefs.setInt(
      prefKey(userId, 'activeDate'),
      _activeDate.millisecondsSinceEpoch,
    );
    final startedAt = _sessionStartedAt;
    if (_state.connected && startedAt != null) {
      await prefs.setInt(
        prefKey(userId, 'startedAt'),
        startedAt.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(prefKey(userId, 'startedAt'));
    }
  }

  Future<void> _clearSavedSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setBool(prefKey(userId, 'deviceOn'), false);
    await prefs.setInt(prefKey(userId, 'pausedElapsed'), 0);
    await prefs.setInt(prefKey(userId, 'activeDate'), now.millisecondsSinceEpoch);
    await prefs.remove(prefKey(userId, 'startedAt'));
  }

  Future<void> _finishDeviceSession(String userId) async {
    final startedAt = _sessionStartedAt;
    final now = DateTime.now();
    if (startedAt != null && now.isAfter(startedAt)) {
      await _movementRepository.addDeviceSession(
        userId: userId,
        startedAt: startedAt,
        endedAt: now,
      );
    }
  }

  void _setState(EspSensorState state, {bool force = false}) {
    _state = state;
    _emitState(force: force);
  }

  void _emitState({bool force = false}) {
    final now = DateTime.now();

    if (!force && now.difference(_lastStateEmitAt) < uiEmitInterval) {
      return;
    }

    _lastStateEmitAt = now;

    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
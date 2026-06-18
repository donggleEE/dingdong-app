import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'models/fetal_movement_record.dart';
import 'models/app_user.dart';
import 'repositories/auth_repository.dart';
import 'repositories/movement_repository.dart';
import 'services/belt_message_parser.dart';
import 'services/esp_sensor_service.dart';

const _alertSoundAssets = [
  'assets/sounds/dingdong1.mp3',
  'assets/sounds/dingdong2.mp3',
  'assets/sounds/dingdong3.mp3',
  'assets/sounds/dingdong4.mp3',
  'assets/sounds/dingdong5.mp3',
];

const _alertMessagesAsset = 'assets/messages/movement_alert_messages.txt';
const _alertSoundChannel = MethodChannel('ding_dong/sound');

String _alertSoundPrefKey(String userId) => 'alertSound.$userId.asset';

Future<String> _loadAlertSoundAsset(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_alertSoundPrefKey(userId));
  return _alertSoundAssets.contains(saved) ? saved! : _alertSoundAssets.first;
}

Future<void> _saveAlertSoundAsset(String userId, String asset) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_alertSoundPrefKey(userId), asset);
}

Future<void> _playAlertSound(String asset) async {
  try {
    await _alertSoundChannel.invokeMethod<void>('playAsset', {'asset': asset});
  } catch (_) {}
}

Future<List<String>> _loadMovementAlertMessages() async {
  try {
    final raw = await rootBundle.loadString(_alertMessagesAsset);
    final messages = raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.contains('(20가지)'),
        )
        .toList();
    if (messages.isNotEmpty) return messages;
  } catch (_) {}
  return const [
    '태동이 감지되었어요. 잠시 편안히 호흡하며 움직임을 확인해 보세요.',
    '방금 태동 신호가 기록되었어요. 오늘의 흐름에 함께 저장했어요.',
    '작은 움직임을 놓치지 않도록 알림으로 남겨 두었어요.',
    '센서가 태동 후보를 확인했어요. 앱에서 기록을 확인할 수 있어요.',
  ];
}

String _pickMovementAlertMessage(
  List<String> messages,
  int intensity, {
  String fetusName = '아기',
  String? previousMessage,
}) {
  if (messages.isEmpty) return '태동이 감지되었어요.';
  final pool = messages
      .where((message) => message.trim().isNotEmpty)
      .toList(growable: false);
  if (pool.isEmpty) return '태동이 감지되었어요.';
  final random = math.Random(DateTime.now().microsecondsSinceEpoch + intensity);
  var picked = pool[random.nextInt(pool.length)];
  if (pool.length > 1 && picked == previousMessage) {
    picked = pool[(pool.indexOf(picked) + 1) % pool.length];
  }
  final name = fetusName.trim().isEmpty ? '아기' : fetusName.trim();
  return picked
      .replaceAll('(태명)', name)
      .replaceAll('(태명 )', name);
}

double _sensorIntensityRatio(num intensity) =>
    ((intensity - 2000) / (beltSensorMaxValue - 2000))
        .clamp(0.0, 1.0)
        .toDouble();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  runApp(FetalMovementApp());
}

class AppColors {
  static const coral = Color(0xFFFF9172);
  static const coralDark = Color(0xFFD96E54);
  static const peach = Color(0xFFFFE2D6);
  static const mint = Color(0xFF45D77F);
  static const ink = Color(0xFF292727);
  static const muted = Color(0xFF7E7774);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFEAE0DD);
  static const softGray = Color(0xFFE9E8E7);
  static const controlGray = Color(0xFFF0EFEE);
}

ThemeData _buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.coral),
    scaffoldBackgroundColor: Colors.white,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w900,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w900,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      titleSmall: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      bodyMedium: TextStyle(color: AppColors.muted),
      bodySmall: TextStyle(color: AppColors.muted),
      labelSmall: TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: .18),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.ink
              : Colors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.ink,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class FetalMovementApp extends StatelessWidget {
  FetalMovementApp({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? AuthRepository();
  final AuthRepository authRepository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DingDongApp',
    debugShowCheckedModeBanner: false,
    theme: _buildTheme(),
    home: AuthGate(authRepository: authRepository),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.authRepository});
  final AuthRepository authRepository;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppUser? _user;
  bool _loading = true;
  String _fetusName = 'Ding-Dong';
  int _profileStyle = 0;
  int _profileBackgroundIndex = 0;
  Uint8List? _profileImageBytes;
  @override
  void initState() {
    super.initState();
    widget.authRepository.getCurrentUser().then((user) async {
      if (mounted) {
        setState(() {
          _user = user;
          if (user != null) {
            _fetusName = user.fetusName;
            _profileStyle = user.profileImageIndex;
            _profileBackgroundIndex = user.profileBackgroundIndex;
          }
          _loading = false;
        });
        if (user != null) {
          final savedImage = await _loadCustomProfileImage(user.id);
          if (mounted && _user?.id == user.id) {
            setState(() => _profileImageBytes = savedImage);
          }
        }
      }
    });
  }

  Future<void> _handleAuthenticated(AppUser user) async {
    final pendingImage = _profileImageBytes;
    setState(() {
      _user = user;
      _fetusName = user.fetusName;
      _profileStyle = user.profileImageIndex;
      _profileBackgroundIndex = user.profileBackgroundIndex;
      _profileImageBytes = pendingImage;
    });
    if (pendingImage != null) {
      await _saveCustomProfileImage(user.id, pendingImage);
      return;
    }
    final savedImage = await _loadCustomProfileImage(user.id);
    if (mounted && _user?.id == user.id) {
      setState(() => _profileImageBytes = savedImage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return AuthScreen(
        authRepository: widget.authRepository,
        onAuthenticated: (user) => unawaited(_handleAuthenticated(user)),
        onFetusNameChanged: (name) => setState(
          () => _fetusName = name.trim().isEmpty ? 'Ding-Dong' : name.trim(),
        ),
        profileStyle: _profileStyle,
        profileBackgroundIndex: _profileBackgroundIndex,
        profileImageBytes: _profileImageBytes,
        onChangeProfileStyle: (value) => setState(() {
          _profileStyle = value;
          _profileImageBytes = null;
        }),
        onChangeProfileBackground: (value) =>
            setState(() => _profileBackgroundIndex = value),
        onChangeProfileImage: (value) =>
            setState(() => _profileImageBytes = value),
      );
    }
    return HomeScreen(
      user: _user!,
      fetusName: _fetusName,
      initialProfileStyle: _profileStyle,
      initialProfileBackgroundIndex: _profileBackgroundIndex,
      initialProfileImageBytes: _profileImageBytes,
      authRepository: widget.authRepository,
      onUserChanged: (user) => setState(() => _user = user),
      onSignedOut: () => setState(() {
        _user = null;
        _profileImageBytes = null;
      }),
      onFetusNameChanged: (name) => setState(
        () => _fetusName = name.trim().isEmpty ? 'Ding-Dong' : name.trim(),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
    required this.onFetusNameChanged,
    required this.profileStyle,
    required this.profileBackgroundIndex,
    this.profileImageBytes,
    required this.onChangeProfileStyle,
    required this.onChangeProfileBackground,
    required this.onChangeProfileImage,
  });
  final AuthRepository authRepository;
  final ValueChanged<AppUser> onAuthenticated;
  final ValueChanged<String> onFetusNameChanged;
  final int profileStyle;
  final int profileBackgroundIndex;
  final Uint8List? profileImageBytes;
  final ValueChanged<int> onChangeProfileStyle;
  final ValueChanged<int> onChangeProfileBackground;
  final ValueChanged<Uint8List> onChangeProfileImage;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _fetusName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _isSignUp = false;
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _fetusName.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final user = _isSignUp
          ? await widget.authRepository.signUp(
              _email.text,
              _password.text,
              _displayName.text,
              fetusName: _fetusName.text,
              profileImageIndex: widget.profileStyle,
              profileBackgroundIndex: widget.profileBackgroundIndex,
            )
          : await widget.authRepository.login(_email.text, _password.text);
      if (_isSignUp) widget.onFetusNameChanged(_fetusName.text);
      if (mounted) widget.onAuthenticated(user);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? '회원가입' : '로그인';
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/stainbackground.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/logo/logo.png',
                            width: 360,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 18),
                        if (_isSignUp) ...[
                          Center(
                            child: Column(
                              children: [
                                _ProfileAvatar(
                                  style: widget.profileStyle,
                                  backgroundIndex:
                                      widget.profileBackgroundIndex,
                                  imageBytes: widget.profileImageBytes,
                                  radius: 42,
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  key: const Key('signUpProfilePickerButton'),
                                  onPressed: () => _showProfilePicker(
                                    context,
                                    widget.profileStyle,
                                    widget.profileBackgroundIndex,
                                    widget.onChangeProfileStyle,
                                    widget.onChangeProfileBackground,
                                    widget.onChangeProfileImage,
                                  ),
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: const Text('프로필 이미지 선택'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('displayNameField'),
                            controller: _displayName,
                            decoration: const InputDecoration(
                              labelText: '이름 또는 별명',
                            ),
                            validator: _validateDisplayName,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('fetusNameField'),
                            controller: _fetusName,
                            decoration: const InputDecoration(labelText: '태명'),
                            validator: _validateFetusName,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          key: const Key('emailField'),
                          controller: _email,
                          decoration: const InputDecoration(labelText: '이메일'),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('passwordField'),
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            suffixIcon: IconButton(
                              tooltip: '비밀번호 보기',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('passwordConfirmField'),
                            controller: _passwordConfirm,
                            obscureText: _obscure,
                            decoration: const InputDecoration(
                              labelText: '비밀번호 확인',
                            ),
                            validator: (value) => value == _password.text
                                ? null
                                : '비밀번호가 서로 다릅니다.',
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ErrorNotice(message: _error!),
                        ],
                        const SizedBox(height: 18),
                        ElevatedButton(
                          key: const Key('submitAuthButton'),
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const _ButtonLoader()
                              : Text(title),
                        ),
                        TextButton(
                          key: const Key('toggleAuthModeButton'),
                          onPressed: () =>
                              setState(() => _isSignUp = !_isSignUp),
                          child: Text(
                            _isSignUp ? '이미 계정이 있나요? 로그인' : '처음 사용하시나요? 회원가입',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.fetusName,
    required this.initialProfileStyle,
    required this.initialProfileBackgroundIndex,
    this.initialProfileImageBytes,
    required this.authRepository,
    required this.onUserChanged,
    required this.onSignedOut,
    required this.onFetusNameChanged,
  });
  final AppUser user;
  final String fetusName;
  final int initialProfileStyle;
  final int initialProfileBackgroundIndex;
  final Uint8List? initialProfileImageBytes;
  final AuthRepository authRepository;
  final ValueChanged<AppUser?> onUserChanged;
  final VoidCallback onSignedOut;
  final ValueChanged<String> onFetusNameChanged;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _MovementAlertEntry {
  const _MovementAlertEntry({
    required this.createdAt,
    required this.intensity,
    required this.message,
  });

  final DateTime createdAt;
  final int intensity;
  final String message;
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final Set<int> _visitedPageIndexes = {0};
  
  int _fetusStyle = 0;
  bool _deviceOn = false;
  bool _hasUnreadAlert = false;
  final List<_MovementAlertEntry> _alerts = [];
  String _sensorStatus = '복부 센서 자동 수신 준비 중';
  DateTime _lastSensorStatusUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  EspSensorState _espState = EspSensorService.instance.currentState;
  StreamSubscription<EspSensorState>? _espStateSubscription;
  StreamSubscription<EspMovementEvent>? _espMovementSubscription;
  bool _recordingMovement = false;
  String _selectedAlertSound = _alertSoundAssets.first;
  List<String> _alertMessages = const [];
  String? _lastAlertMessage;
  late int _profileStyle = widget.initialProfileStyle;
  late int _profileBackgroundIndex = widget.initialProfileBackgroundIndex;
  Uint8List? _fetusImageBytes;
  late Uint8List? _profileImageBytes = widget.initialProfileImageBytes;

  Future<void> _changeProfileStyle(int value) async {
    setState(() {
      _profileStyle = value;
      _profileImageBytes = null;
    });
    await _clearCustomProfileImage(widget.user.id);
  }

  Future<void> _changeProfileImage(Uint8List value) async {
    setState(() => _profileImageBytes = value);
    await _saveCustomProfileImage(widget.user.id, value);
  }

  void _addMovementAlert(_MovementAlertEntry alert) {
    setState(() {
      _alerts.insert(0, alert);
      _hasUnreadAlert = true;
    });
  }

  void _selectPage(int index) {
    if (_selectedIndex == index && _visitedPageIndexes.contains(index)) return;
    setState(() {
      _selectedIndex = index;
      _visitedPageIndexes.add(index);
    });
  }

  void _updateSensorStatus(String value) {
    final now = DateTime.now();
    final isImportant =
        value == '태동 감지됨' ||
        value.contains('연결') ||
        value.contains('fallback') ||
        value.contains('준비');
    if (_sensorStatus == value && !isImportant) return;
    if (!isImportant &&
        now.difference(_lastSensorStatusUpdate) <
            const Duration(seconds: 2)) {
      return;
    }
    _lastSensorStatusUpdate = now;
    setState(() => _sensorStatus = value);
  }

  @override
  void initState() {
    super.initState();
    _restoreAlertSettings();
    _espStateSubscription = EspSensorService.instance.stateStream.listen(
      _handleEspState,
    );
    _espMovementSubscription = EspSensorService.instance.movementStream.listen(
      (event) => unawaited(_handleEspMovement(event)),
    );
    unawaited(EspSensorService.instance.start(userId: widget.user.id));
    _handleEspState(EspSensorService.instance.currentState);

    unawaited(_seedJune2026DummyMovementsOnce());
  }

  @override
  void dispose() {
    _espStateSubscription?.cancel();
    _espMovementSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreAlertSettings() async {
    final sound = await _loadAlertSoundAsset(widget.user.id);
    final messages = await _loadMovementAlertMessages();
    if (!mounted) return;
    setState(() {
      _selectedAlertSound = sound;
      _alertMessages = messages;
    });
  }

  void _handleEspState(EspSensorState state) {
    if (!mounted) return;
    setState(() {
      _espState = state;
      _deviceOn = state.connected;
    });
    _updateSensorStatus(state.status);
  }

  Future<void> _handleEspMovement(EspMovementEvent event) async {
    await _playAlertSound(_selectedAlertSound);
    if (!mounted) return;
    final message = _pickMovementAlertMessage(
      _alertMessages,
      event.intensity,
      fetusName: widget.fetusName,
      previousMessage: _lastAlertMessage,
    );
    final displayMessage = event.measuredDuringUserMotion
        ? '$message 사용자 움직임이 섞였을 수 있어요.'
        : message;
    _lastAlertMessage = message;
    _addMovementAlert(
      _MovementAlertEntry(
        createdAt: event.createdAt,
        intensity: event.intensity,
        message: displayMessage,
      ),
    );
  }

  Future<void> _seedJune2026DummyMovementsOnce() async {
    final userId = widget.user.id;
    final prefs = await SharedPreferences.getInstance();
    final seedKey = 'dummy.june2026.seeded.$userId';

    if (prefs.getBool(seedKey) ?? false) return;

    final repository = MovementRepository();
    final random = math.Random(20260618);

    // 6월 18일 이전 기준.
    // 3, 7, 11, 14, 17일은 측정 없이 지나간 날.
    // 나머지는 모두 20회 초과, 200회 미만.
    const dailyCounts = <int, int>{
      1: 62,
      2: 88,
      4: 35,
      5: 124,
      6: 77,
      8: 42,
      9: 96,
      10: 153,
      12: 69,
      13: 118,
      15: 82,
      16: 41,
    };

    for (final entry in dailyCounts.entries) {
      final day = entry.key;
      final count = entry.value;
      final usedMinutes = <int>{};

      for (var i = 0; i < count; i++) {
        // 06:00 ~ 23:30 사이에서 생성
        var minuteOfDay = 6 * 60 + random.nextInt(17 * 60 + 30);

        // 완전 동일 시간만 너무 많아지는 것 방지
        var guard = 0;
        while (usedMinutes.contains(minuteOfDay) && guard < 20) {
          minuteOfDay = 6 * 60 + random.nextInt(17 * 60 + 30);
          guard++;
        }
        usedMinutes.add(minuteOfDay);

        final measuredAt = DateTime(
          2026,
          6,
          day,
          minuteOfDay ~/ 60,
          minuteOfDay % 60,
          random.nextInt(60),
        );

        // 2000~4095 사이. 리포트에서 _sensorIntensityRatio로 0~100% 환산됨.
        final intensity = 2100 + random.nextInt(1900);

        await repository.addRecord(
          userId: userId,
          measuredAt: measuredAt,
          intensity: intensity,
          measuredDuringUserMotion: random.nextDouble() < 0.08,
        );
      }
    }

    await prefs.setBool(seedKey, true);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _recordManualMovement(int intensity) async {
    if (_recordingMovement) return;
    setState(() => _recordingMovement = true);
    final now = DateTime.now();
    try {
      await MovementRepository().addRecord(
        userId: widget.user.id,
        measuredAt: now,
        intensity: intensity,
      );
      await _playAlertSound(_selectedAlertSound);
      if (!mounted) return;
      final message = _pickMovementAlertMessage(
        _alertMessages,
        intensity,
        fetusName: widget.fetusName,
        previousMessage: _lastAlertMessage,
      );
      _lastAlertMessage = message;
      _addMovementAlert(
        _MovementAlertEntry(
          createdAt: now,
          intensity: intensity,
          message: message,
        ),
      );
    } finally {
      if (mounted) setState(() => _recordingMovement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _LazyTabPage(
        active: _selectedIndex == 0,
        built: _visitedPageIndexes.contains(0),
        builder: (context) => _ScrollableArtworkBackground(
          asset: 'assets/images/background/stainbackground.png',
          child: _DashboardPage(
            userId: widget.user.id,
            fetusName: widget.fetusName,
            fetusStyle: _fetusStyle,
            fetusImageBytes: _fetusImageBytes,
            profileStyle: _profileStyle,
            profileBackgroundIndex: _profileBackgroundIndex,
            profileImageBytes: _profileImageBytes,
            hasUnreadAlert: _hasUnreadAlert,
            alerts: _alerts,
            onOpenReport: () => _selectPage(2),
            onOpenAccount: () => _selectPage(3),
            onAlertsViewed: () => setState(() => _hasUnreadAlert = false),
            onDeleteAlert: (alert) => setState(() => _alerts.remove(alert)),
            onClearAlerts: () => setState(() {
              _alerts.clear();
              _hasUnreadAlert = false;
            }),
            onChangeFetusStyle: (value) => setState(() {
              _fetusStyle = value;
              _fetusImageBytes = null;
            }),
            onChangeFetusImage: (value) => setState(() => _fetusImageBytes = value),
          ),
        ),
      ),
      _LazyTabPage(
        active: _selectedIndex == 1,
        built: _visitedPageIndexes.contains(1),
        builder: (context) => _ScrollableArtworkBackground(
          asset: 'assets/images/background/backgroundReport.png',
          child: _MonitoringPage(
            sensorState: _espState,
            recordingMovement: _recordingMovement,
            onOpenReport: () => _selectPage(2),
            onManualRecord: (intensity) =>
                unawaited(_recordManualMovement(intensity)),
          ),
        ),
      ),
      _LazyTabPage(
        active: _selectedIndex == 2,
        built: _visitedPageIndexes.contains(2),
        builder: (context) => _ScrollableArtworkBackground(
          asset: 'assets/images/background/stainbackground.png',
          child: ReportPage(userId: widget.user.id),
        ),
      ),
      _LazyTabPage(
        active: _selectedIndex == 3,
        built: _visitedPageIndexes.contains(3),
        builder: (context) => _ScrollableArtworkBackground(
          asset: 'assets/images/background/stainbackground.png',
          child: MyPage(
            user: widget.user,
            fetusName: widget.fetusName,
            profileStyle: _profileStyle,
            profileBackgroundIndex: _profileBackgroundIndex,
            profileImageBytes: _profileImageBytes,
            deviceOn: _deviceOn,
            sensorStatus: _sensorStatus,
            authRepository: widget.authRepository,
            onUserChanged: (user) => widget.onUserChanged(user),
            onLogout: () async {
              await EspSensorService.instance.stop();
              await widget.authRepository.logout();
              widget.onSignedOut();
            },
            onFetusNameChanged: widget.onFetusNameChanged,
            onChangeProfileStyle: (value) =>
                unawaited(_changeProfileStyle(value)),
            onChangeProfileBackground: (value) =>
                setState(() => _profileBackgroundIndex = value),
            onChangeProfileImage: (value) =>
                unawaited(_changeProfileImage(value)),
          ),
        ),
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10 + MediaQuery.viewPaddingOf(context).bottom,
              child: _PngBottomNavigationBar(
                selectedIndex: _selectedIndex,
                onSelected: _selectPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LazyTabPage extends StatelessWidget {
  const _LazyTabPage({
    required this.active,
    required this.built,
    required this.builder,
  });

  final bool active;
  final bool built;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: built ? builder(context) : const SizedBox.shrink(),
    );
  }
}

class _ScrollableArtworkBackground extends StatefulWidget {
  const _ScrollableArtworkBackground({
    required this.asset,
    required this.child,
  });

  final String asset;
  final Widget child;

  @override
  State<_ScrollableArtworkBackground> createState() =>
      _ScrollableArtworkBackgroundState();
}

class _ScrollableArtworkBackgroundState
    extends State<_ScrollableArtworkBackground> {
  double _scrollOffset = 0;
  double _maxScrollExtent = 0;

  bool _handleScroll(ScrollNotification notification) {
    final metrics = notification.metrics;

    final nextMaxScrollExtent = math.max(0.0, metrics.maxScrollExtent);
    final nextScrollOffset = metrics.pixels.clamp(
      0.0,
      nextMaxScrollExtent,
    );

    final offsetChanged = (nextScrollOffset - _scrollOffset).abs() > 0.5;
    final extentChanged =
        (nextMaxScrollExtent - _maxScrollExtent).abs() > 0.5;

    if (offsetChanged || extentChanged) {
      setState(() {
        _scrollOffset = nextScrollOffset;
        _maxScrollExtent = nextMaxScrollExtent;
      });
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        final backgroundHeight = math.max(
          viewportHeight,
          viewportHeight + _maxScrollExtent,
        );

        final backgroundTop = -_scrollOffset.clamp(
          0.0,
          _maxScrollExtent,
        );

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: backgroundTop,
                height: backgroundHeight,
                child: RepaintBoundary(
                  child: Image.asset(
                    widget.asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned.fill(
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PngBottomNavigationBar extends StatelessWidget {
  const _PngBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _holder = 'assets/images/icon/iconholder.png';
  static const _activeIcons = [
    'assets/images/icon/nowHome.png',
    'assets/images/icon/nowMonitoring.png',
    'assets/images/icon/nowReport.png',
    'assets/images/icon/nowMy.png',
  ];
  static const _inactiveIcons = [
    'assets/images/icon/toHome.png',
    'assets/images/icon/toMonitoring.png',
    'assets/images/icon/toReport.png',
    'assets/images/icon/toMy.png',
  ];
  static const _labels = ['홈', '모니터링', '리포트', 'My'];
  static const _keys = ['navHome', 'navMonitoring', 'navReport', 'navMy'];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    const designWidth = 274.0;
    const designHeight = 70.0;

    final holderWidth = math.min(designWidth, screenWidth - 44);
    final holderHeight = holderWidth * designHeight / designWidth;
    final scale = holderWidth / designWidth;

    final sideInset = 8.0 * scale;
    final itemSize = 59.0 * scale;

    return Center(
      child: SizedBox(
        width: holderWidth,
        height: holderHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                _holder,
                fit: BoxFit.fill,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sideInset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var index = 0; index < _activeIcons.length; index++)
                    Semantics(
                      button: true,
                      selected: selectedIndex == index,
                      label: _labels[index],
                      child: Tooltip(
                        message: _labels[index],
                        child: GestureDetector(
                          key: Key(_keys[index]),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(index),
                          child: SizedBox(
                            width: itemSize,
                            height: itemSize,
                            child: Image.asset(
                              selectedIndex == index
                                  ? _activeIcons[index]
                                  : _inactiveIcons[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.userId,
    required this.fetusName,
    required this.fetusStyle,
    this.fetusImageBytes,
    required this.profileStyle,
    required this.profileBackgroundIndex,
    this.profileImageBytes,
    required this.hasUnreadAlert,
    required this.alerts,
    required this.onOpenReport,
    required this.onOpenAccount,
    required this.onAlertsViewed,
    required this.onDeleteAlert,
    required this.onClearAlerts,
    required this.onChangeFetusStyle,
    required this.onChangeFetusImage,
  });
  final String userId;
  final String fetusName;
  final int fetusStyle;
  final Uint8List? fetusImageBytes;
  final int profileStyle;
  final int profileBackgroundIndex;
  final Uint8List? profileImageBytes;
  final bool hasUnreadAlert;
  final List<_MovementAlertEntry> alerts;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenAccount;
  final VoidCallback onAlertsViewed;
  final ValueChanged<_MovementAlertEntry> onDeleteAlert;
  final VoidCallback onClearAlerts;
  final ValueChanged<int> onChangeFetusStyle;
  final ValueChanged<Uint8List> onChangeFetusImage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 130),
      children: [
        Row(
          children: [
            Expanded(child: _HomeHeadline(fetusName: fetusName)),
            InkWell(
              key: const Key('homeProfileButton'),
              onTap: onOpenAccount,
              customBorder: const CircleBorder(),
              child: _ProfileAvatar(
                style: profileStyle,
                backgroundIndex: profileBackgroundIndex,
                imageBytes: profileImageBytes,
                radius: 22,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              key: const Key('homeAlertButton'),
              onTap: () {
                onAlertsViewed();
                _showAlerts(
                  context,
                  alerts: alerts,
                  onDelete: onDeleteAlert,
                  onClear: onClearAlerts,
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      key: const Key('homeAlertButton'),
                      onTap: () {
                        onAlertsViewed();
                        _showAlerts(
                          context,
                          alerts: alerts,
                          onDelete: onDeleteAlert,
                          onClear: onClearAlerts,
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          hasUnreadAlert
                              ? 'assets/images/icon/alertnew.png'
                              : 'assets/images/icon/alert.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _TodayHeroCard(
          userId: userId,
          fetusStyle: fetusStyle,
          fetusImageBytes: fetusImageBytes,
          onChangeFetusStyle: onChangeFetusStyle,
          onChangeFetusImage: onChangeFetusImage,
        ),
        const SizedBox(height: 22),
        _MovementFlowCard(userId: userId, onOpenReport: onOpenReport),
        const SizedBox(height: 22),
        const _CareNotice(),
      ],
    );
  }
}

class _HomeHeadline extends StatelessWidget {
  const _HomeHeadline({required this.fetusName});
  final String fetusName;
  @override
  Widget build(BuildContext context) {
    final name = fetusName.trim().isEmpty ? 'Ding-Dong' : fetusName.trim();
    final fontSize = math.max(18.0, 30.0 - math.max(0, name.length - 8) * .62);
    final baseStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontSize: fontSize,
      height: 1.12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: RichText(
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: '오늘\n'),
            TextSpan(
              text: name,
              style: baseStyle?.copyWith(fontWeight: FontWeight.w800),
            ),
            const TextSpan(text: '의\n태동이에요!'),
          ],
        ),
      ),
    );
  }
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.userId,
    required this.fetusStyle,
    this.fetusImageBytes,
    required this.onChangeFetusStyle,
    required this.onChangeFetusImage,
  });
  final String userId;
  final int fetusStyle;
  final Uint8List? fetusImageBytes;
  final ValueChanged<int> onChangeFetusStyle;
  final ValueChanged<Uint8List> onChangeFetusImage;
  @override
  Widget build(BuildContext context) {
    final movementRepository = MovementRepository();
    final today = _dateOnly(DateTime.now());
    return SizedBox(
      height: 360,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/background/fetal_card_background.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: _FloatingFetusViewer(
                style: fetusStyle,
                imageBytes: fetusImageBytes,
              ),
            ),
            Positioned(
              top: 12,
              right: 10,
              child: _MiniPill(
                label: '정상 범위 유지 중',
                foreground: AppColors.ink,
                background: Colors.white.withValues(alpha: .5),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '태동 감지',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: '',
                        style: Theme.of(context).textTheme.headlineSmall,
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: FutureBuilder<int>(
                              future: movementRepository.countRecords(
                                userId: userId,
                                start: today,
                                end: today.add(const Duration(days: 1)),
                              ),
                              initialData: 0,
                              builder: (context, snapshot) => Text(
                                '${snapshot.data ?? 0}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const TextSpan(
                            text: '회',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: GestureDetector(
                onLongPress: () => _showFetusPicker(
                  context,
                  onChangeFetusStyle,
                  onChangeFetusImage,
                ),
                child: IconButton.filledTonal(
                  tooltip: fetusStyle == 1 ? '추상 태아 이미지로 변경' : '실사 태아 이미지로 변경',
                  onPressed: () => onChangeFetusStyle(fetusStyle == 0 ? 1 : 0),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .5),
                    foregroundColor: AppColors.ink,
                  ),
                  icon: Image.asset(
                    fetusStyle == 1
                        ? 'assets/images/icon/painting.png'
                        : 'assets/images/icon/picture.png',
                    width: 12,
                    height: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementFlowCard extends StatelessWidget {
  const _MovementFlowCard({required this.userId, required this.onOpenReport});
  final String userId;
  final VoidCallback onOpenReport;
  @override
  Widget build(BuildContext context) {
    final movementRepository = MovementRepository();
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '최근 태동 흐름',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenReport,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('더보기'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 190,
              child: FutureBuilder<List<FetalMovementRecord>>(
                future: movementRepository.findRecords(
                  userId: userId,
                  start: start,
                  end: today.add(const Duration(days: 1)),
                ),
                initialData: const [],
                builder: (context, snapshot) {
                  final records = snapshot.data ?? const [];
                  final counts = List<int>.filled(7, 0);
                  for (final record in records) {
                    final index = _dateOnly(
                      record.measuredAt,
                    ).difference(start).inDays;
                    if (index >= 0 && index < counts.length) counts[index]++;
                  }
                  final maxCount = math.max(1, counts.fold<int>(0, math.max));
                  return CustomPaint(
                    painter: _LineChartPainter(
                      values: [
                        for (final count in counts)
                          (count / maxCount).clamp(0.0, 1.0),
                      ],
                      labels: [
                        for (var i = 0; i < 7; i++)
                          _weekdayDateLabel(start.add(Duration(days: i))),
                      ],
                      displayMax: maxCount.toDouble(),
                      xPositions: _evenPositions(7),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringPage extends StatefulWidget {
  const _MonitoringPage({
    required this.sensorState,
    required this.recordingMovement,
    required this.onOpenReport,
    required this.onManualRecord,
  });

  final EspSensorState sensorState;
  final bool recordingMovement;
  final VoidCallback onOpenReport;
  final ValueChanged<int> onManualRecord;

  @override
  State<_MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<_MonitoringPage> {
  bool _showManualRecordChoices = false;

  @override
  void didUpdateWidget(covariant _MonitoringPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordingMovement && !widget.recordingMovement) {
      setState(() => _showManualRecordChoices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensorState = widget.sensorState;
    final sensorPercent = ((sensorState.peak.clamp(0, 4095) / 4095) * 100)
        .round();
        
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 130),
      children: [
        Center(
          child: Column(
            children: [
              Text('실시간 모니터링', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: '디바이스 연결 상태  ',
                  children: [
                    TextSpan(
                      text: sensorState.connected ? '기기 수신 중' : '수신 대기',
                      style: TextStyle(
                        color: sensorState.connected
                            ? AppColors.mint
                            : AppColors.coralDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 46),
        SizedBox(
          width: 280,
          height: 318,
          child: WaveMonitorWidget(
            connected: sensorState.connected,
            userMoving: sensorState.userMoving,
            movementActive: sensorState.movementActive,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatusTile(
                title: '태동',
                value: sensorState.movementActive ? '감지됨' : '감지 중',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusTile(
                title: '자세',
                value: sensorState.userMoving ? '흔들림' : '안정 상태',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusTile(
                title: '센서값', 
                value: '$sensorPercent%'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                '세션 시간',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(sensorState.elapsed),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          key: const Key('openManualMovementPickerButton'),
          onPressed: widget.recordingMovement
              ? null
              : () => setState(
                    () => _showManualRecordChoices = !_showManualRecordChoices,
                  ),
          icon: widget.recordingMovement
              ? const _ButtonLoader()
              : const Icon(Icons.touch_app_outlined),
          label: const Text('태동 기록 저장'),
        ),
        if (_showManualRecordChoices) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.recordingMovement
                      ? null
                      : () => widget.onManualRecord(2000),
                  child: const Text('약함'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.recordingMovement
                      ? null
                      : () => widget.onManualRecord(3000),
                  child: const Text('중간'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.recordingMovement
                      ? null
                      : () => widget.onManualRecord(3600),
                  child: const Text('강함'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.onOpenReport,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('타임라인 보기'),
          ),
        ),
        const SizedBox(height: 18),
        const _CareNotice(),
      ],
    );
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.userId});

  final String userId;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final MovementRepository _movementRepository = MovementRepository();
  Timer? _timelineTimer;
  int _range = 1;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timelineTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _isSameDay(_selectedDate, DateTime.now())) setState(() {});
    });
  }

  @override
  void dispose() {
    _timelineTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickReportDate() async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _ReportCalendarDialog(
        initialDate: _selectedDate,
        firstDate: DateTime(now.year - 1, 1, 1),
        lastViewMonth: DateTime(now.year, now.month + 2, 0),
        range: _range,
      ),
    );
    if (picked == null) return;
    setState(() => _selectedDate = _dateOnly(picked));
  }

  DateTime get _today => _dateOnly(DateTime.now());

  DateTime get _selectedWeekStart =>
      _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

  DateTime get _selectedWeekEnd {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    return _today.isBefore(weekEnd) ? _today : weekEnd;
  }

  String get _rangeLabel {
    if (_range == 0) return _formatDate(_selectedDate);
    if (_range == 1) {
      return '${_formatDate(_selectedWeekStart)} - ${_formatDate(_selectedWeekEnd)}';
    }
    return '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}';
  }

  void _movePeriod(int delta) {
    setState(() {
      if (_range == 0) {
        _selectedDate = _dateOnly(
          _selectedDate.add(Duration(days: delta)),
        );
      } else if (_range == 1) {
        _selectedDate = _dateOnly(
          _selectedDate.add(Duration(days: delta * 7)),
        );
      } else {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + delta,
        );
      }
      final today = _today;
      if (_selectedDate.isAfter(today)) _selectedDate = today;
    });
  }

  DateTime get _periodStart {
    if (_range == 0) return _dateOnly(_selectedDate);
    if (_range == 1) return _selectedWeekStart;
    return DateTime(_selectedDate.year, _selectedDate.month);
  }

  DateTime get _periodEndExclusive {
    if (_range == 0) {
      return _dateOnly(_selectedDate).add(const Duration(days: 1));
    }
    if (_range == 1) {
      return _selectedWeekStart.add(const Duration(days: 7));
    }
    return DateTime(_selectedDate.year, _selectedDate.month + 1);
  }

  Future<List<FetalMovementRecord>> _loadRecords() {
    return _movementRepository.findRecords(
      userId: widget.userId,
      start: _periodStart,
      end: _periodEndExclusive,
    );
  }

  Future<_DeviceTimelineData> _loadDeviceTimelineData() async {
    final start = _range == 0 ? _dateOnly(_selectedDate) : _periodStart;
    final end = _range == 0
        ? _dateOnly(_selectedDate).add(const Duration(days: 1))
        : _periodEndExclusive;
    final sessions = await _movementRepository.findDeviceSessions(
      userId: widget.userId,
      start: start,
      end: end,
    );
    DateTime? activeStart;
    final prefs = await SharedPreferences.getInstance();
    final on =
        prefs.getBool(EspSensorService.prefKey(widget.userId, 'deviceOn')) ??
        false;
    final startedAtMillis = prefs.getInt(
      EspSensorService.prefKey(widget.userId, 'startedAt'),
    );
    if (on && startedAtMillis != null) {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
      final now = DateTime.now();
      if (startedAt.isBefore(end) && now.isAfter(start)) {
        activeStart = startedAt;
      }
    }
    return _DeviceTimelineData(sessions: sessions, activeStart: activeStart);
  }

  _ReportPair _buildReportData(List<FetalMovementRecord> records) {
    if (_range == 0) return _buildDailyReport(records);
    if (_range == 1) return _buildWeeklyReport(records);
    return _buildMonthlyReport(records);
  }

  _ReportPair _buildDailyReport(List<FetalMovementRecord> records) {
    final moments = records
        .map(
          (record) => _ReportMoment(
            hour: record.measuredAt.hour + record.measuredAt.minute / 60,
            value: _sensorIntensityRatio(record.intensity),
            measuredAt: record.measuredAt,
            intensity: record.intensity,
            measuredDuringUserMotion: record.measuredDuringUserMotion,
          ),
        )
        .toList();
    return _ReportPair(
      count: _ReportData(
        title: '태동 횟수',
        unit: '회',
        labels: const ['0', '6', '12', '18', '24'],
        values: const [],
        moments: moments,
        mode: _ChartMode.dailyDots,
        zoomMax: 24,
      ),
      intensity: _ReportData(
        title: '태동 세기',
        unit: '%',
        labels: const ['0', '6', '12', '18', '24'],
        values: const [],
        moments: moments,
        mode: _ChartMode.dailyBars,
        displayMax: 100,
        zoomMax: 24,
      ),
    );
  }

  _ReportPair _buildWeeklyReport(List<FetalMovementRecord> records) {
    final counts = List<int>.filled(7, 0);
    final intensityTotals = List<int>.filled(7, 0);
    for (final record in records) {
      final index = _dateOnly(
        record.measuredAt,
      ).difference(_selectedWeekStart).inDays;
      if (index < 0 || index >= 7) continue;
      counts[index]++;
      intensityTotals[index] += record.intensity;
    }
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final countMax = math.max(200, counts.fold<int>(0, math.max)).toDouble();
    return _ReportPair(
      count: _ReportData(
        title: '태동 횟수',
        unit: '회',
        labels: labels,
        values: [
          for (var i = 0; i < 7; i++)
            _isFutureDate(_selectedWeekStart.add(Duration(days: i)))
                ? null
                : (counts[i] / countMax).clamp(0.0, 1.0),
        ],
        mode: _ChartMode.bar,
        displayMax: countMax,
        xPositions: _evenPositions(7),
        topInset: 24,
        highlightIndex: _todayIndexInWeek(),
        zoomMax: 1,
      ),
      intensity: _ReportData(
        title: '태동 세기',
        unit: '%',
        labels: labels,
        values: [
          for (var i = 0; i < 7; i++)
            _isFutureDate(_selectedWeekStart.add(Duration(days: i)))
                ? null
                : counts[i] == 0
                ? 0
                : _sensorIntensityRatio(intensityTotals[i] / counts[i]),
        ],
        mode: _ChartMode.bar,
        displayMax: 100,
        xPositions: _evenPositions(7),
        highlightIndex: _todayIndexInWeek(),
        zoomMax: 1,
      ),
    );
  }

  _ReportPair _buildMonthlyReport(List<FetalMovementRecord> records) {
    final lastDay = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final days = [for (var day = 1; day <= lastDay; day++) day];
    final counts = List<int>.filled(lastDay, 0);
    final intensityTotals = List<int>.filled(lastDay, 0);
    for (final record in records) {
      final index = record.measuredAt.day - 1;
      if (index < 0 || index >= lastDay) continue;
      counts[index]++;
      intensityTotals[index] += record.intensity;
    }
    final countMax = math.max(200, counts.fold<int>(0, math.max)).toDouble();
    final countValues = [
      for (var i = 0; i < days.length; i++)
        _isFutureDate(
              DateTime(_selectedDate.year, _selectedDate.month, days[i]),
            )
            ? null
            : counts[i] == 0
            ? null
            : (counts[i] / countMax).clamp(0.0, 1.0),
    ];
    final intensityValues = [
      for (var i = 0; i < days.length; i++)
        _isFutureDate(
              DateTime(_selectedDate.year, _selectedDate.month, days[i]),
            )
            ? null
            : counts[i] == 0
            ? null
            : _sensorIntensityRatio(intensityTotals[i] / counts[i]),
    ];
    final filledCounts = _interpolateMissingValues(countValues);
    final filledIntensity = _interpolateMissingValues(intensityValues);
    return _ReportPair(
      count: _ReportData(
        title: '태동 횟수',
        unit: '회',
        labels: [for (final day in days) day.toString()],
        values: filledCounts.values,
        mode: _ChartMode.line,
        displayMax: countMax,
        xPositions: _monthPositions(_selectedDate, days),
        zoomMax: 30 / 7,
        initialScale: 30 / 7,
        initialCenterPosition: _todayPositionInMonth(),
        topInset: 24,
        highlightIndex: _todayIndexInMonth(_selectedDate),
        missingIndexes: filledCounts.missingIndexes,
        monthlyDynamic: true,
        monthLastDay: lastDay,
      ),
      intensity: _ReportData(
        title: '태동 세기',
        unit: '%',
        labels: [for (final day in days) day.toString()],
        values: filledIntensity.values,
        mode: _ChartMode.line,
        displayMax: 100,
        xPositions: _monthPositions(_selectedDate, days),
        zoomMax: 30 / 7,
        initialScale: 30 / 7,
        initialCenterPosition: _todayPositionInMonth(),
        highlightIndex: _todayIndexInMonth(_selectedDate),
        missingIndexes: filledIntensity.missingIndexes,
        monthlyDynamic: true,
        monthLastDay: lastDay,
      ),
    );
  }

  bool _isFutureDate(DateTime date) => _dateOnly(date).isAfter(_today);

  int? _todayIndexInWeek() {
    final index = _today.difference(_selectedWeekStart).inDays;
    return index >= 0 && index < 7 ? index : null;
  }

  int? _todayIndexInMonth(DateTime month) {
    if (_today.year != month.year || _today.month != month.month) return null;
    return _today.day - 1;
  }

  double? _todayPositionInMonth() {
    final index = _todayIndexInMonth(_selectedDate);
    if (index == null) return null;
    final lastDay = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    return lastDay == 1 ? .5 : index / (lastDay - 1);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 130),
      children: [
        Row(
          children: [
            _ReportCircleIconButton(
              tooltip: '공유',
              onPressed: () {},
              asset: 'assets/images/icon/upload.png',
            ),
            Expanded(
              child: Center(
                child: Text(
                  '리포트',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            _ReportCircleIconButton(
              tooltip: '달력',
              onPressed: _pickReportDate,
              asset: 'assets/images/icon/calendar.png',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: _ReportRangeSelector(
            selected: _range,
            onChanged: (value) => setState(() {
              _range = value;
              final today = _today;
              if (_selectedDate.isAfter(today)) _selectedDate = today;
            }),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              onPressed: () => _movePeriod(-1),
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.black,
                size: 21,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 90),
              child: Text(
                _rangeLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              onPressed: _selectedDate.isBefore(_today)
                  ? () => _movePeriod(1)
                  : null,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black,
                size: 21,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<FetalMovementRecord>>(
          future: _loadRecords(),
          initialData: const [],
          builder: (context, snapshot) {
            final report = _buildReportData(snapshot.data ?? const []);
            return Column(
              children: [
                _ReportChartCard(data: report.count),
                const SizedBox(height: 14),
                _ReportChartCard(data: report.intensity),
                const SizedBox(height: 14),
                FutureBuilder<_DeviceTimelineData>(
                  future: _loadDeviceTimelineData(),
                  initialData: const _DeviceTimelineData(sessions: []),
                  builder: (context, timelineSnapshot) => _DeviceTimelineCard(
                    date: _selectedDate,
                    range: _range,
                    data:
                        timelineSnapshot.data ??
                        const _DeviceTimelineData(sessions: []),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'AI 요약',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'AI 요약은 아직 준비 중입니다. 태동 흐름을 참고용으로 정리하는 방향으로 고민하고 있습니다.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.user,
    required this.fetusName,
    required this.profileStyle,
    required this.profileBackgroundIndex,
    this.profileImageBytes,
    required this.deviceOn,
    required this.sensorStatus,
    required this.authRepository,
    required this.onUserChanged,
    required this.onLogout,
    required this.onFetusNameChanged,
    required this.onChangeProfileStyle,
    required this.onChangeProfileBackground,
    required this.onChangeProfileImage,
  });
  final AppUser user;
  final String fetusName;
  final int profileStyle;
  final int profileBackgroundIndex;
  final Uint8List? profileImageBytes;
  final bool deviceOn;
  final String sensorStatus;
  final AuthRepository authRepository;
  final ValueChanged<AppUser> onUserChanged;
  final VoidCallback onLogout;
  final ValueChanged<String> onFetusNameChanged;
  final ValueChanged<int> onChangeProfileStyle;
  final ValueChanged<int> onChangeProfileBackground;
  final ValueChanged<Uint8List> onChangeProfileImage;
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _profileForm = GlobalKey<FormState>();
  final _accountForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.user.displayName,
  );
  late final TextEditingController _fetus = TextEditingController(
    text: widget.fetusName,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.user.email,
  );
  final _accountPassword = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPasswordConfirm = TextEditingController();
  final _deletePassword = TextEditingController();
  int _tabIndex = 0;
  bool _autoSave = true;
  bool _profileSaving = false;
  bool _accountSaving = false;
  bool _passwordSaving = false;
  bool _deleting = false;
  String _selectedAlertSound = _alertSoundAssets.first;
  String? _profileMessage;
  String? _accountMessage;
  String? _passwordMessage;
  String? _deleteMessage;

  @override
  void initState() {
    super.initState();
    _restoreAlertSound();
  }

  Future<void> _restoreAlertSound() async {
    final asset = await _loadAlertSoundAsset(widget.user.id);
    if (mounted) setState(() => _selectedAlertSound = asset);
  }

  Future<void> _chooseAlertSound(String asset) async {
    setState(() => _selectedAlertSound = asset);
    await _saveAlertSoundAsset(widget.user.id, asset);
    await _playAlertSound(asset);
  }

  @override
  void dispose() {
    _name.dispose();
    _fetus.dispose();
    _email.dispose();
    _accountPassword.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _newPasswordConfirm.dispose();
    _deletePassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    setState(() {
      _profileSaving = true;
      _profileMessage = null;
    });
    try {
      final user = await widget.authRepository.updateAccount(
        displayName: _name.text,
        email: widget.user.email,
        fetusName: _fetus.text,
        profileImageIndex: widget.profileStyle,
        profileBackgroundIndex: widget.profileBackgroundIndex,
      );
      widget.onFetusNameChanged(user.fetusName);
      widget.onUserChanged(user);
      setState(() => _profileMessage = '태명과 프로필 정보가 클라우드에 저장되었습니다.');
    } on AuthException catch (error) {
      setState(() => _profileMessage = error.message);
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
  }

  Future<void> _saveAccount() async {
    if (!_accountForm.currentState!.validate()) return;
    setState(() {
      _accountSaving = true;
      _accountMessage = null;
    });
    try {
      final user = await widget.authRepository.updateAccount(
        displayName: widget.user.displayName,
        email: _email.text,
        currentPassword: _accountPassword.text,
      );
      widget.onUserChanged(user);
      setState(() => _accountMessage = '계정 정보가 클라우드에 저장되었습니다.');
    } on AuthException catch (error) {
      setState(() => _accountMessage = error.message);
    } finally {
      if (mounted) setState(() => _accountSaving = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() {
      _passwordSaving = true;
      _passwordMessage = null;
    });
    try {
      await widget.authRepository.updatePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      _newPassword.clear();
      _newPasswordConfirm.clear();
      setState(() => _passwordMessage = '비밀번호가 변경되었습니다.');
    } on AuthException catch (error) {
      setState(() => _passwordMessage = error.message);
    } finally {
      if (mounted) setState(() => _passwordSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletePassword.text.length < 6) {
      setState(() => _deleteMessage = '현재 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _deleting = true;
      _deleteMessage = null;
    });
    try {
      await widget.authRepository.deleteAccount(
        currentPassword: _deletePassword.text,
      );
      widget.onLogout();
    } on AuthException catch (error) {
      setState(() => _deleteMessage = error.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 120),
      children: [
        Text('My', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '계정과 기기 연결 정보를 확인해요',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _MyTabButton(
                key: const Key('profileTabButton'),
                selected: _tabIndex == 0,
                icon: Icons.badge_outlined,
                label: '프로필',
                onTap: () => setState(() => _tabIndex = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MyTabButton(
                key: const Key('accountTabButton'),
                selected: _tabIndex == 1,
                icon: Icons.manage_accounts_outlined,
                label: '계정 관리',
                onTap: () => setState(() => _tabIndex = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_tabIndex == 0)
          _buildProfileTab(context)
        else
          _buildAccountTab(context),
      ],
    );
  }

  Widget _buildProfileTab(BuildContext context) => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _ProfileAvatar(
                style: widget.profileStyle,
                backgroundIndex: widget.profileBackgroundIndex,
                imageBytes: widget.profileImageBytes,
                radius: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      widget.user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: '프로필 이미지 변경',
                onPressed: () => _showProfilePicker(
                  context,
                  widget.profileStyle,
                  widget.profileBackgroundIndex,
                  widget.onChangeProfileStyle,
                  widget.onChangeProfileBackground,
                  widget.onChangeProfileImage,
                ),
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _profileForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('프로필 설정', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('myDisplayNameField'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'User 이름'),
                  validator: _validateDisplayName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('myFetusNameField'),
                  controller: _fetus,
                  decoration: const InputDecoration(labelText: '태명'),
                  validator: _validateFetusName,
                ),
                if (_profileMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorNotice(message: _profileMessage!),
                ],
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  key: const Key('saveProfileButton'),
                  onPressed: _profileSaving ? null : _saveProfile,
                  icon: _profileSaving
                      ? const _ButtonLoader()
                      : const Icon(Icons.save_outlined),
                  label: const Text('프로필 저장'),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _buildAlertSoundCard(context),
      const SizedBox(height: 14),
      _buildDeviceCard(context),
    ],
  );

  Widget _buildAccountTab(BuildContext context) => Column(
    children: [
      _buildAccountInfoCard(context),
      const SizedBox(height: 14),
      _buildPasswordCard(context),
      const SizedBox(height: 14),
      _buildDeleteCard(context),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        key: const Key('logoutAccountButton'),
        onPressed: widget.onLogout,
        icon: const Icon(Icons.logout_outlined),
        label: const Text('로그아웃'),
      ),
    ],
  );

  Widget _buildAccountInfoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Form(
        key: _accountForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '계정 정보',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilterChip(
                  selected: _autoSave,
                  onSelected: (value) => setState(() => _autoSave = value),
                  label: Text(_autoSave ? '실시간 저장' : '수동 저장'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('myEmailField'),
              controller: _email,
              decoration: const InputDecoration(labelText: '이메일 주소'),
              validator: _validateEmail,
              onFieldSubmitted: (_) {
                if (_autoSave) _saveAccount();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('myCurrentPasswordField'),
              controller: _accountPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: '현재 비밀번호'),
            ),
            if (_accountMessage != null) ...[
              const SizedBox(height: 12),
              ErrorNotice(message: _accountMessage!),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              key: const Key('saveAccountButton'),
              onPressed: _accountSaving ? null : _saveAccount,
              icon: _accountSaving
                  ? const _ButtonLoader()
                  : const Icon(Icons.save_outlined),
              label: const Text('계정 정보 저장'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildPasswordCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _passwordForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('비밀번호 변경', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('passwordCurrentField'),
              controller: _currentPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: '현재 비밀번호'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('newPasswordField'),
              controller: _newPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호'),
              validator: _validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('newPasswordConfirmField'),
              controller: _newPasswordConfirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
              validator: (value) =>
                  value == _newPassword.text ? null : '비밀번호가 서로 다릅니다.',
            ),
            if (_passwordMessage != null) ...[
              const SizedBox(height: 12),
              ErrorNotice(message: _passwordMessage!),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              key: const Key('savePasswordButton'),
              onPressed: _passwordSaving ? null : _savePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.ink.withValues(alpha: .35),
                disabledForegroundColor: Colors.white70,
                elevation: 3,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              icon: _passwordSaving
                  ? const _ButtonLoader()
                  : const Icon(Icons.lock_reset_outlined),
              label: const Text('비밀번호 변경'),
            )
          ],
        ),
      ),
    ),
  );

  Widget _buildDeleteCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('계정 삭제', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '현재 비밀번호가 맞으면 계정 삭제가 진행됩니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('deletePasswordField'),
            controller: _deletePassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: '현재 비밀번호'),
          ),
          if (_deleteMessage != null) ...[
            const SizedBox(height: 12),
            ErrorNotice(message: _deleteMessage!),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            key: const Key('deleteAccountButton'),
            onPressed: _deleting ? null : _deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.ink.withValues(alpha: .35),
              disabledForegroundColor: Colors.white70,
              elevation: 3,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            icon: _deleting
                ? const _ButtonLoader()
                : const Icon(Icons.delete_outline),
            label: const Text('계정 삭제'),
          )
        ],
      ),
    ),
  );

  Widget _buildDeviceCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sensors_outlined,
                  color: AppColors.coralDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '복부 센서 기기',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _MiniPill(
                label: widget.deviceOn ? '복부센서 기기 연결됨' : '수신 대기',
                foreground: widget.deviceOn
                    ? AppColors.mint
                    : AppColors.coralDark,
                background: widget.deviceOn
                    ? const Color(0xFFDDF2EA)
                    : AppColors.peach,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.sensorStatus,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Wi-Fi: GODORI_WEARABLE / password1234',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  Widget _buildAlertSoundCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.coralDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '알림음 선택',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _selectedAlertSound
                          .split('/')
                          .last
                          .replaceAll('.mp3', ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: '미리듣기',
                onPressed: () =>
                    unawaited(_playAlertSound(_selectedAlertSound)),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            key: const Key('openAlertSoundPickerButton'),
            onPressed: () => _showAlertSoundPicker(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: .18),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            icon: const Icon(Icons.music_note_outlined),
            label: const Text('알림음 선택'),
          ),
        ],
      ),
    ),
  );

  void _showAlertSoundPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('알림음 선택', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 18),
            for (var i = 0; i < _alertSoundAssets.length; i++) ...[
              _AlertSoundSheetRow(
                key: Key('alertSoundChoice$i'),
                title: i == 0 ? '알림음 1 (default)' : '알림음 ${i + 1}',
                selected: _selectedAlertSound == _alertSoundAssets[i],
                onSelect: () {
                  unawaited(_chooseAlertSound(_alertSoundAssets[i]));
                  Navigator.pop(context);
                },
                onPreview: () => unawaited(
                  _playAlertSound(_alertSoundAssets[i]),
                ),
              ),
              if (i != _alertSoundAssets.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertSoundSheetRow extends StatelessWidget {
  const _AlertSoundSheetRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onSelect,
    required this.onPreview,
  });

  final String title;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onSelect,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: selected ? AppColors.peach : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton.icon(
            onPressed: onPreview,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('소리재생'),
            style: TextButton.styleFrom(foregroundColor: const ui.Color.fromARGB(255, 255, 255, 255)),
          ),
        ],
      ),
    ),
  );
}

class _MyTabButton extends StatelessWidget {
  const _MyTabButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.coralDark : AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: selected ? AppColors.peach : Colors.white.withValues(alpha: .6),
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.coral : AppColors.line,
                width: selected ? 4 : 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportChartCard extends StatefulWidget {
  const _ReportChartCard({required this.data});
  final _ReportData data;

  @override
  State<_ReportChartCard> createState() => _ReportChartCardState();
}

class _ReportCircleIconButton extends StatelessWidget {
  const _ReportCircleIconButton({
    required this.tooltip,
    required this.asset,
    required this.onPressed,
  });

  final String tooltip;
  final String asset;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Image.asset(
          asset,
          width: 24,
          height: 24,
          color: AppColors.ink,
        ),
      ),
    ),
  );
}

class _ReportRangeSelector extends StatelessWidget {
  const _ReportRangeSelector({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['일간', '주간', '월간'];
    return Container(
      width: 246,
      height: 54,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.controlGray,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i ? AppColors.ink : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: i == selected
                        ? null
                        : Border.all(color: AppColors.line.withValues(alpha: .8)),
                  ),
                  child: Text(
                    labels[i],
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected == i ? Colors.white : AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportChartCardState extends State<_ReportChartCard> {
  late final ScrollController _scrollController;
  late double _axisScale;
  double _gestureStartScale = 1;
  String? _dataKey;
  List<_ReportMoment> _selectedMoments = const [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _resetChartState();
  }

  @override
  void didUpdateWidget(covariant _ReportChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _chartDataKey(widget.data);
    if (_dataKey != nextKey) {
      _resetChartState();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetChartState() {
    _dataKey = _chartDataKey(widget.data);
    _axisScale = widget.data.initialScale.clamp(1.0, widget.data.zoomMax);
    _gestureStartScale = _axisScale;
    _selectedMoments = const [];
    _centerOnInitialPosition();
  }

  void _centerOnInitialPosition() {
    final position = widget.data.initialCenterPosition;
    if (position == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final viewport = _scrollController.position.viewportDimension;
      final contentWidth =
          _scrollController.position.maxScrollExtent + viewport;
      final target = (contentWidth * position - viewport / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    });
  }

  void _setAxisScale(double nextScale) {
    setState(() {
      _axisScale = nextScale.clamp(1.0, widget.data.zoomMax);
      _gestureStartScale = _axisScale;
    });
  }

  void _selectDailyDetail(TapUpDetails details, BoxConstraints constraints) {
    if (widget.data.moments.isEmpty ||
        (widget.data.mode != _ChartMode.dailyDots &&
            widget.data.mode != _ChartMode.dailyBars)) {
      return;
    }

    final contentWidth = constraints.maxWidth * _axisScale;
    final tappedX = details.localPosition.dx + _scrollController.offset;
    final tappedHour = (tappedX / contentWidth * 24).clamp(0.0, 24.0);

    final bucketMinutes = _aggregationMinutes(_axisScale);
    final tappedMinute = (tappedHour * 60).round();
    final tappedBucket = (tappedMinute / bucketMinutes).floor() * bucketMinutes;

    final grouped = <int, List<_ReportMoment>>{};

    for (final moment in widget.data.moments) {
      final measuredAt = moment.measuredAt;
      if (measuredAt == null) continue;

      final minute = (moment.hour * 60).round();
      final bucket = (minute / bucketMinutes).floor() * bucketMinutes;

      grouped.putIfAbsent(bucket, () => []).add(moment);
    }

    if (grouped.isEmpty) return;

    final nearestBucket = grouped.keys.reduce((a, b) {
      final aDiff = (a - tappedBucket).abs();
      final bDiff = (b - tappedBucket).abs();
      return aDiff <= bDiff ? a : b;
    });

    final bucketMoments = [...grouped[nearestBucket]!]
      ..sort((a, b) => a.measuredAt!.compareTo(b.measuredAt!));

    setState(() => _selectedMoments = bucketMoments);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.data.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.data.zoomMax > 1) ...[
                IconButton(
                  tooltip: '축소',
                  iconSize: 22,
                  onPressed: _axisScale <= 1
                      ? null
                      : () => _setAxisScale(_axisScale - .35),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.ink,
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                ),
                IconButton(
                  tooltip: '확대',
                  iconSize: 22,
                  onPressed: _axisScale >= widget.data.zoomMax
                      ? null
                      : () => _setAxisScale(_axisScale + .35),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.ink,
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 178,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth * _axisScale;
                return GestureDetector(
                  onTapUp: (details) =>
                      _selectDailyDetail(details, constraints),
                  onScaleStart: (_) => _gestureStartScale = _axisScale,
                  onScaleUpdate: (details) {
                    if (details.pointerCount < 2) return;
                    setState(() {
                      _axisScale = (_gestureStartScale * details.scale).clamp(
                        1.0,
                        widget.data.zoomMax,
                      );
                    });
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      height: constraints.maxHeight,
                      child: CustomPaint(
                        painter: widget.data.mode == _ChartMode.bar
                            ? _RoundedBarChartPainter(
                                values: widget.data.values,
                                labels: widget.data.labels,
                                displayMax: widget.data.displayMax,
                                xPositions: widget.data.xPositions,
                                topInset: widget.data.topInset,
                                highlightIndex: widget.data.highlightIndex,
                              )
                            : widget.data.mode == _ChartMode.line
                            ? _LineChartPainter(
                                values: widget.data.values,
                                labels: widget.data.labels,
                                displayMax: widget.data.displayMax,
                                xPositions: widget.data.xPositions,
                                topInset: widget.data.topInset,
                                highlightIndex: widget.data.highlightIndex,
                                missingIndexes: widget.data.missingIndexes,
                                monthlyDynamic: widget.data.monthlyDynamic,
                                axisScale: _axisScale,
                                monthLastDay: widget.data.monthLastDay,
                              )
                            : widget.data.mode == _ChartMode.dailyBars
                            ? _DailyBarChartPainter(
                                points: widget.data.moments,
                                axisScale: _axisScale,
                              )
                            : _DailyDotChartPainter(
                                points: widget.data.moments,
                                axisScale: _axisScale,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedMoments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DailyDetailCard(
              title: widget.data.title,
              moments: _selectedMoments,
              onClose: () => setState(() => _selectedMoments = const []),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DeviceTimelineData {
  const _DeviceTimelineData({required this.sessions, this.activeStart});
  final List<DeviceUsageSession> sessions;
  final DateTime? activeStart;
}

class _DailyDetailCard extends StatefulWidget {
  const _DailyDetailCard({
    required this.title,
    required this.moments,
    required this.onClose,
  });

  final String title;
  final List<_ReportMoment> moments;
  final VoidCallback onClose;

  @override
  State<_DailyDetailCard> createState() => _DailyDetailCardState();
}

class _DailyDetailCardState extends State<_DailyDetailCard> {
  static const int _itemsPerPage = 6;
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant _DailyDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.moments != widget.moments ||
        oldWidget.title != widget.title) {
      _pageIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final moments = widget.moments;
    final first = moments.isEmpty ? null : moments.first.measuredAt;

    final minuteLabel = first == null
        ? ''
        : '${first.hour.toString().padLeft(2, '0')}:${first.minute.toString().padLeft(2, '0')}';

    final isCount = widget.title.contains('횟수');

    final pageCount = math.max(1, (moments.length / _itemsPerPage).ceil());
    final safePageIndex = _pageIndex.clamp(0, pageCount - 1);
    final startIndex = safePageIndex * _itemsPerPage;
    final endIndex = math.min(startIndex + _itemsPerPage, moments.length);
    final visibleMoments = moments.sublist(startIndex, endIndex);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 38),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      minuteLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (moments.length > _itemsPerPage)
                      Text(
                        '총 ${moments.length}개 중 ${startIndex + 1}-$endIndex',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),

          for (final moment in visibleMoments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                isCount
                    ? '${_formatClock(moment.measuredAt)} 태동: 1회${moment.measuredDuringUserMotion ? ' (사용자의 움직임이 센서 값에 섞여있어요)' : ''}'
                    : '${_formatClock(moment.measuredAt)} 세기: ${(_sensorIntensityRatio(moment.intensity ?? 0) * 100).round()}% (${_intensityLabel(moment.intensity ?? 0)})${moment.measuredDuringUserMotion ? ' (사용자의 움직임이 센서 값에 섞여있어요)' : ''}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),

          if (pageCount > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '이전 페이지',
                  onPressed: safePageIndex <= 0
                      ? null
                      : () => setState(() => _pageIndex--),
                  icon: const Icon(Icons.chevron_left_rounded),
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                ),
                Text(
                  '${safePageIndex + 1}/$pageCount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: '다음 페이지',
                  onPressed: safePageIndex >= pageCount - 1
                      ? null
                      : () => setState(() => _pageIndex++),
                  icon: const Icon(Icons.chevron_right_rounded),
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTimelineCard extends StatefulWidget {
  const _DeviceTimelineCard({
    required this.date,
    required this.range,
    required this.data,
  });
  final DateTime date;
  final int range;
  final _DeviceTimelineData data;

  @override
  State<_DeviceTimelineCard> createState() => _DeviceTimelineCardState();
}

class _DeviceTimelineCardState extends State<_DeviceTimelineCard> {
  late final ScrollController _scrollController;
  late double _axisScale;
  double _gestureStartScale = 1;
  String? _timelineKey;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _resetTimelineState();
  }

  @override
  void didUpdateWidget(covariant _DeviceTimelineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey =
        '${widget.range}-${widget.date.year}-${widget.date.month}-${widget.date.day}';
    if (_timelineKey != nextKey) _resetTimelineState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetTimelineState() {
    _timelineKey =
        '${widget.range}-${widget.date.year}-${widget.date.month}-${widget.date.day}';
    _axisScale = widget.range == 2 ? 30 / 7 : 1;
    _gestureStartScale = _axisScale;
    if (widget.range == 2) _centerMonthlyToday();
  }

  void _centerMonthlyToday() {
    final today = _dateOnly(DateTime.now());
    if (today.year != widget.date.year || today.month != widget.date.month) {
      return;
    }
    final lastDay = DateTime(widget.date.year, widget.date.month + 1, 0).day;
    final position = lastDay == 1 ? .5 : (today.day - 1) / (lastDay - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final viewport = _scrollController.position.viewportDimension;
      final contentWidth =
          _scrollController.position.maxScrollExtent + viewport;
      final target = (contentWidth * position - viewport / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기기 사용 타임라인', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 20),
          SizedBox(
            height: widget.range == 0 ? 96 : 178,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxScale = widget.range == 0
                    ? 1.0
                    : widget.range == 1
                    ? 4.0
                    : 30 / 7;
                final width = constraints.maxWidth * _axisScale;
                return GestureDetector(
                  onScaleStart: (_) => _gestureStartScale = _axisScale,
                  onScaleUpdate: (details) {
                    if (details.pointerCount < 2 || maxScale <= 1) return;
                    setState(() {
                      _axisScale = (_gestureStartScale * details.scale).clamp(
                        1.0,
                        maxScale,
                      );
                    });
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      height: constraints.maxHeight,
                      child: CustomPaint(
                        painter: widget.range == 0
                            ? _DeviceTimelinePainter(
                                date: widget.date,
                                data: widget.data,
                              )
                            : widget.range == 1
                            ? _DeviceUsageBarPainter(
                                date: widget.date,
                                data: widget.data,
                              )
                            : _DeviceUsageMonthlyPainter(
                                date: widget.date,
                                data: widget.data,
                                axisScale: _axisScale,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReportCalendarDialog extends StatefulWidget {
  const _ReportCalendarDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastViewMonth,
    required this.range,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastViewMonth;
  final int range;

  @override
  State<_ReportCalendarDialog> createState() => _ReportCalendarDialogState();
}

class _ReportCalendarDialogState extends State<_ReportCalendarDialog> {
  late DateTime _visibleMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  @override
  Widget build(BuildContext context) {
    final firstVisible = DateTime(_visibleMonth.year, _visibleMonth.month, 1)
        .subtract(
          Duration(
            days: DateTime(_visibleMonth.year, _visibleMonth.month).weekday - 1,
          ),
        );
    final selected = _dateOnly(widget.initialDate);
    final rangeStart = widget.range == 1
        ? selected.subtract(Duration(days: selected.weekday - 1))
        : widget.range == 2
        ? DateTime(selected.year, selected.month)
        : selected;
    final rangeEnd = widget.range == 1
        ? rangeStart.add(const Duration(days: 6))
        : widget.range == 2
        ? DateTime(selected.year, selected.month + 1, 0)
        : selected;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _canMoveMonth(-1)
                      ? () => setState(
                          () => _visibleMonth = DateTime(
                            _visibleMonth.year,
                            _visibleMonth.month - 1,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 30),
                ),
                Expanded(
                  child: Text(
                    '${_visibleMonth.year}.${_visibleMonth.month.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _canMoveMonth(1)
                      ? () => setState(
                          () => _visibleMonth = DateTime(
                            _visibleMonth.year,
                            _visibleMonth.month + 1,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final label in const ['월', '화', '수', '목', '금', '토', '일'])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final date = firstVisible.add(Duration(days: index));
                final inMonth = date.month == _visibleMonth.month;
                final inRange =
                    !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
                final isSelected = _isSameDay(date, selected);
                final enabled = !date.isBefore(widget.firstDate);
                return InkWell(
                  onTap: enabled
                      ? () => Navigator.pop(context, _dateOnly(date))
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.coral
                          : inRange
                          ? AppColors.peach.withValues(alpha: .74)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: !enabled || !inMonth
                            ? AppColors.muted.withValues(alpha: .45)
                            : isSelected
                            ? Colors.white
                            : AppColors.ink,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _canMoveMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final last = DateTime(
      widget.lastViewMonth.year,
      widget.lastViewMonth.month,
    );
    return !next.isBefore(first) && !next.isAfter(last);
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 92),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.foreground,
    required this.background,
  });
  final String label;
  final Color foreground;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CareNotice extends StatelessWidget {
  const _CareNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF2),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8D9B8)),
    ),
    child: Text(
      '태동 정보는 일상 확인을 돕는 참고 지표입니다. 걱정이 이어지면 의료진과 상담해 주세요.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.peach,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message),
  );
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.style,
    required this.backgroundIndex,
    required this.radius,
    this.imageBytes,
  });
  final int style;
  final int backgroundIndex;
  final double radius;
  final Uint8List? imageBytes;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: Container(
      width: radius * 2,
      height: radius * 2,
      color:
          _profileBackgroundColors[backgroundIndex %
              _profileBackgroundColors.length],
      child: imageBytes == null
          ? Transform.scale(
              scale: 1.16,
              child: Padding(
                padding: EdgeInsets.all(radius * .04),
                child: Image.asset(
                  _profileAssetPath(style),
                  fit: BoxFit.contain,
                ),
              ),
            )
          : Image.memory(imageBytes!, fit: BoxFit.cover),
    ),
  );
}

class _FloatingFetusViewer extends StatefulWidget {
  const _FloatingFetusViewer({required this.style, this.imageBytes});
  final int style;
  final Uint8List? imageBytes;
  @override
  State<_FloatingFetusViewer> createState() => _FloatingFetusViewerState();
}

class _FloatingFetusViewerState extends State<_FloatingFetusViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * math.pi * 2;
        final usesObjectAsset =
            widget.imageBytes == null &&
            (widget.style == 0 || widget.style == 1);
        final floatingOffset = usesObjectAsset
            ? Offset(0, math.sin(t) * 4)
            : Offset(math.cos(t) * 7, math.sin(t * 1.4) * 6);
        return LayoutBuilder(
          builder: (context, constraints) {
            final imageSize =
                math.min(constraints.maxWidth, constraints.maxHeight) * .88;
            
            const realFetusScale = .96;
            const abstractFetusScale = 1.08;
            const uploadedFetusScale = .95;
            
            if (widget.imageBytes == null && widget.style == 1) {
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: Transform.translate(
                    offset: floatingOffset,
                    child: Transform.scale(
                      alignment: Alignment.centerLeft,
                      scale: realFetusScale,
                      child: Image.asset(
                        _fetusRealObjectAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            }
            return Center(
              child: SizedBox(
                width: imageSize,
                height: imageSize,
                child: Transform.translate(
                  offset: floatingOffset,
                  child: widget.imageBytes != null
                      ? Transform.scale(
                          scale: uploadedFetusScale,
                          child: Image.memory(
                            widget.imageBytes!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Transform.scale(
                          scale: abstractFetusScale,
                          child: Image.asset(
                            _fetusAbstractObjectAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class WaveMonitorWidget extends StatefulWidget {
  const WaveMonitorWidget({
    super.key,
    required this.connected,
    required this.userMoving,
    required this.movementActive,
  });

  final bool connected;
  final bool userMoving;
  final bool movementActive;

  @override
  State<WaveMonitorWidget> createState() => _WaveMonitorWidgetState();
}

class _WaveMonitorWidgetState extends State<WaveMonitorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _statusText {
    if (widget.movementActive) return '태동 감지 중';
    if (widget.userMoving) return '센서 흔들리는 중';
    if (widget.connected) return '기기 작동 중';
    return '기기 전원 꺼짐';
  }

  Color get _statusColor {
    if (widget.movementActive) return const Color(0xFFFFA279);
    if (widget.userMoving) return const Color(0xFFFF461D);
    if (widget.connected) return const Color(0xFF00C96B);
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.connected || widget.movementActive;

    return Center(
      child: SizedBox(
        width: 280,
        height: 318,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            SizedBox.square(
              dimension: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    _monitoringStainAsset,
                    width: 276,
                    height: 276,
                    fit: BoxFit.contain,
                  ),
                  Transform.scale(
                    scale: 1.28,
                    child: Image.asset(
                      _monitoringCircleAsset,
                      width: 270,
                      height: 270,
                      fit: BoxFit.contain,
                    ),
                  ),
                  RepaintBoundary(
                    child: SizedBox.square(
                      dimension: 280,
                      child: CustomPaint(
                        painter: _MonitoringWavePainter(
                          active: active,
                          phase: _controller,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _statusColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringWavePainter extends CustomPainter {
  const _MonitoringWavePainter({
    required this.active,
    required this.phase,
  }) : super(repaint: phase);

  final bool active;
  final Animation<double> phase;

  static const Color _waveColor = Color(0xFFFFA279);
  static const int _pointCount = 96;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final circleRect = Rect.fromCircle(center: center, radius: radius);
    final circlePath = Path()..addOval(circleRect);

    final baseY = center.dy + radius * 0.04;
    final amplitude = active ? 30.0 : 10.0;
    final waveLength = radius * 0.62;

    final wavePath = Path();
    final fillPath = Path();

    final startX = center.dx - radius;
    final endX = center.dx + radius;

    final phaseRadians = phase.value * math.pi * 2;

    for (var i = 0; i <= _pointCount; i++) {
      final progress = i / _pointCount;
      final x = startX + (endX - startX) * progress;

      final y = baseY +
          math.sin(((x / waveLength) * math.pi * 2) + phaseRadians) *
              amplitude;

      if (i == 0) {
        wavePath.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(endX, center.dy + radius)
      ..lineTo(startX, center.dy + radius)
      ..close();

    canvas.save();
    canvas.clipPath(circlePath);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(center.dx, baseY - amplitude - 12),
        Offset(center.dx, center.dy + radius),
        [
          const Color(0xFFFFD7C6),
          const Color(0xCCFFD7C6), // wave 바로 아래 진한 살구색
          const Color(0x00FFD7C6), // 아래쪽 투명
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawPath(fillPath, fillPaint);

    final wavePaint = Paint()
      ..color = _waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(wavePath, wavePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MonitoringWavePainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.phase != phase;
  }
}

enum _ChartMode { bar, line, dailyDots, dailyBars }

enum _ChartValueFormat { number, duration }

Path _smoothPathForPoints(List<Offset> points) {
  final path = Path();

  if (points.isEmpty) return path;

  path.moveTo(points.first.dx, points.first.dy);

  if (points.length == 1) return path;

  for (var i = 0; i < points.length - 1; i++) {
    final current = points[i];
    final next = points[i + 1];

    final midX = (current.dx + next.dx) / 2;

    path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
  }

  return path;
}

class _ReportMoment {
  const _ReportMoment({
    required this.hour,
    required this.value,
    this.measuredAt,
    this.intensity,
    this.measuredDuringUserMotion = false,
  });
  final double hour;
  final double value;
  final DateTime? measuredAt;
  final int? intensity;
  final bool measuredDuringUserMotion;
}

class _ReportPair {
  const _ReportPair({required this.count, required this.intensity});
  final _ReportData count;
  final _ReportData intensity;
}

class _InterpolatedValues {
  const _InterpolatedValues({
    required this.values,
    required this.missingIndexes,
  });
  final List<double?> values;
  final Set<int> missingIndexes;
}

class _ReportData {
  const _ReportData({
    required this.title,
    required this.unit,
    required this.labels,
    required this.values,
    required this.mode,
    this.displayMax = 100,
    this.xPositions = const [],
    this.zoomMax = 4,
    this.initialScale = 1,
    this.initialCenterPosition,
    this.topInset = 0,
    this.highlightIndex,
    this.moments = const [],
    this.missingIndexes = const {},
    this.monthlyDynamic = false,
    this.monthLastDay,
  });
  final String title;
  final String unit;
  final List<String> labels;
  final List<double?> values;
  final _ChartMode mode;
  final double displayMax;
  final List<double> xPositions;
  final double zoomMax;
  final double initialScale;
  final double? initialCenterPosition;
  final double topInset;
  final int? highlightIndex;
  final List<_ReportMoment> moments;
  final Set<int> missingIndexes;
  final bool monthlyDynamic;
  final int? monthLastDay;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.labels,
    required this.displayMax,
    this.xPositions = const [],
    this.topInset = 0,
    this.highlightIndex,
    this.valueFormat = _ChartValueFormat.number,
    this.missingIndexes = const {},
    this.monthlyDynamic = false,
    this.axisScale = 1,
    this.monthLastDay,
  });
  final List<double?> values;
  final List<String> labels;
  final double displayMax;
  final List<double> xPositions;
  final double topInset;
  final int? highlightIndex;
  final _ChartValueFormat valueFormat;
  final Set<int> missingIndexes;
  final bool monthlyDynamic;
  final double axisScale;
  final int? monthLastDay;
  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - 22 - topInset;
    if (displayMax == 100) {
      _drawIntensityGuides(canvas, size, height, topInset: topInset);
    }
    final visibleIndexes = monthlyDynamic
        ? _monthlyVisibleIndexes(axisScale, monthLastDay ?? values.length)
        : [for (var i = 0; i < values.length; i++) i];
    final points = <Offset?>[
      for (final i in visibleIndexes)
        if (values[i] == null)
          null
        else
          Offset(
            _chartX(size, i, values.length, xPositions),
            topInset + height - height * values[i]!,
          ),
    ];
    final segments = <List<Offset>>[];
    var currentSegment = <Offset>[];
    for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
      final point = points[pointIndex];
      final valueIndex = visibleIndexes[pointIndex];
      if (point == null || (!monthlyDynamic && missingIndexes.contains(valueIndex))) {
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
          currentSegment = <Offset>[];
        }
        continue;
      }
      currentSegment.add(point);
    }
    if (currentSegment.isNotEmpty) segments.add(currentSegment);
    for (final segment in segments) {
      final path = _smoothPathForPoints(segment);
      final fillPath = Path.from(path)
        ..lineTo(segment.last.dx, topInset + height)
        ..lineTo(segment.first.dx, topInset + height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, topInset),
            Offset(0, topInset + height),
            [
              AppColors.coral.withValues(alpha: .28),
              AppColors.coral.withValues(alpha: 0),
            ],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.coral
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
      final point = points[pointIndex];
      final valueIndex = visibleIndexes[pointIndex];
      if (point == null) {
        _drawMissingMarker(
          canvas,
          size,
          valueIndex,
          values.length,
          height,
          xPositions,
          topInset: topInset,
        );
        continue;
      }
      final pointColor = valueIndex == highlightIndex
          ? AppColors.mint
          : AppColors.coral;
      canvas.drawCircle(point, 5.2, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.4, Paint()..color = pointColor);
      _drawChartValue(
        canvas,
        point.translate(0, -18),
        missingIndexes.contains(valueIndex)
            ? '-'
            : _valueText(values[valueIndex], displayMax, valueFormat),
      );
    }
    _drawLabels(
      canvas,
      size,
      [
        for (final i in visibleIndexes)
          monthlyDynamic && i == 0 && axisScale < 3.5 ? '0' : labels[i],
      ],
      xPositions: [for (final i in visibleIndexes) xPositions[i]],
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.axisScale != axisScale ||
      oldDelegate.highlightIndex != highlightIndex ||
      oldDelegate.topInset != topInset ||
      oldDelegate.missingIndexes != missingIndexes ||
      oldDelegate.monthlyDynamic != monthlyDynamic ||
      oldDelegate.valueFormat != valueFormat;
}

class _RoundedBarChartPainter extends CustomPainter {
  const _RoundedBarChartPainter({
    required this.values,
    required this.labels,
    required this.displayMax,
    this.xPositions = const [],
    this.topInset = 0,
    this.highlightIndex,
    this.valueFormat = _ChartValueFormat.number,
  });
  final List<double?> values;
  final List<String> labels;
  final double displayMax;
  final List<double> xPositions;
  final double topInset;
  final int? highlightIndex;
  final _ChartValueFormat valueFormat;
  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - 28 - topInset;
    if (displayMax == 100) {
      _drawIntensityGuides(canvas, size, height, topInset: topInset);
    }
    final gap = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final width = math.min(26.0, gap * .42);
      final centerX = _chartX(size, i, values.length, xPositions);
      final x = (centerX - width / 2).clamp(0, size.width - width).toDouble();
      final value = values[i];
      final isMissing = value == null;
      final barHeight = height * (value ?? .12);
      final rect = isMissing
          ? RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(centerX, topInset + height),
                width: math.max(24, width),
                height: 10,
              ),
              const Radius.circular(99),
            )
          : RRect.fromRectAndRadius(
              Rect.fromLTWH(x, topInset + height - barHeight, width, barHeight),
              Radius.circular(width / 2),
            );
      final isHighlighted =
          i == highlightIndex || (i == 3 && highlightIndex == null);
     
      final paint = Paint();

      if (isMissing) {
        paint.color = AppColors.softGray.withValues(alpha: .52);
      } else if (isHighlighted) {
        paint.shader = ui.Gradient.linear(
          Offset(0, rect.top),
          Offset(0, rect.bottom),
          [AppColors.mint, AppColors.mint.withValues(alpha: .58)],
        );
      } else {
        paint.shader = ui.Gradient.linear(
          Offset(0, rect.top),
          Offset(0, rect.bottom),
          const [Color(0xFFFFA077), Color(0xFFFFD7C6)],
          const [0.0, 1.0],
        );
      }

      canvas.drawRRect(rect, paint);

      _drawChartValue(
        canvas,
        Offset(x + width / 2, topInset + height - barHeight - 12),
        isMissing ? '-' : _valueText(value, displayMax, valueFormat),
      );
    }
    _drawLabels(canvas, size, labels, xPositions: xPositions);
  }

  @override
  bool shouldRepaint(covariant _RoundedBarChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.highlightIndex != highlightIndex ||
      oldDelegate.topInset != topInset ||
      oldDelegate.valueFormat != valueFormat;
}

class _DailyDotChartPainter extends CustomPainter {
  const _DailyDotChartPainter({required this.points, required this.axisScale});
  final List<_ReportMoment> points;
  final double axisScale;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - 28;
    final baselineY = height * .66;
    _drawTimeAxis(
      canvas,
      size,
      baselineY,
      intervalHours: _timeInterval(axisScale),
    );
    final grouped = <int, List<_ReportMoment>>{};
    final bucketMinutes = _aggregationMinutes(axisScale);
    for (final point in points) {
      final minute = (point.hour * 60).round();
      final bucket = (minute / bucketMinutes).floor() * bucketMinutes;
      grouped.putIfAbsent(bucket, () => []).add(point);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      final group = entry.value;
      final hour = entry.key / 60;
      final intensity =
          group.fold<double>(0, (sum, point) => sum + point.value) /
          group.length;
      final x = (hour / 24).clamp(0.0, 1.0) * size.width;
      final outerRadius = 4.5 + intensity.clamp(0.0, 1.0) * 3;
      final innerRadius = math.max(3.2, outerRadius - 2.1);
      canvas.drawCircle(
        Offset(x, baselineY),
        outerRadius,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(x, baselineY),
        innerRadius,
        Paint()..color = AppColors.coral,
      );
      _drawTinyLabel(
        canvas,
        Offset(x, baselineY - outerRadius - 8),
        '${group.length}',
      );
    }
    _drawLabels(
      canvas,
      size,
      _timeLabels(axisScale),
      xPositions: _timeLabelPositions(axisScale),
    );
  }

  @override
  bool shouldRepaint(covariant _DailyDotChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.axisScale != axisScale;
}

class _DailyBarChartPainter extends CustomPainter {
  const _DailyBarChartPainter({required this.points, required this.axisScale});
  final List<_ReportMoment> points;
  final double axisScale;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - 28;
    _drawIntensityGuides(canvas, size, height);
    _drawTimeAxis(
      canvas,
      size,
      height,
      intervalHours: _timeInterval(axisScale),
    );
    final viewportWidth = size.width / axisScale.clamp(1.0, double.infinity);
    final barWidth = 7.0;
    final grouped = <int, List<_ReportMoment>>{};
    final bucketMinutes = _aggregationMinutes(axisScale);
    for (final point in points) {
      final minute = (point.hour * 60).round();
      final bucket = (minute / bucketMinutes).floor() * bucketMinutes;
      grouped.putIfAbsent(bucket, () => []).add(point);
    }
    for (final group in grouped.values) {
      final hour =
          group.fold<double>(0, (sum, point) => sum + point.hour) /
          group.length;
      final value =
          group.fold<double>(0, (sum, point) => sum + point.value) /
          group.length;
      final x = (hour / 24).clamp(0.0, 1.0) * size.width;
      final barHeight = height * value.clamp(.08, 1.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (x - barWidth / 2).clamp(0, size.width - barWidth),
          height - barHeight,
          barWidth,
          barHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, rect.top),
            Offset(0, rect.bottom),
            const [Color(0xFFFFA077), Color(0xFFFFD7C6)],
            const [0.0, 1.0],
          ),
      );
    }
    _drawLabels(
      canvas,
      size,
      _timeLabels(axisScale),
      xPositions: _timeLabelPositions(axisScale),
    );
  }

  @override
  bool shouldRepaint(covariant _DailyBarChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.axisScale != axisScale;
}

class _DeviceTimelinePainter extends CustomPainter {
  const _DeviceTimelinePainter({required this.date, required this.data});
  final DateTime date;
  final _DeviceTimelineData data;

  @override
  void paint(Canvas canvas, Size size) {
    final axisY = size.height * .46;
    _drawTimeAxis(canvas, size, axisY);
    final dayStart = _dateOnly(date);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final endedPaint = Paint()
      ..color = AppColors.coral
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final session in data.sessions) {
      final start = session.startedAt.isBefore(dayStart)
          ? dayStart
          : session.startedAt;
      final end = session.endedAt.isAfter(dayEnd) ? dayEnd : session.endedAt;
      if (!end.isAfter(start)) continue;
      final startHour = start.difference(dayStart).inMinutes / 60;
      final endHour = end.difference(dayStart).inMinutes / 60;
      canvas.drawLine(
        Offset(size.width * startHour / 24, axisY),
        Offset(size.width * endHour / 24, axisY),
        endedPaint,
      );
    }
    final activeStart = data.activeStart;
    if (activeStart != null && _isSameDay(date, DateTime.now())) {
      final start = activeStart.isBefore(dayStart) ? dayStart : activeStart;
      final end = DateTime.now().isAfter(dayEnd) ? dayEnd : DateTime.now();
      if (end.isAfter(start)) {
        final activePaint = Paint()
          ..color = AppColors.mint
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        final startHour = start.difference(dayStart).inMinutes / 60;
        final endHour = end.difference(dayStart).inMinutes / 60;
        final startOffset = Offset(size.width * startHour / 24, axisY);
        final endOffset = Offset(size.width * endHour / 24, axisY);
        canvas.drawCircle(startOffset, 4.5, Paint()..color = AppColors.mint);
        canvas.drawLine(startOffset, endOffset, activePaint);
        canvas.drawCircle(endOffset, 4.5, Paint()..color = AppColors.mint);
      }
    }
    _drawLabels(canvas, size, const ['0', '6', '12', '18', '24']);
  }

  @override
  bool shouldRepaint(covariant _DeviceTimelinePainter oldDelegate) =>
      oldDelegate.date != date || oldDelegate.data != data;
}

class _DeviceUsageBarPainter extends CustomPainter {
  const _DeviceUsageBarPainter({required this.date, required this.data});
  final DateTime date;
  final _DeviceTimelineData data;

  @override
  void paint(Canvas canvas, Size size) {
    final weekStart = _dateOnly(
      date,
    ).subtract(Duration(days: date.weekday - 1));
    final labels = const ['월', '화', '수', '목', '금', '토', '일'];
    final values = [
      for (var i = 0; i < 7; i++)
        _usageMinutesForDay(
              data,
              weekStart.add(Duration(days: i)),
            ).clamp(0, 1440) /
            1440,
    ];
    _RoundedBarChartPainter(
      values: values,
      labels: labels,
      displayMax: 1440,
      xPositions: _evenPositions(7),
      highlightIndex: _todayIndexForRange(weekStart, 7),
      valueFormat: _ChartValueFormat.duration,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _DeviceUsageBarPainter oldDelegate) =>
      oldDelegate.date != date || oldDelegate.data != data;
}

class _DeviceUsageMonthlyPainter extends CustomPainter {
  const _DeviceUsageMonthlyPainter({
    required this.date,
    required this.data,
    required this.axisScale,
  });
  final DateTime date;
  final _DeviceTimelineData data;
  final double axisScale;

  @override
  void paint(Canvas canvas, Size size) {
    final lastDay = DateTime(date.year, date.month + 1, 0).day;
    final days = [for (var day = 1; day <= lastDay; day++) day];
    final values = [
      for (final day in days)
        _dateOnly(
              DateTime(date.year, date.month, day),
            ).isAfter(_dateOnly(DateTime.now()))
            ? null
            : _usageMinutesForDay(
                    data,
                    DateTime(date.year, date.month, day),
                  ).clamp(0, 1440) /
                  1440,
    ];
    _LineChartPainter(
      values: values,
      labels: [for (final day in days) day.toString()],
      displayMax: 1440,
      xPositions: _monthPositions(date, days),
      highlightIndex: _todayIndexForMonth(date),
      valueFormat: _ChartValueFormat.duration,
      monthlyDynamic: true,
      axisScale: axisScale,
      monthLastDay: lastDay,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _DeviceUsageMonthlyPainter oldDelegate) =>
      oldDelegate.date != date ||
      oldDelegate.data != data ||
      oldDelegate.axisScale != axisScale;
}

void _drawTimeAxis(
  Canvas canvas,
  Size size,
  double y, {
  double intervalHours = 6,
}) {
  canvas.drawLine(
    Offset(0, y),
    Offset(size.width, y),
    Paint()
      ..color = AppColors.softGray.withValues(alpha: .82)
      ..strokeWidth = 2,
  );
  for (var hour = 0.0; hour <= 24.0001; hour += intervalHours) {
    final x = size.width * hour / 24;
    canvas.drawLine(
      Offset(x, y - 4),
      Offset(x, y + 4),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );
  }
}

int _aggregationMinutes(double axisScale) {
  if (axisScale < 1.6) return 120;
  if (axisScale < 2.6) return 60;
  if (axisScale < 4.5) return 30;
  if (axisScale < 9) return 10;
  return 1;
}

double _timeInterval(double axisScale) {
  if (axisScale < 1.6) return 6;
  if (axisScale < 3) return 3;
  if (axisScale < 8) return 1;
  if (axisScale < 16) return .5;
  return 1 / 6;
}

List<String> _timeLabels(double axisScale) {
  final interval = _timeInterval(axisScale);
  return [
    for (var hour = 0.0; hour <= 24.0001; hour += interval)
      interval >= 1
          ? hour.round().toString()
          : '${hour.floor()}:${((hour % 1) * 60).round().toString().padLeft(2, '0')}',
  ];
}

List<double> _timeLabelPositions(double axisScale) {
  final interval = _timeInterval(axisScale);
  return [for (var hour = 0.0; hour <= 24.0001; hour += interval) hour / 24];
}

String _chartDataKey(_ReportData data) =>
    '${data.mode}-${data.monthlyDynamic}-${data.monthLastDay}-${data.zoomMax}-${data.initialScale}-${data.title}';

List<int> _monthlyVisibleIndexes(double axisScale, int lastDay) {
  if (axisScale >= 3.5) {
    return [for (var i = 0; i < lastDay; i++) i];
  }
  final step = axisScale < 1.4
      ? 6
      : axisScale < 2.4
      ? 3
      : axisScale < 3.5
      ? 2
      : 1;
  final indexes = <int>{0};
  for (var day = step; day < lastDay; day += step) {
    if (lastDay - day < step) continue;
    indexes.add((day - 1).clamp(0, lastDay - 1));
  }
  indexes.add(lastDay - 1);
  return indexes.toList()..sort();
}

double _chartX(Size size, int index, int count, List<double> xPositions) {
  final gutter = math.min(14.0, size.width * .04);
  final plotWidth = math.max(1.0, size.width - gutter * 2);
  if (xPositions.length == count) {
    return gutter + plotWidth * xPositions[index].clamp(0.0, 1.0);
  }
  return count == 1 ? size.width / 2 : gutter + plotWidth * index / (count - 1);
}

_InterpolatedValues _interpolateMissingValues(List<double?> values) {
  final result = List<double?>.from(values);
  final missing = <int>{};
  for (var i = 0; i < result.length; i++) {
    if (result[i] != null) continue;
    var previous = i - 1;
    while (previous >= 0 && values[previous] == null) {
      previous--;
    }
    var next = i + 1;
    while (next < values.length && values[next] == null) {
      next++;
    }
    if (previous < 0 && next < values.length) {
      result[i] = 0;
      missing.add(i);
    } else if (previous >= 0 && next < values.length) {
      final start = values[previous]!;
      final end = values[next]!;
      final ratio = (i - previous) / (next - previous);
      result[i] = start + (end - start) * ratio;
      missing.add(i);
    }
  }
  return _InterpolatedValues(values: result, missingIndexes: missing);
}

int _usageMinutesForDay(_DeviceTimelineData data, DateTime date) {
  final dayStart = _dateOnly(date);
  final dayEnd = dayStart.add(const Duration(days: 1));
  var minutes = 0;
  for (final session in data.sessions) {
    final start = session.startedAt.isBefore(dayStart)
        ? dayStart
        : session.startedAt;
    final end = session.endedAt.isAfter(dayEnd) ? dayEnd : session.endedAt;
    if (end.isAfter(start)) minutes += end.difference(start).inMinutes;
  }
  final activeStart = data.activeStart;
  if (activeStart != null && _isSameDay(date, DateTime.now())) {
    final start = activeStart.isBefore(dayStart) ? dayStart : activeStart;
    final end = DateTime.now().isAfter(dayEnd) ? dayEnd : DateTime.now();
    if (end.isAfter(start)) minutes += end.difference(start).inMinutes;
  }
  return minutes;
}

int? _todayIndexForRange(DateTime start, int length) {
  final today = _dateOnly(DateTime.now());
  final index = today.difference(_dateOnly(start)).inDays;
  return index >= 0 && index < length ? index : null;
}

int? _todayIndexForMonth(DateTime month) {
  final today = _dateOnly(DateTime.now());
  if (today.year != month.year || today.month != month.month) return null;
  return today.day - 1;
}

void _drawIntensityGuides(
  Canvas canvas,
  Size size,
  double height, {
  double topInset = 0,
}) {
  final paint = Paint()
    ..color = AppColors.softGray.withValues(alpha: .72)
    ..strokeWidth = 1;
  for (final level in const [.3, .6, .8]) {
    final y = topInset + height - height * level;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
    }
  }
}

void _drawLabels(
  Canvas canvas,
  Size size,
  List<String> labels, {
  List<double> xPositions = const [],
}) {
  if (labels.isEmpty || size.width <= 0) return;
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  var lastPaintedX = -1000.0;
  for (var i = 0; i < labels.length; i++) {
    final x = _chartX(size, i, labels.length, xPositions);
    final isEdge = i == 0 || i == labels.length - 1;
    if (!isEdge && x - lastPaintedX < 34) continue;
    painter.text = TextSpan(
      text: labels[i],
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        height: 1.16,
        fontWeight: FontWeight.w600,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(
        (x - painter.width / 2).clamp(0, size.width - painter.width),
        size.height - 16,
      ),
    );
    lastPaintedX = x;
  }
}

void _drawTinyLabel(Canvas canvas, Offset offset, String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 8,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, Offset(offset.dx - painter.width / 2, offset.dy));
}

void _drawChartValue(Canvas canvas, Offset offset, String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(offset.dx - painter.width / 2, offset.dy - painter.height / 2),
  );
}

void _drawMissingMarker(
  Canvas canvas,
  Size size,
  int index,
  int count,
  double height,
  List<double> xPositions, {
  double topInset = 0,
}) {
  final x = _chartX(size, index, count, xPositions);
  final markerY = topInset + height;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, markerY), width: 26, height: 10),
      const Radius.circular(99),
    ),
    Paint()..color = AppColors.softGray.withValues(alpha: .48),
  );
  _drawChartValue(canvas, Offset(x, markerY - 18), '-');
}

String _valueText(
  double? value,
  double displayMax, [
  _ChartValueFormat format = _ChartValueFormat.number,
]) {
  if (value == null) return '-';
  final rawValue = (value * displayMax).round();
  if (format == _ChartValueFormat.duration) {
    final hours = rawValue ~/ 60;
    final minutes = rawValue % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
  return rawValue.toString();
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _formatDate(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

String _formatClock(DateTime? value) {
  if (value == null) return '--:--:--';
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}

String _intensityLabel(int intensity) {
  if (intensity >= 3400) return '강';
  if (intensity >= 2700) return '중';
  return '약';
}

List<double> _evenPositions(int count) => [
  for (var i = 0; i < count; i++) count == 1 ? .5 : i / (count - 1),
];

List<double> _monthPositions(DateTime selectedDate, List<int> days) {
  final lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
  return [for (final day in days) (day - 1) / math.max(1, lastDay - 1)];
}

String _weekdayDateLabel(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${weekdays[date.weekday - 1]}\n${date.month}.${date.day}';
}

void _showFetusPicker(
  BuildContext context,
  ValueChanged<int> onPick,
  ValueChanged<Uint8List> onUpload,
) => _showCleanImagePickerSheet(
  context: context,
  title: '태아 이미지 변경',
  description: '기본 태아 이미지를 선택할 수 있습니다.',
  uploadLabel: '초음파 사진 업로드',
  onPick: onPick,
  onUpload: onUpload,
  fetusPicker: true,
);

void _showProfilePicker(
  BuildContext context,
  int selectedProfile,
  int selectedBackground,
  ValueChanged<int> onPick,
  ValueChanged<int> onBackgroundPick,
  ValueChanged<Uint8List> onUpload,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .48,
      maxChildSize: .92,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('프로필 이미지 변경', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('기본 프로필 이미지와 파스텔 배경색을 선택하거나 개인 사진을 업로드할 수 있습니다.'),
            const SizedBox(height: 16),
            Center(
              child: _ProfileAvatar(
                style: selectedProfile,
                backgroundIndex: selectedBackground,
                radius: 44,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('uploadProfileImageButton'),
              onPressed: () async {
                final bytes = await _pickImageBytes();
                if (bytes == null || !context.mounted) return;
                final cropped = await _showImageCropPreview(
                  context,
                  bytes,
                  showInnerOrbit: false,
                );
                if (cropped == null || !context.mounted) return;
                onUpload(cropped);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('개인 사진 업로드'),
            ),
            const SizedBox(height: 18),
            Text('기본 프로필', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _FiveByThreeGrid(
              children: List.generate(_profileAssetPaths.length, (index) {
                return _SelectableProfileTile(
                  key: Key('profileAssetTile$index'),
                  selected: selectedProfile == index,
                  child: _ProfileAvatar(
                    style: index,
                    backgroundIndex: selectedBackground,
                    radius: 28,
                  ),
                  onTap: () {
                    onPick(index);
                    Navigator.pop(context);
                  },
                );
              }),
            ),
            const SizedBox(height: 18),
            Text('배경색', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _FiveByThreeGrid(
              children: List.generate(_profileBackgroundColors.length, (index) {
                final color = _profileBackgroundColors[index];
                return _SelectableProfileTile(
                  key: Key('profileBackgroundTile$index'),
                  selected: selectedBackground == index,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                  ),
                  onTap: () {
                    onBackgroundPick(index);
                    Navigator.pop(context);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showCleanImagePickerSheet({
  required BuildContext context,
  required String title,
  required String description,
  required String uploadLabel,
  required ValueChanged<int> onPick,
  required ValueChanged<Uint8List> onUpload,
  required bool fetusPicker,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
      final lift = fetusPicker ? MediaQuery.sizeOf(context).height * .30 : 0.0;
      return Padding(
        padding: EdgeInsets.fromLTRB(22, 8, 22, 32 + bottomInset + lift),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            if (!fetusPicker) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final bytes = await _pickImageBytes();
                  if (bytes == null || !context.mounted) return;
                  final cropped = await _showImageCropPreview(
                    context,
                    bytes,
                    showInnerOrbit: fetusPicker,
                  );
                  if (cropped == null || !context.mounted) return;
                  onUpload(cropped);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(uploadLabel),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(fetusPicker ? 2 : 9, (index) {
                final icons = fetusPicker
                    ? [Icons.gesture, Icons.child_care]
                    : [
                        Icons.face_3,
                        Icons.face_4,
                        Icons.face,
                        Icons.person,
                        Icons.face_5,
                        Icons.face_6,
                        Icons.face_2,
                        Icons.account_circle,
                        Icons.person_pin,
                      ];
                return InkWell(
                  onTap: () {
                    onPick(index);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: [
                        AppColors.peach,
                        const Color(0xFFDDF2EA),
                        const Color(0xFFE7E4FF),
                        const Color(0xFFFFF0C4),
                        const Color(0xFFE8F3FF),
                        const Color(0xFFFFE1EA),
                        const Color(0xFFE9F8DF),
                        const Color(0xFFF1E7DA),
                        const Color(0xFFEDEDED),
                      ][index % 9],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Icon(icons[index], color: AppColors.ink),
                  ),
                );
              }),
            ),
            if (!fetusPicker) ...[
              const SizedBox(height: 18),
              Text('배경색', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_profileBackgroundColors.length, (
                  index,
                ) {
                  final color = _profileBackgroundColors[index];
                  return InkWell(
                    onTap: () {
                      onPick(index);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.line),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _FiveByThreeGrid extends StatelessWidget {
  const _FiveByThreeGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 5,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1,
    children: children,
  );
}

class _SelectableProfileTile extends StatelessWidget {
  const _SelectableProfileTile({
    super.key,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.coralDark : AppColors.line,
          width: selected ? 2.2 : 1,
        ),
      ),
      child: child,
    ),
  );
}

const _fetusAbstractObjectAsset =
    'assets/images/fetal/abstract_fetal_object.png';
const _fetusRealObjectAsset = 'assets/images/fetal/fetus_real_object.png';
const _monitoringCircleAsset = 'assets/images/monitoring/circle.png';
const _monitoringStainAsset = 'assets/images/monitoring/stain.png';
const _profileAssetPaths = [
  'assets/images/profile/profile_01_object.png',
  'assets/images/profile/profile_02_object.png',
  'assets/images/profile/profile_03_object.png',
  'assets/images/profile/profile_04_object.png',
  'assets/images/profile/profile_05_object.png',
  'assets/images/profile/profile_06_object.png',
  'assets/images/profile/profile_07_object.png',
  'assets/images/profile/profile_08_object.png',
  'assets/images/profile/profile_09_object.png',
  'assets/images/profile/profile_10_object.png',
  'assets/images/profile/profile_11_object.png',
  'assets/images/profile/profile_12_object.png',
  'assets/images/profile/profile_13_object.png',
  'assets/images/profile/profile_14_object.png',
  'assets/images/profile/profile_15_object.png',
];

String _profileAssetPath(int index) =>
    _profileAssetPaths[index % _profileAssetPaths.length];

String _customProfileImageKey(String userId) =>
    'ding_dong_custom_profile_image_$userId';

Future<Uint8List?> _loadCustomProfileImage(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = prefs.getString(_customProfileImageKey(userId));
  if (encoded == null || encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } catch (_) {
    await prefs.remove(_customProfileImageKey(userId));
    return null;
  }
}

Future<void> _saveCustomProfileImage(String userId, Uint8List bytes) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_customProfileImageKey(userId), base64Encode(bytes));
}

Future<void> _clearCustomProfileImage(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_customProfileImageKey(userId));
}

const _profileBackgroundColors = [
  Color(0xFFFFDAD1),
  Color(0xFFDDF2EA),
  Color(0xFFE7E4FF),
  Color(0xFFFFF0C4),
  Color(0xFFE8F3FF),
  Color(0xFFFFE1EA),
  Color(0xFFE9F8DF),
  Color(0xFFF1E7DA),
  Color(0xFFEDEDED),
  Color(0xFFD9EEF7),
  Color(0xFFFFE5C7),
  Color(0xFFEBDCF8),
  Color(0xFFDFF3D8),
  Color(0xFFF8D9DF),
  Color(0xFFE6EEE8),
];

Future<Uint8List?> _pickImageBytes() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 88,
  );
  return image?.readAsBytes();
}

Future<Uint8List?> _showImageCropPreview(
  BuildContext context,
  Uint8List bytes, {
  required bool showInnerOrbit,
}) async {
  final controller = TransformationController();
  var viewportSize = Size.zero;
  void zoomImage(double factor) {
    final currentScale = controller.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(.85, 4.0);
    final adjustedFactor = nextScale / currentScale;
    controller.value = controller.value.clone()
      ..multiply(Matrix4.diagonal3Values(adjustedFactor, adjustedFactor, 1));
  }

  try {
    return await showDialog<Uint8List>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('원형 범위 맞추기', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    viewportSize = constraints.biggest;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: InteractiveViewer(
                            transformationController: controller,
                            minScale: .85,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: Image.memory(
                              bytes,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _CropGuidePainter(
                              showInnerOrbit: showInnerOrbit,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: '축소',
                    onPressed: () => zoomImage(.88),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: '초기화',
                    onPressed: () => controller.value = Matrix4.identity(),
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: '확대',
                    onPressed: () => zoomImage(1.14),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final cropped = await _cropGuidedSquarePng(
                          bytes,
                          controller.value,
                          viewportSize,
                        );
                        if (context.mounted) Navigator.pop(context, cropped);
                      },
                      child: const Text('적용'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<Uint8List> _cropGuidedSquarePng(
  Uint8List bytes,
  Matrix4 transform,
  Size viewportSize,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final side = viewportSize.shortestSide > 0
      ? viewportSize.shortestSide
      : 512.0;
  final inverse = Matrix4.inverted(transform);
  final cropSide = side * .88;
  final cropInViewport = Rect.fromCenter(
    center: Offset(side / 2, side / 2),
    width: cropSide,
    height: cropSide,
  );
  final topLeft = MatrixUtils.transformPoint(inverse, cropInViewport.topLeft);
  final bottomRight = MatrixUtils.transformPoint(
    inverse,
    cropInViewport.bottomRight,
  );
  final childCrop = Rect.fromPoints(topLeft, bottomRight);
  final imageScale = math.max(side / image.width, side / image.height);
  final fittedWidth = image.width * imageScale;
  final fittedHeight = image.height * imageScale;
  final fittedOffset = Offset(
    (side - fittedWidth) / 2,
    (side - fittedHeight) / 2,
  );
  var src = Rect.fromLTWH(
    (childCrop.left - fittedOffset.dx) / imageScale,
    (childCrop.top - fittedOffset.dy) / imageScale,
    childCrop.width / imageScale,
    childCrop.height / imageScale,
  );
  src = src.intersect(
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
  );
  if (src.isEmpty) {
    final fallbackSide = math.min(image.width, image.height).toDouble();
    src = Rect.fromLTWH(
      (image.width - fallbackSide) / 2,
      (image.height - fallbackSide) / 2,
      fallbackSide,
      fallbackSide,
    );
  }
  const outputSize = 512.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    src,
    const Rect.fromLTWH(0, 0, outputSize, outputSize),
    Paint(),
  );
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(outputSize.toInt(), outputSize.toInt());
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List() ?? bytes;
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter({this.showInnerOrbit = true});
  final bool showInnerOrbit;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) * .44;
    final inner = outer * .82;
    canvas.drawCircle(
      center,
      outer,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    if (!showInnerOrbit) return;
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 56; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: inner),
        math.pi * 2 * i / 56,
        math.pi * 2 / 56,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropGuidePainter oldDelegate) =>
      oldDelegate.showInnerOrbit != showInnerOrbit;
}

void _showAlerts(
  BuildContext context, {
  required List<_MovementAlertEntry> alerts,
  required ValueChanged<_MovementAlertEntry> onDelete,
  required VoidCallback onClear,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '알림',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: alerts.isEmpty
                          ? null
                          : () {
                              onClear();
                              setDialogState(() {});
                            },
                      child: const Text('모두 지우기'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (alerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '확인할 알림이 없습니다.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: alerts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _AlertRow(
                          time: _formatAlertTime(alert.createdAt),
                          message: alert.message,
                          onDelete: () {
                            onDelete(alert);
                            setDialogState(() {});
                          },
                        );
                      },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _formatAlertTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.time,
    required this.message,
    required this.onDelete,
  });
  final String time;
  final String message;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.notifications_none, color: AppColors.coralDark),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$time\n',
              style: Theme.of(context).textTheme.labelSmall,
              children: [
                TextSpan(
                  text: message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: '삭제',
          onPressed: onDelete,
          icon: const Icon(Icons.close_rounded, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _formatDuration(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
String? _validateDisplayName(String? v) =>
    (v?.trim().length ?? 0) < 2 ? '2자 이상 입력해 주세요.' : null;
String? _validateFetusName(String? v) =>
    (v?.trim().isEmpty ?? true) ? '태명을 입력해 주세요.' : null;
String? _validateEmail(String? v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
    ? null
    : '올바른 이메일을 입력해 주세요.';
String? _validatePassword(String? v) =>
    (v ?? '').length < 6 ? '비밀번호는 6자 이상이어야 합니다.' : null;

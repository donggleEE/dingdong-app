import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'repositories/auth_repository.dart';

void main() {
  runApp(FetalMovementApp());
}

class FetalMovementApp extends StatelessWidget {
  FetalMovementApp({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? AuthRepository();

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFEBA17F);
    final baseTheme = ThemeData(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: '태동 기록',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme.copyWith(
          primary: const Color(0xFFD9795F),
          secondary: const Color(0xFF68A795),
          surface: const Color(0xFFFFFBF7),
          surfaceContainerHighest: const Color(0xFFFFEEE5),
          outlineVariant: const Color(0xFFF0D7CA),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF3EA),
        textTheme: baseTheme.textTheme
            .copyWith(
              headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF372E2A),
              ),
              headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF372E2A),
              ),
              titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF372E2A),
              ),
              titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF372E2A),
              ),
              bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: const Color(0xFF5A4C45),
              ),
              bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: const Color(0xFF685A53),
              ),
              bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: const Color(0xFF817069),
              ),
            )
            .apply(fontFamily: 'Roboto'),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFFFF3EA),
          foregroundColor: Color(0xFF372E2A),
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFBF7),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFF0D7CA)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFBF7),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFEBCFC2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFEBCFC2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD9795F), width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.error),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            backgroundColor: const Color(0xFFD9795F),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFC86651),
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFBF7),
          indicatorColor: const Color(0xFFFFDDCF),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            );
          }),
        ),
      ),
      home: AuthGate(authRepository: authRepository),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppUser? _currentUser;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final user = await widget.authRepository.getCurrentUser();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = user;
      _isCheckingSession = false;
    });
  }

  void _handleAuthenticated(AppUser user) {
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _handleLogout() async {
    await widget.authRepository.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const SplashScreen();
    }

    final user = _currentUser;
    if (user == null) {
      return AuthScreen(
        authRepository: widget.authRepository,
        onAuthenticated: _handleAuthenticated,
      );
    }

    return HomeScreen(user: user, onLogout: _handleLogout);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 36,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isSignUp = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _isSignUp
          ? await widget.authRepository.signUp(
              _emailController.text,
              _passwordController.text,
              _displayNameController.text,
            )
          : await widget.authRepository.login(
              _emailController.text,
              _passwordController.text,
            );

      if (!mounted) {
        return;
      }
      widget.onAuthenticated(user);
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = '계정 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? '회원가입' : '로그인';
    final subtitle = _isSignUp
        ? '오늘의 태동 기록을 편안하게 확인할 계정을 만들어 주세요.'
        : '복부 기기에서 받은 태동 정보를 차분하게 살펴보세요.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _BrandHeader(),
                      const SizedBox(height: 22),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (_isSignUp) ...<Widget>[
                              TextFormField(
                                key: const Key('displayNameField'),
                                controller: _displayNameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: '이름 또는 별칭',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: _validateDisplayName,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              key: const Key('emailField'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              decoration: const InputDecoration(
                                labelText: '이메일',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('passwordField'),
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: _isSignUp
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: '비밀번호',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? '비밀번호 보기'
                                      : '비밀번호 숨기기',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: _validatePassword,
                              onFieldSubmitted: (_) {
                                if (!_isSignUp && !_isSubmitting) {
                                  _submit();
                                }
                              },
                            ),
                            if (_isSignUp) ...<Widget>[
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('passwordConfirmField'),
                                controller: _passwordConfirmController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: '비밀번호 확인',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: _validatePasswordConfirm,
                                onFieldSubmitted: (_) {
                                  if (!_isSubmitting) {
                                    _submit();
                                  }
                                },
                              ),
                            ],
                            if (_errorMessage != null) ...<Widget>[
                              const SizedBox(height: 14),
                              ErrorNotice(message: _errorMessage!),
                            ],
                            const SizedBox(height: 22),
                            ElevatedButton(
                              key: const Key('submitAuthButton'),
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const _ButtonLoader()
                                  : Text(title),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              key: const Key('toggleAuthModeButton'),
                              onPressed: _isSubmitting ? null : _toggleMode,
                              child: Text(
                                _isSignUp
                                    ? '이미 계정이 있나요? 로그인'
                                    : '처음 사용하시나요? 회원가입',
                              ),
                            ),
                          ],
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
    );
  }

  String? _validatePasswordConfirm(String? value) {
    if (value != _passwordController.text) {
      return '비밀번호가 서로 다릅니다.';
    }
    return null;
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFFFD9CA),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_border,
            color: Color(0xFFD9795F),
            size: 34,
          ),
        ),
        const SizedBox(height: 12),
        Text('태동 기록', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '하루의 움직임을 부드럽게 확인해요',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: <Widget>[
            _HomeTab(user: widget.user, onLogout: widget.onLogout),
            const _MonitoringTab(),
            const _ReportTab(),
            const _NotificationTab(),
            _MyTab(user: widget.user),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '모니터링',
          ),
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined),
            selectedIcon: Icon(Icons.insert_chart),
            label: '리포트',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: '알림',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'My',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.user, required this.onLogout});

  final AppUser user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: <Widget>[
        _TopGreeting(user: user, onLogout: onLogout),
        const SizedBox(height: 18),
        const _BabyHeroCard(),
        const SizedBox(height: 14),
        const Row(
          children: <Widget>[
            Expanded(
              child: _ScoreCard(
                label: '태동 감지',
                value: '18회',
                caption: '오늘 누적',
                icon: Icons.favorite,
                color: Color(0xFFD9795F),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ScoreCard(
                label: '자세 점수',
                value: '82점',
                caption: '착용 안정',
                icon: Icons.accessibility_new,
                color: Color(0xFF68A795),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _LineChartCard(),
        const SizedBox(height: 14),
        const _RecentAlertsCard(),
        const SizedBox(height: 12),
        const _CareNotice(),
      ],
    );
  }
}

class _TopGreeting extends StatelessWidget {
  const _TopGreeting({required this.user, required this.onLogout});

  final AppUser user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${user.displayName}님, 안녕하세요',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '오늘의 태동 흐름을 차분히 확인해요',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        _CircleIconButton(
          tooltip: '알림',
          icon: Icons.notifications_none,
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          tooltip: '로그아웃',
          icon: Icons.logout_outlined,
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFFFFBF7),
        foregroundColor: const Color(0xFF5F4A40),
      ),
    );
  }
}

class _BabyHeroCard extends StatelessWidget {
  const _BabyHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 228,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFDCCB), Color(0xFFFFBFA8)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFD9795F).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -20,
            top: -18,
            child: _SoftCircle(size: 112, color: Colors.white),
          ),
          Positioned(
            right: 22,
            bottom: 12,
            child: _SoftCircle(
              size: 54,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
          Positioned(
            right: 24,
            top: 36,
            child: CustomPaint(
              size: const Size(118, 118),
              painter: _BabyIllustrationPainter(),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '실시간 기록 중',
                  style: TextStyle(
                    color: Color(0xFF9B5647),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '오늘 태동 감지',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF6F3E35),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '18회',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 42,
                  color: const Color(0xFF4C2F2A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '참고용 기록이며 의료 진단을 대신하지 않습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7C554B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _CardHeader(
              title: '최근 태동 흐름',
              trailing: '최근 6시간',
              icon: Icons.show_chart,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 130,
              width: double.infinity,
              child: CustomPaint(painter: _LineChartPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAlertsCard extends StatelessWidget {
  const _RecentAlertsCard();

  @override
  Widget build(BuildContext context) {
    const alerts = <_AlertItem>[
      _AlertItem('오후 2:20', '부드러운 움직임이 감지되었습니다.'),
      _AlertItem('오후 1:05', '착용 자세가 안정적으로 유지되었습니다.'),
      _AlertItem('오전 11:40', '손목 알림 전송 준비 상태입니다.'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _CardHeader(
              title: '최근 알림',
              trailing: '3건',
              icon: Icons.notifications_active_outlined,
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => _AlertRow(alert: alert)),
          ],
        ),
      ),
    );
  }
}

class _AlertItem {
  const _AlertItem(this.time, this.message);

  final String time;
  final String message;
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final _AlertItem alert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE3D7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              color: Color(0xFFD9795F),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  alert.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(alert.time, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoringTab extends StatelessWidget {
  const _MonitoringTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: const <Widget>[
        _PageTitle(title: '실시간 모니터링', subtitle: '기기에서 전달된 움직임 신호를 확인해요'),
        SizedBox(height: 18),
        _WaveMonitorCard(),
        SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _ScoreCard(
                label: '자세 점수',
                value: '82점',
                caption: '현재',
                icon: Icons.sensors,
                color: Color(0xFF68A795),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ScoreCard(
                label: '비교 점수',
                value: '72점',
                caption: '이전 평균',
                icon: Icons.screen_rotation_alt_outlined,
                color: Color(0xFFE0A549),
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        _SensorStatusCard(),
      ],
    );
  }
}

class _WaveMonitorCard extends StatelessWidget {
  const _WaveMonitorCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const _CardHeader(
              title: '원형 웨이브',
              trailing: '감지 대기',
              icon: Icons.monitor_heart_outlined,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 210,
              child: Center(
                child: CustomPaint(
                  size: const Size(188, 188),
                  painter: _WavePainter(),
                  child: SizedBox(
                    width: 188,
                    height: 188,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '18회',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '오늘 감지',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              '측정값은 참고용 지표입니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorStatusCard extends StatelessWidget {
  const _SensorStatusCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: const <Widget>[
            _StatusLine(icon: Icons.vibration, title: '진동 센서', status: '연결됨'),
            Divider(height: 24),
            _StatusLine(
              icon: Icons.screen_rotation_alt_outlined,
              title: '자이로 센서',
              status: '수신 중',
            ),
            Divider(height: 24),
            _StatusLine(
              icon: Icons.watch_outlined,
              title: 'Galaxy Watch',
              status: '확장 예정',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.title,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: const Color(0xFFD9795F)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        _Pill(label: status),
      ],
    );
  }
}

class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: const <Widget>[
        _PageTitle(title: '주간 리포트', subtitle: '일주일 흐름을 보기 쉽게 모았어요'),
        SizedBox(height: 18),
        _WeeklyChartCard(),
        SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _ScoreCard(
                label: '주간 평균',
                value: '15회',
                caption: '하루 기준',
                icon: Icons.calendar_month_outlined,
                color: Color(0xFFD9795F),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ScoreCard(
                label: '자세 평균',
                value: '72점',
                caption: '지난 7일',
                icon: Icons.timeline,
                color: Color(0xFF68A795),
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        _CareNotice(),
      ],
    );
  }
}

class _NotificationTab extends StatelessWidget {
  const _NotificationTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: const <Widget>[
        _PageTitle(title: '알림', subtitle: '태동 기록과 기기 상태 알림을 모아봤어요'),
        SizedBox(height: 18),
        _AlertListCard(),
        SizedBox(height: 14),
        _SoftSettingCard(
          icon: Icons.watch_outlined,
          title: 'Galaxy Watch 진동 알림',
          value: '향후 확장',
          description: '복부 기기에서 감지한 신호를 손목 진동으로 한 번 더 확인하는 기능을 준비합니다.',
        ),
        SizedBox(height: 14),
        _CareNotice(),
      ],
    );
  }
}

class _MyTab extends StatelessWidget {
  const _MyTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: <Widget>[
        const _PageTitle(title: 'My', subtitle: '계정과 기기 연결 정보를 확인해요'),
        const SizedBox(height: 18),
        _ProfileCard(user: user),
        const SizedBox(height: 14),
        const _SoftSettingCard(
          icon: Icons.sensors_outlined,
          title: '복부 센서 기기',
          value: '연결 준비',
          description: '자이로센서와 진동센서 데이터가 연결되면 상태가 표시됩니다.',
        ),
        const SizedBox(height: 14),
        const _CareNotice(),
      ],
    );
  }
}

class _AlertListCard extends StatelessWidget {
  const _AlertListCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            _CardHeader(
              title: '최근 알림',
              trailing: '3건',
              icon: Icons.notifications_none,
            ),
            SizedBox(height: 14),
            _AlertRow(alert: _AlertItem('오후 02:32', '자세 점수 기록이 업데이트되었습니다.')),
            _AlertRow(alert: _AlertItem('오후 01:18', '실시간 모니터링 세션이 준비되었습니다.')),
            _AlertRow(alert: _AlertItem('오전 11:40', '손목 알림 전송 준비 상태입니다.')),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE1D4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Color(0xFFD9795F)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const _Pill(label: '로그인됨'),
          ],
        ),
      ),
    );
  }
}

class _SoftSettingCard extends StatelessWidget {
  const _SoftSettingCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE6D9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFD9795F)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _Pill(label: value),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChartCard extends StatelessWidget {
  const _WeeklyChartCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _CardHeader(
              title: '주간 막대/라인 차트',
              trailing: '7일',
              icon: Icons.bar_chart,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(painter: _WeeklyChartPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.trailing,
    required this.icon,
  });

  final String title;
  final String trailing;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: const Color(0xFFD9795F), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        _Pill(label: trailing),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6D9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF9B5647),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CareNotice extends StatelessWidget {
  const _CareNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEED7AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, color: Color(0xFF9A7432)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '태동 기록은 일상 확인을 돕는 참고 지표입니다. 불편감이나 걱정이 이어지면 의료진과 상담해 주세요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF725A2C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BabyIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyPaint = Paint()..color = Colors.white.withValues(alpha: 0.82);
    final accentPaint = Paint()
      ..color = const Color(0xFFD9795F).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final heartPaint = Paint()..color = const Color(0xFFD9795F);

    canvas.drawCircle(center, size.width * 0.42, bodyPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.28),
      math.pi * 0.15,
      math.pi * 1.25,
      false,
      accentPaint,
    );
    canvas.drawCircle(
      center.translate(-size.width * 0.08, -size.height * 0.08),
      size.width * 0.12,
      Paint()..color = const Color(0xFFFFC9B6),
    );
    final heart = Path()
      ..moveTo(center.dx, center.dy + 18)
      ..cubicTo(
        center.dx - 22,
        center.dy + 4,
        center.dx - 18,
        center.dy - 14,
        center.dx,
        center.dy - 6,
      )
      ..cubicTo(
        center.dx + 18,
        center.dy - 14,
        center.dx + 22,
        center.dy + 4,
        center.dx,
        center.dy + 18,
      );
    canvas.drawPath(heart, heartPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF2DCCF)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0x55D9795F), Color(0x00D9795F)],
      ).createShader(Offset.zero & size);
    final linePaint = Paint()
      ..color = const Color(0xFFD9795F)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const values = <double>[0.35, 0.54, 0.42, 0.74, 0.6, 0.86, 0.68];
    final points = _chartPoints(size, values);

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.5, Paint()..color = const Color(0xFFD9795F));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rings = <double>[0.48, 0.36, 0.24];
    for (var i = 0; i < rings.length; i++) {
      canvas.drawCircle(
        center,
        size.width * rings[i],
        Paint()
          ..color = const Color(0xFFD9795F).withValues(alpha: 0.08 + i * 0.05)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawCircle(
      center,
      size.width * 0.22,
      Paint()..color = const Color(0xFFFFFBF7),
    );
    canvas.drawCircle(
      center,
      size.width * 0.48,
      Paint()
        ..color = const Color(0xFFD9795F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeeklyChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bars = <double>[0.42, 0.64, 0.5, 0.78, 0.7, 0.92, 0.58];
    final barPaint = Paint()..color = const Color(0xFFFFC4AF);
    final linePaint = Paint()
      ..color = const Color(0xFF68A795)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bottom = size.height - 24;
    final chartHeight = size.height - 36;
    final gap = size.width / bars.length;
    final points = <Offset>[];

    for (var i = 0; i < bars.length; i++) {
      final x = gap * i + gap * 0.22;
      final width = gap * 0.56;
      final height = chartHeight * bars[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bottom - height, width, height),
        const Radius.circular(10),
      );
      canvas.drawRRect(rect, barPaint);
      points.add(
        Offset(x + width / 2, bottom - chartHeight * (bars[i] * 0.75)),
      );
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = const Color(0xFF68A795));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<Offset> _chartPoints(Size size, List<double> values) {
  return List<Offset>.generate(values.length, (index) {
    final x = size.width * index / (values.length - 1);
    final y = size.height - (size.height * values[index]);
    return Offset(x, y.clamp(10, size.height - 10));
  });
}

String? _validateDisplayName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return '이름 또는 별칭을 입력해 주세요.';
  }
  if (text.length < 2) {
    return '2자 이상 입력해 주세요.';
  }
  return null;
}

String? _validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return '이메일을 입력해 주세요.';
  }
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(text)) {
    return '올바른 이메일 형식으로 입력해 주세요.';
  }
  return null;
}

String? _validatePassword(String? value) {
  final text = value ?? '';
  if (text.isEmpty) {
    return '비밀번호를 입력해 주세요.';
  }
  if (text.length < 6) {
    return '비밀번호는 6자 이상이어야 합니다.';
  }
  return null;
}

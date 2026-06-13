import 'package:ding_dong_app/main.dart';
import 'package:ding_dong_app/models/app_user.dart';
import 'package:ding_dong_app/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFrame(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> openMonitoring(WidgetTester tester) async {
  await tester.tap(find.text('모니터링'));
  await pumpFrame(tester);
}

Future<void> openMy(WidgetTester tester) async {
  await tester.tap(find.text('My'));
  await pumpFrame(tester);
}

void main() {
  testWidgets('로그인하지 않은 사용자는 인증 화면을 본다', (tester) async {
    await tester.pumpWidget(
      FetalMovementApp(authRepository: FakeAuthRepository()),
    );
    await pumpFrame(tester);

    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    expect(find.byKey(const Key('submitAuthButton')), findsOneWidget);
  });

  testWidgets('회원가입 후 홈 화면을 볼 수 있다', (tester) async {
    await tester.pumpWidget(
      FetalMovementApp(authRepository: FakeAuthRepository()),
    );
    await pumpFrame(tester);

    await tester.tap(find.byKey(const Key('toggleAuthModeButton')));
    await pumpFrame(tester);
    await tester.enterText(find.byKey(const Key('displayNameField')), '보호자');
    await tester.enterText(find.byKey(const Key('fetusNameField')), '튼튼이');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'user@test.com',
    );
    await tester.enterText(find.byKey(const Key('passwordField')), '123456');
    await tester.enterText(
      find.byKey(const Key('passwordConfirmField')),
      '123456',
    );
    await tester.ensureVisible(find.byKey(const Key('submitAuthButton')));
    await tester.tap(find.byKey(const Key('submitAuthButton')));
    await pumpFrame(tester);

    expect(find.byKey(const Key('homeProfileButton')), findsOneWidget);
    expect(find.byKey(const Key('navMonitoring')), findsOneWidget);
  });

  testWidgets('하단 내비게이션으로 모니터링 화면을 볼 수 있다', (tester) async {
    final repository = FakeAuthRepository.withUser();
    await tester.pumpWidget(FetalMovementApp(authRepository: repository));
    await pumpFrame(tester);

    await openMonitoring(tester);

    expect(find.text('복부 센서 자동 수신'), findsOneWidget);
    expect(find.text('태동 감지 중'), findsOneWidget);
    expect(find.text('약'), findsOneWidget);
    expect(find.text('중'), findsOneWidget);
    expect(find.text('강'), findsOneWidget);
    expect(find.byKey(const Key('devicePowerSwitch')), findsNothing);
  });

  testWidgets('수동 태동 기록 버튼은 세기 선택 UI를 연다', (tester) async {
    final repository = FakeAuthRepository.withUser();
    await tester.pumpWidget(FetalMovementApp(authRepository: repository));
    await pumpFrame(tester);

    await openMonitoring(tester);

    expect(find.text('약'), findsOneWidget);
    expect(find.text('중'), findsOneWidget);
    expect(find.text('강'), findsOneWidget);
  });

  testWidgets('My에서 프로필 정보를 수정할 수 있다', (tester) async {
    final repository = FakeAuthRepository.withUser();
    await tester.pumpWidget(FetalMovementApp(authRepository: repository));
    await pumpFrame(tester);

    await openMy(tester);

    expect(find.byKey(const Key('myDisplayNameField')), findsOneWidget);
    expect(find.byKey(const Key('myFetusNameField')), findsOneWidget);
    expect(find.text('알림음 선택'), findsOneWidget);
  });
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository();

  FakeAuthRepository.withUser({
    String fetusName = 'Ding-Dong',
    int profileImageIndex = 0,
    int profileBackgroundIndex = 0,
  }) : _currentUser = AppUser(
         id: 'test-uid',
         email: 'user@test.com',
         displayName: '보호자',
         fetusName: fetusName,
         profileImageIndex: profileImageIndex,
         profileBackgroundIndex: profileBackgroundIndex,
         createdAt: DateTime(2026, 5, 22),
         updatedAt: DateTime(2026, 5, 22),
       );

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser?> getCurrentUser() async => _currentUser;

  @override
  Stream<AppUser?> watchCurrentUser() => Stream<AppUser?>.value(_currentUser);

  @override
  Future<AppUser> signUp(
    String email,
    String password,
    String displayName, {
    String fetusName = 'Ding-Dong',
    int profileImageIndex = 0,
    int profileBackgroundIndex = 0,
  }) async {
    return _currentUser = AppUser(
      id: 'test-uid',
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      fetusName: fetusName.trim().isEmpty ? 'Ding-Dong' : fetusName.trim(),
      profileImageIndex: profileImageIndex,
      profileBackgroundIndex: profileBackgroundIndex,
      createdAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 22),
    );
  }

  @override
  Future<AppUser> login(String email, String password) async {
    return _currentUser = AppUser(
      id: 'test-uid',
      email: email.trim().toLowerCase(),
      displayName: '보호자',
      fetusName: _currentUser?.fetusName ?? 'Ding-Dong',
      profileImageIndex: _currentUser?.profileImageIndex ?? 0,
      profileBackgroundIndex: _currentUser?.profileBackgroundIndex ?? 0,
      createdAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 22),
    );
  }

  @override
  Future<void> logout() async => _currentUser = null;

  @override
  Future<AppUser> updateAccount({
    required String displayName,
    required String email,
    String? currentPassword,
    String? fetusName,
    int? profileImageIndex,
    int? profileBackgroundIndex,
  }) async {
    return _currentUser = AppUser(
      id: 'test-uid',
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      fetusName: fetusName?.trim().isNotEmpty == true
          ? fetusName!.trim()
          : _currentUser?.fetusName ?? 'Ding-Dong',
      profileImageIndex:
          profileImageIndex ?? _currentUser?.profileImageIndex ?? 0,
      profileBackgroundIndex:
          profileBackgroundIndex ?? _currentUser?.profileBackgroundIndex ?? 0,
      createdAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 24),
    );
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> deleteAccount({required String currentPassword}) async {
    _currentUser = null;
  }
}

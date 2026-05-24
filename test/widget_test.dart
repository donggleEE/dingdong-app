import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test1/main.dart';
import 'package:test1/models/app_user.dart';
import 'package:test1/repositories/auth_repository.dart';

void main() {
  testWidgets('로그인하지 않은 사용자는 로그인 화면을 본다', (tester) async {
    await tester.pumpWidget(
      FetalMovementApp(authRepository: FakeAuthRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsWidgets);
    expect(find.text('처음 사용하시나요? 회원가입'), findsOneWidget);
  });

  testWidgets('회원가입 후 홈 화면으로 이동하고 로그아웃할 수 있다', (tester) async {
    await tester.pumpWidget(
      FetalMovementApp(authRepository: FakeAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggleAuthModeButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('displayNameField')), '보호자');
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitAuthButton')));
    await tester.pumpAndSettle();

    expect(find.text('보호자님, 안녕하세요'), findsOneWidget);
    expect(find.text('태동 감지'), findsOneWidget);
    expect(find.text('18회'), findsWidgets);
    expect(find.text('최근 태동 흐름'), findsOneWidget);

    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('홈 화면 하단의 최근 알림 카드가 표시된다', (tester) async {
    final repository = FakeAuthRepository()
      .._currentUser = AppUser(
        id: 1,
        email: 'user@test.com',
        displayName: '보호자',
        createdAt: DateTime(2026, 5, 22),
        updatedAt: DateTime(2026, 5, 22),
      );

    await tester.pumpWidget(FetalMovementApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('최근 알림'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('최근 알림'), findsOneWidget);
  });

  testWidgets('비밀번호 확인이 다르면 안내 문구를 표시한다', (tester) async {
    await tester.pumpWidget(
      FetalMovementApp(authRepository: FakeAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggleAuthModeButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('displayNameField')), '보호자');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'user@test.com',
    );
    await tester.enterText(find.byKey(const Key('passwordField')), '123456');
    await tester.enterText(
      find.byKey(const Key('passwordConfirmField')),
      '654321',
    );
    await tester.ensureVisible(find.byKey(const Key('submitAuthButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitAuthButton')));
    await tester.pumpAndSettle();

    expect(find.text('비밀번호가 서로 다릅니다.'), findsOneWidget);
  });

  testWidgets('하단 네비게이션으로 모니터링과 리포트 화면을 볼 수 있다', (tester) async {
    final repository = FakeAuthRepository()
      .._currentUser = AppUser(
        id: 1,
        email: 'user@test.com',
        displayName: '보호자',
        createdAt: DateTime(2026, 5, 22),
        updatedAt: DateTime(2026, 5, 22),
      );

    await tester.pumpWidget(FetalMovementApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('모니터링'));
    await tester.pumpAndSettle();
    expect(find.text('실시간 모니터링'), findsOneWidget);
    expect(find.text('원형 웨이브'), findsOneWidget);
    expect(find.text('82점'), findsOneWidget);
    expect(find.text('72점'), findsOneWidget);

    await tester.tap(find.text('리포트'));
    await tester.pumpAndSettle();
    expect(find.text('주간 리포트'), findsOneWidget);
    expect(find.text('주간 막대/라인 차트'), findsOneWidget);

    await tester.tap(find.text('알림'));
    await tester.pumpAndSettle();
    expect(find.text('태동 기록과 기기 상태 알림을 모아봤어요'), findsOneWidget);

    await tester.tap(find.text('My'));
    await tester.pumpAndSettle();
    expect(find.text('계정과 기기 연결 정보를 확인해요'), findsOneWidget);
  });
}

class FakeAuthRepository extends AuthRepository {
  AppUser? _currentUser;

  @override
  Future<AppUser?> getCurrentUser() async => _currentUser;

  @override
  Future<AppUser> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final user = AppUser(
      id: 1,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      createdAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 22),
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> login(String email, String password) async {
    final user = AppUser(
      id: 1,
      email: email.trim().toLowerCase(),
      displayName: '보호자',
      createdAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 22),
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }
}

# 🤰 태동 감지 데이터 시각화 앱 (Dingdong App)

임산부가 일상 속에서 놓치기 쉬운 태동 정보를 더 쉽게 확인할 수 있도록 돕는 **Flutter 앱**입니다.

### 🎯 프로젝트 목표
- 복부 벨트형 기기에서 **자이로센서**와 **진동센서** 데이터 수집
- 태동 관련 정보를 이해하기 쉬운 형태로 **시각화**
- **로컬 저장소** 기반 (서버 의존성 없음, SQLite 사용)
- 향후 **Galaxy Watch** 연동 확장 예정

> ⚠️ **참고**: 이 앱의 정보는 참고 지표이며, 의학적 진단을 대신하지 않습니다.

---

## 📋 사전 요구사항

다음 도구를 설치해야 합니다:

| 항목 | 설치 링크 | 버전 |
|------|---------|------|
| **Flutter SDK** | [flutter.dev](https://flutter.dev/docs/get-started/install) | ^3.12.0 이상 |
| **Dart SDK** | Flutter와 함께 설치됨 | 3.12.0 이상 |
| **Android Studio** | [android.com/studio](https://developer.android.com/studio) | 최신 버전 |
| **VS Code** | [code.visualstudio.com](https://code.visualstudio.com) | 최신 버전 |

### VS Code 확장 프로그램 설치
- `Dart` (Dart Code)
- `Flutter` (Dart Code)

### 설정 확인
```bash
flutter doctor
```
이 명령으로 모든 의존성이 설치되었는지 확인합니다.

> 💡 **Windows Desktop 개발**: C++ 개발 도구 없이는 Windows 빌드가 실패할 수 있습니다. **Chrome 또는 Android** 실행을 권장합니다.

---

## 🚀 빠른 시작

### 1️⃣ 프로젝트 클론
```bash
git clone https://github.com/donggleEE/dingdong-app.git
cd dingdong-app
```

### 2️⃣ 의존성 설치
```bash
flutter pub get
```

또는 VS Code에서: `Terminal > Run Task...` → `Flutter: pub get` 선택

### 3️⃣ 실행 가능한 기기 확인
```bash
flutter devices
```

### 4️⃣ 앱 실행

**옵션 1: VS Code에서 (권장)**
- `Run and Debug` 패널 열기 (Ctrl+Shift+D)
- 원하는 플랫폼 선택:
  - 🌐 `Flutter: Chrome` (웹 미리보기)
  - 📱 `Flutter: Android` (Android 에뮬레이터/기기)
  - 💻 `Flutter: Windows` (Windows Desktop - C++ 도구 필수)

**옵션 2: 터미널에서**
```bash
# 사용 가능한 모든 기기로 실행
flutter run

# 특정 기기로 실행 (예: Chrome)
flutter run -d chrome
```

---

## 📁 프로젝트 구조

```
lib/
├── main.dart              # 앱 진입점
├── data/
│   └── auth_database.dart # 로컬 데이터베이스 (SQLite)
├── models/
│   └── app_user.dart      # 사용자 데이터 모델
└── repositories/
    └── auth_repository.dart # 데이터 접근 계층

android/                  # Android 플랫폼 코드
ios/                      # iOS 플랫폼 코드
windows/                  # Windows Desktop 코드
web/                      # Web 플랫폼 코드
```

---

## 🛠️ 개발 환경 설정

### 코드 분석
```bash
flutter analyze
```

### 코드 포맷팅
```bash
dart format lib/
```

### 테스트 실행
```bash
flutter test
```

---

## 📦 주요 의존성

| 패키지 | 용도 |
|--------|------|
| `sqflite` | 로컬 SQLite 데이터베이스 |
| `path` | 파일 시스템 경로 처리 |
| `crypto` | 암호화 기능 |
| `cupertino_icons` | iOS 스타일 아이콘 |

---

## 🤝 기여 방법

1. Fork 이 저장소
2. 새로운 브랜치 생성: `git checkout -b feature/기능명`
3. 변경 사항 커밋: `git commit -m "설명"`
4. 브랜치에 푸시: `git push origin feature/기능명`
5. Pull Request 생성

---

## 📚 추가 문서

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Dart 공식 문서](https://dart.dev/guides)
- [SQLite 사용법](https://pub.dev/packages/sqflite)

---

## 의존성 설치 (개발자용)

의존성은 다음 명령으로 내려받습니다.

```powershell
flutter pub get
```

VS Code에서는 `Terminal > Run Task...` 메뉴에서 `Flutter: pub get` 작업을 선택해도 됩니다.

## 실행 방법

사용 가능한 기기 목록을 확인합니다.

```powershell
flutter devices
```

VS Code에서 실행하려면 `Run and Debug` 패널을 열고 다음 설정 중 하나를 선택합니다.

- `Flutter: 사용 가능한 기기 선택`: VS Code에서 선택된 Flutter 기기로 실행합니다.
- `Flutter: Chrome`: Chrome 웹 실행을 시도합니다.
- `Flutter: Android`: 연결된 Android 에뮬레이터 또는 기기 실행을 시도합니다.
- `Flutter: Windows`: Windows desktop 실행을 시도합니다.

터미널에서 직접 실행하려면 다음 명령을 사용합니다.

```powershell
flutter run
```

특정 기기로 실행하려면 예를 들어 다음처럼 실행합니다.

```powershell
flutter run -d chrome
flutter run -d android
```

VS Code 작업으로 실행하려면 `Terminal > Run Task...`에서 `Flutter: run`을 선택합니다.

## 테스트 방법

정적 분석은 다음 명령으로 실행합니다.

```powershell
flutter analyze
```

테스트는 다음 명령으로 실행합니다.

```powershell
flutter test
```

VS Code에서는 `Terminal > Run Task...` 메뉴에서 `Flutter: analyze` 또는 `Flutter: test` 작업을 선택할 수 있습니다.

Android APK 빌드는 다음 명령으로 실행합니다.

```powershell
flutter build apk
```

VS Code 작업으로는 `Flutter: build apk`를 선택합니다.

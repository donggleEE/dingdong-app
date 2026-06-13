# 수동 재구성 변경사항 추적표

- 작업 폴더: `C:\Users\dongg\Desktop\Manual_Rebuild_App_20260610_20260613`
- 기준점: VS Code Local History의 2026-05-31 `lib/main.dart` 및 5월 말 핵심 파일
- 적용 범위: 2026-05-31 이후부터 2026-06-10 23:59:59까지의 `CODEX_LOG.md` 기록
- 제외 범위: 2026-06-11 이후 복구 기록, `watch_alerts`, 태동/세션 Firestore 동기화, 임시 로그/복구 파일

## 상태 표기

- 대기: 아직 적용 전
- 적용 완료: 수동 적용 완료
- 보류: 근거 또는 파일 부족으로 보류
- 제외: 최종 앱에서 제외
- 충돌: 이후 기록이 덮어쓸 예정 또는 덮어씀

## 수정사항 목록

| 번호 | 날짜/시간 | 원문 내용 요약 | 수정 유형 | 적용 대상 파일 | 구체적으로 해야 할 일 | 필요한 assets | 필요한 dependency | 충돌 여부 | 적용 상태 | 확인 방법 |
|---:|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-06-01 02:43 | 홈 태아 이미지, 선택 시트, 리포트 날짜/그래프, 태명 클라우드 문구 수정 | UI/기능/Firebase | `lib/main.dart` | 추상 태아 이미지를 asset으로 변경, 하단 시트 여백, 일/주/月 리포트 날짜 범위와 그래프 미측정 표시, 태명 저장 문구 조정 | `abstract_fetal_object.png` | 없음 | 이후 UI가 여러 번 덮어씀 | 대기 | 화면, analyze |
| 2 | 2026-06-01 03:30 | SQLite 태동 저장과 리포트 실제 데이터 연동 | DB/기능 | `lib/models/fetal_movement_record.dart`, `lib/data/local_database.dart`, `lib/repositories/movement_repository.dart`, `lib/main.dart` | SQLite 모델/DB/저장소 추가, `태동 기록 저장` 버튼, 리포트 실제 기록 조회 | 없음 | `sqflite`, `path` | 이후 Firestore 추가 후 6/9 로컬 전용으로 회수 | 대기 | pub get, analyze |
| 3 | 2026-06-01 14:45 | 홈 실제 데이터, 차트 정렬/단위 제거/점선/확대/달력/세션/My 상태 | UI/DB/기능 | `lib/main.dart`, `local_database.dart`, `movement_repository.dart`, `test/widget_test.dart` | 홈 오늘 횟수와 최근 7일 SQLite 집계, 원 테두리 색, 차트/달력/세션 타임라인/My 기기 상태 반영 | 없음 | 없음 | 이후 차트 세부 변경 다수 | 대기 | analyze, test |
| 4 | 2026-06-01 15:28 | 그래프 확대를 x축 정밀 스크롤 방식으로 변경 | UI/기능 | `lib/main.dart` | 카드 내부 캔버스 폭 확대, 버킷 집계, 진행 중 세션 초록 표시, 월간 세기 평균 | 없음 | 없음 | 이후 확대 단계 변경 | 대기 | 리포트 확인 |
| 5 | 2026-06-01 16:16 | 월간 x축, 보간선, 기기 사용 타임라인 세분화 | UI/기능 | `lib/main.dart` | 월간 축 6/3/2/1일, 빈 날짜 보간 `-`, 일/주/月 기기 사용 그래프 분화 | 없음 | 없음 | 이후 라벨/초기 확대 변경 | 대기 | 리포트 확인 |
| 6 | 2026-06-01 16:54 | 값 라벨 여백, 오늘 강조, 월말 중복 제거, 사용시간 HH:MM | UI | `lib/main.dart` | 그래프 상단 여백, 오늘 초록 강조, 월간 초기 확대/스크롤, 사용시간 분 계산과 `HH:MM` 표기 | 없음 | 없음 | 유지 | 대기 | 리포트 확인 |
| 7 | 2026-06-01 17:07 | 주간 태동 세기를 막대그래프로 변경, 미래 `-` 낮춤 | UI | `lib/main.dart` | 주간 세기 선→막대, 기준 점선 유지, 미래 미측정 표시 위치 하향 | 없음 | 없음 | 유지 | 대기 | 리포트 확인 |
| 8 | 2026-06-01 18:07 | 그래프 카드 전체 핀치 확대/축소 | UI/제스처 | `lib/main.dart` | 리포트 차트와 기기 타임라인 카드 전체에서 두 손가락 줌 인식 | 없음 | 없음 | 주간 줌은 이후 제거 | 대기 | 제스처 확인 |
| 9 | 2026-06-02 02:06 | 디자인 수정 전 백업 생성 | 기타 | 없음 | 백업 기록만 참고하고 앱에는 반영하지 않음 | 없음 | 없음 | 기능 변경 아님 | 제외 | 제외 사유 기록 |
| 10 | 2026-06-03 13:09 | 이미지 폴더 이동에 맞춰 프로필/태아 경로 수정 | assets/UI | `lib/main.dart`, `pubspec.yaml` | 태아 경로 `assets/images/fetal/`, 프로필 경로 `assets/images/profile/`로 변경 | fetal/profile 이미지 | 없음 | 최종 asset 경로 기준 | 대기 | asset 존재 검사 |
| 11 | 2026-06-03 15:49 | Figma 기준 홈/네비/모니터링/리포트 UI 1차 적용 | UI/assets | `lib/main.dart`, `pubspec.yaml` | PNG 하단 네비, 배경 이미지, 홈 태아 카드, 모니터링 파동, 리포트 버튼/그래프 스타일 적용 | background/icon/monitoring 이미지 | 없음 | 이후 세부 보정 다수 | 대기 | 화면, analyze |
| 12 | 2026-06-03 15:56 | 하위 asset 폴더를 `pubspec.yaml`에 명시 | assets | `pubspec.yaml` | `background`, `fetal`, `icon`, `monitoring`, `profile`, `logo` 등 등록 | 전체 이미지 폴더 | 없음 | 유지 | 대기 | pub get |
| 13 | 2026-06-03 16:12 | Figma 픽셀 정합 시도 실패 | 제외 | 없음 | Figma MCP 호출 제한으로 반영 없음 | 없음 | 없음 | 반영 불가 | 제외 | 제외 사유 기록 |
| 14 | 2026-06-03 19:06 | Pretendard와 주요 화면 배경/버튼 톤 적용 | UI/assets | `lib/main.dart`, `pubspec.yaml` | Pretendard 등록, 배경 이미지 적용, 알림 아이콘 상태, 카드/칩/버튼 톤 조정 | fonts/background/icon | 없음 | 이후 UI 보정 | 대기 | pub get, 화면 |
| 15 | 2026-06-03 19:58 | 로고 등록, 하단 네비, 모니터링 원형, 리포트 제목/달력 보정 | UI/assets | `lib/main.dart`, `pubspec.yaml` | `assets/images/logo/` 등록, `iconholder.png`, wave ClipOval, 그래프 제목 15pt, 오늘 테두리 | logo/icon/monitoring | 없음 | 이후 보정 | 대기 | 화면 |
| 16 | 2026-06-03 20:23 | 로그인 로고, 홈 태아, 중앙 원형, 저장 버튼, 네비 크기 보정 | UI/assets | `lib/main.dart` | 로고 확대, 태아 영역 확대, `stain.png` 레이어, 저장 버튼 이동, 네비 아이콘 크기/정렬 | stain/icon/logo | 없음 | 이후 보정 | 대기 | 화면 |
| 17 | 2026-06-03 20:54 | 로그인 로고 2배, 태아 카드/네비/그래프/파동 strip 보정 | UI/애니메이션 | `lib/main.dart` | 로고 2배, 실사 태아 확대/좌측, 네비 간격, 파동 무한 이동 | fetal/icon/monitoring | 파동은 이후 되돌림 | 충돌 | 화면 |
| 18 | 2026-06-03 21:31 | 배경/태아 PNG crop, 네비 투명, 파동 반대방향 | UI/assets | `lib/main.dart`, 이미지 파일 | `fetal_card_background.png`, `fetus_real_object.png`, 로고/네비/파동 보정 | background/fetal | 파동은 이후 변경 | 대기 | 이미지/화면 |
| 19 | 2026-06-03 21:45 | 로고 overflow, 태아 0.7, 모니터링 백업 파형 복구 | UI/애니메이션 | `lib/main.dart` | 로고 `672x312`, 간격 20, 실사 scale 0.7, strip 제거 | monitoring | 이후 로고/scale 재변경 | 충돌 | 화면 |
| 20 | 2026-06-03 21:55 | 로고 overflow layout 오류 수정 | 버그 수정 | `lib/main.dart` | `OverflowBox`를 유한 높이 `SizedBox`로 감싸기 | 없음 | 없음 | 유지 | 대기 | analyze |
| 21 | 2026-06-03 22:08 | 모니터링 wave 복원, 홈 태아 1.5, 로고 crop | UI/assets | `lib/main.dart`, `logo.png` | `_MonitoringWavePainter`, 태아 scale, 로고 투명 여백 crop | logo | 이후 scale 재변경 | 충돌 | 화면 |
| 22 | 2026-06-03 22:22 | 로그인 여백, 태아 scale 1.05, iconholder 확인, wave 그림자 | UI | `lib/main.dart` | 로고 폭 360, 실사 scale 1.05, wave shadow/stroke | iconholder | 그림자는 이후 제거 | 충돌 | 화면 |
| 23 | 2026-06-03 22:31 | 로그인 중앙 배치, 네비 overlay, 바깥 그림자 | UI | `lib/main.dart` | 동적 top padding, Stack overlay nav, `SafeArea(bottom:false)`, outer blur | 없음 | 그림자는 이후 제거 | 대기 | 화면 |
| 24 | 2026-06-03 22:43 | 실사 0.84, 네비 0.8배, wave 그라데이션 | UI | `lib/main.dart` | holder `238.4x60.8`, icon `52.8`, gap `6.4`, 실사 scale `0.84`, wave fill gradient | icon/monitoring | 일부 유지 | 대기 | 화면 |
| 25 | 2026-06-03 22:50 | 하단 여백 76, 추상 1.2, 흰 링 제거 | UI | `lib/main.dart` | 주요 페이지 bottom padding 76, 추상 scale 1.2, glow 조정 | 없음 | 22:58에서 여백/그림자 재변경 | 충돌 | 화면 |
| 26 | 2026-06-03 22:58 | 하단 여백 106.4, 파동 그림자 제거 | UI | `lib/main.dart` | bottom padding `106.4`, shadow 관련 제거, 살구색 stroke만 유지 | 없음 | 최종 유지 | 대기 | 화면 |
| 27 | 2026-06-03 23:13 | 일간 리포트 x축 확대 단계 변경 | UI | `lib/main.dart` | 시간축 라벨을 단계별로 변경 | 없음 | 이후 30/10/1분 확장 | 충돌 | 리포트 |
| 28 | 2026-06-05 09:50 | ESP32 WebSocket kick/force 수신 | 기능/dependency/Android | `lib/main.dart`, `pubspec.yaml`, `AndroidManifest.xml` | `web_socket_channel`, `ws://192.168.4.1:81`, kick/noise 처리, cleartext 권한 | 없음 | 이후 16채널 센서 방식으로 변경 | 충돌 | analyze |
| 29 | 2026-06-05 10:12 | 벨트 메시지 파서 분리와 테스트 추가 | 기능/테스트 | `lib/services/belt_message_parser.dart`, `test/belt_message_parser_test.dart`, `lib/main.dart` | 파서 서비스와 테스트 추가 | 없음 | 이후 파서 기준 계속 변경 | 대기 | test |
| 30 | 2026-06-05 11:39 | 반응형 네비, 30/10분 축, 계정 버튼/알림 삭제/문구 | UI/기능 | `lib/main.dart` | 화면폭 기반 네비/여백, 일간 확대 단계 확장, 계정 UI, 알림 X 삭제와 시간대/세기 문구 | 없음 | 멘트는 6/10 asset으로 대체 | 대기 | analyze |
| 31 | 2026-06-05 14:45 | ESP 파싱 보강, 스위치 무관 저장, 랜덤 알림 | 기능 | `belt_message_parser.dart`, `lib/main.dart`, `test` | 접두 텍스트/문자열 force 파싱, kick 저장, 랜덤 문구 | 없음 | 이후 센서 형식 변경 | 충돌 | test |
| 32 | 2026-06-05 15:23 | 실시간 저장 chip, 월별 보간선, 멘트 중복 방지 | UI/기능 | `lib/main.dart` | chip `#4EDF72` 61%, 보간 path 분리, 직전 멘트 중복 회피 | 없음 | 최종 멘트 asset과 병행 | 대기 | analyze |
| 33 | 2026-06-05 16:30 | 일별 1분 확대, 그래프 상세, 시스템바 | UI/기능/Android | `lib/main.dart` | 1분 버킷, 상세 팝업, 막대 폭 고정, 중앙 기준 zoom, 하단 inset | 없음 | 상세 UI는 17:27에서 변경 | 충돌 | test |
| 34 | 2026-06-05 17:10 | 상세 페이지/닫힘, force 원값 저장, displayMax 동적 | 기능/UI | `lib/main.dart`, `movement_repository.dart`, `belt_message_parser.dart` | 상세 pagination, force 원값 반올림, 10점 상한 제거 | 없음 | 상세 UI 뒤에서 변경 | 충돌 | test |
| 35 | 2026-06-05 17:21 | 1분 이후 추가 확대 금지 | UI | `lib/main.dart` | 최대 확대 `288x`, 720/1440 제거 | 없음 | 유지 | 대기 | 리포트 |
| 36 | 2026-06-05 17:27 | 상세 드롭다운을 그래프 아래 카드로 변경 | UI | `lib/main.dart` | `_ChartDetailCard`, X 닫기, `(hh:mm:ss)` 형식 | 없음 | 이후 움직임 안내/백분율 추가 | 대기 | 화면 |
| 37 | 2026-06-05 17:47 | 주간 줌 제거, 백그라운드 서비스 추가 | 기능/Android | `lib/main.dart`, `AndroidManifest.xml`, `MainActivity.kt`, `BackgroundBeltService.kt` | foreground service, MethodChannel, 주간 줌 제거, 백그라운드 DB 저장 | 없음 | 이후 센서 기준 수정 | 대기 | Kotlin compile |
| 38 | 2026-06-05 17:49 | 중복 입력 제한 10ms로 조정 | 기능 | `lib/main.dart`, `BackgroundBeltService.kt` | 600ms 제한을 10ms로 낮춤 | 없음 | 유지 여부 확인 | 대기 | test |
| 39 | 2026-06-06 00:00 | Flutter SDK bugreport 이동/upgrade | 제외 | 없음 | 앱 기능과 무관, 반영하지 않음 | 없음 | 제외 | 제외 | 제외 사유 기록 |
| 40 | 2026-06-06 00:00 | `flutter pub upgrade`, Gradle 경고 확인 | dependency | `pubspec.lock` | 호환 잠금 버전 갱신, Gradle 옵션 원복 | 없음 | 최종 lock 기준 | 대기 | pub get |
| 41 | 2026-06-07 00:00 | 주간 기기 사용 타임라인 줌 제거 | UI | `lib/main.dart` | `_DeviceTimelineCard` 주간 zoomMax 1.0 | 없음 | 유지 | 대기 | 리포트 |
| 42 | 2026-06-08 00:00 | 수동 세기 10/17/25 기준 | 기능/UI | `lib/main.dart` | 약/중/강 선택과 기준 변경 | 없음 | 6/9, 6/10 기준으로 덮어씀 | 충돌 | test |
| 43 | 2026-06-08 00:00 | 버튼 클릭 시 세기 선택 | UI | `lib/main.dart` | 항상 보이는 선택 UI 제거, 버튼 클릭 후 선택 | 없음 | 뒤에서 작은 가로 선택창으로 변경 | 충돌 | 화면 |
| 44 | 2026-06-08 00:00 | My 화면 ESP 연결됨 표시 | UI/기능 | `lib/main.dart` | `_beltConnected`, 연결됨/연결 대기 표시 | 없음 | 이후 자동 수신 문구 보강 | 대기 | 화면 |
| 45 | 2026-06-08 00:00 | 모든 그래프 y축 현재 최대값 기준 | UI | `lib/main.dart` | 현재 데이터 max 기반 비율, 상단 안전 여백 | 없음 | 유지 | 대기 | 리포트 |
| 46 | 2026-06-08 00:00 | 그래프 좌우 끝 값 중앙 정렬 | UI | `lib/main.dart` | x좌표 helper와 좌우 plot padding | 없음 | 유지 | 대기 | 리포트 |
| 47 | 2026-06-08 00:00 | 일일 횟수 점 복구, 세기 점선, 작은 선택창 | UI | `lib/main.dart` | 횟수 선 위 점, 10/17/25 점선, 평균 문구, 버튼 아래 작은 가로 선택창 | 없음 | 세기 값은 이후 ADC 기준 변경 | 대기 | 화면 |
| 48 | 2026-06-08 00:00 | 워치 알림 Firestore 저장 추가 | Firebase/기능 | `watch_alert_repository.dart`, `lib/main.dart`, `firestore.rules` | `watch_alerts` 저장 추가 | 없음 | 6/9 02:34 제거 | 제외 | 최종 검색 |
| 49 | 2026-06-08 00:00 | watch_alerts 규칙 배포/로그 | Firebase | `lib/main.dart`, `firestore.rules` | 규칙 배포와 실패 로그 | 없음 | watch_alerts 제거 | 제외 | 최종 검색 |
| 50 | 2026-06-08 00:00 | watch payload 축소와 문서 생성 | Firebase/docs | `watch_alert_repository.dart`, `docs/watch_alert_payload.md` | `t/i/m/r`, 멘트 테이블 | 없음 | watch_alerts 제거 | 제외 | 최종 검색 |
| 51 | 2026-06-08 00:00 | 태동/세션 Firestore 동기화 | Firebase/DB | `movement_repository.dart`, `firestore.rules` | `movement_records`, `device_sessions` 클라우드 병합 | 없음 | 6/9 02:34 제거 | 제외 | 최종 검색 |
| 52 | 2026-06-08 00:00 | 워치 로그인 외부 프로젝트 확인 | 제외 | 없음 | 외부 워치 프로젝트 작업, 모바일 앱에는 반영하지 않음 | 없음 | 범위 밖 | 제외 | 제외 사유 기록 |
| 53 | 2026-06-09 01:37 | Firebase 시간 `t` Timestamp | Firebase | `movement_repository.dart` | Firestore `t` 타입 변경 | 없음 | 로컬 전용으로 제거 | 제외 | 최종 검색 |
| 54 | 2026-06-09 01:44 | movement_records에 멘트번호 `m` 저장 | Firebase | `movement_repository.dart`, `watch_alert_repository.dart`, `lib/main.dart` | `m` 병합 저장 | 없음 | 로컬 전용으로 제거 | 제외 | 최종 검색 |
| 55 | 2026-06-09 01:55 | 수동 세기 2000/3000/3600 | 기능 | `lib/main.dart` | 수동 약/중/강 값을 ADC 기준으로 변경 | 없음 | 6/10에서 3500/3800/4095로 변경 | 충돌 | test |
| 56 | 2026-06-09 02:05 | 수동 저장 무한 로딩 수정 | DB/버그 | `movement_repository.dart`, `lib/main.dart` | 로컬 저장 즉시 완료, 전원 상태 무관 저장 | 없음 | 로컬 전용과 병합 | 대기 | test |
| 57 | 2026-06-09 02:34 | 태동/워치 Firebase 제거, 로컬 그래프 복귀 | DB/Firebase/삭제 | `movement_repository.dart`, `lib/main.dart`, 삭제 `watch_alert_repository.dart` | 태동/세션 Firestore 제거, watch_alert 제거, 계정 Firebase 유지 | 없음 | 최종 핵심 | 대기 | 검색 |
| 58 | 2026-06-09 02:46 | 로컬 전용 검증과 widget_test 복구 | 테스트 | `test/widget_test.dart` | 현재 UI 키 기반 테스트로 복구 | 없음 | 유지 | 대기 | flutter test |
| 59 | 2026-06-09 02:52 | 세기 백분율을 2000~4095 기준으로 변경 | UI/기능 | `lib/main.dart` | `(intensity-2000)/(4095-2000)*100`, 가이드 정리 | 없음 | 6/10 기준과 조화 필요 | 대기 | 리포트 |
| 60 | 2026-06-09 날짜만 | HTTP 16채널 JSON 폴링 도입 | 기능/Android | `belt_message_parser.dart`, `lib/main.dart`, `BackgroundBeltService.kt`, `test` | `c0~c15`, 초과/하강 판정, 원본 ADC 저장 | 없음 | 이후 WebSocket 중심+fallback | 충돌 | test |
| 61 | 2026-06-09 10:22 | 폴링 주기 100ms | 기능 | `lib/main.dart`, `BackgroundBeltService.kt` | HTTP polling interval 250ms→100ms | 없음 | fallback에 유지 | 대기 | test |
| 62 | 2026-06-09 14:14 | WebSocket 16채널 실시간, 기준 2000/3000/3800 | 기능/Android | `lib/main.dart`, `belt_message_parser.dart`, `BackgroundBeltService.kt` | `ws://192.168.4.1:81`, 16채널, 강함 3800 | 없음 | 6/10 기준으로 변경 | 충돌 | test |
| 63 | 2026-06-09 17:51 | 2000 초과 첫 시점 즉시 저장 | 기능 | `belt_message_parser.dart`, `test`, `BackgroundBeltService.kt`, `lib/main.dart` | 상승 첫 시점 저장, 하강 전 추가 금지, refresh key | 없음 | 6/10 임계값 적용 | 대기 | test |
| 64 | 2026-06-09 18:07 | 자동 수신 시작과 Wi-Fi 정보 표시 | 기능/UI | `lib/main.dart` | 자동 수신, WS 주소 후보, My에 `GODORI_WEARABLE` 정보 | 없음 | 이후 주소/상태 이동 | 충돌 | 화면 |
| 65 | 2026-06-09 18:30 | WS timeout/상태 표시/파싱 보강 | 기능/UI | `lib/main.dart`, `belt_message_parser.dart`, `test` | 2초 timeout, 상태 문구, 바이트/라벨 메시지 파싱 | 없음 | 상태 문구는 6/10 My로 이동 | 대기 | test |
| 66 | 2026-06-09 19:37 | HTTP fallback 추가 | 기능 | `lib/main.dart` | WS 실패 시 여러 HTTP 경로 순환 폴링 | 없음 | 19:41에서 `/data` 단일 | 충돌 | test |
| 67 | 2026-06-09 19:41 | HTTP fallback `/data` 단일, WS 중심 정리 | 기능 | `lib/main.dart` | WS 단일 주소/timeout, HTTP fallback은 실패 시 `/data` | 없음 | 20:11에서 dart:io WS | 대기 | test |
| 68 | 2026-06-09 20:11 | `dart:io WebSocket.connect`와 compression off | 기능 | `lib/main.dart` | WebSocket 압축 끄기, 성공 시 HTTP 중지 | 없음 | 최종 연결 방식 | 대기 | test |
| 69 | 2026-06-10 09:36 | 상세 세기 백분율, 전체 리빌드 방지 | UI/버그 | `lib/main.dart` | 상세 `0~100%`, `ValueKey` 제거, `refreshKey`, 상태 변화 시만 갱신 | 없음 | 유지 | 대기 | test |
| 70 | 2026-06-10 10:26 | 자이로/가속도 움직임 판단, 임계값 3500, 상세 안내 | 기능/UI/DB | `lib/main.dart`, `belt_message_parser.dart`, `local_database.dart` | 움직임 중 임계값 상승, `measured_during_user_motion`, 보정 그래프, 텍스트 원 아래 | 없음 | 14:50에서 기준 재정의 | 충돌 | test |
| 71 | 2026-06-10 14:50 | 최종 자이로/세기 기준 3500/3800/4095, 움직임 중 4090 | 기능/UI | `belt_message_parser.dart`, `lib/main.dart`, `test` | 기본 `>3500`, 중 `>=3800`, 강 `>=4095`, gyro abs>=245이면 `>4090`, 안내 문구와 평균 보정 | 없음 | 최종 센서 기준 | 대기 | test |
| 72 | 2026-06-10 15:30 | 알림창 유지, 상태 텍스트/흔들림, 알림음, My 선택 UI | UI/기능/assets/Android | `lib/main.dart`, `pubspec.yaml`, `AndroidManifest.xml`, `MainActivity.kt`, `BackgroundBeltService.kt` | 알림 dialog, 흔들림/감지 텍스트, `dingdong1~5`, MediaPlayer, My 알림음 선택, 상태 문구 이동 | `assets/sounds/` | 이후 효과음 보강 | 대기 | test, compile |
| 73 | 2026-06-10 15:45 | 깨진 한글 문구 복구 | 버그/UI | `lib/main.dart` | UI/알림/상세/검증 문구 정상 한국어 복구, `�` 제거 | 없음 | 유지 | 대기 | 문자열 검색 |
| 74 | 2026-06-10 17:12 | 알림음 선택창 overflow, 음량, 연결 후 자동 켜짐, 전원 버튼 제거 | UI/기능/Android | `lib/main.dart`, `MainActivity.kt` | 바텀시트 78%, AudioAttributes/최대 볼륨, 연결 후 모니터링 on, 전원 스위치 제거 | sounds | 유지 | 화면, compile |
| 75 | 2026-06-10 18:48 | APK 압축 asset 효과음 재생과 48개 멘트 fallback | Android/assets/기능 | `lib/main.dart`, `MainActivity.kt` | asset stream을 캐시로 복사해 MediaPlayer 재생, 48개 멘트 풀 | `dingdong1~5` | 19:03 asset 멘트가 최종 | 대기 | build apk |
| 76 | 2026-06-10 19:03 | 첨부 멘트 목록을 asset으로 추가 | assets/기능 | `assets/messages/movement_alert_messages.txt`, `lib/main.dart`, `pubspec.yaml` | 앱 시작 시 멘트 파일 로드, 실패 시 fallback 유지 | `assets/messages/` | 최종 유효 변경 | 대기 | build apk, jar tf |

## 적용 기록

### 1~10번 구간

- 1번 적용 완료: 홈 태아 asset, 선택 시트, 리포트 날짜/그래프, 태명 클라우드 문구가 포함된 2026-06-02 중간 상태를 기준으로 반영했다.
- 2번 적용 완료: `FetalMovementRecord`, `LocalDatabase`, `MovementRepository` 및 SQLite 기록 저장/조회 구조를 반영했다.
- 3번 적용 완료: 홈 실제 데이터 집계, 리포트 차트/달력/세션/My 상태 반영 구조를 반영했다.
- 4번 적용 완료: 리포트 x축 정밀 스크롤/확대 구조와 진행 중 세션 표시 구조를 반영했다.
- 5번 적용 완료: 월간 축/보간/기기 사용 그래프 세분화 구조를 반영했다.
- 6번 적용 완료: 값 라벨 여백, 오늘 강조, 월말 중복 제거, 사용시간 표기 구조를 반영했다.
- 7번 적용 완료: 주간 태동 세기 막대그래프와 미래 미측정 표시 위치 조정 구조를 반영했다.
- 8번 적용 완료: 카드 전체 핀치 확대/축소 구조를 반영했다.
- 9번 제외: 백업 생성 기록으로 앱 기능/코드 변경이 아니므로 최종 앱에는 반영하지 않았다.
- 10번 적용 완료: 태아 이미지는 `assets/images/fetal/`, 프로필 이미지는 `assets/images/profile/` 경로로 옮겨 코드 상수를 맞췄다.

### 11~20번 구간

- 11번 적용 완료: Figma 기준 PNG 네비/배경/홈/모니터링/리포트 UI 구조를 반영했다.
- 12번 적용 완료: `pubspec.yaml`에 하위 asset 폴더와 이후 사용할 messages/sounds 경로가 포함되었다. messages/sounds는 72번/76번에서 실제 파일을 채운다.
- 13번 제외: Figma MCP 호출 제한으로 실제 디자인 데이터를 가져오지 못한 기록이라 코드 반영 없음.
- 14번 적용 완료: Pretendard 폰트와 주요 화면 배경/버튼 톤을 반영했다.
- 15번 적용 완료: 로고 폴더, 하단 네비, 모니터링 원형, 리포트 제목/달력 보정 구조를 반영했다.
- 16번 적용 완료: 로그인 로고, 홈 태아 표시, 중앙 원형, 저장 버튼, 네비 크기 보정 구조를 반영했다.
- 17번 충돌: 파동 strip 애니메이션 등은 19번 이후 되돌림 기록이 있어 최종에는 남기지 않는다.
- 18번 적용 완료: crop된 배경/태아/로고 asset과 네비 투명 구조를 반영했다.
- 19번 충돌: 실시간 모니터링 strip 제거와 백업 파형 복귀는 이후 wave painter 최종 상태로 흡수했다.
- 20번 적용 완료: 로그인 로고 overflow 오류가 나지 않도록 유한 높이 구조를 유지했다.
- 검증: `flutter pub get` 성공, `flutter analyze` 성공.

### 21~30번 구간

- 21번 충돌/적용 완료: 홈 태아와 모니터링 wave 구조는 이후 최종 wave painter 상태로 흡수했다.
- 22번 충돌: wave 그림자는 26번에서 제거되므로 최종에는 남기지 않는다.
- 23번 적용 완료: 하단 네비 overlay와 SafeArea 처리 구조를 반영했다.
- 24번 적용 완료: 하단 네비 축소, 실사 태아 scale, wave gradient 계열 최종 구조를 반영했다.
- 25번 충돌: 하단 여백 76은 26번에서 106.4로 덮어쓴다.
- 26번 적용 완료: 하단 여백과 모니터링 파동 그림자 제거 최종 상태를 반영했다.
- 27번 충돌: 일간 x축 확대 단계는 30번과 35번에서 더 세분화되므로 중간 상태로만 기록한다.
- 28번 충돌/적용 확인: 초기 `kick/force` WebSocket 구조는 이후 16채널 센서 방식으로 대체되지만 `web_socket_channel` 의존성은 유지했다.
- 29번 적용 완료: `lib/services/belt_message_parser.dart`와 `test/belt_message_parser_test.dart`를 추가했다.
- 30번 적용 완료: 반응형 네비, 확대 단계 확장, 계정 UI, 알림 삭제/문구 구조를 반영했다.
- 검증: `flutter pub get` 성공, `flutter analyze` 성공.

### 31~40번 구간

- 31번 충돌/적용 확인: 초기 ESP 파싱 보강은 이후 16채널/자이로 파서로 대체되었다.
- 32번 적용 완료: 실시간 저장 chip 색상과 보간선/멘트 중복 방지 구조는 최종 UI에 흡수되었다.
- 33번 충돌: 그래프 내부 드롭다운 상세는 36번 카드 UI로 대체되었다.
- 34번 충돌/적용 확인: force 원값 저장과 동적 displayMax 계열은 최종 ADC 기준으로 이어졌다.
- 35번 적용 완료: 일간 그래프 최대 확대를 1분 단위로 제한하는 구조를 유지했다.
- 36번 적용 완료: 그래프 아래 상세 카드와 X 닫기 구조를 반영했다.
- 37번 적용 완료: Android foreground `BackgroundBeltService`, `MainActivity` MethodChannel, Manifest 권한을 반영했다.
- 38번 적용 완료: 중복 입력 제한 완화는 최종 센서 판정 흐름에 포함되었다.
- 39번 제외: Flutter SDK bugreport 이동/upgrade는 앱 소스 기능이 아니므로 제외했다.
- 40번 적용 완료: 최종 `pubspec.lock`과 dependency 잠금 상태를 유지했다.
- 검증: `flutter pub get` 성공, `flutter analyze` 성공.

### 41~50 적용 기록
- 41 적용 완료: `_DeviceTimelineCard`에서 주간 범위는 `maxScale = 1.0` 흐름으로 확인했고, 일간/월간 확대만 유지했다.
- 42 충돌: 6/8의 10/17/25 수동 세기 기준은 이후 ADC 기준 변경과 충돌하므로 최종 ADC 변환 흐름을 우선했다.
- 43 충돌: 버튼 클릭 후 세기 선택 UI는 이후 작은 선택창/최종 입력 UI 흐름으로 대체된 것으로 판단했다.
- 44 적용 완료: My/상태 영역의 연결 상태 표시는 최종 코드 흐름 기준으로 확인했다.
- 45 적용 완료: 리포트 그래프는 현재 데이터 기반 최대값과 상단 여백 흐름을 유지했다.
- 46 적용 완료: `_chartX` gutter와 좌우 끝 라벨 위치 보정 흐름을 확인했다.
- 47 적용 완료/부분 충돌: 일일 횟수 점, 세기 가이드, 그래프 보정은 유지하되 10/17/25 기준값은 이후 ADC 기준으로 대체했다.
- 48 제외: `watch_alerts` Firestore 저장은 6/9 제거 기록과 사용자 제외 조건에 따라 반영하지 않았다.
- 49 제외: `watch_alerts` Firestore 규칙/실패 로그는 반영하지 않았다.
- 50 제외: watch payload 축소 문서와 관련 저장소는 최종 앱에서 제외했다.
- 검증: `flutter pub get` 성공, `flutter analyze` 성공(No issues found).
### 51~60 적용 기록
- 51 제외: `movement_records`, `device_sessions` Firestore 동기화는 사용자 제외 조건과 6/9 제거 기록에 따라 반영하지 않았다.
- 52 제외: 외부 워치 로그인 프로젝트 확인은 모바일 앱 최종 복구 범위 밖으로 처리했다.
- 53 제외: Firestore `Timestamp` 저장 변경은 로컬 전용 저장으로 대체되어 반영하지 않았다.
- 54 제외: Firestore 멘트번호 `m` 저장은 `watch_alerts`/movement Firestore 제거와 함께 제외했다.
- 55 충돌: 2000/3000/3600 수동 세기 기준은 6/10의 3500/3800/4095 계열 ADC 기준으로 대체했다.
- 56 적용 완료: `MovementRepository.addRecord`는 SQLite insert만 수행하며 전원/클라우드 대기 없이 저장한다.
- 57 적용 완료: 태동/세션 Firestore 및 watch 저장소는 새 복구본에 두지 않고, 계정 Firebase와 로컬 SQLite만 유지했다.
- 58 적용 완료: 현재 UI 키 기반 `widget_test.dart`를 유지했다.
- 59 적용 완료: 세기 표시/계산은 최종 ADC 원본값 흐름과 4095 상한 기준으로 이어가도록 확인했다.
- 60 충돌/적용 완료: 초기 HTTP 16채널 JSON 폴링은 이후 WebSocket 중심 및 HTTP fallback 흐름으로 대체될 항목으로 표시했다.
- 검증: `flutter pub get` 성공, `flutter analyze` 성공(No issues found).
### 61~70 적용 기록
- 61 충돌/적용 완료: 100ms HTTP polling 요청은 이후 WebSocket 중심 구조로 대체되었고, 최종 HTTP fallback은 `/data` 단일 500ms 폴링으로 정리했다.
- 62 충돌: 2000/3000/3800 기준 WebSocket 16채널 구조는 유지하되 기준값은 6/10의 3500/3800/4095 및 움직임 중 4090 초과 기준으로 대체했다.
- 63 적용 완료: `BeltMovementDetector`가 threshold 초과 첫 시점에 1회 저장하고 활성 상태가 내려가기 전 추가 저장하지 않는 흐름을 확인했다.
- 64 충돌/적용 완료: 자동 수신과 Wi-Fi 안내는 유지하되, 상태 문구 위치는 이후 My 화면/복부 센서 카드 흐름으로 정리했다.
- 65 적용 완료: WebSocket timeout, 상태 문구, 바이트/라벨 메시지 파싱 보강을 `parseBeltSensorSample`과 UI 상태 문구로 확인했다.
- 66 충돌: 다중 HTTP fallback은 이후 `/data` 단일 fallback으로 대체했다.
- 67 적용 완료: HTTP fallback을 WebSocket 실패 시 `http://192.168.4.1/data` 단일 경로로만 동작하게 보정했다.
- 68 적용 완료: foreground WebSocket 연결을 `dart:io WebSocket.connect()`와 `CompressionOptions.compressionOff`로 보정했다.
- 69 적용 완료: 상세 세기 백분율 표시, `refreshKey` 기반 갱신, 반복 리빌드 억제 흐름을 유지했다.
- 70 충돌/적용 완료: 사용자 움직임 판단, `measured_during_user_motion`, 그래프 보정은 유지하되 기준값은 6/10 14:50 최종 기준으로 이어간다.
- 검증: `dart format lib/main.dart` 성공, `flutter pub get` 성공, `flutter analyze` 성공(No issues found), `flutter test test/belt_message_parser_test.dart` 성공(9 tests passed).
### 71~76 적용 기록
- 71 적용 완료: 최종 센서 기준 `>3500`, `>=3800`, `>=4095`, 움직임 중 `>4090`, gyro abs>=245 기준과 상세 안내/그래프 보정 흐름을 확인했다.
- 72 적용 완료: 알림 dialog 유지, 상태 텍스트/흔들림 상태, `dingdong1~5` 알림음, Android `MediaPlayer`, My 알림음 선택 UI, foreground service 권한을 반영했다.
- 73 적용 완료: `main.dart`와 `widget_test.dart`의 한글 깨짐을 실제 UTF-8 문자열 기준으로 확인/복구했다.
- 74 적용 완료: 알림음 음량은 `AudioAttributes`와 `setVolume(1.0f, 1.0f)`로 반영했고, 연결 후 자동 모니터링 흐름 및 기기 전원 스위치 제거 상태를 테스트로 확인했다.
- 75 적용 완료: APK/source_only에 있던 `dingdong1.mp3`~`dingdong5.mp3`를 `assets/sounds/`에 복원하고 네이티브 asset stream 캐시 재생 흐름을 유지했다.
- 76 적용 완료: `assets/messages/movement_alert_messages.txt`를 6/10 source_only에서 복원하고 `pubspec.yaml`의 `assets/messages/` 등록을 확인했다.
- 추가 보정: `android/app/google-services.json`을 복원하고 `android/app/build.gradle.kts`의 `namespace/applicationId`를 6/10 기준 `com.example.test1`로 맞췄다.
- 검증: `flutter pub get` 성공, `flutter analyze` 성공(No issues found), `flutter test` 성공(14 tests passed).
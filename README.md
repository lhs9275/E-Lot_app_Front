# PSP2 FN

수소 충전소 정보를 확인하고 카카오 로그인을 통해 빠르게 지도 화면으로 진입할 수 있는 Flutter 애플리케이션입니다. 처음 프로젝트를 접하는 분도 전체 흐름을 이해하고 바로 실행해 볼 수 있도록 아래에 모든 준비 과정을 정리했습니다.

---

## 1. 주요 기능
- **카카오 로그인**: `WelcomeScreen`에서 카카오톡/카카오계정 로그인을 지원하고 발급받은 토큰을 안전하게 보관합니다.
- **충전소 지도**: `MapScreen`이 `H2StationApiService`를 통해 실시간 데이터를 불러온 뒤 위경도가 있는 충전소만 지도에 마커로 표시합니다. 마커를 누르면 운영 상태, 대기 차량 수, 최종 갱신 시각이 바텀시트로 노출됩니다.
- **공통 초기화**: `.env` 값을 읽어 API, Kakao SDK, 지도 SDK 초기화를 한 번에 처리합니다.

---

## 2. 프로젝트 구조 사전 (매우 상세)
> **표기 규칙**  
> `D/` = 디렉터리, `F/` = 파일, 괄호 안은 대표 클래스·함수.

| 경로 | 타입 | 설명 |
| --- | --- | --- |
| `lib/main.dart` | 파일 | 앱 진입점. 다른 로직 없이 `bootstrap()`만 호출해서 모든 초기화를 한 곳으로 집약합니다. |
| `lib/bootstrap.dart` | 파일 | 위젯 바인딩 → `.env` 로드 → HTTP Override → H2 API 서비스 구성 → 네이버 지도 초기화 → Kakao SDK 초기화 → `runApp()` 순서로 실행합니다. 실패 시마다 `debugPrint`로 상황을 남기며 앱 전체 설정을 담당합니다. |
| `lib/app/` | 디렉터리 | 전역 MaterialApp 정의와 라우팅만 모아둔 공간입니다. |
| `lib/app/app.dart` | 파일 (`App` 위젯) | 공통 테마/폰트/시드 색상을 설정하고 `AppRouter`를 연결합니다. 앱 전체의 UI 컨테이너 역할입니다. |
| `lib/app/router/app_router.dart` | 파일 (`AppRouter`) | 모든 라우트를 중앙집중식으로 정의합니다. `welcome`, `map` 상수를 제공하며 `onGenerateRoute`, `onUnknownRoute` 내부에서 `MapScreen`, `WelcomeScreen` 위젯을 생성합니다. 새로운 화면이 생기면 이 파일에만 경로를 추가하면 됩니다. |
| `lib/auth/` | 디렉터리 | 인증 도메인 공통 코드. 현재는 보안 스토리지 래퍼(`TokenStorage`)가 위치합니다. 나중에 OAuth API 등을 추가해 확장 가능합니다. |
| `lib/auth/token_storage.dart` | 파일 (`TokenStorage`) | `flutter_secure_storage`를 감싸 access/refresh 토큰을 저장, 조회, 삭제하는 Promise 기반 API를 제공합니다. |
| `lib/core/` | 디렉터리 | 어떤 기능에도 종속되지 않는 코어 레이어입니다. 환경 변수와 HTTP 정책을 이곳에서 정의해 전역으로 재사용합니다. |
| `lib/core/config/environment.dart` | 파일 (`EnvironmentConfig`) | `.env`를 한 번만 로드하고, 하위 getter로 Kakao/네이버/H2 설정을 제공합니다. 값이 없을 때 기본값을 적용하거나 경고를 출력합니다. |
| `lib/core/http/insecure_http_overrides.dart` | 파일 (`configureHttpOverrides`) | 개발 중 TLS 인증서 검증을 무시해야 할 때 `HttpOverrides.global`을 교체합니다. 웹 빌드나 프로덕션에서는 자동으로 비활성화됩니다. |
| `lib/features/` | 디렉터리 | 실제 비즈니스 기능을 모은 공간입니다. 각 기능이 독립적으로 커질 수 있도록 `features/<도메인>/<layer>` 패턴을 사용합니다. |
| `lib/features/auth/` | 디렉터리 | 로그인/인증 UX를 담당합니다. |
| `lib/features/auth/presentation/welcome_screen.dart` | 파일 (`WelcomeScreen`) | 카카오 로그인을 시도하고, 서버 토큰 교환 → `TokenStorage` 저장 → `MapScreen` 라우팅을 처리합니다. UI 리소스(이미지, SVG)도 여기서 로드합니다. |
| `lib/features/map/` | 디렉터리 | 지도와 충전소 데이터 기능을 모았습니다. |
| `lib/features/map/data/h2_station_api_service.dart` | 파일 (`H2StationApiService`) | 충전소 목록 API 호출을 담당하며, `configureH2StationApi()`로 전역 인스턴스를 설정합니다. URL 끝 슬래시를 정규화하고 응답 JSON을 `H2Station` 모델로 변환합니다. |
| `lib/features/map/presentation/map_screen.dart` | 파일 (`MapScreen`) | 네이버 지도를 렌더링하고, 충전소 마커를 표시하며, 하단 내비게이션 및 Floating 버튼 로직도 포함합니다. `_loadStations`, `_renderStationMarkers`, `_showStationBottomSheet` 등 UI와 데이터 흐름을 모두 제어합니다. |
| `lib/models/` | 디렉터리 | 여러 기능에서 공유하는 모델 정의. |
| `lib/models/h2_station.dart` | 파일 (`H2Station`) | 서버 응답을 안전하게 파싱하기 위한 헬퍼들(`_parseInt`, `_parseDouble`, `_stringOrFallback`)을 포함하며 각 충전소의 상태/위치/통계를 표현합니다. |
| `lib/screens/` | 디렉터리 | 레거시 화면이 임시로 남아 있는 공간입니다. 새 기능은 `features/` 아래에 추가하고, 기존 화면도 순차적으로 옮길 예정입니다. |
| `test/widget_test.dart` | 파일 | 라우터가 적절한 화면을 반환하는지 검증하는 단위 테스트입니다. 기본 Counter 테스트 대신 앱 구조를 검사하도록 교체했습니다. |

필요 시 이 표를 “사전”처럼 참고해 어떤 파일이 무슨 책임을 갖는지 빠르게 파악할 수 있습니다.

---

## 3. 준비물
1. **Flutter SDK**: 3.22 이상 권장  
2. **Dart SDK**: Flutter에 포함되어 자동 설치됩니다.  
3. **필수 계정/키**
   - Kakao Native & JavaScript App Key
   - Naver Map Client ID
   - H2 API 서버 주소 (예: `https://clos21.kr`)

---

## 4. 설치 및 실행
```bash
git clone <이 레포 주소>
cd psp2Fn
flutter pub get

# 실행 (예: iOS 시뮬레이터 혹은 Android 에뮬레이터)
flutter run
```

---

## 5. .env 설정 (⚠️ 저장소에 올리지 마세요)
1. 프로젝트 루트에 `.env` 파일을 **직접 생성**합니다.  
2. 아래 키를 프로젝트 요구사항에 맞게 채웁니다.

| 키 | 설명 |
| --- | --- |
| `KAKAO_NATIVE_APP_KEY` | Kakao SDK Native 앱 키 |
| `KAKAO_JAVASCRIPT_APP_KEY` | Kakao SDK JavaScript 키 |
| `NAVER_MAP_CLIENT_ID` | 네이버 지도 클라이언트 ID |
| `H2_API_BASE_URL` | H2 API 서버 주소 (예: `https://clos21.kr`) |
| `H2_API_ALLOW_INSECURE_SSL` | 개발 중 자체 서명 인증서 허용 여부 (`true`/`false`) |

> `.env` 파일은 민감 정보가 포함되므로 Git에 추가하지 마세요. 이미 `.gitignore`에 등록돼 있어 추적되지 않도록 구성돼 있습니다.  
> 키가 비어 있으면 `EnvironmentConfig`에서 기본값(`http://10.0.2.2:8443`)을 사용하면서 경고를 출력합니다.

---

## 6. 자주 쓰는 명령어
| 작업 | 명령 |
| --- | --- |
| 의존성 설치 | `flutter pub get` |
| 정적 분석 | `flutter analyze` |
| 단위 테스트 | `flutter test` |
| 린트/포맷 (필요 시) | `dart fix --apply`, `dart format .` |

---

## 7. 동작 흐름
1. `main.dart` → `bootstrap()` 호출.
2. `.env` 로드 → HTTP Override → H2 API 서비스 준비 → Naver Map/Kakao SDK 초기화.
3. `App` 실행 → `AppRouter`가 초기 화면(`WelcomeScreen`)을 띄움.
4. 카카오 로그인 성공 시 토큰 저장 후 `MapScreen`으로 이동하여 충전소 데이터를 로드/표시.

---

## 8. 주요 함수 및 역할
- `lib/main.dart > main()` : 앱 실행 진입점으로, 다른 로직 없이 `bootstrap()`만 호출합니다.
- `lib/bootstrap.dart > bootstrap()` : 위젯 바인딩, `.env` 로드, HTTP Override 설정, H2 API/네이버 지도/Kakao SDK 초기화를 수행한 뒤 `runApp()`을 호출합니다.
- `lib/core/config/environment.dart > EnvironmentConfig.load()` : `.env`를 한 번만 불러오고 이후에는 캐싱된 값을 사용합니다.
- `EnvironmentConfig.h2ApiBaseUrl / kakaoNativeAppKey / naverMapClientId` : 환경 변수를 읽고 기본값이나 경고를 처리합니다.
- `lib/core/http/insecure_http_overrides.dart > configureHttpOverrides()` : 개발 환경에서만 자체 서명 인증서를 허용하도록 전역 `HttpOverrides`를 세팅합니다.
- `lib/features/map/data/h2_station_api_service.dart > configureH2StationApi()` : 앱 전역에서 사용할 수 있도록 H2 API 서비스 싱글턴을 초기화합니다.
- `H2StationApiService.fetchStations()` : 서버에서 충전소 목록을 가져오고 `H2Station` 모델 리스트로 변환합니다.
- `lib/features/auth/presentation/welcome_screen.dart > _handleKakaoLogin()` : 카카오 로그인 로직, 서버 토큰 교환, 토큰 저장, 지도 화면 이동까지 담당합니다.
- `lib/features/map/presentation/map_screen.dart > _loadStations()` : API 호출, 로딩 상태/에러 상태 관리, 마커 렌더링 트리거를 포함한 핵심 비즈니스 로직입니다.
- `MapScreenState._renderStationMarkers()` : 지도 컨트롤러에 마커를 추가하고 상태에 따른 색상/캡션을 설정합니다.
- `lib/app/router/app_router.dart > AppRouter.onGenerateRoute()` : 모든 라우트를 한곳에서 정의하고, 알 수 없는 경로도 웰컴 화면으로 안전하게 돌려보냅니다.

---

## 9. 문제 해결 가이드
- **네이버 지도 초기화 실패**: `.env`에 `NAVER_MAP_CLIENT_ID`가 있는지 확인하고, 콘솔 로그를 참고하세요.
- **카카오 로그인 에러**: 카카오 개발자 콘솔에서 앱 키, 플랫폼(앱 패키지명/번들 ID) 설정을 확인하세요.
- **H2 API 호출 실패**: `H2_API_BASE_URL`이 실제 서버 URL인지, HTTP/HTTPS 프로토콜이 맞는지 검토하세요.

---

## 10. H2 지도 데이터 흐름
1. `main.dart`에서 `.env`를 읽고 없으면 기본값 `https://clos21.kr`을 사용해 `configureH2StationApi()`를 호출합니다.
2. `MapScreen.initState()`가 시작되면 `_loadStations()`가 실행되어 `h2StationApi.fetchStations()`로 `/mapi/h2/stations?type=all` 데이터를 불러옵니다.
3. 응답 JSON은 `H2Station.fromJson()`에서 실시간 정보(`realtime`)와 운영 정보(`operation`)를 조합해 위경도, 대기 차량 수, 최종 갱신 시각을 안전하게 파싱합니다.
4. 좌표가 있는 충전소만 `_stationsWithCoordinates`에 남기고, `_renderStationMarkers()`가 네이버 지도에 `NMarker`로 표시합니다.
5. 마커를 탭하면 `_showStationBottomSheet()`가 바텀시트로 상세 정보를 노출하며, 상단 배지와 로딩/에러 배너는 `_isLoadingStations`, `_stationError` 상태에 따라 자동으로 갱신됩니다.

---

문의나 개선 아이디어가 있다면 Issues나 Pull Request로 공유해주세요. 즐거운 개발 되세요! 🚀

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
| `lib/main.dart` | 파일 | 위젯 바인딩을 준비하고 `.env` → HTTP Override → `configureH2StationApi()` → 네이버 지도 & Kakao SDK 초기화 순으로 실행한 뒤 `MyApp`을 띄웁니다. |
| `lib/assets/` | 디렉터리 | 폰트(`assets/fonts`)와 웰컴 화면에서 사용하는 SVG/PNG 아이콘이 들어 있습니다. |
| `lib/auth/` | 디렉터리 | 인증 관련 헬퍼를 담는 공간으로, 현재는 토큰 스토리지가 핵심입니다. |
| `lib/auth/token_storage.dart` | 파일 (`TokenStorage`) | `flutter_secure_storage`를 감싸 access/refresh 토큰 저장·조회·삭제 메서드를 제공합니다. |
| `lib/services/` | 디렉터리 | 외부 API와 통신하는 서비스 계층입니다. |
| `lib/services/h2_station_api_service.dart` | 파일 (`H2StationApiService`) | 충전소 목록 API를 호출하고 성공 시 `H2Station` 리스트로 파싱합니다. |
| `lib/services/ev_station_api_service.dart` | 파일 | EV 충전소 연동을 위한 자리이며 아직 TODO로 남아 있습니다. |
| `lib/models/` | 디렉터리 | 화면 간 공유하는 데이터 모델 정의가 위치합니다. |
| `lib/models/h2_station.dart` | 파일 (`H2Station`) | 실시간(`realtime`)과 운영(`operation`) 정보를 합쳐 좌표·상태·통계 값을 안전하게 파싱합니다. |
| `lib/screens/` | 디렉터리 | 모든 Flutter 화면이 위치하며 지도, 정보, 신고 등 서브 화면을 포함합니다. |
| `lib/screens/welcom.dart` | 파일 (`WelcomeScreen`) | 카카오 로그인 UI와 `_handleKakaoLogin()` 로직을 담당해 성공 시 `MapScreen`으로 라우팅합니다. |
| `lib/screens/map.dart` | 파일 (`MapScreen`) | 네이버 지도를 렌더링하고 마커, 하단 내비게이션, 바텀시트, 로딩/에러 배너를 제어합니다. |
| `lib/screens/h2info_screen.dart` | 파일 (`InfoScreen`) | 리스트 형태로 충전소 세부 정보를 탐색할 수 있는 보조 화면입니다. |
| `test/widget_test.dart` | 파일 | Flutter 기본 Counter 예제 테스트가 남아 있으며 나중에 실제 위젯 테스트로 교체할 예정입니다. |

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
> 키가 비어 있으면 `lib/main.dart`의 `_resolveH2BaseUrl()`이 기본값(`https://clos21.kr`)을 사용하면서 콘솔에 경고를 남깁니다.
> Kakao 키(`KAKAO_NATIVE_APP_KEY`, `KAKAO_JAVASCRIPT_APP_KEY`)가 비어 있으면 앱이 Kakao SDK 초기화를 건너뛰고 웰컴 화면에서 경고를 표시하며 로그인 버튼을 막습니다.

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
1. `main()`이 `WidgetsFlutterBinding`을 초기화하고 `.env`를 로드한 뒤 `_configureHttpOverrides()`와 `configureH2StationApi(_resolveH2BaseUrl())`를 수행합니다.
2. 같은 함수에서 `_initializeNaverMap()`과 Kakao SDK 초기화를 끝내고 `.env` 키 상태(`isKakaoConfigured`)를 `MyApp`으로 전달해 앱을 실행합니다.
3. `WelcomeScreen`이 카카오 로그인을 시도하고 Clos21 백엔드와 토큰을 교환한 뒤 `TokenStorage`에 access/refresh 토큰을 저장합니다.
4. 로그인 성공 시 `MapScreen`으로 이동해 `_loadStations()`가 `h2StationApi.fetchStations()` 결과를 받아오고, 마커/배지/바텀시트를 갱신합니다.

---

## 8. 주요 함수 및 역할
- `lib/main.dart > main()` : 위젯 바인딩 준비 → `.env` 로드 → `_configureHttpOverrides()` → `configureH2StationApi()` → `_initializeNaverMap()` → `KakaoSdk.init()` → `runApp()` 순서로 앱을 띄웁니다.
- `lib/main.dart > _configureHttpOverrides()` : `H2_API_ALLOW_INSECURE_SSL` 값이 true/1/yes일 때만 자체 서명 인증서를 허용하도록 `HttpOverrides.global`을 교체합니다.
- `lib/main.dart > _resolveH2BaseUrl()` : `.env`에 값이 없으면 기본값 `https://clos21.kr`을 선택하고 경고 로그를 남깁니다.
- `lib/main.dart > _initializeNaverMap()` : `FlutterNaverMap().init()`을 호출해 클라이언트 ID 인증과 예외 처리를 담당합니다.
- `lib/services/h2_station_api_service.dart > H2StationApiService.fetchStations()` : `/mapi/h2/stations?type=all`을 호출해 JSON을 `H2Station` 리스트로 변환합니다.
- `lib/screens/welcom.dart > _handleKakaoLogin()` : 카카오 로그인 시도 → Clos21 백엔드 토큰 교환 → `TokenStorage.saveTokens()` → `MapScreen` 라우팅 흐름을 구현합니다.
- `lib/auth/token_storage.dart > TokenStorage` : `flutter_secure_storage` 기반으로 access/refresh 토큰 저장·조회·삭제 기능을 제공합니다.
- `lib/screens/map.dart > _loadStations()` : 로딩/에러 상태를 관리하며 최신 충전소 데이터를 가져옵니다.
- `lib/screens/map.dart > _renderStationMarkers()` : 좌표가 있는 충전소만 모아 네이버 지도에 마커/클러스터를 추가하고 터치 시 바텀시트를 엽니다.
- `lib/screens/map.dart > _showStationBottomSheet()` : 충전소 이름, 상태, 대기 차량, 최대 충전 가능 대수, 최종 갱신 시각을 표시하는 바텀시트를 렌더링합니다.

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

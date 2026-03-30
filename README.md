# 알비 (Albi)

**알코올 비서** — 자연어 한 줄 입력으로 음주 기록을 만드는 로컬 중심 앱

## 핵심 기능

- 자연어 입력 ("벤로막 15 두 잔 마셨어") → 구조화 기록 초안 자동 생성
- AI(Gemini) 연동 시 더 정확한 파싱, AI 없이도 로컬 파서로 동작
- 저장 전 반드시 검토/수정 화면 거침
- 마셔본 술 아카이브, 주종별 통계
- 위스키 48종 + 기타 주류 27종 시드 데이터 내장

## 기술 스택

| 항목 | 선택 |
|------|------|
| 프레임워크 | Flutter 3.41.6 (Dart 3.11.4) |
| 상태관리 | Riverpod (MVVM) |
| 로컬 DB | sqflite |
| AI | Gemini 2.5 Flash Lite / Flash (선택) |
| CI | GitHub Actions |

## 프로젝트 구조

```
lib/
├── views/           # 화면 (Screen + Widget)
├── viewmodels/      # 상태관리 (Riverpod Notifier)
├── domain/entities/ # 데이터 모델
├── data/            # Repository (DB 접근)
├── integrations/    # AI 파서, Gemini 클라이언트
└── core/            # DB 초기화, 테마, 유틸
```

## 실행

```bash
flutter pub get
flutter run
```

## 테스트

```bash
flutter test        # 33개 유닛 테스트
flutter analyze     # 정적 분석
```

## 화면 구성

| 화면 | 설명 |
|------|------|
| 온보딩 | 첫 실행 시 3장 안내 |
| 홈 | 자연어 입력 + 최근 기록 + 통계 카드 |
| 초안 검토 | 파서 결과 수정 + 저장 |
| 기록 목록 | 날짜순, 검색, 삭제 |
| 기록 상세 | 수정/삭제 |
| 마셔본 술 | 주종 필터, 즐겨찾기 |
| 통계 | 총 기록, 주종별 분포, TOP 5 |
| 설정 | AI 연결, 모델 선택, 사용량 |

## 팀

| 이름 | 역할 |
|------|------|
| 김태겸 | 기획, 파싱/DB, 기능 개발 |
| 곽지한 | 화면 설계, 디자인, UI 구현 |

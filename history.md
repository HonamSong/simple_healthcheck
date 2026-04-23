# Health Check Server - 작업 히스토리

> 이 파일은 이 프로젝트에서 수행한 모든 작업을 시간 역순으로 기록합니다.
> 새 작업을 시작하기 전에 반드시 이 파일을 읽어 컨텍스트를 파악합니다.
> 작업이 끝나면 최신 엔트리를 맨 위에 추가합니다.

## 형식

```
## [YYYY-MM-DD] 작업 제목

- **의도**: 왜 이 작업을 했는지
- **변경**: 어떤 파일을 어떻게 수정했는지
- **결과/검증**: 빌드/테스트/배포 결과
- **후속**: 다음에 이어서 할 일 (있다면)
```

---

## [2026-04-23] health-server → simple_healthcheck 디렉토리/레포 이관

- **의도**: 프로젝트를 GitHub 레포(HonamSong/simple_healthcheck)에 맞춰 디렉토리/모듈명 정비
- **변경**:
  - /Users/lt-131/tools/health-server → /Users/lt-131/tools/simple_healthcheck 로 파일 복사 (rsync, .git 제외)
  - 새 경로의 기본 README.md는 health-server에서 가져온 상세 README로 덮어씀
  - go.mod module: `health-server` → `github.com/HonamSong/simple_healthcheck`
  - Dockerfile 바이너리명: `health-server` → `simple_healthcheck` (3곳: go build -o / COPY --from / CMD)
  - build_push.sh의 IMAGE_NAME(`shutdown_health`)은 의도적으로 유지 — 기존 Artifact Registry 이미지 저장소 일관성 보호
- **결과/검증**: 파일 복사 및 편집 완료. 빌드 검증은 사용자 지시 대기
- **후속**: 기존 /Users/lt-131/tools/health-server 디렉토리는 새 경로에서 동작 확인 후 삭제 예정 (사용자 승인 대기)

---

## [2026-04-23] MIT 라이선스 확정 + LICENSE 파일 추가

- **의도**: 민감정보 없는 범용 유틸리티이므로 마찰 없는 MIT 라이선스 채택
- **변경**:
  - LICENSE 신규 생성 — 표준 MIT 텍스트, Copyright (c) 2026 DSRV Labs
  - README.md License 섹션에 LICENSE 파일 링크 + 저작권자 명시
- **결과/검증**: 파일 생성 완료. README 뱃지는 이미 MIT로 세팅되어 있어 동기화 OK
- **후속**: 없음 (라이선스 확정)

---

## [2026-04-23] README 작성 + shields.io 뱃지 추가

- **의도**: 프로젝트 개요, 엔드포인트, 환경변수, 시작 로그 포맷, 로컬/Docker/Cloud Run 배포 절차를 한 곳에 정리. 뱃지로 스택/플랫폼 한눈에 파악 가능하게 함
- **변경**:
  - README.md 신규 생성
  - 뱃지 6종: Go 1.22 / Alpine 3.19 / linux/amd64 / Cloud Run / port 8080 / MIT (shields.io 기반)
  - 섹션: Endpoints, Startup Log(JSON 예시), Environment Variables, Run Locally, Run with Docker, Deploy, Files, Design Notes, License
- **결과/검증**: 파일 생성만 수행. 뱃지 렌더링은 GitHub/렌더러 환경에서 확인 필요
- **후속**: 라이선스 최종 결정 후 LICENSE 파일 추가 + README 뱃지 갱신

---

## [2026-04-23] 시작 로그 JSON 출력 + Cloud Run 메타데이터 수집

- **의도**: 프로세스 기동 시 shutdown 이미지 식별용 JSON 로그를 stdout에 남기고, Cloud Run 환경에서 어느 서비스/리비전/리전에서 도는지 운영 로그에서 추적 가능하게 함
- **변경**: main.go
  - emitStartupLog(startedAt) 추가 — goroutine으로 비동기 실행 (HTTP 서버 시작은 블로킹하지 않음)
  - JSON 필드: timestamp(로그 찍힌 시각, UTC RFC3339Nano), msg("cloud run service shutdown, Only health Check image"), start_at(프로세스 시작 시각)
  - 환경변수 기반 필드: service=K_SERVICE, revision=K_REVISION, configuration=K_CONFIGURATION
  - 메타데이터 서버 조회(http://metadata.google.internal/computeMetadata/v1, 헤더 Metadata-Flavor: Google, 개별 요청 2s timeout, 전체 ctx 3s timeout)로 project_id, region, instance_id 수집
  - region 응답("projects/<NUM>/regions/<REGION>")에서 마지막 슬래시 뒤 토큰만 추출
  - PORT 환경변수 지원 추가 (없으면 기본 8080) — Cloud Run은 PORT를 주입함
- **결과/검증**: 파일 저장만 수행. 로컬 go build는 사용자 지시에 따라 생략. Docker 빌드/배포 시 실제 동작 확인 예정
- **후속**: 다음 배포(build_push.sh) 후 Cloud Run 로그 탐색기에서 startup 로그에 service/revision/project_id/region/instance_id가 정상 채워지는지 확인

---

## [2026-04-23] 작업 히스토리 추적 체계 도입

- **의도**: 세션 간 컨텍스트 유실을 막기 위해 작업 기록 파일과 프로젝트 CLAUDE.md 생성
- **변경**:
  - history.md 신규 생성 (본 파일)
  - CLAUDE.md 신규 생성 — 세션 시작 시 history.md 확인, 종료 시 업데이트 규칙 명시
- **결과/검증**: 파일 생성 완료
- **후속**: 이후 모든 작업은 이 파일에 엔트리 추가

---

## [이전 세션 요약] 초기 구축

> 별도 핸드오프 문서에서 이관된 내용. 원본 핸드오프 문서는 대화 로그 참조.

### 프로젝트 개요
- GCP Cloud Run shutdown 트리거용 Go 헬스체크 서버
- 포트 8080, 엔드포인트: GET /health, GET /api/health (동일 동작)
- 응답: 200 OK, application/json; charset=utf-8
  - 바디: {"status":"ok","dest":"shutdown, cloud run service"}
- Go 1.22, 표준 라이브러리만 사용 (외부 의존성 없음)

### 파일 구성
- main.go — HTTP 서버 본체
- go.mod — module health-server, go 1.22
- Dockerfile — 멀티스테이지 (golang:1.22-alpine → alpine:3.19), non-root user, HEALTHCHECK 포함
- build_push.sh — buildx 기반 크로스빌드(linux/amd64) + Artifact Registry 푸시
  (원본 핸드오프 문서에는 build-and-push.sh로 표기되어 있으나 실제 파일명은 build_push.sh)

### 배포 대상
- 레지스트리: asia-northeast3-docker.pkg.dev
- 프로젝트: portal-dev-490501
- 저장소: infra (Docker 포맷, asia-northeast3)
- 이미지 URI: asia-northeast3-docker.pkg.dev/portal-dev-490501/infra/shutdown_health:latest

### 주요 설계 결정
- 표준 라이브러리만 사용 → go.sum 불필요
- CGO_ENABLED=0 + alpine → 정적 바이너리, glibc 이슈 회피
- -ldflags="-s -w" → 디버그 심볼 제거로 바이너리 축소
- non-root 유저(app) → 컨테이너 보안 모범 사례
- docker buildx --platform linux/amd64 → 맥(ARM) → Ubuntu(x86_64) 크로스빌드
- --push 사용 → buildx는 로컬 저장 대신 바로 푸시가 효율적

### 이전 세션 진행 흐름
1. Go 서버 작성 (초기 응답: plain text "ok")
2. Dockerfile 멀티스테이지 빌드 작성
3. 맥 → Ubuntu 아키텍처 호환성 논의 → linux/amd64 크로스빌드 확정
4. Artifact Registry 푸시 스크립트 작성 (buildx + gcloud + 사전 점검)
5. 응답 포맷 plain text → JSON 변경: {"status":"ok","dest":"shutdown, cloud run service"}

### 향후 개선 후보
- Git SHA 태그 병행 ($(git rev-parse --short HEAD))
- CI 파이프라인 이관 (GitHub Actions / Cloud Build + WIF)
- distroless/static 또는 scratch 런타임 (단, wget 기반 HEALTHCHECK 대체 필요)
- /metrics (Prometheus), 구조화 로깅
- Graceful shutdown (http.Server + SIGTERM 핸들링)

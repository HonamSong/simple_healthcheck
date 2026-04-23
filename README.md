# health-server

![Go](https://img.shields.io/badge/Go-1.22-00ADD8?logo=go&logoColor=white)
![Container](https://img.shields.io/badge/Container-Alpine%203.19-0D597F?logo=alpinelinux&logoColor=white)
![Platform](https://img.shields.io/badge/platform-linux%2Famd64-lightgrey)
![Deploy](https://img.shields.io/badge/Deploy-Cloud%20Run-4285F4?logo=googlecloud&logoColor=white)
![Port](https://img.shields.io/badge/port-8080-brightgreen)
![License](https://img.shields.io/badge/license-MIT-green)

GCP Cloud Run 서비스의 **shutdown 트리거용 경량 헬스체크 서버**. 외부 의존성 없는 Go 표준 라이브러리 기반으로, Docker 이미지 ~10MB 수준의 정적 바이너리로 배포된다. 특정 Cloud Run 서비스를 종료(shutdown) 상태로 전환하기 위한 지정 이미지로 사용한다.

## Endpoints

| Method | Path          | Response                                                   |
|--------|---------------|------------------------------------------------------------|
| GET    | /health       | 200 `{"status":"ok","dest":"shutdown, cloud run service"}` |
| GET    | /api/health   | 동일                                                       |

응답 Content-Type: `application/json; charset=utf-8`

## Startup Log

프로세스 기동 시 stdout으로 JSON 한 줄을 출력한다. Cloud Run 메타데이터 서버에서 project_id / region / instance_id를 비동기로 조회해 포함하며, 조회 실패 시 해당 필드는 생략된다. 환경변수 K_SERVICE / K_REVISION / K_CONFIGURATION은 Cloud Run이 자동 주입한다.

```json
{
  "timestamp": "2026-04-23T02:31:05.123Z",
  "msg": "cloud run service shutdown, Only health Check image",
  "start_at": "2026-04-23T02:31:05.100Z",
  "service": "shutdown-health",
  "revision": "shutdown-health-00003-abc",
  "configuration": "shutdown-health",
  "project_id": "portal-dev-490501",
  "region": "asia-northeast3",
  "instance_id": "0000xxxx"
}
```

- `timestamp`: 로그가 emit된 시각 (UTC, RFC3339Nano)
- `start_at`: 프로세스가 main() 진입한 시각

## Environment Variables

| Variable          | Source         | Default | Purpose              |
|-------------------|----------------|---------|----------------------|
| PORT              | Cloud Run 주입 | 8080    | HTTP listen port     |
| K_SERVICE         | Cloud Run 주입 | -       | Cloud Run 서비스명   |
| K_REVISION        | Cloud Run 주입 | -       | Cloud Run 리비전명   |
| K_CONFIGURATION   | Cloud Run 주입 | -       | Cloud Run 구성명     |

## Run Locally

```bash
go run main.go
curl -s http://localhost:8080/health
curl -s http://localhost:8080/api/health
```

## Run with Docker

```bash
docker build -t health-server:latest .
docker run --rm -p 8080:8080 health-server:latest
```

## Deploy to Artifact Registry

**최초 1회 (인증 설정):**

```bash
gcloud auth login
gcloud config set project portal-dev-490501
gcloud auth configure-docker asia-northeast3-docker.pkg.dev
```

**매 배포:**

```bash
./build_push.sh
```

**이미지 URI:**

```
asia-northeast3-docker.pkg.dev/portal-dev-490501/infra/shutdown_health:latest
```

Cloud Run 리비전에 동일 태그(`:latest`)를 재사용할 경우 트래픽 전환을 위해 수동 재배포가 필요할 수 있다:

```bash
gcloud run deploy <SERVICE_NAME> \
  --image asia-northeast3-docker.pkg.dev/portal-dev-490501/infra/shutdown_health:latest \
  --region asia-northeast3
```

## Files

| File          | Purpose                                                           |
|---------------|-------------------------------------------------------------------|
| main.go       | HTTP 서버 본체 + startup 로그 + Cloud Run 메타데이터 조회         |
| go.mod        | Go 1.22, 외부 의존성 없음                                         |
| Dockerfile    | 멀티스테이지 (golang:1.22-alpine → alpine:3.19), non-root user   |
| build_push.sh | buildx 크로스빌드(linux/amd64) + Artifact Registry push + 검증    |
| history.md    | 작업 히스토리 기록                                                |
| CLAUDE.md     | 세션 작업 규칙 (히스토리 관리)                                    |

## Design Notes

- **표준 라이브러리만 사용** — go.sum 불필요, 빌드 단순화
- **CGO_ENABLED=0 + Alpine** — 정적 바이너리, glibc 호환성 이슈 회피
- **-ldflags="-s -w"** — 디버그 심볼 제거로 바이너리 축소
- **non-root user (app)** — 컨테이너 보안 모범 사례
- **buildx linux/amd64** — 맥(ARM) → Ubuntu(x86_64) 크로스빌드
- **비동기 startup log** — 메타데이터 조회 지연이 서버 기동을 블로킹하지 않도록 goroutine에서 출력

## License

MIT — see [LICENSE](./LICENSE). Copyright (c) 2026 DSRV Labs.

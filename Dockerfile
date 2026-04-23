# ---------- Build Stage ----------
FROM golang:1.22-alpine AS builder

WORKDIR /app

# 의존성 먼저 복사 (레이어 캐싱 최적화)
COPY go.mod ./
RUN go mod download

# 소스 복사 후 빌드
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o simple_healthcheck .

# ---------- Runtime Stage ----------
FROM alpine:3.19

# 보안: non-root 사용자 생성
RUN addgroup -S app && adduser -S app -G app

WORKDIR /app
COPY --from=builder /app/simple_healthcheck .

USER app
EXPOSE 8080

# 컨테이너 헬스체크 (선택사항이지만 유용)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["./simple_healthcheck"]


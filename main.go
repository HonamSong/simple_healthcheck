package main

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

const metadataBase = "http://metadata.google.internal/computeMetadata/v1"

type healthResponse struct {
	Status string `json:"status"`
	Dest   string `json:"dest"`
}

type startupLog struct {
	Timestamp     string `json:"timestamp"`
	Msg           string `json:"msg"`
	StartAt       string `json:"start_at"`
	Service       string `json:"service,omitempty"`
	Revision      string `json:"revision,omitempty"`
	Configuration string `json:"configuration,omitempty"`
	ProjectID     string `json:"project_id,omitempty"`
	Region        string `json:"region,omitempty"`
	InstanceID    string `json:"instance_id,omitempty"`
}

func fetchMetadata(ctx context.Context, path string) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, metadataBase+path, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("Metadata-Flavor", "Google")

	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ""
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(body))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	resp := healthResponse{
		Status: "ok",
		Dest:   "shutdown, cloud run service",
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusOK)

	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("encode error: %v", err)
	}
}

func emitStartupLog(startedAt time.Time) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	projectID := fetchMetadata(ctx, "/project/project-id")

	// /instance/region 응답 형식: "projects/<NUMBER>/regions/<REGION>" — region만 추출
	region := fetchMetadata(ctx, "/instance/region")
	if idx := strings.LastIndex(region, "/"); idx >= 0 {
		region = region[idx+1:]
	}

	instanceID := fetchMetadata(ctx, "/instance/id")

	entry := startupLog{
		Timestamp:     time.Now().UTC().Format(time.RFC3339Nano),
		Msg:           "cloud run service shutdown, Only health Check image",
		StartAt:       startedAt.UTC().Format(time.RFC3339Nano),
		Service:       os.Getenv("K_SERVICE"),
		Revision:      os.Getenv("K_REVISION"),
		Configuration: os.Getenv("K_CONFIGURATION"),
		ProjectID:     projectID,
		Region:        region,
		InstanceID:    instanceID,
	}

	b, err := json.Marshal(entry)
	if err != nil {
		log.Printf("startup log marshal error: %v", err)
		return
	}
	os.Stdout.Write(append(b, '\n'))
}

func main() {
	startedAt := time.Now()

	go emitStartupLog(startedAt)

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/api/health", healthHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	addr := ":" + port

	log.Printf("Server listening on %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

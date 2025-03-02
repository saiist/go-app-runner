package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	// ポート番号を環境変数から取得（App Runner対応）
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080" // デフォルトポート
	}

	// ルートパスのハンドラを登録
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello, AWS App Runner from Go!")
	})

	// ヘルスチェック用エンドポイント
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	log.Printf("Server starting on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

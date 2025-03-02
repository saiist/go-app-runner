.PHONY: build run test clean deps docker-build docker-push tf-init tf-plan tf-apply tf-destroy tf-show

# Go 関連コマンド
build:
	go build -o app main.go

run:
	go run main.go

test:
	go test -v ./...

clean:
	rm -f app
	go clean

deps:
	go mod download

# Docker 関連コマンド
docker-build:
	docker build -t go-app-runner .

docker-push: docker-build
	@echo "ECR リポジトリ URL を指定してください"
	@read -p "ECR URL: " ECR_URL; \
	docker tag go-app-runner:latest $$ECR_URL:latest && \
	aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin $$ECR_URL && \
	docker push $$ECR_URL:latest

# Terraform 関連コマンド
tf-init:
	cd ./ && terraform init

tf-plan:
	cd ./ && terraform plan

tf-apply:
	cd ./ && terraform apply

tf-destroy:
	cd ./ && terraform destroy

tf-show:
	cd ./ && terraform show

# ヘルプ
help:
	@echo "利用可能なコマンド:"
	@echo "  make build         - Goアプリケーションをビルド"
	@echo "  make run           - ローカルでアプリケーションを実行"
	@echo "  make test          - テストを実行"
	@echo "  make clean         - ビルド成果物を削除"
	@echo "  make deps          - 依存関係をダウンロード"
	@echo "  make docker-build  - Dockerイメージをビルド"
	@echo "  make docker-push   - ECRにDockerイメージをプッシュ"
	@echo "  make tf-init       - Terraformを初期化"
	@echo "  make tf-plan       - 変更計画を表示"
	@echo "  make tf-apply      - インフラストラクチャを適用"
	@echo "  make tf-destroy    - インフラストラクチャを削除"
	@echo "  make tf-show       - 現在の状態を表示"

# デフォルトターゲット
.DEFAULT_GOAL := help

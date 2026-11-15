.PHONY: build start stop test clean

build:
	lake build

start: build
	pkill -f lean-worker || true
	nohup lake exe lean-worker > /tmp/lean-worker.log 2>&1 &
	@echo "Server running on http://127.0.0.1:8080"

stop:
	pkill -f lean-worker || true

test: start
	./test.sh

clean:
	lake clean
	rm -rf data/*.json

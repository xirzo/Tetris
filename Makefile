.DEFAULT_GOAL := run-hotreload

.PHONY: build-release build-hotreload run-hotreload clean
 
COLLECTIONS = -collection:game=.
OUTPUT_NAME = x86_64-linux-minecraft

build-release:
	odin build cmd/release -out:$(OUTPUT_NAME) $(COLLECTIONS)

build-hotreload:
	odin build cmd/hotreload -out:$(OUTPUT_NAME) $(COLLECTIONS) -define:RAYLIB_SHARED=true

run-hotreload:
	odin run cmd/hotreload $(COLLECTIONS) -define:RAYLIB_SHARED=true

clean:
	rm $(OUTPUT_NAME)

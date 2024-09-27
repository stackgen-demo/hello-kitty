build:
	rm -rf build
	mkdir build
	zip build/app.zip main.py index.html

.PHONY: build

# Whine - a mosquito's bloodline for Playdate.
#
#   make            release build -> out/Whine.pdx
#   make smoke      instrumented build -> out/WhineSmoke.pdx
#
# Staging copies source/* into build/<variant>/source and writes the generated
# smokeflag.lua (pdc wants one source root).

OUT := out

all: release

release: build/release/source
	pdc build/release/source $(OUT)/Whine.pdx

smoke: build/smoke/source
	pdc build/smoke/source $(OUT)/WhineSmoke.pdx

build/release/source: source/*
	mkdir -p $@ $(OUT)
	cp -r source/* $@/
	echo 'SMOKE_BUILD = false' > $@/smokeflag.lua

build/smoke/source: source/*
	mkdir -p $@ $(OUT)
	cp -r source/* $@/
	echo 'SMOKE_BUILD = true' > $@/smokeflag.lua
	echo 'SHOT_PATH = "$(CURDIR)/build/whine-shot.png"' >> $@/smokeflag.lua

clean:
	rm -rf build $(OUT)

.PHONY: all release smoke clean

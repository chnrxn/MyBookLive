ALL := .git configure Makefile build

all: $(foreach S,$(ALL),crosstool-ng/$S)
	(cd crosstool-ng; make install)

crosstool-ng/Makefile:
	(cd crosstool-ng; ./configure)

crosstool-ng/configure:
	(cd crosstool-ng; ./bootstrap)

crosstool-ng/build:
	mkdir -p $@

crosstool-ng/.git:
	git clone https://github.com/crosstool-ng/crosstool-ng

pull: crosstool-ng/.git
	(cd crosstool-ng; git pull)

clean: crosstool-ng/.git
	(cd crosstool-ng; git clean -xfd)

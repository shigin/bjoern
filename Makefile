SOURCE_DIR	= bjoern
BUILD_DIR	= build
objects		= $(patsubst $(SOURCE_DIR)/%.c, $(BUILD_DIR)/%.o, \
		             $(wildcard $(SOURCE_DIR)/*.c))

PYTHON_INCLUDE	= $(shell python-config --include)
PYTHON_LDFLAGS	= $(shell python-config --ldflags)

HTTP_PARSER_DIR	= http-parser
HTTP_PARSER_OBJ = $(HTTP_PARSER_DIR)/http_parser.o
HTTP_PARSER_SRC = $(HTTP_PARSER_DIR)/http_parser.c

CPPFLAGS	+= $(PYTHON_INCLUDE) -I . -I $(SOURCE_DIR) -I $(HTTP_PARSER_DIR)
CFLAGS		+= $(FEATURES) -std=c99 -fno-strict-aliasing -Wall -Wextra \
		   -Wno-unused -g -O3 -fPIC
LDFLAGS		+= $(PYTHON_LDFLAGS) -l ev -shared --as-needed

ifneq ($(WANT_SENDFILE), no)
FEATURES	+= -D WANT_SENDFILE
endif

ifneq ($(WANT_SIGINT_HANDLING), no)
FEATURES	+= -D WANT_SIGINT_HANDLING
endif

all: prepare-build $(objects) bjoernmodule

print-env:
	@echo CFLAGS=$(CFLAGS)
	@echo CPPFLAGS=$(CPPFLAGS)
	@echo LDFLAGS=$(LDFLAGS)
	@echo args=$(HTTP_PARSER_SRC) $(wildcard $(SOURCE_DIR)/*.c)

opt: clean
	CFLAGS='-O3' make

small: clean
	CFLAGS='-Os' make

bjoernmodule:
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(objects) $(HTTP_PARSER_OBJ) -o $(BUILD_DIR)/bjoern.so
	PYTHONPATH=$$PYTHONPATH:$(BUILD_DIR) python -c "import bjoern"

again: clean all

debug:
	CFLAGS='-D DEBUG' make again

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# foo.o: shortcut to $(BUILD_DIR)/foo.o
%.o: $(BUILD_DIR)/%.o


prepare-build:
	mkdir -p $(BUILD_DIR)

clean:
	rm -f $(BUILD_DIR)/*

ab:
	ab -c 100 -n 10000 'http://127.0.0.1:8080/a/b/c?k=v&k2=v2#fragment'

wget:
	wget -O - -q -S 'http://127.0.0.1:8080/a/b/c?k=v&k2=v2#fragment'

test:
	cd tests && python ~/dev/wsgitest/runner.py

valgrind:
	valgrind --leak-check=full --show-reachable=yes python tests/hello.py

callgrind:
	valgrind --tool=callgrind python tests/wsgitest-round-robin.py

memwatch:
	watch -n 0.5 \
	  'cat /proc/$$(pidof -s python)/cmdline | tr "\0" " " | head -c -1; \
	   echo; echo; \
	   tail -n +25 /proc/$$(pidof -s python)/smaps'

release:
	python setup.py sdist

upload:
	python setup.py sdist upload

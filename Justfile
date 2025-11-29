help:
    just --list

# Build a WASM release
build-wasm:
    #!/bin/sh
    TMPDIR=$(mktemp -d)

    godot --headless --export-release "Web" "$TMPDIR/index.html"

    # Check that the output file exists
    if [ ! -f "$TMPDIR/index.html" ]; then
        echo "WASM build failed: index.html not found" >&2
        echo "Have you installed the Web export template in Godot?" >&2
        exit 1
    fi
    echo "WASM export built in $TMPDIR."

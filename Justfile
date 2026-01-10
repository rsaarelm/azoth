repo := env_var_or_default('REPO', 'git@github.com:${USER}/azoth/')

help:
    just --list

# Build a WASM release
build-wasm:
    #!/bin/sh

    rm -rf wasm/
    mkdir -p wasm/

    godot --headless --export-release "Web" "wasm/index.html"

    # Check that the output file exists
    if [ ! -f "wasm/index.html" ]; then
        echo "WASM build failed: index.html not found" >&2
        echo "Have you installed the Web export template in Godot?" >&2
        exit 1
    fi
    echo "WASM export built in wasm/."

run-wasm: build-wasm
    #!/bin/sh

    cd wasm/
    # Fill in a caddyfile
    cat <<EOF > Caddyfile
    http://localhost:8080 {
        root * .
        file_server
    }
    EOF
    caddy run

publish: build-wasm
    #!/bin/sh

    DIR=$(mktemp -d)
    cp -r wasm/* $DIR/
    pushd $DIR/
    git init --initial-branch=gh-pages
    git add .
    git commit -m "Generated WASM export"

    read -p "About to overwrite gh-pages at {{repo}} with built WASM export, proceed? [y/n] " -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push --force {{repo}} gh-pages
    else
        echo "Aborted."
    fi
    popd
    rm -rf $DIR/

remove-save:
    rm ~/.local/share/godot/app_userdata/Azoth/savegame.json

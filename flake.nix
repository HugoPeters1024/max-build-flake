{
  description = "Eclipse Platform Releng Aggregator development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        # Use Java 24 (or latest available)
        jdk = pkgs.jdk;

        # Source derivation
        # Clone the aggregator repo with submodules enabled
        source = pkgs.fetchFromGitHub {
          owner = "maxeler";
          repo = "eclipse.platform.releng.aggregator";
          rev = "e7f40bf9ae1bb249802b16529172ccf3e0dc6357";
          sha256 = "sha256-3w6sp7zpcA7t4CVKaiVGwqBbXfCqGsVJ4FHr38j176o=";
          fetchSubmodules = true;
        };

        # ECJ build derivation
        ecj = pkgs.stdenv.mkDerivation {
          pname = "eclipse-ecj";
          version = "3.42.0-SNAPSHOT";

          src = source;

          nativeBuildInputs = with pkgs; [
            jdk
            maven
            git
            which
          ];

          # Set up environment variables
          preBuild = ''
            export JAVA_HOME=${jdk}
            export PATH="$JAVA_HOME/bin:$PATH"
            export MAVEN_OPTS="-Xmx2G"
            export WORKSPACE=$PWD
            export M2_REPO=$WORKSPACE/.m2/repository

            # Create minimal git repositories for Tycho build qualifier
            # Tycho searches upwards from project directories, so we create repos
            # at the root and in eclipse.jdt.core (where org.eclipse.jdt.core.compiler.batch is)
            # Using empty commits avoids the slow 'git add .' operation
            echo "Creating minimal git repositories for Tycho..."
            git init
            git config user.email "build@nix"
            git config user.name "Nix Build"
            git commit --allow-empty -m "Initial commit for Nix build" || true

            # Create git repo in eclipse.jdt.core (Tycho checks this directory)
            if [ -d "eclipse.jdt.core" ] && [ ! -d "eclipse.jdt.core/.git" ]; then
              (cd eclipse.jdt.core && \
               git init && \
               git config user.email "build@nix" && \
               git config user.name "Nix Build" && \
               git commit --allow-empty -m "Initial commit" || true)
            fi
          '';

          buildPhase = ''
            runHook preBuild

            echo "Building ECJ..."
            mvn clean install \
              -pl :eclipse-sdk-prereqs,:org.eclipse.jdt.core.compiler.batch \
              -DlocalEcjVersion=99.99 \
              -Dmaven.repo.local=$M2_REPO \
              -U \
              -DskipTests=true
          '';

          installPhase = ''
            runHook preInstall

            # Find the ECJ jar file
            ECJ_JAR=$(find eclipse.jdt.core/org.eclipse.jdt.core.compiler.batch/target \
              -name "org.eclipse.jdt.core.compiler.batch-*-SNAPSHOT.jar" | head -1)

            if [ -z "$ECJ_JAR" ]; then
              echo "Error: ECJ jar not found!"
              exit 1
            fi

            echo "Found ECJ jar: $ECJ_JAR"

            # Install the jar
            mkdir -p $out/lib
            cp $ECJ_JAR $out/lib/ecj.jar

            # Also install to a versioned path for reference
            mkdir -p $out/share/eclipse-ecj
            cp $ECJ_JAR $out/share/eclipse-ecj/

            # Create a symlink for convenience
            ln -s $out/lib/ecj.jar $out/ecj.jar

            runHook postInstall
          '';

          # Don't fail if submodules aren't initialized (for local builds)
          dontFixup = true;
        };

        # Map Nix system to Eclipse native property format
        # Format: ws.os.arch (e.g., cocoa.macosx.aarch64)
        nativeProperty = {
          "aarch64-darwin" = "cocoa.macosx.aarch64";
          "x86_64-darwin" = "cocoa.macosx.x86_64";
          "x86_64-linux" = "gtk.linux.x86_64";
          "aarch64-linux" = "gtk.linux.aarch64";
        }.${system} or "gtk.linux.x86_64";

        # Eclipse build derivation
        eclipse = pkgs.stdenv.mkDerivation {
          pname = "eclipse-platform";
          version = "4.36.0-SNAPSHOT";
          cores = 24;

          src = source;

          # Depend on ECJ build - this ensures ECJ is built first
          # and makes the ECJ path available in the build
          buildInputs = [ ecj ];

          nativeBuildInputs = with pkgs; [
            jdk
            maven
            git
            gnumake
            # SWT native build requires C compiler
            clang
            which
          ];

          preBuild = ''
            export JAVA_HOME=${jdk}
            export PATH="$JAVA_HOME/bin:$PATH"
            export MAVEN_OPTS="-Xmx2G"
            export WORKSPACE=$PWD
            export M2_REPO=$WORKSPACE/.m2/repository

            # Create minimal git repositories for Tycho build qualifier
            # Tycho searches upwards from project directories, so we create repos
            # at the root and in eclipse.jdt.core (where org.eclipse.jdt.core.compiler.batch is)
            # Using empty commits avoids the slow 'git add .' operation
            echo "Creating minimal git repositories for Tycho..."
            git init
            git config user.email "build@nix"
            git config user.name "Nix Build"
            git commit --allow-empty -m "Initial commit for Nix build" || true

            # Create git repo in eclipse.jdt.core (Tycho checks this directory)
            if [ -d "eclipse.jdt.core" ] && [ ! -d "eclipse.jdt.core/.git" ]; then
              (cd eclipse.jdt.core && \
               git init && \
               git config user.email "build@nix" && \
               git config user.name "Nix Build" && \
               git commit --allow-empty -m "Initial commit" || true)
            fi

            # Install ECJ with the correct Maven coordinates for Tycho
            # Tycho compiler plugin needs org.eclipse.jdt:ecj:99.99
            ECJ_PATH="${ecj}/lib/ecj.jar"
            if [ -f "$ECJ_PATH" ]; then
              echo "Installing ECJ to Maven repository with coordinates org.eclipse.jdt:ecj:99.99"
              # Install as org.eclipse.jdt:ecj:99.99 (required by Tycho compiler plugin)
              mkdir -p $M2_REPO/org/eclipse/jdt/ecj/99.99
              cp "$ECJ_PATH" $M2_REPO/org/eclipse/jdt/ecj/99.99/ecj-99.99.jar

              # Also create the POM file for this artifact
              cat > $M2_REPO/org/eclipse/jdt/ecj/99.99/ecj-99.99.pom <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>org.eclipse.jdt</groupId>
  <artifactId>ecj</artifactId>
  <version>99.99</version>
  <packaging>jar</packaging>
</project>
EOF

              # Also install with the original coordinates for compatibility
              mkdir -p $M2_REPO/org/eclipse/jdt/org.eclipse.jdt.core.compiler.batch/3.42.0-SNAPSHOT
              cp "$ECJ_PATH" $M2_REPO/org/eclipse/jdt/org.eclipse.jdt.core.compiler.batch/3.42.0-SNAPSHOT/org.eclipse.jdt.core.compiler.batch-3.42.0-SNAPSHOT.jar
            else
              echo "Error: ECJ not found at $ECJ_PATH"
              echo "Building ECJ first..."
              mvn clean install \
                -pl :eclipse-sdk-prereqs,:org.eclipse.jdt.core.compiler.batch \
                -DlocalEcjVersion=99.99 \
                -Dmaven.repo.local=$M2_REPO \
                -U \
                -DskipTests=true
            fi
          '';

          buildPhase = ''
            runHook preBuild

            echo "Building Eclipse Platform..."
            # Set native property to enable SWT native build
            # Tycho automatically sets ws, os, arch from build.properties in each fragment
            # Native property format: ws.os.arch (e.g., cocoa.macosx.aarch64)
            echo "Building for system: ${pkgs.stdenv.hostPlatform.system}"
            echo "Using native property: ${nativeProperty}"
            # Use single-threaded build to avoid ConcurrentModificationException in Tycho
            # The validate-classpath goal has concurrency issues with parallel builds
            mvn clean verify \
              -e \
              -Dmaven.repo.local=$M2_REPO \
              -T 1 \
              -DskipTests=true \
              -Dcompare-version-with-baselines.skip=true \
              -DapiBaselineTargetDirectory=$WORKSPACE \
              -Dcbi-ecj-version=99.99 \
              -Dtycho.disableP2Mirrors=true \
              -Dnative=${nativeProperty} \
              -U

            echo "Building JDTLS product (for VSCode patcher)..."
            # Build JDTLS product now that platform repository is available
            # Skip test compilation to avoid compilation errors in test code
            mvn clean install \
              -pl eclipse.jdt.ls/org.eclipse.jdt.ls.product \
              -Dmaven.repo.local=$M2_REPO \
              -Dcbi-ecj-version=99.99 \
              -Dtycho.disableP2Mirrors=true \
              -DskipTests=true \
              -Dmaven.test.skip=true \
              -U || echo "JDTLS product build had issues, continuing..."
          '';


          installPhase = ''
            runHook preInstall

            # Find the distribution builds
            DIST_DIR=eclipse.platform.releng.tychoeclipsebuilder/eclipse.platform.repository/target/products

            if [ ! -d "$DIST_DIR" ]; then
              echo "Error: Distribution directory not found: $DIST_DIR"
              exit 1
            fi

            echo "Installing Eclipse distributions..."
            mkdir -p $out/distributions
            cp -r $DIST_DIR/* $out/distributions/

            # Create symlinks for the most relevant distributions
            if [ -f "$out/distributions/org.eclipse.sdk.ide-macosx.cocoa.aarch64.tar.gz" ]; then
              ln -s $out/distributions/org.eclipse.sdk.ide-macosx.cocoa.aarch64.tar.gz \
                $out/eclipse-sdk-macos-aarch64.tar.gz
            fi

            if [ -f "$out/distributions/org.eclipse.sdk.ide-linux.gtk.x86_64.tar.gz" ]; then
              ln -s $out/distributions/org.eclipse.sdk.ide-linux.gtk.x86_64.tar.gz \
                $out/eclipse-sdk-linux-x86_64.tar.gz
            fi

            # Install JDTLS repository if it was built
            JDTLS_REPO_DIR="eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository"
            if [ -d "$JDTLS_REPO_DIR" ]; then
              echo "Installing JDTLS repository..."
              # Copy full repository for jdtls binary
              mkdir -p $out/jdtls-repository
              cp -r $JDTLS_REPO_DIR/* $out/jdtls-repository/

              # Also copy plugins separately for backward compatibility with jdtlsPatcher
              JDTLS_PLUGINS_DIR="$JDTLS_REPO_DIR/plugins"
              if [ -d "$JDTLS_PLUGINS_DIR" ]; then
                mkdir -p $out/jdtls-plugins
                cp -r $JDTLS_PLUGINS_DIR/* $out/jdtls-plugins/
              fi
            else
              echo "Warning: JDTLS repository directory not found, skipping..."
            fi

            runHook postInstall
          '';

          # Don't fail if submodules aren't initialized (for local builds)
          dontFixup = true;
        };

        # JDTLS patcher derivation
        # This package extracts the JDTLS plugins from the eclipse build
        # and creates universal scripts to patch VSCode's or Cursor's Java extension
        # Shared derivation that creates both binaries
        jdtlsPatcher = pkgs.stdenv.mkDerivation {
          pname = "jdtls-patcher";
          version = "1.0.0";

          # Depend on eclipse build - it already builds JDTLS plugins
          buildInputs = [ eclipse ];

          # No build needed - we just extract from eclipse's output
          dontUnpack = true;

          installPhase = ''
            runHook preInstall

            # Extract JDTLS plugins from eclipse build output
            PLUGINS_SOURCE="${eclipse}/jdtls-plugins"

            if [ ! -d "$PLUGINS_SOURCE" ] || [ -z "$(ls -A $PLUGINS_SOURCE 2>/dev/null)" ]; then
              echo "Error: JDTLS plugins not found in eclipse build output: $PLUGINS_SOURCE"
              echo "The eclipse build may not have successfully built JDTLS."
              echo "Available in eclipse output:"
              ls -la "${eclipse}" || true
              exit 1
            fi

            echo "Found JDTLS plugins in eclipse build: $PLUGINS_SOURCE"

            # Copy plugins to output
            mkdir -p $out/plugins
            cp -r $PLUGINS_SOURCE/* $out/plugins/

            # Create a function to generate the patching script for a specific editor
            # Parameters: editor_name, editor_dirs (space-separated), editor_display_name
            generate_patch_script() {
              local editor_name="$1"
              local editor_dirs="$2"
              local editor_display_name="$3"
              local script_name="$4"

              cat > $out/bin/$script_name <<SCRIPT_EOF
#!/usr/bin/env bash
# Replace ''${editor_display_name}'s JDTLS plugins with custom patched versions
# This replaces the actual JDTLS server files in the extension directory

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get the plugins directory from the nix store
# This script is installed in \$out/bin, so plugins are at \$out/plugins
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
PLUGINS_DIR="\$(cd "\$SCRIPT_DIR/../plugins" && pwd)"

echo -e "\''${BLUE}=== Replacing JDTLS Plugins in ''${editor_display_name} Extension ===\''${NC}\n"

# Check if custom plugins exist
if [ ! -d "\''${PLUGINS_DIR}" ]; then
    echo -e "\''${RED}Error: Custom JDTLS plugins not found at \''${PLUGINS_DIR}\''${NC}"
    exit 1
fi

# Find ''${editor_display_name} extension directory dynamically
# Try common locations for different operating systems
EDITOR_PLUGINS_DIR=""
EDITOR_EXT_DIR=""

if [[ "\$OSTYPE" == "darwin"* ]]; then
    # macOS
    for ext_base in ''${editor_dirs}; do
        if [ -d "\$ext_base" ]; then
            java_exts=\$(find "\$ext_base" -maxdepth 1 -type d -name "redhat.java-*" 2>/dev/null | head -1)
            if [ -n "\$java_exts" ]; then
                potential_plugins="\$java_exts/server/plugins"
                if [ -d "\$potential_plugins" ]; then
                    EDITOR_PLUGINS_DIR="\$potential_plugins"
                    EDITOR_EXT_DIR="\$java_exts"
                    break
                fi
            fi
        fi
    done
elif [[ "\$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    for ext_base in ''${editor_dirs}; do
        if [ -d "\$ext_base" ]; then
            java_exts=\$(find "\$ext_base" -maxdepth 1 -type d -name "redhat.java-*" 2>/dev/null | head -1)
            if [ -n "\$java_exts" ]; then
                potential_plugins="\$java_exts/server/plugins"
                if [ -d "\$potential_plugins" ]; then
                    EDITOR_PLUGINS_DIR="\$potential_plugins"
                    EDITOR_EXT_DIR="\$java_exts"
                    break
                fi
            fi
        fi
    done
elif [[ "\$OSTYPE" == "msys" || "\$OSTYPE" == "cygwin" || "\$OSTYPE" == "win32" ]]; then
    # Windows
    for ext_base in ''${editor_dirs}; do
        if [ -d "\$ext_base" ]; then
            java_exts=\$(find "\$ext_base" -maxdepth 1 -type d -name "redhat.java-*" 2>/dev/null | head -1)
            if [ -n "\$java_exts" ]; then
                potential_plugins="\$java_exts/server/plugins"
                if [ -d "\$potential_plugins" ]; then
                    EDITOR_PLUGINS_DIR="\$potential_plugins"
                    EDITOR_EXT_DIR="\$java_exts"
                    break
                fi
            fi
        fi
    done
fi

# If not found, try to find it more broadly
if [ -z "\$EDITOR_PLUGINS_DIR" ]; then
    # Search more broadly for redhat.java extensions
    for search_dir in ''${editor_dirs}; do
        if [ -d "\$search_dir" ]; then
            found_ext=\$(find "\$search_dir" -type d -path "*/redhat.java-*/server/plugins" 2>/dev/null | head -1)
            if [ -n "\$found_ext" ]; then
                EDITOR_PLUGINS_DIR="\$found_ext"
                EDITOR_EXT_DIR=\$(dirname "\$(dirname "\$found_ext")")
                break
            fi
        fi
    done
fi

if [ -z "\''${EDITOR_PLUGINS_DIR}" ]; then
    echo -e "\''${RED}Error: ''${editor_display_name} Java extension not found\''${NC}"
    echo "Please install 'Extension Pack for Java' in ''${editor_display_name}"
    echo ""
    echo "Searched in common ''${editor_display_name} extension directories."
    exit 1
fi

echo -e "\''${GREEN}✓ Custom plugins found: \''${PLUGINS_DIR}\''${NC}"
echo -e "\''${GREEN}✓ ''${editor_display_name} extension found: \''${EDITOR_EXT_DIR}\''${NC}"
echo -e "\''${GREEN}✓ Plugins directory: \''${EDITOR_PLUGINS_DIR}\''${NC}\n"

# Create backup
BACKUP_DIR="\''${EDITOR_PLUGINS_DIR}.backup.\$(date +%Y%m%d_%H%M%S)"
if [ ! -d "\''${EDITOR_PLUGINS_DIR}.backup" ]; then
    echo -e "\''${BLUE}Creating backup of original plugins...\''${NC}"
    cp -r "\''${EDITOR_PLUGINS_DIR}" "\''${BACKUP_DIR}"
    echo -e "\''${GREEN}✓ Backup created: \''${BACKUP_DIR}\''${NC}\n"
fi

# Find all org.eclipse.jdt.core* plugins in custom build
CUSTOM_CORE_PLUGINS=\$(find "\''${PLUGINS_DIR}" -name "org.eclipse.jdt.core*.jar" -type f)

if [ -z "\''${CUSTOM_CORE_PLUGINS}" ]; then
    echo -e "\''${RED}Error: No org.eclipse.jdt.core plugins found in custom build\''${NC}"
    exit 1
fi

echo -e "\''${BLUE}Replacing JDTLS core plugins...\''${NC}"

# Replace each plugin by matching base name (ignoring version)
for custom_plugin in \''${CUSTOM_CORE_PLUGINS}; do
    # Extract plugin prefix (e.g., "org.eclipse.jdt.core" from "org.eclipse.jdt.core_3.42.0.v20250606-1600.jar")
    plugin_prefix=\$(basename "\''${custom_plugin}" | sed 's/_[0-9].*//')

    # Find matching plugin in ''${editor_display_name} extension by prefix
    editor_plugin=\$(find "\''${EDITOR_PLUGINS_DIR}" -name "\''${plugin_prefix}_*.jar" | head -1)

    if [ -n "\''${editor_plugin}" ]; then
        editor_name=\$(basename "\''${editor_plugin}")
        custom_name=\$(basename "\''${custom_plugin}")
        echo "  Replacing: \''${editor_name}"
        echo "    With:     \''${custom_name}"
        # Backup original
        if [ ! -f "\''${editor_plugin}.orig" ]; then
            cp "\''${editor_plugin}" "\''${editor_plugin}.orig"
        fi
        # Replace with custom version (keep ''${editor_display_name}'s filename to maintain references)
        cp "\''${custom_plugin}" "\''${editor_plugin}"
        echo -e "    \''${GREEN}✓ Replaced\''${NC}"
    else
        echo -e "  \''${YELLOW}Warning: No matching plugin found for \''${plugin_prefix}\''${NC}"
    fi
done

# Also replace the main JDTLS launcher and other critical plugins
echo ""
echo -e "\''${BLUE}Replacing other critical JDTLS plugins...\''${NC}"

# Replace org.eclipse.jdt.ls.core if it exists
CUSTOM_LS_CORE=\$(find "\''${PLUGINS_DIR}" -name "org.eclipse.jdt.ls.core*.jar" | head -1)
if [ -n "\''${CUSTOM_LS_CORE}" ]; then
    EDITOR_LS_CORE=\$(find "\''${EDITOR_PLUGINS_DIR}" -name "org.eclipse.jdt.ls.core*.jar" | head -1)
    if [ -n "\''${EDITOR_LS_CORE}" ]; then
        echo "  Replacing: \$(basename "\''${EDITOR_LS_CORE}")"
        if [ ! -f "\''${EDITOR_LS_CORE}.orig" ]; then
            cp "\''${EDITOR_LS_CORE}" "\''${EDITOR_LS_CORE}.orig"
        fi
        cp "\''${CUSTOM_LS_CORE}" "\''${EDITOR_LS_CORE}"
        echo -e "    \''${GREEN}✓ Replaced\''${NC}"
    fi
fi

# Replace equinox launcher if version differs
CUSTOM_LAUNCHER=\$(find "\''${PLUGINS_DIR}" -name "org.eclipse.equinox.launcher_*.jar" | head -1)
if [ -n "\''${CUSTOM_LAUNCHER}" ]; then
    EDITOR_LAUNCHER=\$(find "\''${EDITOR_PLUGINS_DIR}" -name "org.eclipse.equinox.launcher_*.jar" | head -1)
    if [ -n "\''${EDITOR_LAUNCHER}" ]; then
        echo "  Replacing: \$(basename "\''${EDITOR_LAUNCHER}")"
        if [ ! -f "\''${EDITOR_LAUNCHER}.orig" ]; then
            cp "\''${EDITOR_LAUNCHER}" "\''${EDITOR_LAUNCHER}.orig"
        fi
        cp "\''${CUSTOM_LAUNCHER}" "\''${EDITOR_LAUNCHER}"
        echo -e "    \''${GREEN}✓ Replaced\''${NC}"
    fi
fi

echo ""
echo -e "\''${GREEN}=== Replacement Complete ===\''${NC}\n"
echo "Next steps:"
echo "1. Close ''${editor_display_name} completely"
echo "2. Restart ''${editor_display_name}"
echo "3. Open a Java file with custom operators"
echo "4. Check that red squiggles are gone"
echo ""
echo -e "\''${YELLOW}Note:\''${NC} You may need to run this script again if:"
echo "- ''${editor_display_name} updates the Java extension"
echo "- The extension gets reinstalled"
SCRIPT_EOF
              chmod +x $out/bin/$script_name
            }

            # Create both binaries
            mkdir -p $out/bin

            # Generate patchJdtlsVsCode script
            generate_patch_script "vscode" \
              '"$HOME/.vscode/extensions" "$HOME/.vscode-insiders/extensions" "$HOME/Library/Application Support/Code/User/extensions" "$HOME/.config/Code/User/extensions" "$APPDATA/Code/User/extensions" "$APPDATA/Code - Insiders/User/extensions"' \
              "VSCode" \
              "patchJdtlsVsCode"

            # Generate patchJdtlsCursor script
            generate_patch_script "cursor" \
              '"$HOME/.cursor/extensions" "$HOME/Library/Application Support/Cursor/User/extensions" "$HOME/.config/Cursor/User/extensions" "$APPDATA/Cursor/User/extensions"' \
              "Cursor" \
              "patchJdtlsCursor"

            runHook postInstall
          '';

          # Don't fail if submodules aren't initialized (for local builds)
          dontFixup = true;
        };

        # JDTLS binary wrapper
        # This package creates a jdtls binary that runs the custom JDTLS language server
        jdtls = pkgs.stdenv.mkDerivation {
          pname = "jdtls";
          version = "1.0.0";

          # Depend on eclipse build - it already builds JDTLS repository
          buildInputs = [ eclipse jdk ];

          # No build needed - we just create a wrapper script
          dontUnpack = true;

          installPhase = ''
            runHook preInstall

            # Extract JDTLS repository from eclipse build output
            REPO_SOURCE="${eclipse}/jdtls-repository"

            if [ ! -d "$REPO_SOURCE" ] || [ -z "$(ls -A $REPO_SOURCE 2>/dev/null)" ]; then
              echo "Error: JDTLS repository not found in eclipse build output: $REPO_SOURCE"
              echo "The eclipse build may not have successfully built JDTLS."
              echo "Available in eclipse output:"
              ls -la "${eclipse}" || true
              exit 1
            fi

            echo "Found JDTLS repository in eclipse build: $REPO_SOURCE"

            # Copy repository to output
            mkdir -p $out/repository
            cp -r $REPO_SOURCE/* $out/repository/

            # Create the jdtls wrapper script
            mkdir -p $out/bin
            cat > $out/bin/jdtls <<'SCRIPT_EOF'
#!/usr/bin/env bash
# Script to run the built JDT Language Server
# Usage: jdtls [data_directory]

# Get the repository directory from the nix store (use absolute path)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "''${SCRIPT_DIR}/../repository" && pwd)"

# Check if repository exists
if [ ! -d "''${REPO_DIR}" ]; then
    echo "Error: Repository not found at ''${REPO_DIR}"
    exit 1
fi

# Find the equinox launcher jar (use absolute path)
LAUNCHER_JAR=$(find "''${REPO_DIR}/plugins" -name "org.eclipse.equinox.launcher_*.jar" | head -1)

if [ -z "''${LAUNCHER_JAR}" ]; then
    echo "Error: Equinox launcher jar not found in ''${REPO_DIR}/plugins"
    exit 1
fi

# Make launcher jar path absolute
LAUNCHER_JAR="$(cd "$(dirname "''${LAUNCHER_JAR}")" && pwd)/$(basename "''${LAUNCHER_JAR}")"

# Detect OS and set source configuration directory (in Nix store)
OS=$(uname -s)
case "''${OS}" in
    Linux*)
        SOURCE_CONFIG_DIR="''${REPO_DIR}/config_linux"
        ;;
    Darwin*)
        SOURCE_CONFIG_DIR="''${REPO_DIR}/config_mac"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        SOURCE_CONFIG_DIR="''${REPO_DIR}/config_win"
        ;;
    *)
        echo "Warning: Unknown OS ''${OS}, using config_linux"
        SOURCE_CONFIG_DIR="''${REPO_DIR}/config_linux"
        ;;
esac

# Create a writable configuration directory in /tmp
# Use a user-specific directory to avoid conflicts
WRITABLE_CONFIG_DIR="/tmp/jdtls-config-''${USER:-nix}-$(basename "''${REPO_DIR}" | cut -d'-' -f1)"

# Copy configuration from Nix store to writable location if needed
if [ ! -d "''${WRITABLE_CONFIG_DIR}" ] || [ "''${SOURCE_CONFIG_DIR}" -nt "''${WRITABLE_CONFIG_DIR}" ]; then
    mkdir -p "''${WRITABLE_CONFIG_DIR}"
    # Copy all config files, preserving structure
    if [ -d "''${SOURCE_CONFIG_DIR}" ]; then
        cp -r "''${SOURCE_CONFIG_DIR}"/* "''${WRITABLE_CONFIG_DIR}/" 2>/dev/null || true
    fi
fi

# Always remove osgi.framework.extensions line and fix osgi.framework path (even if config wasn't just copied)
# This ensures cached configs are also cleaned up
if [ -f "''${WRITABLE_CONFIG_DIR}/config.ini" ]; then
    TMP_FILE="''${WRITABLE_CONFIG_DIR}/config.ini.tmp"
    # Remove osgi.framework.extensions line and ensure osgi.framework uses absolute path
    sed -e '/^osgi\.framework\.extensions=/d' \
        -e "s|^osgi\.framework=file\\\\:plugins/|osgi.framework=file:''${REPO_DIR}/plugins/|g" \
        "''${WRITABLE_CONFIG_DIR}/config.ini" > "''${TMP_FILE}" 2>/dev/null && \
    mv "''${TMP_FILE}" "''${WRITABLE_CONFIG_DIR}/config.ini" 2>/dev/null || true
fi

# Use the writable config directory
CONFIG_DIR="''${WRITABLE_CONFIG_DIR}"

# Set data directory (default to /tmp/jdtls-data if not provided)
DATA_DIR="''${1:-/tmp/jdtls-data}"

# Change to repository directory so relative paths work
cd "''${REPO_DIR}"

# Run the language server
# Set osgi.install.area explicitly to ensure Equinox can find plugins
exec @java@/bin/java \
  -Declipse.application=org.eclipse.jdt.ls.core.id1 \
  -Dosgi.bundles.defaultStartLevel=4 \
  -Declipse.product=org.eclipse.jdt.ls.core.product \
  -Dosgi.install.area="''${REPO_DIR}" \
  -Dlog.level=ALL \
  -Xmx1G \
  --add-modules=ALL-SYSTEM \
  --add-opens java.base/java.util=ALL-UNNAMED \
  --add-opens java.base/java.lang=ALL-UNNAMED \
  -jar "''${LAUNCHER_JAR}" \
  -configuration "''${CONFIG_DIR}" \
  -data "''${DATA_DIR}"
SCRIPT_EOF

            # Substitute Java path in the script
            substituteInPlace $out/bin/jdtls \
              --subst-var-by java "${jdk}"

            chmod +x $out/bin/jdtls

            runHook postInstall
          '';

          # Don't fail if submodules aren't initialized (for local builds)
          dontFixup = true;
        };

        # Eclipse IDE package - extracts the tar archive and sets up a working IDE
        eclipse-ide = pkgs.stdenv.mkDerivation {
          pname = "eclipse-ide";
          version = "4.36.0-SNAPSHOT";

          # Depend on eclipse build and JDK
          buildInputs = with pkgs; [ eclipse jdk git git-lfs curl unzip zip ];

          # No source needed - we extract from eclipse build output
          dontUnpack = true;

          installPhase = ''
            runHook preInstall

            # Determine the appropriate distribution archive based on system
            DIST_ARCHIVE=""
            if [ "${pkgs.stdenv.hostPlatform.system}" == "aarch64-darwin" ] || [ "${pkgs.stdenv.hostPlatform.system}" == "x86_64-darwin" ]; then
              # macOS - try aarch64 first, then x86_64
              if [ -f "${eclipse}/distributions/org.eclipse.sdk.ide-macosx.cocoa.aarch64.tar.gz" ]; then
                DIST_ARCHIVE="${eclipse}/distributions/org.eclipse.sdk.ide-macosx.cocoa.aarch64.tar.gz"
              elif [ -f "${eclipse}/distributions/org.eclipse.sdk.ide-macosx.cocoa.x86_64.tar.gz" ]; then
                DIST_ARCHIVE="${eclipse}/distributions/org.eclipse.sdk.ide-macosx.cocoa.x86_64.tar.gz"
              fi
            elif [ "${pkgs.stdenv.hostPlatform.system}" == "x86_64-linux" ] || [ "${pkgs.stdenv.hostPlatform.system}" == "aarch64-linux" ]; then
              # Linux
              if [ -f "${eclipse}/distributions/org.eclipse.sdk.ide-linux.gtk.x86_64.tar.gz" ]; then
                DIST_ARCHIVE="${eclipse}/distributions/org.eclipse.sdk.ide-linux.gtk.x86_64.tar.gz"
              elif [ -f "${eclipse}/distributions/org.eclipse.sdk.ide-linux.gtk.aarch64.tar.gz" ]; then
                DIST_ARCHIVE="${eclipse}/distributions/org.eclipse.sdk.ide-linux.gtk.aarch64.tar.gz"
              fi
            fi

            if [ -z "$DIST_ARCHIVE" ] || [ ! -f "$DIST_ARCHIVE" ]; then
              echo "Error: No suitable Eclipse distribution found for system ${pkgs.stdenv.hostPlatform.system}"
              echo "Available distributions:"
              ls -la "${eclipse}/distributions/" || true
              exit 1
            fi

            echo "Extracting Eclipse IDE from: $DIST_ARCHIVE"

            # Extract the archive
            mkdir -p $out/eclipse-dist
            cd $out/eclipse-dist
            tar -xzf "$DIST_ARCHIVE"

            # Create a post-install script to fix Git LFS pointer files
            # Nix builds are sandboxed without network access, so LFS files can't be fetched during build
            # This script can be run manually after installation to fix the LFS pointers
            mkdir -p $out/bin
            cat > $out/bin/fix-eclipse-lfs <<'FIX_SCRIPT'
#!/usr/bin/env bash
# Script to fix Git LFS pointer files in Eclipse IDE installation
# This requires network access and git-lfs to be installed

set -e

ECLIPSE_IDE_DIR="$(cd "$(dirname "$0")/../eclipse-dist" && pwd)"

if [ ! -d "$ECLIPSE_IDE_DIR" ]; then
  echo "Error: Eclipse IDE directory not found at $ECLIPSE_IDE_DIR"
  exit 1
fi

cd "$ECLIPSE_IDE_DIR"

if ! command -v git-lfs >/dev/null 2>&1; then
  echo "Error: git-lfs is required but not installed"
  echo "Install it with: nix-env -iA nixpkgs.git-lfs"
  exit 1
fi

echo "Fixing LFS pointer files in Eclipse SWT plugins..."
git-lfs install --skip-repo || true

# Find and fix SWT JARs
find . -name "*.jar" | grep -E "org\.eclipse\.swt\.(cocoa|gtk)" | while read jar; do
  jar_abs=$(realpath "$jar")
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"
  
  unzip -q "$jar_abs" "*.jnilib" "*.so" 2>/dev/null || true
  
  FIXED=false
  find . -type f \( -name "*.jnilib" -o -name "*.so" \) | while read lib_file; do
    size=$(stat -f%z "$lib_file" 2>/dev/null || stat -c%s "$lib_file" 2>/dev/null || echo "0")
    if [ "$size" -lt 500 ]; then
      if head -c 50 "$lib_file" 2>/dev/null | grep -q "version https://git-lfs.github.com/spec/v1"; then
        echo "  Fixing LFS pointer: $(basename "$lib_file")"
        oid=$(grep "^oid sha256:" "$lib_file" | cut -d: -f2 | tr -d ' ')
        if [ -n "$oid" ]; then
          # Set up git repo for git-lfs
          git init -q
          git config user.email "fix@nix"
          git config user.name "Nix Fix"
          git remote add origin https://github.com/maxeler/eclipse.platform.releng.aggregator.git 2>/dev/null || true
          
          # Fetch LFS file
          if git lfs fetch origin "$oid" 2>/dev/null; then
            fetched_file=".git/lfs/objects/$(echo "$oid" | cut -c1-2)/$(echo "$oid" | cut -c3-4)/$oid"
            if [ -f "$fetched_file" ]; then
              fetched_size=$(stat -f%z "$fetched_file" 2>/dev/null || stat -c%s "$fetched_file" 2>/dev/null || echo "0")
              if [ "$fetched_size" -gt 100000 ]; then
                cp "$fetched_file" "$lib_file"
                FIXED=true
                echo "    ✓ Fixed (size: $fetched_size bytes)"
              fi
            fi
          fi
        fi
      fi
    fi
  done
  
  if [ "$FIXED" = "true" ]; then
    cd "$OLDPWD"
    jar_file=$(realpath "$jar")
    cd "$tmp_dir"
    zip -q "$jar_file" *.jnilib *.so 2>/dev/null && echo "  Updated: $jar" || true
  fi
  
  cd "$OLDPWD"
  rm -rf "$tmp_dir"
done

echo "Done! Try running Eclipse again."
FIX_SCRIPT
            chmod +x $out/bin/fix-eclipse-lfs
            echo "Created fix script: $out/bin/fix-eclipse-lfs"
            echo "Note: Nix builds are sandboxed without network access."
            echo "Run the fix script manually after installation:"
            echo "  $(nix build '.#eclipse-ide' --print-out-paths)/bin/fix-eclipse-lfs"


            # Find the extracted Eclipse directory
            if [ -d "Eclipse.app" ]; then
              # macOS - Eclipse.app structure
              ECLIPSE_DIR="$out/eclipse-dist/Eclipse.app"
              ECLIPSE_EXEC="$ECLIPSE_DIR/Contents/MacOS/eclipse"
            elif [ -d "eclipse" ]; then
              # Linux - eclipse directory
              ECLIPSE_DIR="$out/eclipse-dist/eclipse"
              ECLIPSE_EXEC="$ECLIPSE_DIR/eclipse"
            else
              echo "Error: Could not find Eclipse.app or eclipse directory after extraction"
              ls -la "$out/eclipse-dist"
              exit 1
            fi

            if [ ! -f "$ECLIPSE_EXEC" ]; then
              echo "Error: Eclipse executable not found at $ECLIPSE_EXEC"
              exit 1
            fi

            echo "Found Eclipse at: $ECLIPSE_DIR"
            echo "Eclipse executable: $ECLIPSE_EXEC"

            # Create a wrapper script that sets up the environment
            mkdir -p $out/bin

            if [ -d "Eclipse.app" ]; then
              # macOS wrapper - launches Eclipse.app with proper environment
              # Following the build instructions: "Open Eclipse.app/"
              # On macOS, we use 'open' command which properly handles .app bundles
              cat > $out/bin/eclipse <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Wrapper script to launch Eclipse IDE with proper Nix environment
# Following build instructions: "Open Eclipse.app/"

set -e

# Get the Eclipse.app directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ECLIPSE_APP="$(cd "$SCRIPT_DIR/../eclipse-dist/Eclipse.app" && pwd)"

# Set up Java environment
export JAVA_HOME="@java@"
export PATH="$JAVA_HOME/bin:$PATH"

# Set Eclipse-specific environment variables
export ECLIPSE_HOME="$ECLIPSE_APP/Contents/Eclipse"

# Ensure Eclipse can find its plugins and configuration
export ECLIPSE_PLUGINS="$ECLIPSE_HOME/plugins"
export ECLIPSE_CONFIGURATION="$ECLIPSE_HOME/configuration"

# On macOS, use 'open' command to launch Eclipse.app properly
# This ensures proper macOS app context which is critical for:
# - Native library loading (SWT libraries)
# - macOS integration (menu bar, dock, etc.)
# - Proper handling of .app bundle structure
# The -a flag specifies the application, -W makes it wait for the app to exit
if [ $# -eq 0 ]; then
  # No arguments - launch Eclipse normally
  exec open -W -a "$ECLIPSE_APP"
else
  # With arguments - need to use the executable directly
  # But set up environment first
  ECLIPSE_EXEC="$ECLIPSE_APP/Contents/MacOS/eclipse"
  # Change to Contents directory so relative paths in eclipse.ini work
  cd "$ECLIPSE_APP/Contents"
  exec "$ECLIPSE_EXEC" "$@"
fi
WRAPPER_EOF
            else
              # Linux wrapper - launches eclipse executable with proper environment
              cat > $out/bin/eclipse <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Wrapper script to launch Eclipse IDE with proper Nix environment

set -e

# Get the eclipse directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ECLIPSE_DIR="$(cd "$SCRIPT_DIR/../eclipse-dist/eclipse" && pwd)"
ECLIPSE_EXEC="$ECLIPSE_DIR/eclipse"

# Set up Java environment
export JAVA_HOME="@java@"
export PATH="$JAVA_HOME/bin:$PATH"

# Set Eclipse-specific environment variables
export ECLIPSE_HOME="$ECLIPSE_DIR"
export ECLIPSE_PLUGINS="$ECLIPSE_DIR/plugins"
export ECLIPSE_CONFIGURATION="$ECLIPSE_DIR/configuration"

# Set library paths for native libraries
export LD_LIBRARY_PATH="$ECLIPSE_DIR:$LD_LIBRARY_PATH"

# Launch Eclipse
exec "$ECLIPSE_EXEC" "$@"
WRAPPER_EOF
            fi

            # Substitute Java path in the wrapper script
            substituteInPlace $out/bin/eclipse \
              --subst-var-by java "${jdk}"

            chmod +x $out/bin/eclipse

            # Also create a symlink to the Eclipse directory for reference
            ln -s $ECLIPSE_DIR $out/eclipse

            # Create an info file about what was installed
            cat > $out/eclipse-info.txt <<EOF
Eclipse IDE Installation
========================
Version: 4.36.0-SNAPSHOT
Source: Built from eclipse.platform.releng.aggregator
Java: ${jdk}
Location: $ECLIPSE_DIR
Executable: $out/bin/eclipse

To run Eclipse:
  $out/bin/eclipse

Or add $out/bin to your PATH and run:
  eclipse
EOF

            echo ""
            echo "Eclipse IDE installed successfully!"
            echo "Run: $out/bin/eclipse"
            echo "Or add $out/bin to your PATH"

            runHook postInstall
          '';

          # Don't fixup - Eclipse has its own native libraries and structure
          dontFixup = true;
        };

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            jdk
            maven
            git
          ];

          shellHook = ''
            export JAVA_HOME=${jdk}
            export PATH="$JAVA_HOME/bin:$PATH"
            echo "Java version:"
            java -version
            echo ""
            echo "Maven version:"
            mvn -version
          '';
        };

        packages = {
          source = source;
          ecj = ecj;
          eclipse = eclipse;
          eclipse-ide = eclipse-ide;
          jdtlsPatcher = jdtlsPatcher;
          jdtls = jdtls;
          default = eclipse;
        };
      }
    );
}

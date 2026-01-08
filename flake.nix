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
        # Instead of using fetchSubmodules=true (which is slow), we fetch each submodule
        # separately and combine them together. This is much faster and allows better caching.

        # Main repository (without submodules)
        mainRepo = pkgs.fetchFromGitHub {
          owner = "maxeler";
          repo = "eclipse.platform.releng.aggregator";
          rev = "e7f40bf9ae1bb249802b16529172ccf3e0dc6357";
          sha256 = "sha256-3w6sp7zpcA7t4CVKaiVGwqBbXfCqGsVJ4FHr38j176o=";
        };

        # Individual submodule fetches
        submodule_eclipse_jdt = pkgs.fetchFromGitHub {
          owner = "eclipse-jdt";
          repo = "eclipse.jdt";
          rev = "fbb19a8ff98e86640b7415d83fc52e91c7ff3e34";
          sha256 = "sha256-sEkls26kajS0ud2Z09DHWGYOJvuIEhhGjfvKZHFRgTY=";
        };

        submodule_eclipse_jdt_core = pkgs.fetchFromGitHub {
          owner = "maxeler";
          repo = "maxj";
          rev = "17d543e9fa42c2647716a4842922c8848b8eddf5";
          sha256 = "sha256-wsauLV3bEu4oExfNr0NWy6bMtlF4oa+xPSW+CGJkViI=";
        };

        submodule_eclipse_jdt_core_binaries = pkgs.fetchFromGitHub {
          owner = "eclipse-jdt";
          repo = "eclipse.jdt.core.binaries";
          rev = "435d794313ac39ef8e7c3cf93518b773e383a68b";
          sha256 = "sha256-zbUaHZbiDIWL9v023UyHj5uR9Wn6N5mSqYHs9qqvYlw=";
        };

        submodule_eclipse_jdt_debug = pkgs.fetchFromGitHub {
          owner = "eclipse-jdt";
          repo = "eclipse.jdt.debug";
          rev = "c3216f8e636eab21d9aedb53becc562f5cee7739";
          sha256 = "sha256-pymQ5+MNGbb41s/aOAIvhN67Fqi70XH/z8w7se9o/R4=";
        };

        submodule_eclipse_jdt_ui = pkgs.fetchFromGitHub {
          owner = "maxeler";
          repo = "eclipse.jdt.ui";
          rev = "387bdf958b95ffc7ea8db798a423cc35e386b940";
          sha256 = "sha256-xUs6RIDZa9oZI5gezziB1LQo9XcTk3LWxWWVyzsvlzQ=";
        };

        submodule_eclipse_jdt_ls = pkgs.fetchFromGitHub {
          owner = "maxeler";
          repo = "eclipse.jdt.ls";
          rev = "f4dbbf689ce02a5e9cfc9a258ff6ee575554871e";
          sha256 = "sha256-sEkls26kajS0ud2Z09DHWGYOJvuIEhhGjfvKZHFRgTY=";
        };

        submodule_eclipse_pde = pkgs.fetchFromGitHub {
          owner = "eclipse-pde";
          repo = "eclipse.pde";
          rev = "bc2f62c776dbccd0932249eda364865c1878c7e9";
          sha256 = "sha256-E3tJPpDDsUahhk1pMpcWMhnfVrycWL1aFGoSULNa5tM=";
        };

        submodule_eclipse_platform = pkgs.fetchFromGitHub {
          owner = "eclipse-platform";
          repo = "eclipse.platform";
          rev = "53c100e6cd6fb8fa1af3b101ed16f6c2bdbc6396";
          sha256 = "sha256-Fhn4mEObjSUetwksUg46qjPU52d1En1T70bkTqWKRdo=";
        };

        submodule_eclipse_platform_swt = pkgs.fetchFromGitHub {
          owner = "eclipse-platform";
          repo = "eclipse.platform.swt";
          rev = "e4890daf9d8aecbf37ba0e7562ca5066e33ebefd";
          sha256 = "sha256-jI5ewA8mn7LhZgFDD6JvIhKq8n3Xz16jdVEEhOe4/NI=";
        };

        submodule_eclipse_platform_ui = pkgs.fetchFromGitHub {
          owner = "eclipse-platform";
          repo = "eclipse.platform.ui";
          rev = "adf7f57615da873b6fbc094d98ccb5ff79ddd99d";
          sha256 = "sha256-hXh535TU+rtqc27ollQL24nr/5V3O+0Z2zSe4tTtrGI=";
        };

        submodule_equinox = pkgs.fetchFromGitHub {
          owner = "eclipse-equinox";
          repo = "equinox";
          rev = "ca95c426a7176f95f085f2f08c29f5cc338d9dcb";
          sha256 = "sha256-42FNMB/w0NJsZlNLG/BQ54dyJiMQ1XIuOdO5ZbaOJtA=";
        };

        submodule_equinox_binaries = pkgs.fetchFromGitHub {
          owner = "eclipse-equinox";
          repo = "equinox.binaries";
          rev = "a72c123aa956a8ad109f42b2094c9a8ad5212aa4";
          sha256 = "sha256-P/jRGoUZc3r9kFi1pCWzpfoTqmnywQdwtxjGnapyLG8=";
        };

        submodule_equinox_p2 = pkgs.fetchFromGitHub {
          owner = "eclipse-equinox";
          repo = "p2";
          rev = "1a09efdb39b2946efbacc281baaee76da8f1c323";
          sha256 = "sha256-9FqDXLAfMRG2Wk2ejQ1ZEy2EX2PS+1uIfPc+wWyiHgk=";
        };

        # Combine main repo with all submodules
        source = pkgs.runCommand "eclipse-platform-releng-aggregator-combined" {} ''
          # Copy main repository
          cp -r ${mainRepo} $out
          chmod -R +w $out

          # Copy each submodule to its designated path
          cp -r ${submodule_eclipse_jdt} $out/eclipse.jdt
          cp -r ${submodule_eclipse_jdt_core} $out/eclipse.jdt.core
          cp -r ${submodule_eclipse_jdt_core_binaries} $out/eclipse.jdt.core.binaries
          cp -r ${submodule_eclipse_jdt_debug} $out/eclipse.jdt.debug
          cp -r ${submodule_eclipse_jdt_ui} $out/eclipse.jdt.ui
          cp -r ${submodule_eclipse_jdt_ls} $out/eclipse.jdt.ls
          cp -r ${submodule_eclipse_pde} $out/eclipse.pde
          cp -r ${submodule_eclipse_platform} $out/eclipse.platform
          cp -r ${submodule_eclipse_platform_swt} $out/eclipse.platform.swt
          cp -r ${submodule_eclipse_platform_ui} $out/eclipse.platform.ui
          cp -r ${submodule_equinox} $out/equinox
          cp -r ${submodule_equinox_binaries} $out/equinox.binaries
          cp -r ${submodule_equinox_p2} $out/equinox.p2
        '';

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
            mvn clean verify \
              -e \
              -Dmaven.repo.local=$M2_REPO \
              -T 1C \
              -DskipTests=true \
              -Dcompare-version-with-baselines.skip=true \
              -DapiBaselineTargetDirectory=$WORKSPACE \
              -Dcbi-ecj-version=99.99 \
              -Dtycho.disableP2Mirrors=true \
              -U

            echo "Building JDTLS product (for VSCode patcher)..."
            # Build JDTLS product now that platform repository is available
            mvn clean install \
              -pl eclipse.jdt.ls/org.eclipse.jdt.ls.product \
              -Dmaven.repo.local=$M2_REPO \
              -Dcbi-ecj-version=99.99 \
              -Dtycho.disableP2Mirrors=true \
              -DskipTests=true \
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

# Get the repository directory from the nix store
REPO_DIR="$(cd "$(dirname "$0")/../repository" && pwd)"

# Check if repository exists
if [ ! -d "''${REPO_DIR}" ]; then
    echo "Error: Repository not found at ''${REPO_DIR}"
    exit 1
fi

# Find the equinox launcher jar
LAUNCHER_JAR=$(find "''${REPO_DIR}/plugins" -name "org.eclipse.equinox.launcher_*.jar" | head -1)

if [ -z "''${LAUNCHER_JAR}" ]; then
    echo "Error: Equinox launcher jar not found in ''${REPO_DIR}/plugins"
    exit 1
fi

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
        # Remove osgi.framework.extensions line if it references the missing compatibility state plugin
        if [ -f "''${WRITABLE_CONFIG_DIR}/config.ini" ]; then
            TMP_FILE="''${WRITABLE_CONFIG_DIR}/config.ini.tmp"
            sed '/^osgi\.framework\.extensions=/d' "''${WRITABLE_CONFIG_DIR}/config.ini" > "''${TMP_FILE}" 2>/dev/null && \
            mv "''${TMP_FILE}" "''${WRITABLE_CONFIG_DIR}/config.ini" 2>/dev/null || true
        fi
    fi
fi

# Use the writable config directory
CONFIG_DIR="''${WRITABLE_CONFIG_DIR}"

# Set data directory (default to /tmp/jdtls-data if not provided)
DATA_DIR="''${1:-/tmp/jdtls-data}"

# Change to repository directory so relative paths work
cd "''${REPO_DIR}"

# Run the language server
exec @java@/bin/java \
  -Declipse.application=org.eclipse.jdt.ls.core.id1 \
  -Dosgi.bundles.defaultStartLevel=4 \
  -Declipse.product=org.eclipse.jdt.ls.core.product \
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
          ecj = ecj;
          eclipse = eclipse;
          jdtlsPatcher = jdtlsPatcher;
          jdtls = jdtls;
          default = eclipse;
        };
      }
    );
}

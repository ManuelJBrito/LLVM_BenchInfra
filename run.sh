#!/bin/sh -ex

# Parse arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --config-file=*)
            config_file="${1#*=}"
            ;;
        --install-only=*)
            install_only="${1#*=}"
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

# Set default values
install_only=${install_only:-false}  # Set default value to false if not provided

# Check if the config file is provided
if [ -z "$config_file" ]; then
    echo "Config file not provided"
    exit 1
fi

# Check if the config file exists
if [ ! -f "$config_file" ]; then
    echo "Config file not found: $config_file"
    exit 1
fi

PTS_BASE=$(jq -r '.PTS_BASE' "$config_file")
export WORK_ENV=$(jq -r '.WORK_ENV' "$config_file")
TOOLCHAIN_PATH=$(jq -r '.TOOLCHAIN_PATH' "$config_file")
export LLVM_PATH=$(jq -r '.LLVM_PATH' "$config_file")
FLAGS=$(jq -r '.FLAGS' "$config_file")
export PASSFILTER=$(jq -r '.PASSFILTER' "$config_file")
export NUM_CPU_CORES=$(jq -r '.NUM_CPU_CORES' "$config_file")
export NUM_CPU_JOBS=$NUM_CPU_CORES

if [ -z "$PTS_BASE" ]; then
    echo "PTS_BASE is not set in the configuration file."
    exit 1
fi

if [ -z "$WORK_ENV" ]; then
    echo "WORK_ENV is not set in the configuration file."
    exit 1
fi

if [ -z "$TOOLCHAIN_PATH" ]; then
    echo "TOOLCHAIN_PATH is not set in the configuration file."
    exit 1
fi

if [ -z "$LLVM_PATH" ]; then
    echo "LLVM_PATH is not set in the configuration file."
    exit 1
fi

# Phoronix-test-suite executable
PTS_PHP="${PTS_BASE}pts-core/phoronix-test-suite.php"

# Check if executable exists
if [ ! -f "$PTS_PHP" ]; then
    echo "Phoronix Test Suite executable not found: $PTS_PHP"
    exit 1
fi

export PTS="php ${PTS_PHP}"
# Location where the profiles are installed, ran and the results are stored.
# export WORK_ENV="$2"

# Check if the WORK_ENV exists
if [ ! -d "$WORK_ENV" ]; then
    echo "WORK_ENV directory not found: $WORK_ENV"
    exit 1
fi

# Create working subdirs and files
CACHE_PATH="${WORK_ENV}download-cache/"
INSTALL_PATH="${WORK_ENV}installed-tests/"
RESULTS_PATH="${WORK_ENV}test-results/"
export COMPILE_RESULTS_PATH="${WORK_ENV}compile-results/"
export COMPILE_TIME_PATH="${COMPILE_RESULTS_PATH}time/"
export COMPILE_STATS_PATH="${COMPILE_RESULTS_PATH}stats/"
export COMPILE_FAIL_PATH="${COMPILE_RESULTS_PATH}fail/"
mkdir -p "$CACHE_PATH" "$INSTALL_PATH" "$RESULTS_PATH" "$COMPILE_RESULTS_PATH" 

rm -rf "$RESULTS_PATH/*" $COMPILE_RESULTS_PATH/*

mkdir -p "$COMPILE_STATS_PATH" "$COMPILE_TIME_PATH"

# Config Phoronix
export PTS_USER_PATH_OVERRIDE="$WORK_ENV"
$PTS user-config-set CacheDirectory="$CACHE_PATH" EnvironmentDirectory="$INSTALL_PATH" ResultsDirectory="$RESULTS_PATH"

# Check if the path exists
if [ ! -d "$TOOLCHAIN_PATH" ]; then
    echo "Clang path not found: $TOOLCHAIN_PATH"
    exit 1
fi

export CC="${TOOLCHAIN_PATH}clang"
export CXX="${TOOLCHAIN_PATH}clang++"
export LD=$CXX

# Check if the path exists
if [ ! -x "$CC" ]; then
    echo "Clang not found: $CC"
    exit 1
fi

if [ ! -x "$CXX" ]; then
    echo "Clang++ not found: $CXX"
    exit 1
fi

# Check if the compilers work using simple CC/CXX programs
echo 'int main() { return 0; }' > test_program.c
if ! "$CC" "-mno-avx256-split-unaligned-store" test_program.c -o test_program; then
    echo "Failed to compile using CC: $CC"
    exit 1
fi

cp test_program.c test_program.cpp
if ! "$CXX" test_program.cpp -o test_program; then
    echo "Failed to compile using CXX: $CXX"
    exit 1
fi
rm test_program


# Check if the compiler accepts the flags
echo 'int main() { return 0; }' > test_program.c
if ! "$CC" $FLAGS test_program.c -o test_program; then
    echo "Failed to compile using CC flags: $FLAGS"
    exit 1
fi
if ! "$CXX" $FLAGS test_program.cpp -o test_program; then
    echo "Failed to compile using CXX flags: $FLAGS"
    exit 1
fi

rm test_program.c test_program.cpp test_program

export CFLAGS="$FLAGS"
export CXXFLAGS="$FLAGS"

# Install the profiles
./scripts/install-profiles.sh

# Run the profiles
if [ "$install_only" != 1 ]; then
  ./scripts/run-profiles.sh
fi
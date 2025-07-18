#!/bin/bash
# mdbook fast view script with environment checks for Linux

echo "========================================"
echo "   mdbook Fast View Script (Linux)"
echo "========================================"
echo

# 1. Environment Check - Python Version Validation
echo "[1/4] Checking Python environment..."

# Check if python3 command exists
if ! command -v python3 >/dev/null 2>&1; then
    # Fallback to python command
    if ! command -v python >/dev/null 2>&1; then
        echo "[ERROR] Python is not installed or not in PATH environment variable"
        echo
        echo "Please install Python 3.7+ and ensure it is added to PATH"
        echo "Ubuntu/Debian: sudo apt-get install python3"
        echo "CentOS/RHEL: sudo yum install python3"
        echo
        read -p "Press Enter to exit..."
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

# Get Python version information
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
echo "Python version: $PYTHON_VERSION"

# Check if Python version is 3.7+
MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

if [ "$MAJOR" -lt 3 ]; then
    echo "[ERROR] Python version too low, requires 3.7+"
    echo "Current version: $PYTHON_VERSION"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi

if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 7 ]; then
    echo "[ERROR] Python version too low, requires 3.7+"
    echo "Current version: $PYTHON_VERSION"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi

echo "[OK] Python environment check passed"

echo
echo "[2/4] Checking dependency files..."

# 2. Dependency Validation - Check generate_summary.py
if [ ! -f "./tools/generate_summary.py" ]; then
    echo "[ERROR] File not found: ./tools/generate_summary.py"
    echo "Please confirm the file exists and path is correct"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi
echo "[OK] generate_summary.py file exists"

# Check mdbook executable
if [ ! -f "./tools/mdbook" ]; then
    echo "[ERROR] File not found: ./tools/mdbook"
    echo "Please confirm mdbook exists in tools directory"
    echo "You may need to download mdbook for Linux from:"
    echo "https://github.com/rust-lang/mdBook/releases"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi

# Check if mdbook is executable
if [ ! -x "./tools/mdbook" ]; then
    echo "[WARNING] mdbook is not executable, attempting to fix..."
    chmod +x ./tools/mdbook
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to make mdbook executable"
        echo "Please run: chmod +x ./tools/mdbook"
        echo
        read -p "Press Enter to exit..."
        exit 1
    fi
fi
echo "[OK] mdbook file exists and is executable"

echo
echo "[3/4] Generating SUMMARY.md file..."

# 3. Automated Execution Flow - Generate SUMMARY.md
$PYTHON_CMD ./tools/generate_summary.py
if [ $? -ne 0 ]; then
    echo "[ERROR] SUMMARY.md generation failed"
    echo "Please check if generate_summary.py script works properly"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi

# Verify SUMMARY.md was successfully generated
if [ ! -f "SUMMARY.md" ]; then
    echo "[ERROR] SUMMARY.md file was not generated"
    echo "Please check generate_summary.py script output"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi
echo "[OK] SUMMARY.md generated successfully"

echo
echo "[4/4] Starting mdbook service..."

# 4. Start mdbook service
echo "Starting mdbook server..."
echo "Server will automatically open in browser"
echo "Press Ctrl+C to stop server"
echo

./tools/mdbook serve --open
if [ $? -ne 0 ]; then
    echo "[ERROR] mdbook service startup failed"
    echo "Please check if mdbook works properly"
    echo "You may need to install mdbook or check dependencies"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi

echo
echo "mdbook service stopped"
read -p "Press Enter to exit..."

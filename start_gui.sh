

echo "================================"
echo "ZZAR - GUI Launcher"
echo "================================"
echo ""

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3."
    exit 1
fi
echo "✓ Python 3 found"

if ! python3 -c "import PyQt5" 2>/dev/null; then
    echo "❌ PyQt5 not found"
    echo ""
    echo "Installing PyQt5..."

    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed python-pyqt5
    elif command -v apt &> /dev/null; then
        sudo apt install python3-pyqt5 python3-pyqt5.qtquick python3-pyqt5.qtmultimedia
    elif command -v dnf &> /dev/null; then
        sudo dnf install python3-qt5
    else
        echo "Please install PyQt5 for your distribution"
        echo "Or use: pip install PyQt5"
        exit 1
    fi
fi
echo "✓ PyQt5 found"

if ! python3 -c "from PyQt5.QtQml import QQmlApplicationEngine" 2>/dev/null; then
    echo "⚠️  PyQt5.QtQml not found"
    echo ""
    echo "The QML UI requires PyQt5 with QML support."
    echo "Please install the full PyQt5 package or run:"
    echo "  pip install PyQt5"
    echo ""
    exit 1
fi
echo "✓ PyQt5.QtQml found"

echo ""
echo "Starting ZZAR GUI..."
echo ""

cd "$(dirname "$0")"
python3 ZZAR.py

echo ""
echo "GUI closed."

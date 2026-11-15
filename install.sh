#!/usr/bin/env bash
set -e

echo "🔍 Se detectează sistemul de operare..."
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

if [ "$OS" != "linux" ]; then
    echo "❌ Acest installer suportă momentan doar Linux (inclusiv WSL2)."
    exit 1
fi

echo "📦 Se creează directorul de instalare..."
INSTALL_DIR="$HOME/.kant-lean-worker"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

# 1. Copiem binarul (sau il descarcam de pe GitHub Releases)
echo "⚙️  Se instalează binarul Lean..."
# Daca exista local il copiem, altfel descarcam (mock URL pentru viitor)
if [ -f "./.lake/build/bin/lean-worker" ]; then
    cp "./.lake/build/bin/lean-worker" "$INSTALL_DIR/lean-worker"
else
    echo "❌ Binarul nu a fost găsit. Rulează 'lake build' mai întâi."
    exit 1
fi
chmod +x "$INSTALL_DIR/lean-worker"
cp "./ui.html" "$INSTALL_DIR/"

# 2. Migram datele existente (daca exista)
if [ -d "./data" ]; then
    echo "📂 Se migrează datele existente..."
    cp -r "./data" "$INSTALL_DIR/"
fi

# 3. Creăm serviciul systemd (la nivel de utilizator)
echo "🔧 Se configurează serviciul systemd..."
mkdir -p "$HOME/.config/systemd/user"
cat << SERVICE_EOF > "$HOME/.config/systemd/user/kant-lean-worker.service"
[Unit]
Description=Kant Lean Worker
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/lean-worker
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
SERVICE_EOF

systemctl --user daemon-reload
systemctl --user enable --now kant-lean-worker.service

# 4. Cream CLI wrapper
echo "🛠️  Se instalează comanda 'kant-lean-worker'..."
cat << CLI_EOF > "$BIN_DIR/kant-lean-worker"
#!/usr/bin/env bash
case "\$1" in
    start) systemctl --user start kant-lean-worker ;;
    stop) systemctl --user stop kant-lean-worker ;;
    status) systemctl --user status kant-lean-worker ;;
    logs) journalctl --user -u kant-lean-worker -f ;;
    *) echo "Utilizare: kant-lean-worker {start|stop|status|logs}" ;;
esac
CLI_EOF
chmod +x "$BIN_DIR/kant-lean-worker"

echo ""
echo "✅ Instalare completă!"
echo "🌐 Accesează: http://localhost:8080/ui"
echo "💡 Comenzi utile: kant-lean-worker status | stop | logs"
echo "📁 Datele tale sunt salvate în: $INSTALL_DIR/data"

# Adaugă în PATH dacă nu există deja
if ! echo $PATH | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "⚠️  Am adăugat ~/.local/bin în ~/.bashrc. Rulează: source ~/.bashrc"
fi

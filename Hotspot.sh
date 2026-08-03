#!/usr/bin/env bash
#
# hotspot.sh — Transforma o notebook em roteador Wi-Fi
# Internet entra via cabo Ethernet, é compartilhada por Wi-Fi (hotspot)
#
# Uso:
#   sudo ./hotspot.sh start     -> cria e ativa o hotspot
#   sudo ./hotspot.sh stop      -> desliga o hotspot
#   sudo ./hotspot.sh status    -> mostra status atual
#
# Antes de usar, edite as variáveis SSID e SENHA abaixo.

set -euo pipefail

# ============ CONFIGURAÇÕES (edite aqui) ============
SSID="MeuNotebookRouter"
SENHA="senha12345"        # mínimo 8 caracteres (WPA2)
CON_NAME="Hotspot"
# Interface Wi-Fi (deixe em branco para detectar automaticamente)
WIFI_IFACE=""
# ======================================================

if [ "$EUID" -ne 0 ]; then
  echo "Erro: rode este script com sudo. Ex: sudo ./hotspot.sh start"
  exit 1
fi

detectar_wifi() {
  if [ -n "$WIFI_IFACE" ]; then
    echo "$WIFI_IFACE"
    return
  fi
  local iface
  iface=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
  if [ -z "$iface" ]; then
    echo "Erro: nenhuma interface Wi-Fi encontrada." >&2
    exit 1
  fi
  echo "$iface"
}

detectar_ethernet() {
  local iface
  iface=$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2=="ethernet" && $3=="connected"{print $1; exit}')
  if [ -z "$iface" ]; then
    echo "Aviso: não encontrei uma interface Ethernet CONECTADA no momento." >&2
    echo "Certifique-se de que o cabo de rede está plugado e com internet ativa." >&2
  else
    echo "$iface"
  fi
}

checar_ap_mode() {
  local iface="$1"
  if command -v iw >/dev/null 2>&1; then
    if ! iw list 2>/dev/null | grep -A 10 "Supported interface modes" | grep -q "AP"; then
      echo "Aviso: não consegui confirmar que a placa Wi-Fi ($iface) suporta modo AP."
      echo "Se o hotspot falhar ao iniciar, esse pode ser o motivo (limitação do chip/driver)."
    fi
  fi
}

start_hotspot() {
  local wifi eth
  wifi=$(detectar_wifi)
  eth=$(detectar_ethernet || true)
  checar_ap_mode "$wifi"

  echo "Interface Wi-Fi:  $wifi"
  echo "Interface Ethernet (internet): ${eth:-'não detectada - conecte o cabo'}"

  # Desbloqueia rádio Wi-Fi caso esteja em rfkill soft-block
  rfkill unblock wifi || true

  # Remove hotspot anterior com mesmo nome, se existir, para recriar limpo
  if nmcli -t -f NAME connection show | grep -qx "$CON_NAME"; then
    nmcli connection delete "$CON_NAME" || true
  fi

  echo "Criando hotspot '$SSID' na interface $wifi..."
  nmcli device wifi hotspot \
    ifname "$wifi" \
    con-name "$CON_NAME" \
    ssid "$SSID" \
    password "$SENHA"

  # Garante NAT/compartilhamento (método 'shared' cuida do IP forwarding + masquerade)
  nmcli connection modify "$CON_NAME" ipv4.method shared

  # Reativa para aplicar
  nmcli connection up "$CON_NAME"

  echo ""
  echo "   Hotspot ativo!"
  echo "   SSID: $SSID"
  echo "   Senha: ************"
  echo "   Conecte seu celular a essa rede Wi-Fi."
}

stop_hotspot() {
  if nmcli -t -f NAME connection show --active | grep -qx "$CON_NAME"; then
    nmcli connection down "$CON_NAME"
    echo "Hotspot desativado."
  else
    echo "Hotspot não está ativo."
  fi
}

listar_dispositivos_conectados() {
  local wifi lease_file
  wifi=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')

  if [ -z "$wifi" ]; then
    echo "Interface Wi-Fi não encontrada."
    return
  fi

  # NetworkManager (modo shared) roda um dnsmasq interno e grava as leases aqui
  lease_file="/var/lib/NetworkManager/dnsmasq-${wifi}.leases"

  if [ -s "$lease_file" ]; then
    printf "%-18s %-16s %-25s\n" "MAC" "IP" "NOME DO DISPOSITIVO"
    printf "%-18s %-16s %-25s\n" "---" "--" "--------------------"
    # Formato da linha: <timestamp> <mac> <ip> <hostname> <client-id>
    while read -r _ mac ip hostname _; do
      [ "$hostname" = "*" ] && hostname="(desconhecido)"
      printf "%-18s %-16s %-25s\n" "$mac" "$ip" "$hostname"
    done < "$lease_file"
  else
    echo "Nenhuma lease de DHCP encontrada ainda (arquivo $lease_file vazio ou inexistente)."
    echo "Tentando via tabela ARP/vizinhança (menos preciso, sem nome do dispositivo):"
    ip neigh show dev "$wifi" 2>/dev/null | grep -v FAILED || echo "Nenhum dispositivo conectado no momento."
  fi
}

status_hotspot() {
  echo "--- Conexões ativas ---"
  nmcli connection show --active
  echo ""
  echo "--- Dispositivos de rede ---"
  nmcli device status
  echo ""
  echo "--- Dispositivos conectados ao hotspot ---"
  listar_dispositivos_conectados
}

case "${1:-}" in
  start)  start_hotspot ;;
  stop)   stop_hotspot ;;
  status) status_hotspot ;;
  *)
    echo "Uso: sudo $0 {start|stop|status}"
    exit 1
    ;;
esac
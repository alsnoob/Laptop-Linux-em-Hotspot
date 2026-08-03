# Hotspot.sh

Transforma um notebook Linux com **Ubuntu** (ou qualquer distro com NetworkManager) em um **roteador Wi-Fi**, compartilhando a internet recebida via cabo Ethernet com celulares e outros dispositivos móveis.

Criado e testado em um notebook **CCE F4030** rodando **Ubuntu 26.04 LTS**.

## ✨ Funcionalidades

- Cria um hotspot Wi-Fi (WPA2) usando `nmcli`/NetworkManager — sem precisar configurar `hostapd`, `dnsmasq` ou `iptables` manualmente.
- Detecta automaticamente a interface Wi-Fi e a interface Ethernet conectada.
- Configura NAT e compartilhamento de IP (`ipv4.method shared`) automaticamente.
- Comando de status que lista as conexões ativas e os **dispositivos conectados ao hotspot** (MAC, IP e nome, quando disponível).
- Oculta a senha na saída do terminal.

## 📋 Requisitos

- Linux com **NetworkManager** (padrão no Ubuntu Desktop).
- Placa Wi-Fi com suporte a **modo AP** (Access Point).
- Conexão de internet ativa via cabo Ethernet.
- Permissões de superusuário (`sudo`).

## 🚀 Instalação

```bash
git clone https://github.com/alsnoob/hotspot.git
cd hotspot
chmod +x hotspot.sh
```

## ⚙️ Configuração

Antes do primeiro uso, edite as variáveis no topo do arquivo `hotspot.sh`:

```bash
SSID="MeuNotebookRouter"
SENHA="senha12345"        # mínimo 8 caracteres (WPA2)
```

## 🖥️ Uso

**Ativar o hotspot:**
```bash
sudo ./hotspot.sh start
```

**Ver status e dispositivos conectados:**
```bash
sudo ./hotspot.sh status
```

**Desativar o hotspot:**
```bash
sudo ./hotspot.sh stop
```

## 🔍 Como funciona

O script usa `nmcli device wifi hotspot` para criar uma conexão Wi-Fi em modo Access Point na interface sem fio detectada. O NetworkManager, ao usar `ipv4.method shared`, cuida automaticamente de:

- Habilitar o encaminhamento de pacotes (IP forwarding);
- Configurar NAT/masquerade para rotear o tráfego dos dispositivos conectados até a internet (recebida via Ethernet);
- Subir um servidor DHCP interno (dnsmasq) para distribuir IPs aos dispositivos.

Os dispositivos conectados são identificados a partir do arquivo de leases do DHCP interno:
```
/var/lib/NetworkManager/dnsmasq-<interface_wifi>.leases
```

## ⚠️ Observações

- Notebooks com placas Wi-Fi mais simples/baratas podem não suportar modo AP. Para verificar:
  ```bash
  iw list | grep -A 10 "Supported interface modes"
  ```
  Se `AP` não aparecer na lista, considere usar um adaptador Wi-Fi USB externo.
- O script assume que a internet chega por **cabo Ethernet** e é compartilhada via **Wi-Fi**. Outros cenários (ex: internet via Wi-Fi compartilhada por cabo) não são cobertos por esta versão.

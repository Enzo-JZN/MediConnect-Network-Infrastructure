#!/bin/bash
# Teste chaque serveur en web (HTTPS) et en SSH : connexion établie = AUTORISÉ, pas de réponse = BLOQUÉ
teste() {   # $1 = IP, $2 = port, $3 = nom affiché
  if timeout 3 bash -c "</dev/tcp/$1/$2" 2>/dev/null; then
    printf "%-24s %-20s ✅ AUTORISÉ\n" "$3" "$1:$2"
  else
    printf "%-24s %-20s ❌ BLOQUÉ\n"   "$3" "$1:$2"
  fi
}
GW=$(ip route | awk '/default/{print $3; exit}')   # passerelle = pfSense
echo "=== Poste : $(hostname)  —  IP : $(hostname -I) ==="
echo "--- Accès web (HTTPS 443) ---"
teste 10.70.10.10 443 "SRV_CRM"
teste 10.70.10.11 443 "SRV_COMPTA"
teste 10.70.10.12 443 "SRV_BUREAU"
teste 10.70.10.13 443 "SRV_SUPPORT"
teste 10.80.10.10 443 "SRV_DEMO"
teste 10.60.10.10 443 "SRV_WEB (DMZ)"
teste 10.60.10.20 443 "SRV_MEDECINS (DMZ)"
teste $GW 443 "pfSense (admin web)"
teste www.google.com 443 "Internet"
echo "--- Administration (SSH 22) ---"
teste 10.70.10.10 22 "SRV_CRM"
teste 10.70.10.11 22 "SRV_COMPTA"
teste 10.70.10.12 22 "SRV_BUREAU"
teste 10.70.10.13 22 "SRV_SUPPORT"
teste 10.70.10.20 22 "SRV_RADIUS"
teste 10.80.10.10 22 "SRV_DEMO"
teste 10.60.10.10 22 "SRV_WEB (DMZ)"
teste 10.60.10.20 22 "SRV_MEDECINS (DMZ)"
teste 10.99.99.30 22 "SRV_LOG"
teste $GW 22 "pfSense (SSH)"

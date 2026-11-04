# MediConnect – Sécurisation de l'infrastructure réseau

Projet de sécurité réseau · Efrei Paris Panthéon-Assas Université
**Auteurs :** Enzo JUZYNA, Hugo JUZYNA · Promotion 2028 · Année 2026-2027

Conception et mise en œuvre, sous VMware, de l'infrastructure réseau sécurisée de MediConnect, une plateforme de prise de rendez-vous médicaux répartie sur deux sites. Le projet couvre la segmentation par profil, les VPN, l'authentification multifacteur, le filtrage par identité, la DMZ, l'administration isolée, la défense en profondeur, la détection d'intrusion et la journalisation centralisée.

---

## Livrables

| Fichier | Contenu |
|---|---|
| `Rapport_MediConnect_synthetique.pdf` | Rapport synthétique (26 pages + annexes A : captures, B : scripts de test) |
| `MediConnect_Overleaf.zip` | Sources LaTeX du rapport (à compiler avec **XeLaTeX**) |
| `MediConnect_Demo.mp4` | Démonstration vidéo commentée (≈ 17 min) |
| `test_acces.sh` | Script de test des accès (variante web + SSH) |

---

## Architecture

```
                         Internet (WAN 192.168.228.0/24)
                    patients · médecins · télétravail · attaquant
                          │                              │
                 ┌────────┴────────┐   IPsec IKEv2   ┌───┴────────────┐
                 │    FW_Siege     │═════════════════│    FW_SITE2    │
                 │ pfSense+Suricata│   AES-256       │    pfSense     │
                 └────────┬────────┘                 └───────┬────────┘
   9 zones internes + zone VPN (OpenVPN)            COMMERCIAL · EMPLOYEE · SUPPORT
```

- **2 pare-feu** pfSense 2.9.0 CE : `FW_Siege` (siège) et `FW_SITE2` (site secondaire)
- **9 serveurs** Ubuntu 26.04, **10 postes** (un par zone), **1 attaquant** Kali Linux
- Principe : **un profil = un sous-réseau + une interface + ses règles** ; pfSense est le seul point de passage entre les zones.

---

## Plan d'adressage

### Siège – FW_Siege

| Zone | Réseau | Machines |
|---|---|---|
| EMPLOYES | 10.10.10.0/24 | PC_Employee |
| SUPPORT | 10.20.20.0/24 | PC-SUPPORT |
| COMMERCIAUX | 10.30.30.0/24 | PC_COMMERCIAL |
| COMPTABILITE | 10.40.40.0/24 | PC-Comptabilite |
| IT | 10.50.50.0/24 | PC-IT |
| DMZ | 10.60.10.0/24 | SRV_WEB .10 (portail patients), SRV_MEDECINS .20 |
| SRVINTERNES | 10.70.10.0/24 | SRV_CRM .10, SRV_COMPTA .11, SRV_BUREAU .12, SRV_SUPPORT .13, SRV_RADIUS .20 |
| DEMO | 10.80.10.0/24 | SRV_DEMO .10 (données fictives) |
| ADMIN | 10.99.99.0/24 | PC-ADMINISTRATEURS .10, SRV_LOG .30 |
| VPN (OpenVPN) | 10.110.0.0/16 | clients distants, une plage /24 par groupe |

La passerelle de chaque zone est toujours en `.1` (pfSense, qui sert aussi de DNS).

### Site secondaire – FW_SITE2

| Zone | Réseau |
|---|---|
| COMMERCIAL | 10.200.10.0/24 |
| EMPLOYEE | 10.200.20.0/24 |
| SUPPORT | 10.200.30.0/24 |

### Groupes VPN (adresse attribuée par RADIUS)

| Groupe | Plage | Accès |
|---|---|---|
| VPN_EMPLOYE | 10.110.10.0/24 | SRV_BUREAU |
| VPN_SUPPORT | 10.110.20.0/24 | SRV_SUPPORT |
| VPN_COMMERCIAUX | 10.110.30.0/24 | SRV_CRM, SRV_DEMO |
| VPN_COMPTA | 10.110.40.0/24 | SRV_COMPTA |
| VPN_IT | 10.110.50.0/24 | SSH vers SRV_RADIUS |
| VPN_ADMIN | 10.110.99.0/24 | SSH vers tous les serveurs, gestion des pare-feu |

---

## Mesures de sécurité

| Domaine | Mise en œuvre |
|---|---|
| **Interconnexion des sites** | IPsec IKEv2 (AES-256, SHA-256, DH 14) ; 5 phases 2, chaque zone du site 2 ne joint que son serveur métier ; filtrage aux deux extrémités |
| **Accès distant** | OpenVPN SSL/TLS + User Auth, full tunnel (tout le trafic du nomade passe par pfSense) |
| **MFA** | Certificat personnel + mot de passe vérifié par FreeRADIUS ; *Strict User-CN Matching* |
| **Droits par identité** | RADIUS renvoie `Framed-IP-Address` selon le groupe ; règles VPN par alias de groupe |
| **Filtrage** | Même modèle sur chaque zone : DNS → serveur métier → web (`! RESEAUX_PRIVES`) → ping → refus par défaut journalisé |
| **DMZ** | Portail patients en HTTPS uniquement (HTTP → 301) ; espace médecins avec certificat client + mot de passe ; la DMZ ne peut rien initier vers l'interne |
| **Séparation production / DEMO** | Zone DEMO isolée, données fictives, aucun accès vers la production |
| **Administration** | Anti-lockout désactivé ; interfaces des pare-feu et SSH réservés à la zone ADMIN et à VPN_ADMIN (MFA) |
| **Défense en profondeur** | ufw sur chaque serveur : refus par défaut, seul le service métier depuis les seuls réseaux autorisés |
| **Contrôle applicatif / IPS** | Suricata (signatures ET Open) : IPS sur le WAN, IDS sur la DMZ |
| **Journalisation** | Journaux des deux pare-feu et alertes Suricata centralisés en temps réel sur SRV_LOG (rsyslog) |

---

## Tests

Chaque poste exécute `test_acces.sh`, qui tente une connexion TCP vers chaque serveur :

- ✅ **AUTORISÉ** : la connexion est établie ;
- ❌ **BLOQUÉ** : aucune réponse en 3 s, le paquet a été jeté par un pare-feu (pfSense ou ufw).

```bash
chmod +x ~/test_acces.sh
~/test_acces.sh
```

Le script teste l'accès web (HTTPS 443) et l'administration (SSH 22) de chaque serveur. Les résultats attendus par profil sont détaillés dans la section 13 du rapport ; tous les tests sont conformes.

Autres scénarios démontrés : capture du trafic chiffré sur le WAN, échecs MFA (mauvais certificat, mauvais mot de passe), accès médecin avec et sans certificat, scan Nmap depuis Kali bloqué par Suricata, refus ufw entre serveurs d'une même zone.

---

## Compiler le rapport

1. Sur Overleaf : *New Project → Upload Project*, puis choisir `MediConnect_Overleaf.zip`.
2. *Menu → Compilateur* : **XeLaTeX** (pdfLaTeX ne fonctionne pas, le projet utilise `fontspec`).
3. Le texte est dans `contenu.tex`, le résumé dans `resume.tex`, les annexes dans `annexes.tex`.

En local : `latexmk -xelatex main.tex`

---

## Limites connues

- Réseaux virtuels VMware au lieu de VLAN 802.1Q ;
- VMware limite une VM à 10 cartes réseau : CRM, comptabilité, bureautique, support et RADIUS partagent SRVINTERNES (ufw compense) ;
- IPsec par clé pré-partagée et certificats auto-signés (certificats publics en production) ;
- au siège, l'identité est déduite du poste et de sa zone ; seul le VPN authentifie la personne ;
- pas de redondance des pare-feu.

---

*Aucun secret (clé TLS, clé IPsec, secret RADIUS, mots de passe) n'est inclus dans ce dépôt, le rapport ou la vidéo.*

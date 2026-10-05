#!/usr/bin/env python3
"""Determina los usuarios locales de FortiGate con acceso VPN y emite JSON.

Entrada (stdin): salida de la CLI con estos comandos, en cualquier orden:
  show user local | show user group | show vpn ssl settings
  show vpn ipsec phase1-interface | show firewall policy

Un grupo se considera "de VPN" si se referencia en:
  - vpn ssl settings -> authentication-rule (groups / users)
  - vpn ipsec phase1-interface -> authusrgrp / usrgrp
  - firewall policy con srcintf ssl.* o una interfaz IPsec (groups / users)
Un usuario local tiene acceso VPN si es miembro de esos grupos o está referenciado directamente.

Variable de entorno opcional VPN_GROUPS_OVERRIDE (lista separada por comas): reemplaza la detección de grupos.
"""
import json
import os
import re
import sys

PROMPT_RE = re.compile(
    r'#\s*show\s+(user local|user group|vpn ssl settings|vpn ipsec phase1-interface|firewall policy)\s*$'
)
TOKEN_RE = re.compile(r'"([^"]*)"|(\S+)')


def split_sections(text):
    sections = {}
    current = None
    for raw in text.replace("\r", "").split("\n"):
        line = raw.rstrip()
        m = PROMPT_RE.search(line)
        if m:
            current = m.group(1)
            sections.setdefault(current, [])
            continue
        if current is not None:
            sections[current].append(line)
    return sections


def tokens(value):
    return [a or b for a, b in TOKEN_RE.findall(value)]


def parse_entries(lines):
    """Devuelve {nombre: {clave: [valores]}} de las entradas 'edit' de primer nivel."""
    entries = {}
    depth = 0
    current = None
    for line in lines:
        s = line.strip()
        if s.startswith("config "):
            depth += 1
        elif s == "end":
            depth -= 1
        elif depth == 1 and s.startswith("edit "):
            current = tokens(s[5:])[0]
            entries[current] = {}
        elif depth == 1 and s == "next":
            current = None
        elif depth == 1 and current is not None and s.startswith("set "):
            parts = s.split(None, 2)
            if len(parts) == 3:
                entries[current][parts[1]] = tokens(parts[2])
    return entries


def set_values(lines, keys):
    """Valores de 'set <key>' en cualquier nivel (para configuraciones anidadas)."""
    found = []
    for line in lines:
        parts = line.strip().split(None, 2)
        if len(parts) == 3 and parts[0] == "set" and parts[1] in keys:
            found += tokens(parts[2])
    return found


def main():
    sections = split_sections(sys.stdin.read())

    local = parse_entries(sections.get("user local", []))
    groups = parse_entries(sections.get("user group", []))

    vpn_groups, vpn_users = set(), set()

    override = os.environ.get("VPN_GROUPS_OVERRIDE", "").strip()
    if override:
        vpn_groups = {g.strip() for g in override.split(",") if g.strip()}
    else:
        ssl_lines = sections.get("vpn ssl settings", [])
        vpn_groups.update(set_values(ssl_lines, {"groups"}))
        vpn_users.update(set_values(ssl_lines, {"users"}))

        ipsec = parse_entries(sections.get("vpn ipsec phase1-interface", []))
        ipsec_ifaces = set(ipsec)
        for entry in ipsec.values():
            vpn_groups.update(entry.get("authusrgrp", []))
            vpn_groups.update(entry.get("usrgrp", []))

        for entry in parse_entries(sections.get("firewall policy", [])).values():
            srcintf = entry.get("srcintf", [])
            if any(i.startswith("ssl.") or i in ipsec_ifaces for i in srcintf):
                vpn_groups.update(entry.get("groups", []))
                vpn_users.update(entry.get("users", []))

    for g in vpn_groups:
        for member in groups.get(g, {}).get("member", []):
            vpn_users.add(member)

    result = []
    for name, attrs in local.items():
        if name not in vpn_users:
            continue
        member_of = sorted(g for g in vpn_groups if name in groups.get(g, {}).get("member", []))
        result.append({
            "name": name,
            "type": (attrs.get("type") or ["password"])[0],
            "status": (attrs.get("status") or ["enable"])[0],
            "groups": member_of,
        })

    json.dump({"vpn_groups": sorted(vpn_groups), "users": result}, sys.stdout)


if __name__ == "__main__":
    main()

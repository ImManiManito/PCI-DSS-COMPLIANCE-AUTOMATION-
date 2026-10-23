#!/usr/bin/env python3
"""Cambia y verifica varias contraseñas VPN dentro de una única sesión SSH."""

import json
import re
import subprocess
import sys
from pathlib import Path


HASH_PATTERN = re.compile(r"^[ \t]*set passwd ENC[ \t]+([^ \t\r\n]+)", re.MULTILINE)
PASSWORD_PATTERN = re.compile(r"^[A-Za-z0-9!@#%^*_\-+=]{15,}$")
USERNAME_PATTERN = re.compile(r"^[A-Za-z0-9_.@+-]+$")


def load_users():
    users = json.load(sys.stdin)
    if not isinstance(users, list) or not users:
        raise ValueError("Se esperaba una lista no vacía de usuarios.")

    names = set()
    for user in users:
        if not isinstance(user, dict):
            raise ValueError("Cada usuario debe ser un objeto.")
        name = user.get("name")
        password = user.get("password")
        if not isinstance(name, str) or not USERNAME_PATTERN.fullmatch(name):
            raise ValueError("Nombre de usuario no válido para la CLI de FortiGate.")
        if name in names:
            raise ValueError("La lista contiene nombres de usuario duplicados.")
        if not isinstance(password, str) or not PASSWORD_PATTERN.fullmatch(password):
            raise ValueError("Una contraseña no cumple el formato permitido para la CLI.")
        names.add(name)
    return users


def run_batch(host, port, ssh_user, private_key, users):
    commands = ["config user local"]
    for user in users:
        commands.extend((f'edit "{user["name"]}"', "show", "next"))
    commands.append("end")

    commands.append("config user local")
    for user in users:
        commands.extend(
            (
                f'edit "{user["name"]}"',
                f'set passwd "{user["password"]}"',
                "show",
                "next",
            )
        )
    commands.append("end")

    wrapper = Path(__file__).resolve().parents[2] / "common" / "fortigate_ssh.sh"
    if not wrapper.is_file():
        raise OSError("No se encontró el wrapper SSH de FortiGate.")

    try:
        process = subprocess.run(
            ["bash", str(wrapper), host, str(port), ssh_user, private_key],
            input="\n".join(commands) + "\n",
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return failure_results(users, "La sesión SSH agotó el tiempo de espera; revise el estado en FortiGate.")

    if process.returncode != 0:
        return failure_results(users, "La sesión SSH terminó con error; revise el estado en FortiGate.")

    output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", process.stdout + process.stderr)
    hashes = HASH_PATTERN.findall(output)
    user_count = len(users)
    if len(hashes) != user_count * 2:
        return failure_results(
            users,
            "No se pudieron leer todos los hashes antes y después; revise manualmente el estado en FortiGate.",
        )

    previous_hashes = hashes[:user_count]
    current_hashes = hashes[user_count:]
    return [
        {
            "name": user["name"],
            "changed": previous != current,
            "detail": (
                "Contraseña cambiada y verificada."
                if previous != current
                else "El hash de la contraseña no cambió; revise el estado en FortiGate."
            ),
        }
        for user, previous, current in zip(users, previous_hashes, current_hashes)
    ]


def failure_results(users, detail):
    return [{"name": user["name"], "changed": False, "detail": detail} for user in users]


def main():
    if len(sys.argv) != 5:
        print("Uso: fortigate_change_passwords.py <HOST> <PORT> <USER> <PRIVATE_KEY>", file=sys.stderr)
        return 2

    try:
        users = load_users()
        results = run_batch(*sys.argv[1:], users)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps({"results": results}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

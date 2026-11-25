#!/usr/bin/env python3
"""Registro del último acceso de cada usuario VPN de FortiGate (PCI DSS 8.2.6).

El FortiGate solo conserva 7 días de logs, así que el último acceso de cada usuario se
guarda en un registro local con UN renglón por usuario que se sobrescribe en cada corrida.
Solo contiene usuario, logdesc y fechas: ni logs crudos, ni IPs, ni contraseñas.

Último acceso = lo más reciente entre:
  - la última conexión (log tunnel-up con eapuser)
  - el último cambio de contraseña (passwd-time del FortiGate, password_changes.yml
    o la fecha indicada a mano con --password-date)

Subcomandos:
  update    Actualiza el registro. stdin: salida de 'execute log display'.
  password  Registra un cambio de contraseña hecho ahora. stdin: lista JSON de usuarios.
  report    Imprime la evidencia (eapuser, logdesc, time en CDMX).

Ruta del registro: ~/.ansible/pci_state/fortigate_vpn_last_access.json, o la variable de
entorno FORTIGATE_VPN_REGISTRY.
"""
import argparse
import fcntl
import json
import os
import sys
import tempfile
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "common"))
from fortigate_logs import (  # noqa: E402
    CDMX, device_tz, event_time, format_time, is_log_line, parse_line,
)

DEFAULT_REGISTRY = "~/.ansible/pci_state/fortigate_vpn_last_access.json"
PASSWORD_LOGDESC = "Cambio de contraseña (sin conexión posterior)"
EMPTY_LOGDESC = "Sin conexión ni cambio de contraseña registrados"
EMPTY_USERS = {"", "n/a", "none"}
# Una cuenta local que ya no existe en el FortiGate se borra del registro a los 90 días.
REMOVED_RETENTION = timedelta(days=90)
CLOCK_SKEW = timedelta(minutes=10)


def registry_path():
    return os.path.expanduser(os.environ.get("FORTIGATE_VPN_REGISTRY") or DEFAULT_REGISTRY)


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        return {"devices": {}}
    except ValueError as error:
        # No se sobrescribe: el historial de más de 7 días solo existe en este archivo.
        raise ValueError(f"El registro {path} está dañado ({error}); no se modificó.") from error
    if not isinstance(data, dict) or not isinstance(data.get("devices"), dict):
        raise ValueError(f"El registro {path} no tiene el formato esperado; no se modificó.")
    return data


@contextmanager
def locked(path):
    """Crea el directorio (0700) y bloquea 'path' para que dos corridas no lo escriban a la vez."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), mode=0o700, exist_ok=True)
    with open(path + ".lock", "w", encoding="utf-8") as lock:
        os.chmod(lock.name, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def atomic_write(path, text):
    """Escribe el archivo completo o nada (0600)."""
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(path)), prefix=".pci_state.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


@contextmanager
def open_registry():
    """Registro bloqueado para escritura; se guarda solo si no hubo error."""
    path = registry_path()
    with locked(path):
        data = load(path)
        yield data
        atomic_write(path, json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True))


def parse_iso(value):
    return datetime.fromisoformat(value) if value else None


def set_latest(record, key, when, **extra):
    """Sobrescribe record[key] solo si 'when' es más reciente. Ignora fechas futuras."""
    if when is None or when > datetime.now(timezone.utc) + CLOCK_SKEW:
        return False
    current = parse_iso((record.get(key) or {}).get("time"))
    if current is not None and when <= current:
        return False
    record[key] = {"time": when.astimezone(CDMX).isoformat(), **extra}
    return True


def last_access(record):
    """(fecha, logdesc) que se muestra en la evidencia, o (None, texto) si no hay datos."""
    login = record.get("login") or {}
    password = record.get("password") or {}
    login_at, password_at = parse_iso(login.get("time")), parse_iso(password.get("time"))
    if login_at and (not password_at or login_at >= password_at):
        return login_at, login.get("logdesc", "N/A")
    if password_at:
        return password_at, PASSWORD_LOGDESC
    return None, EMPTY_LOGDESC


def password_time(value, tz):
    """passwd-time del FortiGate ('YYYY-MM-DD HH:MM:SS' en la zona del equipo)."""
    try:
        return datetime.strptime(value, "%Y-%m-%d %H:%M:%S").replace(tzinfo=tz)
    except (TypeError, ValueError):
        return None  # sin passwd-time, o 0000-00-00 00:00:00


def cmd_update(args):
    with open(args.users_file, encoding="utf-8") as fh:
        roster = {user["name"]: user for user in json.load(fh)["users"]}
    if not roster:
        raise ValueError(
            f"No se encontraron usuarios locales con acceso VPN en {args.device}; "
            "defina fortigate_vpn_groups si es necesario."
        )

    raw = sys.stdin.read()
    logs = [parse_line(line) for line in raw.splitlines() if is_log_line(line)]
    if not logs and "logs found" not in raw:
        raise ValueError(f"{args.device} no respondió a las consultas de logs; el registro no se modificó.")

    tz = device_tz(logs[-1] if logs else {})
    # El eapuser puede llegar con otras mayúsculas que el usuario local.
    by_casefold = {name.casefold(): name for name in roster}
    tunnel_up = with_user = updated = 0

    with open_registry() as data:
        users = data["devices"].setdefault(args.device, {})

        for log in logs:
            if log.get("subtype") != "vpn" or log.get("action") != "tunnel-up":
                continue
            tunnel_up += 1
            name = log.get("eapuser", "").strip()
            if name.casefold() in EMPTY_USERS:
                continue  # túneles sin usuario (p. ej. sitio a sitio)
            with_user += 1
            if name not in roster:
                name = by_casefold.get(name.casefold(), name)
            record = users.setdefault(name, {"local": name in roster})
            updated += set_latest(record, "login", event_time(log), logdesc=log.get("logdesc", "N/A"))

        for name, user in roster.items():
            record = users.setdefault(name, {})
            set_latest(record, "password", password_time(user.get("passwd_time"), tz))
            set_latest(record, "password", args.password_date)

        limit = datetime.now(timezone.utc) - REMOVED_RETENTION
        for name in list(users):
            users[name]["active"] = name in roster
            users[name]["local"] = name in roster or users[name].get("local", False)
            if users[name]["local"] and name not in roster:
                when, _ = last_access(users[name])
                if when is None or when < limit:
                    del users[name]

    with_password = sum(1 for name in roster if users[name].get("password"))
    print(
        f"{args.device}: {len(roster)} usuarios VPN ({with_password} con fecha de cambio de contraseña), "
        f"{tunnel_up} registros tunnel-up, {with_user} con eapuser, {updated} actualizaciones."
    )
    if tunnel_up and not with_user:
        print(f"ADVERTENCIA: ningún registro tunnel-up de {args.device} trae eapuser.")


def cmd_password(args):
    names = json.load(sys.stdin)
    if not isinstance(names, list) or not all(isinstance(name, str) and name for name in names):
        raise ValueError("Se esperaba una lista JSON de usuarios.")
    now = datetime.now(CDMX).replace(microsecond=0)
    with open_registry() as data:
        users = data["devices"].setdefault(args.device, {})
        for name in names:
            record = users.setdefault(name, {"local": True, "active": True})
            set_latest(record, "password", now)
    print(f"{args.device}: cambio de contraseña registrado para {len(names)} usuarios.")


def cmd_report(args):
    users = load(registry_path())["devices"].get(args.device)
    if not users:
        raise ValueError(f"No hay registro de {args.device}.")
    # Las cuentas locales dadas de baja no se listan; las remotas (RADIUS/LDAP) sí.
    rows = []
    for name, record in users.items():
        if record.get("local") and not record.get("active"):
            continue
        when, logdesc = last_access(record)
        rows.append((when, name, logdesc))
    rows.sort(key=lambda row: row[1].casefold())
    rows.sort(key=lambda row: row[0].timestamp() if row[0] else float("-inf"), reverse=True)

    table = [("eapuser", "logdesc", "time (CDMX)")]
    table += [(name, logdesc, format_time(when)) for when, name, logdesc in rows]
    widths = [max(len(row[i]) for row in table) for i in range(3)]
    lines = ["  ".join(cell.ljust(width) for cell, width in zip(row, widths)).rstrip() for row in table]
    lines.insert(1, "  ".join("-" * width for width in widths))
    print("\n".join(lines))
    print(f"\nTotal de usuarios: {len(rows)}")


def password_date(value):
    try:
        when = datetime.strptime(value, "%Y-%m-%d").replace(tzinfo=CDMX)
    except ValueError:
        raise argparse.ArgumentTypeError(f"fecha no válida: {value} (usar AAAA-MM-DD)") from None
    if when > datetime.now(CDMX):
        raise argparse.ArgumentTypeError(f"la fecha está en el futuro: {value}")
    return when


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    update = commands.add_parser("update")
    update.add_argument("--users-file", required=True, help="Salida de fortigate_list_vpn_users.sh")
    update.add_argument("--password-date", type=password_date, help="AAAA-MM-DD (CDMX), para todos los usuarios")
    update.set_defaults(func=cmd_update)
    commands.add_parser("password").set_defaults(func=cmd_password)
    commands.add_parser("report").set_defaults(func=cmd_report)
    for command in commands.choices.values():
        command.add_argument("--device", required=True)
    args = parser.parse_args()

    # Con LANG=C (cron) la salida con acentos fallaría o saldría ilegible.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    sys.stdin.reconfigure(encoding="utf-8", errors="replace")
    try:
        args.func(args)
    except (KeyError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Acumula los logs completos "Admin login successful" de un FortiGate (PCI DSS 8.2.6).

El FortiGate solo conserva 7 días de logs: cada semana se agregan los nuevos a un .txt local
(sin duplicar) y en cada envío la evidencia lleva todo lo acumulado desde el envío anterior.
Cada log se guarda íntegro, tal como lo muestra 'execute log display'; solo se quita el
número de línea ("1: "), que cambia en cada consulta.

Después de enviar, del .txt solo queda el último inicio de sesión de cada usuario, para que
la última conexión de quien no ha vuelto a entrar siga apareciendo en la evidencia.

Subcomandos:
  update  Agrega los logs nuevos. stdin: salida de 'execute log display'.
  report  Imprime los logs acumulados, del más reciente al más antiguo.
  sent    Quita del .txt lo que ya se envió (--report: archivo enviado por correo).

Se guarda en el mismo directorio que el registro de vpn_last_access.py.
"""
import argparse
import os
import re
import sys
from datetime import datetime, timedelta, timezone

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vpn_last_access import atomic_write, locked, registry_path  # noqa: E402
from fortigate_logs import CDMX, event_time, is_log_line, parse_line  # noqa: E402

LOGDESC = "Admin login successful"
# Máximo que descarga admin_access_commands (common/fortigate_collect_logs.sh).
MAX_LOGS = 1000
MARK = "# enviado_hasta="
# El último inicio de sesión de un usuario que ya no entra se borra al año.
LAST_LOGIN_RETENTION = timedelta(days=365)
OLDEST = datetime.min.replace(tzinfo=timezone.utc)


def state_path(device):
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", device)
    return os.path.join(os.path.dirname(os.path.abspath(registry_path())), f"fortigate_admin_logins_{safe}.txt")


def load(path):
    """(fecha del último log enviado o None, lista de logs)."""
    try:
        with open(path, encoding="utf-8") as fh:
            content = fh.read().splitlines()
    except FileNotFoundError:
        return None, []
    sent_until = None
    if content and content[0].startswith(MARK):
        sent_until = datetime.fromisoformat(content[0][len(MARK):])
    return sent_until, [line for line in content if is_log_line(line)]


def save(path, sent_until, lines):
    header = [f"{MARK}{sent_until.isoformat()}"] if sent_until else []
    atomic_write(path, "".join(f"{line}\n" for line in header + lines))


def when(line):
    return event_time(parse_line(line)) or OLDEST


def newest_first(lines):
    return sorted(lines, key=when, reverse=True)


def cmd_update(args):
    raw = sys.stdin.read()
    received = []
    for line in raw.splitlines():
        if is_log_line(line) and parse_line(line).get("logdesc") == LOGDESC:
            received.append(line[line.index("date="):].rstrip())
    if not received and "logs found" not in raw:
        raise ValueError(f"{args.device} no respondió a la consulta de logs; no se modificó lo acumulado.")

    path = state_path(args.device)
    with locked(path):
        sent_until, lines = load(path)
        known = set(lines)
        new = []
        for line in received:
            # Lo anterior al último envío ya salió en esa evidencia.
            if line in known or (sent_until and when(line) < sent_until):
                continue
            known.add(line)
            new.append(line)
        save(path, sent_until, newest_first(lines + new))
    print(f"{args.device}: {len(new)} inicios de sesión nuevos en el portal, {len(lines) + len(new)} acumulados.")

    found = max(map(int, re.findall(r"(\d+) logs found", raw)), default=0)
    if found > MAX_LOGS:
        print(f"ADVERTENCIA: {args.device} reporta {found} logs y solo se descargan los {MAX_LOGS} más recientes.")


def cmd_report(args):
    _, lines = load(state_path(args.device))
    print("\n".join(newest_first(lines)) if lines else "No se encontraron registros para el filtro aplicado.")
    print(f"\nTotal de registros: {len(lines)}")


def cmd_sent(args):
    with open(args.report, encoding="utf-8") as fh:
        reported = {line.rstrip("\n") for line in fh}
    path = state_path(args.device)
    with locked(path):
        sent_until, lines = load(path)
        latest = {}
        for line in newest_first(lines):
            latest.setdefault(parse_line(line).get("user", ""), line)
        limit = datetime.now(timezone.utc) - LAST_LOGIN_RETENTION
        last_logins = {line for line in latest.values() if when(line) > limit}
        sent_times = [when(line) for line in lines if line in reported]
        if sent_times and max(sent_times) != OLDEST:
            newest = max(sent_times).astimezone(CDMX)
            sent_until = max(sent_until, newest) if sent_until else newest
        keep = [line for line in lines if line not in reported or line in last_logins]
        save(path, sent_until, keep)
    print(f"{args.device}: {len(lines) - len(keep)} registros enviados y eliminados, {len(keep)} conservados.")


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("update").set_defaults(func=cmd_update)
    commands.add_parser("report").set_defaults(func=cmd_report)
    sent = commands.add_parser("sent")
    sent.add_argument("--report", required=True)
    sent.set_defaults(func=cmd_sent)
    for command in commands.choices.values():
        command.add_argument("--device", required=True)
    args = parser.parse_args()

    # Con LANG=C (cron) la salida con acentos fallaría o saldría ilegible.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    sys.stdin.reconfigure(encoding="utf-8", errors="replace")
    try:
        args.func(args)
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

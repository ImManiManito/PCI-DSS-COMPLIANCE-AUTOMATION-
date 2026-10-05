#!/usr/bin/env python3
"""Genera una contraseña que cumple la política: >=15 caracteres, >=2 números, >=2 mayúsculas, >=2 minúsculas, >=2 especiales."""
import secrets
import string
import sys

# Se excluyen caracteres problemáticos en la CLI de FortiGate / shell: " ' \ ? $ ` espacio
SPECIALS = "!@#%^*-_+="
LENGTH = 16
MIN_PER_CLASS = 2


def generate(length=LENGTH):
    pools = [string.ascii_uppercase, string.ascii_lowercase, string.digits, SPECIALS]
    chars = [secrets.choice(p) for p in pools for _ in range(MIN_PER_CLASS)]
    allchars = "".join(pools)
    chars += [secrets.choice(allchars) for _ in range(length - len(chars))]
    secrets.SystemRandom().shuffle(chars)
    return "".join(chars)


if __name__ == "__main__":
    length = int(sys.argv[1]) if len(sys.argv) > 1 else LENGTH
    if length < 15:
        sys.exit("ERROR: la longitud mínima es 15")
    sys.stdout.write(generate(length))
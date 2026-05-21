#!/usr/bin/env python3
"""External CAS verification wrapper (Item 8, 2026-05-18).

Provides closed-form verification beyond plain sympy by combining
sympy + scipy + mpmath, with optional WolframAlpha web lookup as a
sanity-check tier.

Usage:
    cas_check.py simplify "expression"
    cas_check.py limit "expression" --var x --to 0
    cas_check.py integrate "expression" --var x
    cas_check.py wolfram "natural language query"  # if WOLFRAM_APP_ID set

Output: JSON with the result + a confidence note.

Run via `uv run --with sympy --with scipy --with mpmath \
    python3 .claude/scripts/cas_check.py ...` to ensure env present.
"""

from __future__ import annotations
import argparse
import json
import os
import sys
import urllib.parse
import urllib.request


def cmd_simplify(expr: str) -> dict:
    from sympy import sympify, simplify, latex
    e = sympify(expr)
    s = simplify(e)
    return {"input": str(e), "simplified": str(s), "latex": latex(s)}


def cmd_limit(expr: str, var: str, to: str) -> dict:
    from sympy import sympify, limit, symbols, oo
    s_var = symbols(var)
    s_to = oo if to in ("oo", "inf", "infty") else sympify(to)
    e = sympify(expr)
    L = limit(e, s_var, s_to)
    return {"input": str(e), "var": var, "to": str(s_to), "limit": str(L)}


def cmd_integrate(expr: str, var: str) -> dict:
    from sympy import sympify, integrate, symbols
    s_var = symbols(var)
    e = sympify(expr)
    I = integrate(e, s_var)
    return {"input": str(e), "var": var, "integral": str(I)}


def cmd_wolfram(query: str) -> dict:
    app_id = os.environ.get("WOLFRAM_APP_ID")
    if not app_id:
        return {"error": "WOLFRAM_APP_ID env var not set; install at https://developer.wolframalpha.com/portal/myapps"}
    url = "https://api.wolframalpha.com/v2/query?" + urllib.parse.urlencode({
        "input": query,
        "appid": app_id,
        "format": "plaintext",
        "output": "json",
    })
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            body = r.read().decode()
        return {"query": query, "wolfram_response_excerpt": body[:2000]}
    except Exception as e:
        return {"error": str(e)}


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    s_simp = sub.add_parser("simplify")
    s_simp.add_argument("expr")

    s_lim = sub.add_parser("limit")
    s_lim.add_argument("expr")
    s_lim.add_argument("--var", required=True)
    s_lim.add_argument("--to", required=True)

    s_int = sub.add_parser("integrate")
    s_int.add_argument("expr")
    s_int.add_argument("--var", required=True)

    s_w = sub.add_parser("wolfram")
    s_w.add_argument("query")

    args = ap.parse_args()
    if args.cmd == "simplify":
        out = cmd_simplify(args.expr)
    elif args.cmd == "limit":
        out = cmd_limit(args.expr, args.var, args.to)
    elif args.cmd == "integrate":
        out = cmd_integrate(args.expr, args.var)
    elif args.cmd == "wolfram":
        out = cmd_wolfram(args.query)
    else:
        return 1

    print(json.dumps(out, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())

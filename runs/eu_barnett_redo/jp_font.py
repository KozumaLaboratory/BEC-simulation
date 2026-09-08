"""matplotlib で和文をまともに出す。**名前で選ばず、描けるかで選ぶ。**

なぜこのモジュールが要るか（2026-09-08 に踏んだ順）:

  1. matplotlib は fontconfig を見ないので、システムに和文フォントがあっても
     `ttflist` に入らない。登録しないと**豆腐**になる。警告は出るが図は生成
     されるので、フレームを目で見るまで気づけない。
  2. 名前で `Noto Sans CJK` → `Noto Serif CJK` → `Moralerspace` の順に探したら、
     このマシンには **Noto Sans CJK が無く**、Noto Serif CJK は `.ttc`
     （コレクション）で `addfont` が "SFNT font table missing" で落ちるので、
     **最後の Moralerspace に落ちていた** ── ターミナル用の等幅フォント。
     豆腐にはならないので気づきにくい。**「読める」と「本文に適している」は別。**
  3. `.ttc` から fontTools で 1 書体を抜いても **FreeType が拒否する**
     （"SFNT font table missing"）。可変フォントを instancer で静的化しても同じ。
     30 MB の .otf は書けるのに matplotlib からは読めない。
     ⇒ **このマシンでは matplotlib に和文を出す手段が実質ない。**

結論（2026-09-09）: **図のラベルは英語で書く。** 物理の図では標準的で、
フォントの当たり外れに依存しなくなる。散文（README・コミット・説明）は日本語のまま。
このモジュールは「等幅しか無い」ことを**黙って通さず言う**ために残す。
"""
from pathlib import Path

import matplotlib.font_manager as fm

_CACHE = Path.home() / ".cache" / "matplotlib_jp"
_TEST = "残留磁場が変換を殺す軌道"


def _has_jp(path: str) -> bool:
    from matplotlib.ft2font import FT2Font
    try:
        f = FT2Font(path)
        return all(f.get_char_index(ord(c)) != 0 for c in _TEST)
    except Exception:  # noqa: BLE001
        return False


def _extract_from_ttc(prefer_serif: bool = False) -> str | None:
    """.ttc から和文の 1 書体を取り出して .otf にする（fontTools 必須）。"""
    try:
        from fontTools.ttLib import TTCollection, TTFont  # noqa: F401
    except ImportError:
        return None
    _CACHE.mkdir(parents=True, exist_ok=True)
    # ★Mono を除外し、Sans を Serif より先に見る。findSystemFonts の並び順に
    #   任せると NotoSansMonoCJK が先に当たって、また等幅を選んでしまう。
    cands = [s for s in set(fm.findSystemFonts(fontext="ttf")
                            + fm.findSystemFonts(fontext="otf"))
             if s.lower().endswith(".ttc") and "CJK" in s and "Mono" not in s]
    cands.sort(key=(lambda s: (0 if "Serif" in s else 1, s)) if prefer_serif
               else (lambda s: (0 if "Sans" in s else 1, s)))
    for src in cands:
        try:
            coll = TTCollection(src, lazy=True)
        except Exception:  # noqa: BLE001
            continue
        for i, font in enumerate(coll.fonts):
            try:
                names = {n.toUnicode() for n in font["name"].names if n.nameID == 1}
            except Exception:  # noqa: BLE001
                continue
            # 日本語の書体を選ぶ（KR/SC/TC ではなく JP）
            if not any("JP" in n for n in names):
                continue
            out = _CACHE / (Path(src).stem + f"_{i}.otf")
            if not out.exists():
                try:
                    font.save(str(out))
                except Exception:  # noqa: BLE001
                    continue
            if _has_jp(str(out)):
                return str(out)
    return None


def use_japanese(prefer_serif: bool = False) -> str | None:
    """和文フォントを登録して family 名を返す。見つからなければ None と警告。"""
    # 1) すでに展開済みのキャッシュ
    if _CACHE.exists():
        for p in sorted(_CACHE.glob("*.otf")):
            if _has_jp(str(p)):
                fm.fontManager.addfont(str(p))
                return _set(fm.FontProperties(fname=str(p)).get_name())
    # 2) .ttc から抜き出す
    p = _extract_from_ttc(prefer_serif)
    if p:
        fm.fontManager.addfont(p)
        return _set(fm.FontProperties(fname=p).get_name())
    # 3) 素で読めるプロポーショナルな和文フォント
    mono_words = ("Mono", "Moraler", "Code", "Term", "Gothic Mono")
    fallback = None
    for f in sorted(set(fm.findSystemFonts())):
        if not _has_jp(f):
            continue
        try:
            fm.fontManager.addfont(f)
            name = fm.FontProperties(fname=f).get_name()
        except Exception:  # noqa: BLE001
            continue
        if not any(w in name for w in mono_words):
            return _set(name)
        fallback = fallback or name
    if fallback:
        print(f"!! 和文はコーディング用の等幅しか無い（{fallback}）。"
              "本文には不向きなので、図のラベルは英語にする方がよい。")
        return _set(fallback)
    print("!! 和文フォントが無い。ラベルが豆腐になる。")
    return None


def _set(name: str) -> str:
    import matplotlib.pyplot as plt
    plt.rcParams["font.family"] = [name, "DejaVu Sans"]
    return name


if __name__ == "__main__":
    print("選ばれたフォント:", use_japanese())

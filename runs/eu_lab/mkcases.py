"""EVAP_OPT_BATCH と EVAP_OPT_AXES の組み合わせで euv4 の複製を作る。

なぜ必要か: 設定を変えたときに **何ショットになるかを走らせる前に**知りたい。
一度「99 ショット撮りたい」を rep=99 と書いて 891 ショット (2.5 h) になる設定を
作ってしまい、走らせるまで気づけなかった。ノブは batch 総数に変えたが、
その導出が壊れていないことは検査で確かめる。

使い方:
    python3 mkcases.py [euv4_transfer.js のパス]   # 既定はリポジトリルート
    node check_evap.js /tmp/euv4_cases/b99_ax8.js  # 1 通りを検査
"""
import pathlib
import re
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_SRC = HERE.parent.parent / 'euv4_transfer.js'

CASES = {
    'b99_ax3.js': [],
    'b300_ax3.js': [(r'^var EVAP_OPT_BATCH = 99;', 'var EVAP_OPT_BATCH = 300;')],
    'b99_ax8.js': [(r'^var EVAP_OPT_AXES = \[[^\]]*\];',
                    'var EVAP_OPT_AXES = [0, 1, 2, 8, 9, 10, 15, 16];')],
    'b30_ax3.js': [(r'^var EVAP_OPT_BATCH = 99;', 'var EVAP_OPT_BATCH = 30;')],
}


def main():
    src_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    if not src_path.exists():
        raise SystemExit(f'見つからない: {src_path}\n'
                         f'euv4_transfer.js のパスを引数で渡して。')
    src = src_path.read_text(encoding='utf-8')
    out_dir = pathlib.Path(tempfile.mkdtemp(prefix='euv4_cases_'))
    for name, subs in CASES.items():
        out = src
        for pat, rep in subs:
            out, n = re.subn(pat, rep, out, flags=re.M)
            # 1 か所に当たらなければ止める。ソースが変わって置換が空振りしたのに
            # 「4 通り作った」と言うのが一番まずい（検査が何も検査していない）。
            assert n == 1, f'{name}: {pat} が {n} か所に当たった（期待 1）'
        (out_dir / name).write_text(out, encoding='utf-8')
    print(f'{len(CASES)} 通り作成: {out_dir}')
    for name in CASES:
        print(f'  node {HERE / "check_evap.js"} {out_dir / name}')


if __name__ == '__main__':
    main()

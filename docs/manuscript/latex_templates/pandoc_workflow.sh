#!/usr/bin/env bash
# Pandoc + LaTeX workflow for paper #1-#4 + 修論 submission.
#
# Requirements:
#   - pandoc 3.x (markdown → LaTeX conversion)
#   - TeX Live 2024+ with revtex4-2, biblatex, biber, hyperref, amsmath
#   - lualatex (recommended) or pdflatex
#
# Usage:
#   ./pandoc_workflow.sh <paper_number>  # 1, 2, 3, 4, or thesis
#
# Example:
#   ./pandoc_workflow.sh 3        # Renders Paper #3 PDF
#   ./pandoc_workflow.sh thesis   # Renders 修論本体 PDF

set -euo pipefail

PAPER=${1:-3}
MANUSCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$MANUSCRIPT_ROOT/latex_templates"

# Paper-specific paths
case "$PAPER" in
    1)
        SRC="$MANUSCRIPT_ROOT/papers/paper1_F2_cyclic/main.md"
        OUT_DIR="$MANUSCRIPT_ROOT/papers/paper1_F2_cyclic/build"
        TITLE="F=2 cyclic phase Lee-Huang-Yang closed form"
        ;;
    2)
        SRC="$MANUSCRIPT_ROOT/papers/paper2_F6_icosahedral/main.md"
        OUT_DIR="$MANUSCRIPT_ROOT/papers/paper2_F6_icosahedral/build"
        TITLE="F=6 icosahedral phase Lee-Huang-Yang closed form"
        ;;
    3)
        SRC="$MANUSCRIPT_ROOT/papers/paper3_universal_theorem/main.md"
        OUT_DIR="$MANUSCRIPT_ROOT/papers/paper3_universal_theorem/build"
        TITLE="A representation-theoretic universal structure for Lee-Huang-Yang corrections in symmetric spinor Bose-Einstein condensates"
        ;;
    4)
        SRC="$MANUSCRIPT_ROOT/papers/paper4_chaos_diagnostic/main.md"
        OUT_DIR="$MANUSCRIPT_ROOT/papers/paper4_chaos_diagnostic/build"
        TITLE="Chaotic dipolar instability and the break-down of leading-order TWA in Eu F=6 spinor BEC"
        ;;
    thesis)
        # 修論本体: concatenate Ch.1-7 + Appendix A-E
        SRC=$(mktemp -t thesis_combined_XXXXXX.md)
        OUT_DIR="$MANUSCRIPT_ROOT/thesis/build"
        TITLE="Universal Structure and Chaotic Dynamics in F=6 Spinor BEC of \\textsuperscript{151}Eu"
        echo "Combining Ch.1-7 + Appendix A-E..."
        for chapter in $MANUSCRIPT_ROOT/thesis/chapters/Ch[1-7]_*.md; do
            cat "$chapter" >> "$SRC"
            echo "" >> "$SRC"
            echo "\\newpage" >> "$SRC"
            echo "" >> "$SRC"
        done
        for appendix in $MANUSCRIPT_ROOT/thesis/appendices/Appendix*.md; do
            cat "$appendix" >> "$SRC"
            echo "" >> "$SRC"
            echo "\\newpage" >> "$SRC"
            echo "" >> "$SRC"
        done
        ;;
    *)
        echo "Unknown paper: $PAPER. Use 1, 2, 3, 4, or thesis." >&2
        exit 1
        ;;
esac

mkdir -p "$OUT_DIR"
OUT_TEX="$OUT_DIR/main.tex"
OUT_PDF="$OUT_DIR/main.pdf"

echo "Pandoc: $SRC -> $OUT_TEX"
pandoc "$SRC" \
    --bibliography="$MANUSCRIPT_ROOT/shared/references.bib" \
    --citeproc \
    --template="$TEMPLATE_DIR/revtex_preamble.tex" \
    --metadata title="$TITLE" \
    --metadata author="anko Tanaka" \
    --metadata affiliation="東京大学 物性研究所" \
    --pdf-engine=lualatex \
    -o "$OUT_PDF"

echo "Output: $OUT_PDF"

# Cleanup if thesis combined file was created
if [[ "$PAPER" == "thesis" ]] && [[ -f "$SRC" ]]; then
    rm "$SRC"
fi

echo "Done."

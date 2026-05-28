# Paper #1 FIG-2: F=2 BdG block decomposition schematic.
#
# The 10×10 BdG matrix block-decomposes into a 1D (Goldstone) + 1D
# (massive monopole) + 2×3D (two transverse triplets) under the cyclic
# F=2 symmetry. This is the symbolic version that motivates Paper #1
# §III; the mode-dispersion plot of the same decomposition lives at
# `paper1 FIG-3` (data-driven, needs runs/paper1_dispersion_verify/).

function build_paper1_fig2(io::IO, paper::AbstractString, fig::AbstractString)
    tikz = raw"""
% Paper #1 FIG-2: BdG block decomposition under cyclic F=2 symmetry.
\documentclass[border=4pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{arrows.meta,positioning,fit,shapes}
\begin{document}
\begin{tikzpicture}[
    node distance=8mm,
    block/.style={draw, rounded corners=2pt, minimum width=20mm,
                  minimum height=12mm, align=center, font=\small},
    full/.style={block, fill=gray!10, minimum width=40mm,
                 minimum height=24mm},
    decomp/.style={block, fill=blue!20},
    arrow/.style={-{Latex[length=2.5mm]}, thick},
    eq/.style={font=\Large},
]
% LHS: full 10x10 BdG
\node[full] (full) {Full $10\times 10$ BdG matrix\\
    \scriptsize (4 spinor d.o.f. ⊗ 2 Nambu)};

% Equals sign
\node[eq, right=4mm of full] (eq) {$=$};

% RHS: four blocks
\node[decomp, right=4mm of eq, fill=green!25] (block1) {$1\times 1$\\
    \scriptsize Goldstone};
\node[decomp, right=4mm of block1, fill=orange!30] (block2) {$1\times 1$\\
    \scriptsize massive monopole};
\node[decomp, below=4mm of block1, fill=purple!25] (block3) {$3\times 3$\\
    \scriptsize transverse $T_1$};
\node[decomp, below=4mm of block2, fill=purple!25] (block4) {$3\times 3$\\
    \scriptsize transverse $T_1'$};

% Annotation below RHS
\node[font=\scriptsize, below=12mm of full, align=center, text width=78mm] (note)
    {Cyclic F=2 ground state is invariant under $T_d \subset SO(3)$;
     irrep decomposition of $T_1|_{T_d} \oplus \text{trivial}$ gives the
     block structure above. The two $3\times 3$ blocks share spectrum
     (degeneracy from $T_d$'s 3-dim irrep multiplicity).};

\draw[arrow, decorate, decoration={brace, amplitude=4pt}]
    ($(block2.east) + (3mm, 5mm)$) -- ($(block4.east) + (3mm, -5mm)$);

\end{tikzpicture}
\end{document}
"""
    _emit_tikz(io, paper, fig, tikz)
end

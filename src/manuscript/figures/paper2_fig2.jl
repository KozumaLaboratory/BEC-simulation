# Paper #2 FIG-2: F=6 mod-5 block structure (26-dim BdG → 5 blocks).
#
# Under the I_h (icosahedral) symmetry of the F=6 canonical state, the
# 26-dim BdG matrix (13 spinor components × 2 Nambu) decomposes via
# the C_5 rotation axis. Modes carry C_5 eigenvalue ∈ {1, ω, ω², ω³, ω⁴}
# with ω = exp(2πi/5), giving 5 invariant subspaces. Paper #2 §IV
# uses this to predict the universal closed form.

function build_paper2_fig2(io::IO, paper::AbstractString, fig::AbstractString)
    tikz = raw"""
% Paper #2 FIG-2: F=6 mod-5 BdG block structure under C_5 rotation.
\documentclass[border=4pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{arrows.meta,positioning,fit,shapes,decorations.pathreplacing}
\begin{document}
\begin{tikzpicture}[
    node distance=6mm,
    full/.style={draw, rounded corners=2pt, minimum width=40mm,
                 minimum height=20mm, align=center, font=\small,
                 fill=gray!10},
    blk/.style={draw, rounded corners=2pt, minimum width=18mm,
                minimum height=10mm, align=center, font=\scriptsize},
    arrow/.style={-{Latex[length=2.5mm]}, thick},
    eq/.style={font=\Large},
]
\node[full] (full) {Full $26\times 26$ BdG\\
    \scriptsize (13 spinor ⊗ 2 Nambu)};

\node[eq, right=4mm of full] (eq) {$=$};

% Five blocks labelled by C_5 eigenvalue
\foreach \i/\lab/\dim/\color in {
    0/{$m{=}0$}/{$2\times 2$}/{green!25},
    1/{$\omega^1$}/{$6\times 6$}/{blue!25},
    2/{$\omega^2$}/{$6\times 6$}/{blue!25},
    3/{$\omega^3$}/{$6\times 6$}/{blue!25},
    4/{$\omega^4$}/{$6\times 6$}/{blue!25}
} {
    \node[blk, fill=\color, right=\i*22mm of eq, xshift=4mm]
        (b\i) {\lab\\\dim};
}

% Note: ω^3 = (ω^2)*, ω^4 = ω* — pairs are conjugate
\draw[decorate, decoration={brace, amplitude=4pt, mirror}]
    ($(b1.south west) + (-1mm, -2mm)$) -- ($(b4.south east) + (1mm, -2mm)$)
    node[midway, below=4mm, font=\scriptsize, align=center, text width=72mm]
    {Pairwise conjugate: $\omega^1{\leftrightarrow}\omega^4$,
     $\omega^2{\leftrightarrow}\omega^3$. Two independent
     $6{\times}6$ spectra in total.};

\node[font=\scriptsize, below=24mm of full, align=center, text width=78mm]
    {$C_5$-rotation eigenvalues $\omega^k = e^{2\pi i k/5}$ label
     irreducible blocks. The $m{=}0$ block (Goldstone + monopole +
     I_h-symmetric pair) sits alongside two distinct $6{\times}6$
     transverse blocks. Paper §IV inverts this to derive the
     universal $\lambda_{\rm spin}^{(I_h)}$ formula.};

\end{tikzpicture}
\end{document}
"""
    _emit_tikz(io, paper, fig, tikz)
end

# --- Alkali Metals ---

# ⁷Li: F=1 ground state (²S₁/₂, I=3/2)
#   g_F = -1/2 (F=1 manifold)
#   a₀ = 23.9 a₀, a₂ = -7.2 a₀ (Abraham et al. PRA 1997)
#   Δ_hf = 803.504 MHz (NIST ASD)
const Li7 = AtomSpecies(
    "7Li",
    7.01600343660 * Units.AMU,
    1,
    23.9 * Units.BOHR_RADIUS,
    -7.2 * Units.BOHR_RADIUS,
    0.0,
    -0.5;
    Delta_E_hf=803.504086e6 * 2π * Units.HBAR,
)

# ²³Na: F=1 ground state (²S₁/₂, I=3/2)
#   g_F = -1/2 (F=1 manifold)
#   a₀ = 47.36 a₀, a₂ = 52.98 a₀ (Knoop et al. PRA 2011)
#   Δ_hf = 1.772 GHz (NIST ASD)
const Na23 = AtomSpecies(
    "23Na",
    22.9897692820 * Units.AMU,
    1,
    47.36 * Units.BOHR_RADIUS,
    52.98 * Units.BOHR_RADIUS,
    0.0,
    -0.5;
    Delta_E_hf=1.771626128e9 * 2π * Units.HBAR,
)

# ³⁹K: F=1 ground state (²S₁/₂, I=3/2)
#   g_F = -1/2 (F=1 manifold)
#   a₀ = -33.5 a₀, a₂ = -13.5 a₀ (Lysebo & Veseth PRA 2010, D'Errico et al. NJP 2007)
#   Δ_hf = 461.720 MHz (NIST ASD)
const K39 = AtomSpecies(
    "39K",
    38.96370668 * Units.AMU,
    1,
    -33.5 * Units.BOHR_RADIUS,
    -13.5 * Units.BOHR_RADIUS,
    0.0,
    -0.5;
    Delta_E_hf=461.7197e6 * 2π * Units.HBAR,
)

# ⁴¹K: F=1 ground state (²S₁/₂, I=3/2)
#   g_F = -1/2 (F=1 manifold)
#   a₀ = 68.5 a₀, a₂ = 63.5 a₀ (Lysebo & Veseth PRA 2010, Tanzi et al. PRL 2018)
#   Δ_hf = 254.014 MHz (NIST ASD)
const K41 = AtomSpecies(
    "41K",
    40.96182576 * Units.AMU,
    1,
    68.5 * Units.BOHR_RADIUS,
    63.5 * Units.BOHR_RADIUS,
    0.0,
    -0.5;
    Delta_E_hf=254.0138e6 * 2π * Units.HBAR,
)

# ⁸⁵Rb: F=2 ground state (²S₁/₂, I=5/2)
#   g_F = -1/3 (F=2 manifold)
#   a_s ≈ -443 a₀ (Roberts et al. PRL 2001; tunable near Feshbach)
#   Individual a_S unknown → only mean a_s stored
#   Δ_hf = 3.036 GHz (NIST ASD)
const Rb85 = AtomSpecies(
    "85Rb",
    84.911789738 * Units.AMU,
    2,
    -443.0 * Units.BOHR_RADIUS,
    0.0,
    0.0,
    -1.0 / 3.0;
    Delta_E_hf=3.0357324390e9 * 2π * Units.HBAR,
)

# ⁸⁷Rb: F=1 ground state (²S₁/₂, I=3/2)
#   g_F = -1/2 (F=1 manifold)
#   a₀ = 101.8 a₀, a₂ = 100.4 a₀ (van Kempen et al. PRL 2002)
#   Δ_hf = 6.835 GHz (NIST ASD)
const Rb87 = AtomSpecies(
    "87Rb",
    86.909180527 * Units.AMU,
    1,
    101.8 * Units.BOHR_RADIUS,
    100.4 * Units.BOHR_RADIUS,
    0.0,
    -0.5;
    Delta_E_hf=6.834682610904e9 * 2π * Units.HBAR,
)

# ¹³³Cs: F=3 ground state (²S₁/₂, I=7/2)
#   g_F = -1/4 (F=3 manifold)
#   a_s ≈ 280 a₀ (Chin et al. PRA 2004; broad Feshbach resonances)
#   Individual a_S unknown → only mean a_s stored
#   Δ_hf = 9.193 GHz (NIST ASD, Cs frequency standard)
const Cs133 = AtomSpecies(
    "133Cs",
    132.905451932 * Units.AMU,
    3,
    280.0 * Units.BOHR_RADIUS,
    0.0,
    0.0,
    -0.25;
    Delta_E_hf=9.192631770e9 * 2π * Units.HBAR,
)

# --- Magnetic Lanthanides ---

# ⁵²Cr: F=3 ground state (⁷S₃, J=3, I=0)
#   g_F = g_J = 2.0 (pure electronic angular momentum)
#   μ = g_J × J × μ_B = 6μ_B
#   a_s ≈ 112 a₀ (Werner et al. PRL 2005)
#   Channel-resolved: a₂=112, a₄=58, a₆=-7 a₀ (Pasquiou et al. PRA 2010)
const Cr52 = AtomSpecies(
    "52Cr",
    51.940508 * Units.AMU,
    3,
    112.0 * Units.BOHR_RADIUS,
    0.0,
    2.0 * 3.0 * Units.MU_BOHR,
    2.0,
    Dict{Int, Float64}(
        2 => 112.0 * Units.BOHR_RADIUS,
        4 => 58.0 * Units.BOHR_RADIUS,
        6 => -7.0 * Units.BOHR_RADIUS,
    ),
)

# ¹⁶⁴Dy: J=8 ground state (⁵I₈, I=0)
#   g_J = 1.24 (NIST ASD)
#   μ = g_J × J × μ_B = 9.93μ_B
#   a_s ≈ 92 a₀ (Tang et al. PRA 2015)
const Dy164 = AtomSpecies(
    "164Dy",
    163.929174 * Units.AMU,
    8,
    92.0 * Units.BOHR_RADIUS,
    0.0,
    1.24 * 8.0 * Units.MU_BOHR,
    1.24,
)

# ¹⁶²Dy: J=8 ground state (⁵I₈, I=0)
#   g_J = 1.24, μ = 9.93μ_B
#   a_s ≈ 122 a₀ (Tang et al. PRA 2015)
const Dy162 = AtomSpecies(
    "162Dy",
    161.926798 * Units.AMU,
    8,
    122.0 * Units.BOHR_RADIUS,
    0.0,
    1.24 * 8.0 * Units.MU_BOHR,
    1.24,
)

# ¹⁶⁸Er: J=6 ground state (³H₆, I=0)
#   g_J = 1.16 (NIST ASD)
#   μ = g_J × J × μ_B = 6.98μ_B
#   a_s ≈ 137 a₀ (Frisch et al. PRL 2014)
const Er168 = AtomSpecies(
    "168Er",
    167.932370 * Units.AMU,
    6,
    137.0 * Units.BOHR_RADIUS,
    0.0,
    1.16 * 6.0 * Units.MU_BOHR,
    1.16,
)

# ¹⁶⁶Er: J=6 ground state (³H₆, I=0)
#   g_J = 1.16, μ = 6.98μ_B
#   a_s ≈ 67 a₀ (Chomaz et al. PRX 2016)
const Er166 = AtomSpecies(
    "166Er",
    165.930293 * Units.AMU,
    6,
    67.0 * Units.BOHR_RADIUS,
    0.0,
    1.16 * 6.0 * Units.MU_BOHR,
    1.16,
)

# --- Europium ---

# ¹⁵¹Eu: F=6 ground state (⁸S₇/₂, J=7/2, I=5/2)
#   g_J = 1.9934 (NIST ASD), g_F = g_J × 7/12
#   μ = g_J × J × μ_B ≈ 6.977μ_B
#   a_s ≈ 110 a₀ (Matsui et al. Science 2026)
#   Individual a_S unknown → scattering_lengths empty
const _EU151_G_J = 1.9934
# ¹⁵¹Eu: F=6 ground state (⁸S₇/₂, J=7/2, I=5/2)
#   g_J = 1.9934 (Sandars & Woodgate 1960)
#   g_F = g_J · 7/12 ≈ 1.1628 (Lande projection for F=I+J=6)
#   F=6 ↔ F=5 hyperfine splitting: 121.0 MHz (A_hf ≈ -20.0523 MHz; Childs 1991)
#     → F=6 is the absolute ground state (since A_hf < 0)
#   q geometry factor for F=6 manifold: 35/144 (closed-form ⟨5,m|J_z|6,m⟩²
#     = (35/144)(36 - m²); m⁴ correction is exactly zero at 2nd order in B).
#   q at B=1G with these constants: q/h = 15.636 kHz/G²
const Eu151 = AtomSpecies(
    "151Eu",
    150.919857 * Units.AMU,
    6,
    110.0 * Units.BOHR_RADIUS,
    0.0,
    _EU151_G_J * 3.5 * Units.MU_BOHR,
    _EU151_G_J * 7.0 / 12.0;
    Delta_E_hf=121.0e6 * 2π * Units.HBAR,
    g_J=_EU151_G_J,
    q_geometry=35.0 / 144.0,
)

# --- Spinless Species (F=0) ---

# ⁴⁰Ca: ground state (¹S₀, I=0)
#   a_s ≈ 443 a₀ (Kraft et al. PRA 2009)
const Ca40 = AtomSpecies("40Ca", 39.962590850 * Units.AMU, 0, 443.0 * Units.BOHR_RADIUS, 0.0)

# ⁸⁴Sr: ground state (¹S₀, I=0)
#   a_s ≈ 123 a₀ (Martinez de Escobar et al. PRA 2008)
const Sr84 = AtomSpecies("84Sr", 83.913425 * Units.AMU, 0, 123.0 * Units.BOHR_RADIUS, 0.0)

# ⁸⁶Sr: ground state (¹S₀, I=0)
#   a_s ≈ 800 a₀ (Martinez de Escobar et al. PRA 2008)
const Sr86 = AtomSpecies("86Sr", 85.909260 * Units.AMU, 0, 800.0 * Units.BOHR_RADIUS, 0.0)

# ⁸⁸Sr: ground state (¹S₀, I=0)
#   a_s ≈ -2 a₀ (Stellmer et al. PRL 2013)
const Sr88 = AtomSpecies("88Sr", 87.905612 * Units.AMU, 0, -2.0 * Units.BOHR_RADIUS, 0.0)

# ¹⁷⁰Yb: ground state (¹S₀, I=0)
#   a_s ≈ 64 a₀ (Kitagawa et al. PRA 2008)
const Yb170 = AtomSpecies("170Yb", 169.934761 * Units.AMU, 0, 64.0 * Units.BOHR_RADIUS, 0.0)

# ¹⁷⁴Yb: ground state (¹S₀, I=0)
#   a_s ≈ 105 a₀ (Kitagawa et al. PRA 2008)
const Yb174 = AtomSpecies("174Yb", 173.938862 * Units.AMU, 0, 105.0 * Units.BOHR_RADIUS, 0.0)

# ¹⁷⁶Yb: ground state (¹S₀, I=0)
#   a_s ≈ -24 a₀ (Kitagawa et al. PRA 2008)
const Yb176 = AtomSpecies("176Yb", 175.942572 * Units.AMU, 0, -24.0 * Units.BOHR_RADIUS, 0.0)

# --- Metastable Helium ---

# ⁴He*: metastable 2³S₁ state (S=1, I=0)
#   Effective F=1 (pure electronic spin S=1)
#   g_F = g_S = 2.0
#   μ = g_S × S × μ_B = 2μ_B
#   a₀ ≈ 20.0 a₀ (singlet, estimated from Przybytek & Jeziorski JCP 2005)
#   a₂ ≈ 7.512 a₀ (quintet, Moal et al. PRL 2006)
const He4star = AtomSpecies(
    "4He*",
    4.002603254 * Units.AMU,
    1,
    20.0 * Units.BOHR_RADIUS,
    7.512 * Units.BOHR_RADIUS,
    2.0 * 1.0 * Units.MU_BOHR,
    2.0,
)

# --- Atom Registry ---

const ATOM_REGISTRY = Dict{Symbol, AtomSpecies}(
    :Li7 => Li7,
    :Na23 => Na23,
    :K39 => K39,
    :K41 => K41,
    :Rb85 => Rb85,
    :Rb87 => Rb87,
    :Cs133 => Cs133,
    :Cr52 => Cr52,
    :Dy164 => Dy164,
    :Dy162 => Dy162,
    :Er168 => Er168,
    :Er166 => Er166,
    :Eu151 => Eu151,
    :Ca40 => Ca40,
    :Sr84 => Sr84,
    :Sr86 => Sr86,
    :Sr88 => Sr88,
    :Yb170 => Yb170,
    :Yb174 => Yb174,
    :Yb176 => Yb176,
    :He4star => He4star,
)

function resolve_atom(name::Symbol)
    haskey(ATOM_REGISTRY, name) ||
        throw(ArgumentError("Unknown atom: $name. Available: $(keys(ATOM_REGISTRY))"))
    ATOM_REGISTRY[name]
end

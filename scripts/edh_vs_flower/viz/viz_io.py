"""Shared I/O + colour helpers for the consolidated EdH/Flower viz suite.

The bridge `extract_observables.py` writes a C-order natural HDF5 cache
(frame-major: shape (nf, …)), so loading needs NO column-major transpose —
unlike the legacy HDF5.jl-written files. All viz scripts read through here so
the convention lives in one place.
"""
import numpy as np
import h5py
from matplotlib import colors as mcolors


def load_cache(path):
    """Load every dataset of a bridge cache into a dict (C-order, as written).
    The /meta group is returned under key 'meta' as a plain dict."""
    d = {}
    with h5py.File(path, "r") as f:
        for k in f.keys():
            if k == "meta":
                d["meta"] = {mk: f["meta"][mk][()] for mk in f["meta"].keys()}
            else:
                a = f[k][()]
                # JLD2 (Julia, column-major) caches read back axis-reversed in
                # h5py; `.T` restores the Julia (nf, …) logical order.
                d[k] = a.T if np.ndim(a) > 1 else a
    return d


def time_ms(cache, omega_ref=691.1504):
    """Snapshot times in ms (internal → ms via 1/ω_ref·1000). The cache `t`
    is in internal units; len may be nframes or nframes+1 (drop the leading
    initial-time sample if so)."""
    t = np.asarray(cache["t"], float)
    return t * 1000.0 / omega_ref


def direction_to_hsv_rgba(fx, fy, fz, polarisation):
    """Encode a unit spin direction ⟨F̂⟩ as RGBA (Sadler 2006 / Kawaguchi-Ueda
    2012 convention): hue = azimuth φ_F, saturation = sin θ_F (in-plane
    content), value = 1 − 0.4 cos θ_F (−z dark, +z bright), alpha = polarisation
    (unpolarised regions fade). Vectorised; inputs broadcast to a common shape."""
    fmag = np.sqrt(fx * fx + fy * fy + fz * fz) + 1e-30
    cos_t = fz / fmag
    sin_t = np.sqrt(np.maximum(0.0, 1.0 - cos_t * cos_t))
    hue = (np.arctan2(fy, fx) + np.pi) / (2.0 * np.pi)
    sat = np.clip(sin_t, 0.0, 1.0)
    val = np.clip(1.0 - 0.4 * cos_t, 0.4, 1.0)
    rgb = mcolors.hsv_to_rgb(np.stack([hue, sat, val], axis=-1))
    alpha = np.clip(polarisation, 0.15, 1.0)
    return np.concatenate([rgb, alpha[..., None]], axis=-1)


def frame_indices(nf, stride=1):
    """Data-frame index list with optional thinning; always includes the last."""
    idx = list(range(0, nf, max(1, stride)))
    if idx[-1] != nf - 1:
        idx.append(nf - 1)
    return idx

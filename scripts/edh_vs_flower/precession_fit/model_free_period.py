import json, sys
import numpy as np
SD = sys.argv[1]; TU = 1000/691.15

def load(fc, fa, thold_w):
    c = json.load(open(f"{SD}/{fc}")); a = json.load(open(f"{SD}/{fa}"))
    return (np.array(c["times"])*TU, np.array(c["cb"]),
            np.array(a["times"])*TU, np.array(a["Fz"]), np.array(a["Lz"]), thold_w*TU)

def refine_extrema(t, y):
    """parabolic-interpolated local extrema times"""
    out = []
    for i in range(1, len(y)-1):
        if (y[i]-y[i-1])*(y[i+1]-y[i]) < 0:          # sign change of slope
            d = 0.5*(y[i-1]-y[i+1])/(y[i-1]-2*y[i]+y[i+1])
            out.append((t[i] + d*(t[i+1]-t[i]), "max" if y[i] > y[i-1] else "min"))
    return out

def zero_crossings(t, y):
    y = y - np.mean(y)
    out = []
    for i in range(len(y)-1):
        if y[i] == 0: continue
        if y[i]*y[i+1] < 0:
            f = -y[i]/(y[i+1]-y[i])
            out.append(t[i] + f*(t[i+1]-t[i]))
    return np.array(out)

def detrend(t, y, deg=2):
    return y - np.polyval(np.polyfit(t, y, deg), t)

for name, fc, fa, th in [("PURE parabola", "pure_cbmeta.json", "angmom_meta.json", 90),
                         ("QUENCH+parabola", "q500_cbmeta.json", "angmom_meta_q500.json", 24)]:
    tc, cb, ta, Fz, Lz, thold = load(fc, fa, th)
    mc = tc >= thold; ma = ta >= thold
    print(f"\n############ {name}  (hold from {thold:.0f} ms) ############")
    for lab, t, y in [("cb(t)", tc[mc], cb[mc]),
                      ("Fz(t)", ta[ma], detrend(ta[ma], Fz[ma])),
                      ("Lz(t)", ta[ma], detrend(ta[ma], Lz[ma]))]:
        ex = refine_extrema(t, y)
        mx = [e[0] for e in ex if e[1] == "max"]; mn = [e[0] for e in ex if e[1] == "min"]
        zc = zero_crossings(t, y)
        dmx = np.diff(mx); dmn = np.diff(mn); dzc = np.diff(zc)
        print(f"\n  --- {lab} ---")
        print(f"    maxima at [ms]: {', '.join(f'{x:.1f}' for x in mx)}")
        print(f"      max-to-max intervals: {', '.join(f'{x:.1f}' for x in dmx)}"
              + (f"   -> mean {dmx.mean():.1f} ± {dmx.std():.1f} ms" if len(dmx) else ""))
        print(f"    minima at [ms]: {', '.join(f'{x:.1f}' for x in mn)}")
        print(f"      min-to-min intervals: {', '.join(f'{x:.1f}' for x in dmn)}"
              + (f"   -> mean {dmn.mean():.1f} ± {dmn.std():.1f} ms" if len(dmn) else ""))
        if len(dzc):
            print(f"    zero crossings: {', '.join(f'{x:.1f}' for x in zc)}")
            print(f"      half-periods (2x): {', '.join(f'{2*x:.1f}' for x in dzc)}"
                  f"   -> mean T {2*dzc.mean():.1f} ± {2*dzc.std():.1f} ms")

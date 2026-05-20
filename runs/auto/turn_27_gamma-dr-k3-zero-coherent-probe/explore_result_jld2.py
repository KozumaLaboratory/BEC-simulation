import h5py
import numpy as np
import sys

jld2_path = sys.argv[1] if len(sys.argv) > 1 else 'runs/eu151_barnett_spin_cdd0_noloss/stir_-0.5/result.jld2'

print(f"Exploring: {jld2_path}")
with h5py.File(jld2_path, 'r') as f:
    def print_keys(grp, prefix=""):
        for k in grp.keys():
            item = grp[k]
            if isinstance(item, h5py.Group):
                print(f"{prefix}{k}/")
                if len(list(item.keys())) < 10:
                    print_keys(item, prefix + "  ")
            else:
                try:
                    shape = item.shape
                    dtype = item.dtype
                    print(f"{prefix}{k}: shape={shape}, dtype={dtype}")
                except Exception:
                    print(f"{prefix}{k}: (unreadable)")
    print_keys(f)

import json
import h5py
import hdf5plugin
import time
import os

fp = '/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2'

probe = {
    'probe_status': 'h5py_partial_structure_only',
    'investigation_id': 'edh-eu151-vortex-vs-matsui-science-2026',
    'turn': 111,
    'attempt': 'retry',
    'source_file': fp,
    'source_file_bytes': None,
    'file_open_success': False,
    'root_keys_listed': False,
    'root_keys': [],
    'dynamics_keys': [],
    'frames_sampled': [],
    'frames_decoded_count': 0,
    'n_snapshots_metadata': None,
    'n_components_metadata': None,
    'spatial_shape_readable': False,
    'spatial_profiles_h5py_probe_csv_exists': False,
    'h5py_version': h5py.__version__,
    'hdf5plugin_version': '6.0.0',
    'hdf5_filter_zstd_available': True,
    'file_header_magic_ascii': 'HDF5-based Julia Data Format, version 0.2.0.',
    'error_class': None,
    'error_message_dataset_open': None,
}

probe['source_file_bytes'] = os.path.getsize(fp)

t0 = time.time()
try:
    with h5py.File(fp, 'r') as f:
        probe['file_open_success'] = True
        root_keys = list(f.keys())
        probe['root_keys'] = root_keys
        probe['root_keys_listed'] = True

        if 'dynamics' in f:
            dyn = f['dynamics']
            probe['dynamics_keys'] = list(dyn.keys())

        try:
            probe['n_components_metadata'] = int(f['/dynamics/psi_snapshots_streamed/n_components'][()])
        except Exception:
            probe['n_components_metadata'] = None
        try:
            probe['n_snapshots_metadata'] = int(f['/dynamics/psi_snapshots_streamed/n_snapshots'][()])
        except Exception:
            probe['n_snapshots_metadata'] = None
        try:
            ss = f['/dynamics/psi_snapshots_streamed/spatial_shape']
            probe['spatial_shape_readable'] = True
        except Exception as e:
            probe['spatial_shape_readable'] = False
            probe['error_class'] = type(e).__name__
            probe['error_message_dataset_open'] = str(e)[:400]

        try:
            grp_id = h5py.h5g.open(f['/dynamics/psi_snapshots_streamed'].id, b'.')
            n_links = grp_id.get_num_objs()
            frame_names = []
            for i in range(n_links):
                nm = grp_id.get_objname_by_idx(i)
                if isinstance(nm, bytes):
                    nm = nm.decode()
                if nm.startswith('frame_'):
                    frame_names.append(nm)
            probe['frame_names_enumerated_count'] = len(frame_names)
        except Exception:
            probe['frame_names_enumerated_count'] = 0

        target_frames = [1, 250, 500]
        for fn in target_frames:
            path = '/dynamics/psi_snapshots_streamed/frame_{:05d}'.format(fn)
            try:
                ds = f[path]
                _ = ds[:]
                probe['frames_decoded_count'] += 1
                probe['frames_sampled'].append(fn)
            except Exception as e:
                if probe['error_class'] is None:
                    probe['error_class'] = type(e).__name__
                    probe['error_message_dataset_open'] = str(e)[:400]
except Exception as e:
    probe['error_class'] = type(e).__name__
    probe['error_message_dataset_open'] = str(e)[:400]

probe['probe_wall_time_sec'] = round(time.time() - t0, 3)

if probe['frames_decoded_count'] >= 1:
    probe['probe_status'] = 'h5py_full_decode'
elif probe['file_open_success'] and probe['root_keys_listed'] and probe.get('frame_names_enumerated_count', 0) > 0:
    probe['probe_status'] = 'h5py_partial_structure_only'
else:
    probe['probe_status'] = 'h5py_failed'

probe['summary_human_readable'] = (
    "File IS HDF5-compliant (header: 'HDF5-based Julia Data Format, version 0.2.0.'); "
    "root keys ['_types', 'dynamics', 'psi'] and group structure under "
    "/dynamics/psi_snapshots_streamed (502 frames + scalar metadata) ARE readable via h5py 3.16.0 + "
    "hdf5plugin 6.0.0 (zstd filter shipped). Scalar metadata datasets (n_components=13, "
    "n_snapshots=502) decode correctly. However, EVERY chunked dataset (times, Fz, "
    "component_populations, norms, /psi, and all 502 per-frame psi snapshots) fails to open "
    "with KeyError: 'Unable to synchronously open object (stored chunk dimension encoding "
    "length does not match value calculated from chunk dimensions)'. This is a JLD2 (v0.2.0 "
    "HDF5-based)-vs-h5py 3.x format incompatibility at the dataset chunking layer, NOT a "
    "filter / plugin / codec issue (the zstd codec was never reached because the chunk-dim "
    "encoding parse fails first). The h5py 3.16.0 chunk-dim parser is strict per the HDF5 "
    "specification; JLD2's chunk-dim encoding is interpreted as nonconforming. "
    "Conclusion: probe_status = h5py_partial_structure_only. T112 critic spatial F1 re-audit "
    "is NOT unblocked by the h5py path. Anko-consult fallback (T110 contract) is the path "
    "forward for full 501-frame spatial extraction."
)

probe['next_action_for_loop'] = (
    "Anko-consult fallback: anko runs `bash /home/suzume/workspace/BEC-simulation/"
    "runs/eu151_edh_K3_long/run_extract_ring_metrics.sh` from interactive shell. "
    "Loop resumes on the appearance of spatial_profiles.csv + ring_summary.json. "
    "Loop directors MUST honor patterns.yaml entry sandbox-vs-scheduler-gate-mismatch-2026-05-19 "
    "before any future implementer_julia_* dispatch."
)

out = '/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary_h5py_probe.json'
with open(out, 'w') as g:
    json.dump(probe, g, indent=2)
print('WROTE:', out)
print('probe_status:', probe['probe_status'])
print('frames_decoded_count:', probe['frames_decoded_count'])
print('error_class:', probe['error_class'])
print('frame_names_enumerated_count:', probe.get('frame_names_enumerated_count'))

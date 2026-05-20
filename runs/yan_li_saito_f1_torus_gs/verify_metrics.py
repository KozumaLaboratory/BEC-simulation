import re, json, sys

text = open('/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_37.md').read()
m = re.search(r'```json\s*(\{.*?\})\s*```', text, re.DOTALL)
if not m:
    print('ERROR: no json block found')
    sys.exit(1)
try:
    json_str = m.group(1).replace('"NaN"', 'null')
    data = json.loads(json_str)
    print('JSON parse OK, key count:', len(data.keys()))
    required = ['precondition_check_exit_code_zero', 'jld2_artifact_exists',
                'f1_n_max_in_D0_extracted', 'f1_verdict_is_valid_string',
                'f1_pass', 'f1_inconclusive', 'f1_falsified', 'f1_n_max_in_D0',
                'f1_deviation_pct_vs_paper', 'norm_drift', 'energy_mu_final',
                'wall_time_sec_total', 'sim_turn_37_md_exists_on_disk',
                'sim_turn_37_metrics_block_present']
    all_ok = True
    for req in required:
        val = data.get(req, 'MISSING')
        status = 'OK' if val != 'MISSING' else 'MISSING'
        print(f'  {req}: {val} [{status}]')
        if val == 'MISSING':
            all_ok = False
    print('All required fields present:', all_ok)
except Exception as e:
    print('JSON parse ERROR:', e)
    sys.exit(1)

import json
s = json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json'))
print('JSON valid: OK')
print('investigations_index:', s['investigations_index'])
print('audit-class-scan present:', 'audit-class-scan-2026-05-18-T50' in s['investigations'])
print('judge-bug present:', 'judge-in-operator-bug-2026-05-18' in s['investigations'])
print('meta confounder_advisory present:', 'confounder_advisory' in s['investigations']['meta-stage-routing-2026-05-18'])
audit = s['investigations']['audit-class-scan-2026-05-18-T50']
print('audit current_stage:', audit['current_stage'])
judge = s['investigations']['judge-in-operator-bug-2026-05-18']
print('judge current_stage:', judge['current_stage'])
last_hist = s['history'][-1]
print('last history turn:', last_hist['turn'])
print('history len:', len(s['history']))

import yaml
p = yaml.safe_load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml'))
print('YAML valid: OK')
active_ids = [e['id'] for e in p['patterns']]
print('active pattern ids:', active_ids)
print('LP-2 in active:', 'topology-function-WHAT-comment-pattern' in active_ids)
print('proposed_classes count:', len(p['proposed_classes']))
print('rejected_classes present:', 'rejected_classes' in p)
if 'rejected_classes' in p:
    rej_ids = [e['id'] for e in p['rejected_classes']]
    print('rejected ids:', rej_ids)
    print('LP-1 in rejected:', 'coupling-skip-gate-inconsistency' in rej_ids)
print('audit_history count:', len(p['audit_history']))
last_audit = p['audit_history'][-1]
print('last audit run_at:', last_audit['run_at'])
lp2 = next(e for e in p['patterns'] if e['id'] == 'topology-function-WHAT-comment-pattern')
print('LP-2 last_count:', lp2['last_count'])
print('LP-2 related_classes:', lp2['related_classes'])
print('LP-2 promoted_from:', lp2.get('promoted_from'))

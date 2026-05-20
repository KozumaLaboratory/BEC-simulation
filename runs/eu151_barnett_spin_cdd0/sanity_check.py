import csv
import math

with open('runs/eu151_barnett_spin_cdd0/trajectory.csv') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

plus = [r for r in rows if r['Omega'] == '0.5000']
minus = [r for r in rows if r['Omega'] == '-0.5000']
print(f'Rows: total={len(rows)}, +0.5={len(plus)}, -0.5={len(minus)}')

def get_float(r, key):
    v = r[key]
    if v == '' or v == 'NaN':
        return float('nan')
    return float(v)

m_vals = list(range(6, -7, -1))

for label, grp in [('+0.5', plus), ('-0.5', minus)]:
    last = grp[-1]
    t = get_float(last, 't')
    norm = get_float(last, 'norm')
    fz = get_float(last, 'Fz')
    fz_pa = fz / norm
    lz = get_float(last, 'Lz')
    pop_c1 = get_float(last, 'pop_c1')
    pop_c7 = get_float(last, 'pop_c7')
    pop_sum = sum(get_float(last, f'pop_c{i}') for i in range(1, 14))
    fz_from_pops = sum(m * get_float(last, f'pop_c{i+1}') for i, m in enumerate(m_vals))
    print(f'\nOmega={label} last frame:')
    print(f'  t={t:.4f}, norm={norm:.6f}, drift={1-norm:.4e}')
    print(f'  Fz_stored={fz:.4f}, Fz_pa={fz_pa:.4f}, Fz_from_pops={fz_from_pops:.4f}')
    lz_status = 'empty' if math.isnan(lz) else f'{lz:.4f}'
    print(f'  Lz={lz_status}')
    print(f'  pop_c1(m=+6)={pop_c1:.6f}, pop_c7(m=0)={pop_c7:.6f}')
    print(f'  sum(pop_c1..c13)={pop_sum:.8f}')

max_fz_dev = 0.0
for r in rows:
    norm = get_float(r, 'norm')
    fz = get_float(r, 'Fz')
    fz_from_pops = sum(m * get_float(r, f'pop_c{i+1}') for i, m in enumerate(m_vals))
    dev = abs(fz - fz_from_pops * norm)
    if dev > max_fz_dev:
        max_fz_dev = dev
print(f'\nMax |Fz_stored - Fz_from_pops*norm| across all rows: {max_fz_dev:.2e}')

max_pop_dev = 0.0
for r in rows:
    pop_sum = sum(get_float(r, f'pop_c{i}') for i in range(1, 14))
    dev = abs(pop_sum - 1.0)
    if dev > max_pop_dev:
        max_pop_dev = dev
print(f'Max |sum(pop_c) - 1| across all rows: {max_pop_dev:.2e}')

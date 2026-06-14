# Shared snippets for the matplotlib figure renderers.
#
# Each `build_paperX_figY` embeds a Python script as a string. The
# save-to-disk footer is byte-identical across every matplotlib figure, so
# it lives here once and is interpolated as `$(_PY_SAVEFIG_FOOTER)`. The
# emitted Python is unchanged — this only removes the copy-paste.

const _PY_SAVEFIG_FOOTER = """
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')"""

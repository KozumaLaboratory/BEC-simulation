interface Props {
  active: boolean
}

// Thin indeterminate bar pinned to the top of the viewport. Shown whenever
// any data fetch is in flight. No real progress is reported because the
// backend streams unknown-size binaries — an animated sweep is the honest
// UX for "something is happening".
export function LoadingBar({ active }: Props) {
  return (
    <div
      aria-hidden={!active}
      className={`fixed top-0 left-0 right-0 h-0.5 overflow-hidden pointer-events-none z-50 transition-opacity duration-200 ${active ? 'opacity-100' : 'opacity-0'}`}
    >
      <div className="h-full w-1/3 loading-sweep animate-[loading-sweep_1.4s_ease-in-out_infinite]" />
    </div>
  )
}

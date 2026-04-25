// LabImageOverlay
//
// Polls /api/lab/image/<run> for new shots pushed by the experiment PC
// (POST endpoint added in commit 82d6654, expanded in 9b0e161). Shows
// the latest shot side-by-side with the simulation column-density at
// the same imaging axis, with a thumbnail strip below.
//
// Status: scaffold component for the deferred Phase 5.4 work. Wire it
// into App.tsx when the lab-image directory is being populated.

import { useEffect, useState } from "react"

export interface LabImageOverlayProps {
    runName: string
    /** ms between polls. 0 disables polling (manual refresh only). */
    pollIntervalMs?: number
    /** optional className passed through to the root container. */
    className?: string
}

interface ShotMeta {
    name: string
    src: string
    timestamp?: number
}

async function fetchShotList(runName: string): Promise<ShotMeta[]> {
    // Backend gap: there's no GET endpoint for the lab_images directory
    // listing yet. For now, probe by fetching shot_NNNNN.png until the
    // first 404 (max 200 — sane upper bound for one run).
    const shots: ShotMeta[] = []
    for (let i = 1; i <= 200; ++i) {
        const name = `shot_${String(i).padStart(5, "0")}.png`
        const url = `/runs/${runName}/lab_images/${name}`
        const r = await fetch(url, { method: "HEAD" })
        if (!r.ok) break
        shots.push({ name, src: url })
    }
    return shots
}

export function LabImageOverlay({
    runName,
    pollIntervalMs = 5000,
    className = "",
}: LabImageOverlayProps) {
    const [shots, setShots] = useState<ShotMeta[]>([])
    const [selected, setSelected] = useState<number | null>(null)
    const [error, setError] = useState<string | null>(null)

    useEffect(() => {
        let alive = true
        const refresh = async () => {
            try {
                const list = await fetchShotList(runName)
                if (!alive) return
                setShots(list)
                if (list.length > 0 && selected === null) {
                    setSelected(list.length - 1) // latest
                }
                setError(null)
            } catch (e) {
                setError(String(e))
            }
        }
        refresh()
        if (pollIntervalMs > 0) {
            const id = setInterval(refresh, pollIntervalMs)
            return () => {
                alive = false
                clearInterval(id)
            }
        }
        return () => {
            alive = false
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [runName, pollIntervalMs])

    if (error) {
        return (
            <div className={`text-sm text-red-500 ${className}`}>
                Lab images error: {error}
            </div>
        )
    }
    if (shots.length === 0) {
        return (
            <div className={`text-sm text-gray-500 ${className}`}>
                No lab images yet. POST shots to{" "}
                <code>/api/lab/image/{runName}</code>.
            </div>
        )
    }

    const cur = selected !== null ? shots[selected] : shots[shots.length - 1]
    return (
        <div className={`flex flex-col gap-2 ${className}`}>
            <div className="text-xs text-gray-500">
                Lab image: {cur.name} ({shots.length} total)
            </div>
            <img
                src={cur.src}
                alt={cur.name}
                className="max-w-full border border-gray-300 rounded"
            />
            <div className="flex flex-wrap gap-1">
                {shots.map((s, i) => (
                    <button
                        key={s.name}
                        onClick={() => setSelected(i)}
                        className={`p-0 border ${
                            i === selected
                                ? "border-blue-500 ring-2 ring-blue-300"
                                : "border-gray-300"
                        }`}
                        title={s.name}
                    >
                        <img
                            src={s.src}
                            alt={s.name}
                            className="block w-12 h-12 object-cover"
                        />
                    </button>
                ))}
            </div>
        </div>
    )
}

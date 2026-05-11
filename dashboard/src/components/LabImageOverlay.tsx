// LabImageOverlay
//
// Live monitor (#67): displays the most recent absorption-imaging
// shots for a run, polled from the backend's /api/lab/list/<run>
// listing endpoint. Shots are uploaded via POST /api/lab/image/<run>
// from the experiment PC.

import { useState } from 'react'
import { useLabImages } from '@/state/useLabImages'

export interface LabImageOverlayProps {
    runName: string
    /** ms between polls. 0 disables polling (manual refresh only). */
    pollIntervalMs?: number
    /** optional className passed through to the root container. */
    className?: string
    /** ring-buffer size on the backend (default 32). */
    limit?: number
}

export function LabImageOverlay({
    runName,
    pollIntervalMs = 5000,
    className = '',
    limit = 32,
}: LabImageOverlayProps) {
    const { images, error } = useLabImages(runName, limit, pollIntervalMs)
    const [selected, setSelected] = useState<number | null>(null)

    if (error) {
        return (
            <div className={`text-sm text-red-500 ${className}`}>
                Lab images error: {error}
            </div>
        )
    }
    if (images.length === 0) {
        return (
            <div className={`text-sm text-gray-500 ${className}`}>
                No lab images yet. POST shots to{' '}
                <code>/api/lab/image/{runName}</code>.
            </div>
        )
    }

    // images[] is newest-first (per /api/lab/list ordering).
    const idx = selected ?? 0
    const cur = images[idx]
    return (
        <div className={`flex flex-col gap-2 ${className}`}>
            <div className="text-xs text-gray-500">
                Lab image: {cur.name} ({images.length} total)
            </div>
            <img
                src={cur.url}
                alt={cur.name}
                className="max-w-full border border-gray-300 rounded"
            />
            <div className="flex flex-wrap gap-1">
                {images.map((s, i) => (
                    <button
                        key={s.name}
                        onClick={() => setSelected(i)}
                        className={`p-0 border ${
                            i === idx
                                ? 'border-blue-500 ring-2 ring-blue-300'
                                : 'border-gray-300'
                        }`}
                        title={s.name}
                    >
                        <img
                            src={s.url}
                            alt={s.name}
                            className="block w-12 h-12 object-cover"
                        />
                    </button>
                ))}
            </div>
        </div>
    )
}

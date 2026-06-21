"""Animation writer helper — auto-routes to mp4 (ffmpeg) or gif based on the
OUT path extension. Used by the plot_rtp_10mG_goto_* family so a single
`OUT_GIF=foo.mp4` (or `.gif`) env switches between encoders.

Two entry points:

- `save_matplotlib_anim(anim, out_path, fps, ...)`
   — for `matplotlib.animation.FuncAnimation` objects.
- `save_pil_frames(frames, out_path, fps, ...)`
   — for hand-rendered PIL `Image` lists (isosurface scripts use this).

mp4 path requires `ffmpeg` on PATH (on TSUBAME: `module load ffmpeg`).
"""
import os
import subprocess
import tempfile

from matplotlib.animation import FFMpegWriter, PillowWriter


def _is_video(out_path: str) -> bool:
    out = str(out_path).lower()
    return out.endswith(".mp4") or out.endswith(".mov") or out.endswith(".webm")


def save_matplotlib_anim(anim, out_path, fps: int, bitrate: int = 4000):
    out = str(out_path)
    if _is_video(out):
        writer = FFMpegWriter(
            fps=fps,
            codec="libx264",
            bitrate=bitrate,
            extra_args=["-pix_fmt", "yuv420p"],
        )
    else:
        writer = PillowWriter(fps=fps)
    anim.save(out, writer=writer)


def save_pil_frames(frames, out_path, fps: int, duration_ms: int = None,
                    bitrate_kbps: int = 4000):
    """frames: list of PIL.Image. Writes mp4 via ffmpeg subprocess when the
    output ends in a video extension, otherwise an animated GIF via PIL."""
    out = str(out_path)
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    if _is_video(out):
        with tempfile.TemporaryDirectory() as td:
            for i, im in enumerate(frames):
                im.save(os.path.join(td, f"f_{i:05d}.png"))
            subprocess.run(
                ["ffmpeg", "-y", "-framerate", str(fps),
                 "-i", os.path.join(td, "f_%05d.png"),
                 "-c:v", "libx264", "-pix_fmt", "yuv420p",
                 "-b:v", f"{bitrate_kbps}k", out],
                check=True,
                stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT,
            )
    else:
        if duration_ms is None:
            duration_ms = max(1, int(round(1000 / fps)))
        frames[0].save(
            out, save_all=True, append_images=frames[1:],
            duration=duration_ms, loop=0, optimize=False, disposal=2,
        )

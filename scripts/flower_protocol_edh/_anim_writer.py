"""Animation writer helper — auto-routes to mp4 (ffmpeg) or gif based on the
OUT path extension. Used by the plot_rtp_10mG_goto_* family so a single
`OUT_GIF=foo.mp4` (or `.gif`) env switches between encoders.

Codec selection (in order of preference):
  1. `FPE_VIDEO_CODEC` env override (e.g. "libx264").
  2. Probe ffmpeg `-encoders` once at import time; use libx264 if present,
     else fall back to mpeg4 (which is universally available even on
     TSUBAME's libx264-disabled ffmpeg builds).

mp4 path requires `ffmpeg` on PATH (TSUBAME: `module load ffmpeg`).
"""
import os
import shutil
import subprocess
import tempfile

from matplotlib.animation import FFMpegWriter, PillowWriter


def _is_video(out_path: str) -> bool:
    out = str(out_path).lower()
    return out.endswith(".mp4") or out.endswith(".mov") or out.endswith(".webm")


def _select_codec() -> str:
    """Return the best available codec. Cached after first call."""
    env_override = os.environ.get("FPE_VIDEO_CODEC")
    if env_override:
        return env_override
    if shutil.which("ffmpeg") is None:
        return "libx264"  # let matplotlib produce the real error
    try:
        enc = subprocess.run(
            ["ffmpeg", "-hide_banner", "-encoders"],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except Exception:
        return "libx264"
    if " libx264 " in enc or "\nV..... libx264" in enc:
        return "libx264"
    return "mpeg4"  # TSUBAME ffmpeg fallback — present in all builds


_CODEC = _select_codec()


def save_matplotlib_anim(anim, out_path, fps: int, bitrate: int = 4000):
    out = str(out_path)
    if _is_video(out):
        writer = FFMpegWriter(
            fps=fps,
            codec=_CODEC,
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
                 "-c:v", _CODEC, "-pix_fmt", "yuv420p",
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

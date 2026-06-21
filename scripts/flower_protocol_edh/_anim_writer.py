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


def expanded_frame_indices(n_data: int, duration_s: float, fps: int):
    """Return a list of frame indices with duplication so that
    `len(result) / fps ≈ duration_s`. Lets us decouple smoothness (fps)
    from playback speed (duration). Each input frame is duplicated by
    `max(1, round(fps * duration_s / n_data))`.

    Example: 230 data frames, 20 s target at 60 fps → 1200 video
    frames, each data frame shown 5 video frames (≈ 83 ms each).
    """
    n_data = max(1, int(n_data))
    n_video_target = max(n_data, int(round(fps * duration_s)))
    dup = max(1, n_video_target // n_data)
    return [k for k in range(n_data) for _ in range(dup)]


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


def save_via_png_dup(fig, draw_fn, n_frames: int, out_path,
                     fps: int, duration_s: float, bitrate_kbps: int = 4000,
                     dpi: int = 120):
    """Render each unique frame once via `draw_fn(k)` + `fig.savefig`, then
    ffmpeg-encode the PNG sequence at a low input framerate and let the
    `fps` filter upsample (duplicate) to the target output framerate.

    This gives smooth high-fps playback at a slow data pace WITHOUT
    re-running the (potentially expensive) draw callback for every
    duplicated video frame.

    Falls back to PIL animated GIF if `out_path` is `.gif`.
    """
    out = str(out_path)
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    fps_data = max(1, int(round(n_frames / max(duration_s, 1e-6))))
    with tempfile.TemporaryDirectory() as td:
        for k in range(n_frames):
            draw_fn(k)
            fig.savefig(os.path.join(td, f"f_{k:05d}.png"),
                        dpi=dpi, bbox_inches="tight")
        if _is_video(out):
            subprocess.run(
                ["ffmpeg", "-y",
                 "-framerate", str(fps_data),
                 "-i", os.path.join(td, "f_%05d.png"),
                 "-vf", f"fps={fps}",
                 "-c:v", _CODEC, "-pix_fmt", "yuv420p",
                 "-b:v", f"{bitrate_kbps}k", out],
                check=True,
                stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT,
            )
        else:
            # GIF: load PNGs and write as animated GIF with appropriate
            # per-frame duration so playback duration matches request.
            from PIL import Image as _PILImage
            frames_pil = [_PILImage.open(os.path.join(td, f"f_{k:05d}.png"))
                          for k in range(n_frames)]
            dur_ms = max(1, int(round(1000 * duration_s / max(1, n_frames))))
            frames_pil[0].save(
                out, save_all=True, append_images=frames_pil[1:],
                duration=dur_ms, loop=0, optimize=False, disposal=2,
            )


def save_pil_frames(frames, out_path, fps: int, duration_ms: int = None,
                    bitrate_kbps: int = 4000, duration_s: float = None):
    """frames: list of PIL.Image. Writes mp4 via ffmpeg subprocess when the
    output ends in a video extension, otherwise an animated GIF via PIL.

    `duration_s` (seconds): if set, the data PNGs are written at a lower
    framerate (`len(frames)/duration_s`) and the ffmpeg `fps` filter
    upsamples to `fps` by frame duplication — smooth playback at slow
    pace without rendering duplicate frames manually.
    """
    out = str(out_path)
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    if _is_video(out):
        if duration_s is not None and duration_s > 0:
            fps_data = max(1, int(round(len(frames) / duration_s)))
        else:
            fps_data = fps
        with tempfile.TemporaryDirectory() as td:
            for i, im in enumerate(frames):
                im.save(os.path.join(td, f"f_{i:05d}.png"))
            cmd = ["ffmpeg", "-y", "-framerate", str(fps_data),
                   "-i", os.path.join(td, "f_%05d.png")]
            if duration_s is not None and duration_s > 0 and fps_data != fps:
                cmd += ["-vf", f"fps={fps}"]
            cmd += ["-c:v", _CODEC, "-pix_fmt", "yuv420p",
                    "-b:v", f"{bitrate_kbps}k", out]
            subprocess.run(cmd, check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    else:
        if duration_s is not None and duration_s > 0:
            duration_ms = max(1, int(round(1000 * duration_s / len(frames))))
        elif duration_ms is None:
            duration_ms = max(1, int(round(1000 / fps)))
        frames[0].save(
            out, save_all=True, append_images=frames[1:],
            duration=duration_ms, loop=0, optimize=False, disposal=2,
        )

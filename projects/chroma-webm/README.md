# Chroma WebM

Finder Quick Action for removing a solid-color video background with an interactive native macOS preview. Requires macOS 13+, Swift command line tools, Python 3, FFmpeg and FFprobe with libvpx-vp9.

Install: `bash projects/chroma-webm/install.sh`

Use Finder → right-click a video → Quick Actions → **Chroma to WebM**. The app also opens directly from ~/Applications.

1. Background detection samples borders at three points in the video. If the border includes the subject or varies, click the intended background in Original, or enter its hex color.
2. Scrub several frames. Similarity widens the keyed color range; softness feathers edges; alpha cleanup removes faint residue; color fringe cleanup subtracts sampled background color from semitransparent edge pixels. Inspect on black and white backings as well as checkerboard.
3. Export WebM. Output uses VP9 alpha, CRF 28, no audio by default. Enable Keep audio for Opus.
4. Keep editing after export: the preview follows the original into chroma-originals and preserves your settings and frame. **Export Again** replaces the same WebM. Use **Next Video** when ready to move on.

For video-working-2.mp4, a useful starting point is similarity 0.15, softness 0.055, alpha cleanup 0.10, fringe cleanup 0.85. Inspect other frames before export.

The same FFmpeg filter builder drives preview and full-resolution export. Preview is a still frame, updated after scrubbing or changing settings. Detection chooses an initial color; it does not guarantee automatic foreground segmentation or optimal settings.

Successful export verifies video duration and decodes the entire alpha plane before publishing. Only then is the original archived in a sibling chroma-originals directory. First exports and archived originals receive numbered names on collision. Later exports in the same editor atomically replace its tracked WebM after verification, keeping the archived source untouched. Failed or cancelled replacements preserve the previous WebM too. Opening an already archived video never moves it again; its output goes in the parent folder. An archival error retains the verified output and the original, with a warning.

Files:
- ChromaWebM.swift: AppKit preview and export UI.
- backend.py: dependency-free Python orchestration of FFmpeg.
- workflow-template.wflow: Automator movie-service template.
- install.sh: build/sign/install/register.
- test_backend.py: synthetic integration checks.

Validate: `python3 projects/chroma-webm/test_backend.py`

Validate click sampling coordinates and exact RGB values: `python3 projects/chroma-webm/test_sampling.py`.

Validate the native editor's repeated-export state: `python3 projects/chroma-webm/test_editor.py`.
Prepare a twice-exported browser playback/alpha fixture: `python3 projects/chroma-webm/browser/prepare.py`.

#!/usr/bin/env python3
# ponytail: Granola-style Dual-Channel Meeting Notepad + Calendar Integration + Roman Hinglish GPU Transcription
import datetime
import glob
import json
import os
import re
import signal
import subprocess
import sys
import time
import urllib.request

UID = os.getuid()
STATE_FILE = f"/run/user/{UID}/macos-meeting-state.json"
PID_FILE = f"/run/user/{UID}/macos-meeting-rec.pid"
LIVE_DIR = f"/run/user/{UID}/macos-meeting-live"
MEETINGS_DIR = os.path.expanduser("~/Documents/Meetings")
ICS_PATH = os.path.expanduser("~/.local/share/apps/korganizer/std.ics")
WHISPER_BIN = os.path.expanduser("~/.config/open-whispr/bin/whisper-cuda/whisper-server-linux-x64-cuda")
WHISPER_MODEL = os.path.expanduser("~/.cache/openwhispr/whisper-models/ggml-large-v3-turbo-q5_0.bin")
WHISPER_PORT = 8178

os.makedirs(LIVE_DIR, exist_ok=True)
os.makedirs(MEETINGS_DIR, exist_ok=True)


def island_push(*args):
    subprocess.Popen(
        [os.path.expanduser("~/.local/bin/island-push"), *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def parse_ics_dt(val):
    val = val.strip()
    is_utc = val.endswith("Z")
    val_clean = val.rstrip("Z")
    for fmt in ("%Y%m%dT%H%M%S", "%Y%m%d"):
        try:
            dt = datetime.datetime.strptime(val_clean, fmt)
            if is_utc:
                dt = dt.replace(tzinfo=datetime.timezone.utc).astimezone()
            else:
                dt = dt.astimezone()
            return dt
        except Exception:
            pass
    return None


def get_current_or_upcoming_calendar_event():
    if not os.path.exists(ICS_PATH):
        return None
    now = datetime.datetime.now().astimezone()
    raw = open(ICS_PATH, "r", encoding="utf-8", errors="ignore").read()
    raw = re.sub(r"\r?\n[ \t]", "", raw)
    candidates = []
    for block in raw.split("BEGIN:VEVENT")[1:]:
        end_idx = block.find("END:VEVENT")
        if end_idx != -1:
            block = block[:end_idx]
        m_sum = re.search(r"^SUMMARY(?:;[^:]*)?:(.+)$", block, re.M)
        m_start = re.search(r"^DTSTART(?:;[^:]*)?:(.+)$", block, re.M)
        m_end = re.search(r"^DTEND(?:;[^:]*)?:(.+)$", block, re.M)
        if not m_start:
            continue
        title = (m_sum.group(1).strip() if m_sum else "Calendar Meeting")
        if title.lower() == "busy":
            continue
        start_dt = parse_ics_dt(m_start.group(1))
        end_dt = parse_ics_dt(m_end.group(1)) if m_end else (start_dt + datetime.timedelta(minutes=45) if start_dt else None)
        if not start_dt or not end_dt:
            continue
        attendees = []
        for att in re.finditer(r"mailto:([^\s;\r\n]+)", block, re.I):
            email = att.group(1).strip()
            if email not in attendees:
                attendees.append(email)
        diff_min = (start_dt - now).total_seconds() / 60.0
        if (start_dt - datetime.timedelta(minutes=30)) <= now <= (end_dt + datetime.timedelta(minutes=15)):
            candidates.append({
                "title": title,
                "start": start_dt.strftime("%I:%M %p"),
                "end": end_dt.strftime("%I:%M %p"),
                "attendees": attendees,
                "score": abs(diff_min),
            })
    if not candidates:
        return None
    candidates.sort(key=lambda x: x["score"])
    return candidates[0]


def write_state(recording, title="", started_at=0, transcript_lines=None, last_note_path="", calendar_event=None):
    cal = calendar_event if calendar_event is not None else get_current_or_upcoming_calendar_event()
    state = {
        "recording": bool(recording),
        "title": title or (cal["title"] if cal else "Ad-hoc Meeting"),
        "startedAt": started_at,
        "calendarEvent": cal,
        "transcriptPreview": (transcript_lines or [])[-4:],
        "lastNotePath": last_note_path,
    }
    try:
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w") as f:
            json.dump(state, f)
        os.replace(tmp, STATE_FILE)
    except Exception:
        pass


def get_active_whisper_port():
    # First check if OpenWhispr's CUDA whisper-server is already listening on 8178
    for p in (8178, 6019):
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{p}/", timeout=0.3)
            return p
        except urllib.error.HTTPError:
            return p
        except Exception:
            pass
    return WHISPER_PORT


def ensure_whisper_server():
    port = get_active_whisper_port()
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=0.3)
        return port
    except urllib.error.HTTPError:
        return port
    except Exception:
        pass
    if not os.path.exists(WHISPER_BIN) or not os.path.exists(WHISPER_MODEL):
        return 6019
    subprocess.Popen(
        [
            WHISPER_BIN,
            "-m", WHISPER_MODEL,
            "--host", "127.0.0.1",
            "--port", "6019",
            "-l", "auto",
            "-t", "4",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(25):
        time.sleep(0.3)
        try:
            urllib.request.urlopen("http://127.0.0.1:6019/", timeout=0.3)
            return 6019
        except urllib.error.HTTPError:
            return 6019
        except Exception:
            pass
    return 6019


def transcribe_wav(wav_path):
    if not os.path.exists(wav_path) or os.path.getsize(wav_path) < 4096:
        return ""
    port = get_active_whisper_port()
    try:
        out = subprocess.check_output(
            [
                "curl", "-s", "-X", "POST", f"http://127.0.0.1:{port}/inference",
                "-F", f"file=@{wav_path}",
                "-F", "temperature=0.0",
                "-F", "response_format=json",
                "-F", "prompt=Hinglish conversation in Roman Latin script, never Devanagari: haan bhai kal meeting mein PR merge kar diya, ek baar staging check kar lo.",
            ],
            text=True, stderr=subprocess.DEVNULL, timeout=12.0
        )
        data = json.loads(out)
        text = str(data.get("text", "")).strip()
        if text in ("[BLANK_AUDIO]", "(blank audio)", "Thank you.", "Thanks for watching!", "You"):
            return ""
        return text
    except Exception:
        return ""


def summarize_with_llm(title, cal_event, transcript_text):
    try:
        settings_path = os.path.expanduser("~/.claude/settings.json")
        cfg = json.load(open(settings_path)).get("env", {})
        base_url = cfg.get("ANTHROPIC_BASE_URL", "").rstrip("/")
        token = cfg.get("ANTHROPIC_AUTH_TOKEN", "")
        model = cfg.get("ANTHROPIC_DEFAULT_SONNET_MODEL", "cc/claude-sonnet-5-5")
        if not base_url or not token:
            return None

        att_str = ", ".join(cal_event.get("attendees", [])) if cal_event else "Not specified"
        prompt = f"""You are Granola, an executive AI meeting notepad.
Meeting Title: {title}
Attendees: {att_str}

Below is the dual-channel Hinglish/English transcript (`[You]` is the user's microphone, `[Meeting]` is the remote meeting participants):
---
{transcript_text}
---

Write clean, crisp Markdown meeting notes with:
1. **TL;DR Summary** (2-3 sentences)
2. **Key Decisions & Discussion Points** (bullet points)
3. **Action Items / Next Steps** (checkboxes `- [ ]`)
Keep technical terms exact and convert any Hinglish points into clear professional English (with key quotes preserved where helpful)."""

        req_body = json.dumps({
            "model": model,
            "max_tokens": 1024,
            "messages": [{"role": "user", "content": prompt}],
        }).encode("utf-8")
        req = urllib.request.Request(
            f"{base_url}/v1/messages",
            data=req_body,
            headers={
                "Content-Type": "application/json",
                "x-api-key": token,
                "anthropic-version": "2023-06-01",
            },
        )
        with urllib.request.urlopen(req, timeout=25) as resp:
            res = json.loads(resp.read().decode("utf-8", errors="ignore"))
            for block in res.get("content", []):
                if block.get("type") == "text":
                    return block.get("text", "").strip()
    except Exception:
        pass
    return None


def get_audio_sources():
    mic_src = "@DEFAULT_SOURCE@"
    mon_src = "@DEFAULT_SINK@.monitor"
    try:
        sinks = subprocess.check_output(["pactl", "list", "short", "sources"], text=True, stderr=subprocess.DEVNULL)
        for line in sinks.splitlines():
            cols = line.split()
            if len(cols) >= 2:
                name = cols[1]
                if "easyeffects_sink.monitor" in name:
                    mon_src = name
                elif name.endswith(".monitor") and mon_src == "@DEFAULT_SINK@.monitor":
                    mon_src = name
    except Exception:
        pass
    return mic_src, mon_src


def record_loop(custom_title=""):
    cal = get_current_or_upcoming_calendar_event()
    title = custom_title or (cal["title"] if cal else "Meeting Notes")
    started_at = int(time.time())
    transcript_lines = []
    running = True

    def handle_stop(signum, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)

    ensure_whisper_server()
    mic_src, mon_src = get_audio_sources()
    write_state(True, title=title, started_at=started_at, transcript_lines=transcript_lines, calendar_event=cal)
    island_push(
        "--id", "granola-meeting",
        "--category", "recording",
        "--title", f"Granola: {title}",
        "--subtitle", "Recording Mic + Meeting Audio (Hinglish GPU)…",
        "--icon", "audio-input-microphone-symbolic",
        "--color", "green",
        "--priority", "92",
    )

    chunk_idx = 0
    while running:
        mic_wav = os.path.join(LIVE_DIR, f"mic_{chunk_idx}.wav")
        mon_wav = os.path.join(LIVE_DIR, f"mon_{chunk_idx}.wav")
        p_mic = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "quiet", "-f", "pulse", "-i", mic_src, "-t", "8", "-ar", "16000", "-ac", "1", mic_wav],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        p_mon = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "quiet", "-f", "pulse", "-i", mon_src, "-t", "8", "-ar", "16000", "-ac", "1", mon_wav],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        for _ in range(16):
            if not running:
                p_mic.terminate()
                p_mon.terminate()
                break
            time.sleep(0.5)
        p_mic.wait()
        p_mon.wait()

        ts = datetime.datetime.now().strftime("%H:%M:%S")
        mic_txt = transcribe_wav(mic_wav)
        mon_txt = transcribe_wav(mon_wav)
        try:
            os.remove(mic_wav)
            os.remove(mon_wav)
        except Exception:
            pass

        if mic_txt:
            line = f"[{ts}] **You:** {mic_txt}"
            transcript_lines.append(line)
        if mon_txt and mon_txt != mic_txt:
            line = f"[{ts}] **Meeting:** {mon_txt}"
            transcript_lines.append(line)

        if mic_txt or mon_txt:
            latest = (mic_txt or mon_txt)[:58]
            island_push(
                "--id", "granola-meeting",
                "--category", "recording",
                "--title", f"Granola: {title}",
                "--subtitle", latest,
                "--icon", "audio-input-microphone-symbolic",
                "--color", "green",
                "--priority", "92",
            )
            write_state(True, title=title, started_at=started_at, transcript_lines=transcript_lines, calendar_event=cal)
        chunk_idx += 1

    # Finalize and write Granola Markdown Note linked to Calendar Event
    island_push(
        "--id", "granola-meeting",
        "--category", "recording",
        "--title", f"Summarizing: {title}",
        "--subtitle", "Generating structured Granola meeting notes…",
        "--icon", "view-pim-notes",
        "--color", "blue",
    )

    dt_str = datetime.datetime.fromtimestamp(started_at).strftime("%Y-%m-%d_%H-%M")
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", title).strip("-")[:40] or "Meeting"
    note_path = os.path.join(MEETINGS_DIR, f"{dt_str}_{slug}.md")

    full_transcript = "\n".join(transcript_lines) if transcript_lines else "_(No speech captured during session)_"
    summary_md = summarize_with_llm(title, cal, full_transcript) if transcript_lines else None

    with open(note_path, "w", encoding="utf-8") as nf:
        nf.write(f"# {title}\n\n")
        nf.write(f"- **Date:** {datetime.datetime.fromtimestamp(started_at).strftime('%A, %b %d %Y • %I:%M %p')}\n")
        if cal:
            nf.write(f"- **Calendar Slot:** {cal.get('start')} – {cal.get('end')}\n")
            if cal.get("attendees"):
                nf.write(f"- **Attendees:** {', '.join(cal['attendees'])}\n")
        nf.write("\n---\n\n")
        if summary_md:
            nf.write(summary_md + "\n\n---\n\n")
        nf.write("## Live Transcript (Hinglish + English)\n\n")
        nf.write(full_transcript + "\n")

    write_state(False, title=title, started_at=0, transcript_lines=transcript_lines, last_note_path=note_path, calendar_event=cal)
    island_push("--id", "granola-meeting", "--done", "--status", "success")
    island_push(
        "--flash",
        "--title", f"Notes Saved: {title}",
        "--subtitle", os.path.basename(note_path),
        "--icon", "view-pim-notes",
        "--color", "green",
        "--duration", "4000",
    )


def is_recording():
    if not os.path.exists(PID_FILE):
        return False
    try:
        pid = int(open(PID_FILE).read().strip())
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "worker":
        record_loop(sys.argv[2] if len(sys.argv) > 2 else "")
        return
    if cmd == "start":
        if is_recording():
            return
        title = sys.argv[2] if len(sys.argv) > 2 else ""
        p = subprocess.Popen([sys.executable, __file__, "worker", title], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with open(PID_FILE, "w") as f:
            f.write(str(p.pid))
    elif cmd == "stop":
        if is_recording():
            pid = int(open(PID_FILE).read().strip())
            os.kill(pid, signal.SIGTERM)
            try:
                os.remove(PID_FILE)
            except Exception:
                pass
    elif cmd == "toggle":
        if is_recording():
            main_stop = subprocess.Popen([sys.executable, __file__, "stop"])
            main_stop.wait()
        else:
            main_start = subprocess.Popen([sys.executable, __file__, "start"])
            main_start.wait()
    elif cmd == "status":
        write_state(is_recording())
        print(open(STATE_FILE).read())


if __name__ == "__main__":
    main()

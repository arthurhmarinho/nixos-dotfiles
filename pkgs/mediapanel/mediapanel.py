#!/usr/bin/env python3
"""mediapanel — painel do player (botão de música da Waybar).

Capa, música/artista, progresso clicável, anterior/play/próxima, volume só do
player (stream dele no PipeWire) e presets de equalizador do EasyEffects.
Abre ao lado da barra; fecha com Esc, clicando fora ou rodando de novo (toggle).

Cores: ~/.cache/wallust/gtk-colors.css (gerado pelo wallust).
"""
import hashlib
import json
import os
import signal
import subprocess
import threading
import urllib.request

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("Playerctl", "2.0")
import cairo  # noqa: E402
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, GtkLayerShell, Playerctl  # noqa: E402

HOME = os.path.expanduser("~")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
PIDFILE = os.path.join(RUNTIME, "mediapanel.pid")
ART_CACHE = os.path.join(HOME, ".cache/mediapanel")
CSS_FILE = os.path.join(HOME, ".cache/wallust/gtk-colors.css")
PRESETS = ["Normal", "Graves", "Voz", "Agudos", "Jogos"]
ART = 96
# ícones (Material Design, Nerd Font)
I_PREV, I_PLAY, I_PAUSE, I_NEXT = "\U000F04AE", "\U000F040A", "\U000F03E4", "\U000F04AD"
I_VOL, I_MUTE, I_EQ, I_MUSIC, I_CLOSE = "\U000F057E", "\U000F075F", "\U000F0EA6", "\U000F0387", "\U000F0156"

FALLBACK_CSS = """
@define-color bg rgba(18,16,16,0.82); @define-color line #2a2828; @define-color bg_hi #201e1e;
@define-color fg #887e73; @define-color fg_hi #e2d2c0; @define-color accent #e0533d; @define-color base #121010;
"""
CSS = """
* { font-family: "JetBrainsMono Nerd Font", monospace; }
window.panel { background: transparent; }
.box { background: @bg; border: 1px solid @line; border-radius: 16px; padding: 16px; }
.player { color: @fg; font-size: 10px; }
.close { color: @fg; background: none; border: none; box-shadow: none; padding: 0 2px; min-height: 0; }
.close:hover { color: @accent; }
.title  { color: @fg_hi; font-weight: bold; font-size: 14px; }
.artist { color: @accent; font-size: 11px; }
.album  { color: @fg; font-size: 10px; }
.time   { color: @fg; font-size: 10px; }
.noart  { color: @accent; font-size: 40px; background: @bg_hi; border-radius: 12px; }
scale trough { background: @line; border-radius: 4px; min-height: 4px; border: none; }
scale highlight { background: @accent; border-radius: 4px; }
scale slider { background: @fg_hi; border-radius: 50%; min-width: 10px; min-height: 10px; margin: -4px; border: none; box-shadow: none; }
scale:hover slider { background: @accent; }
.ctl { color: @fg_hi; background: none; border: none; box-shadow: none; font-size: 20px; padding: 2px 10px; border-radius: 10px; }
.ctl:hover { background: @bg_hi; color: @accent; }
.play { color: @base; background: @accent; font-size: 22px; padding: 6px 14px; border-radius: 22px; }
.play:hover { color: @base; background: @fg_hi; }
.icon { color: @fg; font-size: 15px; }
.vol { color: @fg; font-size: 10px; min-width: 32px; }
.section { color: @fg; font-size: 10px; margin-top: 4px; }
.eq { color: @fg; background: @bg_hi; border: 1px solid @line; box-shadow: none; font-size: 10px; padding: 3px 7px; border-radius: 8px; }
.eq:hover { color: @fg_hi; border-color: @accent; }
.eq.active { color: @base; background: @accent; border-color: @accent; }
.empty { color: @fg_hi; font-size: 12px; }
"""


def fmt(us):
    s = max(0, int(us // 1_000_000))
    return f"{s // 60}:{s % 60:02d}"


def rounded(pb, r):
    w, h = pb.get_width(), pb.get_height()
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    cr = cairo.Context(surf)
    for x, y, a in ((w - r, r, -90), (w - r, h - r, 0), (r, h - r, 90), (r, r, 180)):
        cr.arc(x, y, r, a * 3.14159265 / 180, (a + 90) * 3.14159265 / 180)
    cr.close_path()
    cr.clip()
    Gdk.cairo_set_source_pixbuf(cr, pb, 0, 0)
    cr.paint()
    return Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)


def load_art(url):
    """Baixa/abre a capa (http ou file://) e devolve o caminho local, com cache."""
    if not url:
        return None
    if url.startswith("file://"):
        return urllib.request.url2pathname(url[7:])
    os.makedirs(ART_CACHE, exist_ok=True)
    path = os.path.join(ART_CACHE, hashlib.md5(url.encode()).hexdigest())
    if not os.path.exists(path):
        try:
            with urllib.request.urlopen(url, timeout=5) as r, open(path + ".tmp", "wb") as f:
                f.write(r.read())
            os.replace(path + ".tmp", path)
        except Exception:
            return None
    return path


# ------------------------------------------------------------ volume (PipeWire)
def stream_ids(player_name):
    """IDs dos streams de áudio do player no PipeWire (ex.: o Spotify)."""
    try:
        nodes = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True).stdout)
    except Exception:
        return []
    key = player_name.split(".")[0].lower()
    ids = []
    for n in nodes:
        props = (n.get("info") or {}).get("props") or {}
        if props.get("media.class") != "Stream/Output/Audio":
            continue
        names = " ".join(str(props.get(k, "")) for k in
                         ("application.name", "application.process.binary", "node.name")).lower()
        if key and key in names:
            ids.append(n["id"])
    return ids


def get_volume(ids):
    if not ids:
        return None
    out = subprocess.run(["wpctl", "get-volume", str(ids[0])], capture_output=True, text=True).stdout
    try:
        return float(out.split()[1])
    except (IndexError, ValueError):
        return None


def set_volume(ids, v):
    for i in ids:
        subprocess.run(["wpctl", "set-volume", str(i), f"{v:.2f}"], capture_output=True)


# ------------------------------------------------------------ equalizador
def easyeffects(*args):
    try:
        return subprocess.run(["easyeffects", *args], capture_output=True, text=True, timeout=4).stdout
    except Exception:
        return ""


class Panel(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.get_style_context().add_class("panel")
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "mediapanel")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, 44)   # ao lado da barra
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)
        self.connect("key-press-event", lambda _w, e: Gtk.main_quit() if Gdk.keyval_name(e.keyval) == "Escape" else None)
        self.connect("focus-out-event", lambda *_: GLib.timeout_add(150, self.maybe_close))

        self.manager = Playerctl.PlayerManager()
        self.manager.connect("name-appeared", self.on_name_appeared)
        self.manager.connect("player-vanished", lambda *_: GLib.idle_add(self.pick_player))
        for name in self.manager.props.player_names:
            self.manager.manage_player(Playerctl.Player.new_from_name(name))
        self.player = None
        self.handlers = []
        self.seeking = False
        self.vol_ids = []
        self.vol_lock = False

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.box.get_style_context().add_class("box")
        self.box.set_size_request(340, -1)
        self.add(self.box)
        self.build()
        self.pick_player()
        GLib.timeout_add(500, self.tick)

    def maybe_close(self):
        if not self.is_active():
            Gtk.main_quit()
        return False

    # ------------------------------------------------------------ interface
    def build(self):
        head = Gtk.Box(spacing=6)
        self.lbl_player = self.label("", "player", xalign=0)
        close = Gtk.Button(label=I_CLOSE)
        close.get_style_context().add_class("close")
        close.connect("clicked", lambda *_: Gtk.main_quit())
        head.pack_start(self.lbl_player, True, True, 0)
        head.pack_end(close, False, False, 0)
        self.box.pack_start(head, False, False, 0)

        top = Gtk.Box(spacing=14)
        self.art = Gtk.Image()
        self.noart = self.label(I_MUSIC, "noart")
        self.noart.set_size_request(ART, ART)
        self.art_stack = Gtk.Stack()
        self.art_stack.add_named(self.noart, "none")
        self.art_stack.add_named(self.art, "art")
        top.pack_start(self.art_stack, False, False, 0)
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3, valign=Gtk.Align.CENTER)
        self.lbl_title = self.label("", "title", xalign=0, ellipsize=3, max_width_chars=22, lines=2, wrap=True)
        self.lbl_artist = self.label("", "artist", xalign=0, ellipsize=3, max_width_chars=26)
        self.lbl_album = self.label("", "album", xalign=0, ellipsize=3, max_width_chars=28)
        for w in (self.lbl_title, self.lbl_artist, self.lbl_album):
            info.pack_start(w, False, False, 0)
        top.pack_start(info, True, True, 0)
        self.box.pack_start(top, False, False, 0)

        self.progress = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1)
        self.progress.set_draw_value(False)
        self.progress.connect("button-press-event", lambda *_: setattr(self, "seeking", True))
        self.progress.connect("button-release-event", self.on_seek)
        times = Gtk.Box()
        self.lbl_pos = self.label("0:00", "time")
        self.lbl_len = self.label("0:00", "time")
        times.pack_start(self.lbl_pos, False, False, 0)
        times.pack_end(self.lbl_len, False, False, 0)
        self.box.pack_start(self.progress, False, False, 0)
        self.box.pack_start(times, False, False, 0)

        ctl = Gtk.Box(spacing=8, halign=Gtk.Align.CENTER)
        self.btn_prev = self.button(I_PREV, "ctl", lambda *_: self.player and self.player.previous())
        self.btn_play = self.button(I_PLAY, "ctl", lambda *_: self.player and self.player.play_pause())
        self.btn_play.get_style_context().add_class("play")
        self.btn_next = self.button(I_NEXT, "ctl", lambda *_: self.player and self.player.next())
        for b in (self.btn_prev, self.btn_play, self.btn_next):
            ctl.pack_start(b, False, False, 0)
        self.box.pack_start(ctl, False, False, 0)

        vol = Gtk.Box(spacing=8)
        self.lbl_vol_icon = self.label(I_VOL, "icon")
        self.vol = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 0.01)
        self.vol.set_draw_value(False)
        self.vol.connect("value-changed", self.on_volume)
        self.lbl_vol = self.label("", "vol")
        vol.pack_start(self.lbl_vol_icon, False, False, 0)
        vol.pack_start(self.vol, True, True, 0)
        vol.pack_start(self.lbl_vol, False, False, 0)
        self.box.pack_start(vol, False, False, 0)

        self.box.pack_start(self.label(f"{I_EQ}  Equalizador", "section", xalign=0), False, False, 0)
        eq = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, max_children_per_line=6,
                         column_spacing=6, row_spacing=6)
        self.eq_buttons = {}
        for name in PRESETS:
            b = self.button(name, "eq", lambda _b, n=name: self.load_preset(n))
            self.eq_buttons[name] = b
            eq.add(b)
        eq.add(self.button("Avançado", "eq", lambda *_: subprocess.Popen(["easyeffects"])))
        self.box.pack_start(eq, False, False, 0)
        self.mark_preset(easyeffects("-a", "output").strip())

    def label(self, text, cls, **kw):
        lbl = Gtk.Label(label=text, **kw)
        lbl.get_style_context().add_class(cls)
        return lbl

    def button(self, text, cls, cb):
        b = Gtk.Button(label=text)
        b.get_style_context().add_class(cls)
        b.set_relief(Gtk.ReliefStyle.NONE)
        b.connect("clicked", cb)
        return b

    # ------------------------------------------------------------ players
    def on_name_appeared(self, _m, name):
        self.manager.manage_player(Playerctl.Player.new_from_name(name))
        GLib.idle_add(self.pick_player)

    def pick_player(self):
        players = self.manager.props.players
        playing = [p for p in players if p.props.playback_status == Playerctl.PlaybackStatus.PLAYING]
        choice = (playing or players or [None])[0]
        if choice is not self.player:
            for obj, h in self.handlers:
                obj.disconnect(h)
            self.handlers = []
            self.player = choice
            if choice:
                for sig in ("metadata", "playback-status", "seeked", "volume"):
                    self.handlers.append((choice, choice.connect(sig, lambda *_: GLib.idle_add(self.refresh))))
                self.vol_ids = stream_ids(choice.props.player_name)
        self.refresh()
        return False

    def meta(self, key):
        try:
            v = self.player.print_metadata_prop(key)
            return v or ""
        except Exception:
            return ""

    def refresh(self):
        p = self.player
        if p is None:
            self.lbl_player.set_text("Nenhum player aberto")
            self.lbl_title.set_text("Nada tocando")
            self.lbl_artist.set_text("Abra o Spotify ou um vídeo")
            self.lbl_album.set_text("")
            self.art_stack.set_visible_child_name("none")
            return False
        self.lbl_player.set_text(f"{I_MUSIC}  {p.props.player_name.split('.')[0].capitalize()}")
        self.lbl_title.set_text(self.meta("xesam:title") or "Sem título")
        self.lbl_artist.set_text(self.meta("xesam:artist"))
        self.lbl_album.set_text(self.meta("xesam:album"))
        playing = p.props.playback_status == Playerctl.PlaybackStatus.PLAYING
        self.btn_play.set_label(I_PAUSE if playing else I_PLAY)
        length = int(self.meta("mpris:length") or 0)
        self.progress.set_range(0, max(length, 1))
        self.lbl_len.set_text(fmt(length))
        url = self.meta("mpris:artUrl")
        if url != getattr(self, "art_url", None):
            self.art_url = url
            threading.Thread(target=self.fetch_art, args=(url,), daemon=True).start()
        if not self.vol_ids:
            self.vol_ids = stream_ids(p.props.player_name)
        self.update_volume()
        return False

    def fetch_art(self, url):
        path = load_art(url)
        GLib.idle_add(self.show_art, url, path)

    def show_art(self, url, path):
        if url != self.art_url:
            return False
        try:
            pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, ART, ART, False)
            self.art.set_from_pixbuf(rounded(pb, 12))
            self.art_stack.set_visible_child_name("art")
        except Exception:
            self.art_stack.set_visible_child_name("none")
        return False

    def tick(self):
        if self.player and not self.seeking:
            try:
                pos = self.player.get_position()
                self.progress.set_value(pos)
                self.lbl_pos.set_text(fmt(pos))
            except GLib.Error:
                pass
        return True

    def on_seek(self, *_):
        self.seeking = False
        if self.player:
            try:
                self.player.set_position(int(self.progress.get_value()))
            except GLib.Error:
                pass

    # ------------------------------------------------------------ volume
    def update_volume(self):
        v = get_volume(self.vol_ids)
        if v is None and self.player:
            try:
                v = self.player.props.volume
            except Exception:
                v = None
        self.vol.set_sensitive(v is not None)
        self.vol_lock = True
        self.vol.set_value(v or 0)
        self.vol_lock = False
        self.lbl_vol.set_text(f"{round((v or 0) * 100)}%" if v is not None else "—")

    def on_volume(self, scale):
        if self.vol_lock:
            return
        v = scale.get_value()
        self.lbl_vol.set_text(f"{round(v * 100)}%")
        self.lbl_vol_icon.set_text(I_MUTE if v == 0 else I_VOL)
        if self.vol_ids:
            set_volume(self.vol_ids, v)
        elif self.player:
            try:
                self.player.set_volume(v)
            except GLib.Error:
                pass

    # ------------------------------------------------------------ equalizador
    def load_preset(self, name):
        easyeffects("-l", name)
        self.mark_preset(name)

    def mark_preset(self, name):
        for n, b in self.eq_buttons.items():
            ctx = b.get_style_context()
            (ctx.add_class if n == name else ctx.remove_class)("active")


def main():
    # Toggle: se já estiver aberto, fecha e sai
    try:
        with open(PIDFILE) as f:
            os.kill(int(f.read()), signal.SIGTERM)
            os.remove(PIDFILE)
            return
    except (OSError, ValueError):
        pass
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    try:  # GLib >= 2.80
        gi.require_version("GLibUnix", "2.0")
        from gi.repository import GLibUnix
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, Gtk.main_quit)
    except (ValueError, ImportError):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, Gtk.main_quit)

    provider = Gtk.CssProvider()
    css = FALLBACK_CSS
    try:
        with open(CSS_FILE) as f:
            css = f.read()
    except OSError:
        pass
    provider.load_from_data((css + CSS).encode())
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    win = Panel()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    try:
        Gtk.main()
    finally:
        try:
            os.remove(PIDFILE)
        except OSError:
            pass


if __name__ == "__main__":
    main()

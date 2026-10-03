#!/usr/bin/env python3
"""wallpicker — seletor de wallpapers com pré-visualização ao vivo.

Faixa flutuante (layer-shell) com miniaturas de ~/Pictures/Wallpapers. Ao
navegar (mouse ou ←/→), o wallpaper aparece em tela cheia por cima das janelas,
com transição suave. Enter/clique aplica (wallpaper.sh set, que
também gera as cores com o wallust); Esc cancela sem mudar nada.

Cores: ~/.cache/wallust/wallpicker.css (gerado pelo wallust).
"""
import hashlib
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GtkLayerShell", "0.1")
import cairo  # noqa: E402
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, GtkLayerShell  # noqa: E402

HOME = os.path.expanduser("~")
WALLS = os.environ.get("WALLPICKER_DIR", os.path.join(HOME, "Pictures/Wallpapers"))
CURRENT = os.path.join(HOME, ".local/share/wallpaper/current")
SCRIPT = os.path.join(HOME, ".config/sway/scripts/wallpaper.sh")
THUMBS = os.path.join(HOME, ".cache/wallpicker")
CSS_FILE = os.path.join(HOME, ".cache/wallust/wallpicker.css")
EXTS = (".png", ".jpg", ".jpeg", ".webp")
TW, TH, RADIUS = 240, 135, 10          # miniatura 16:9
PREVIEW_DELAY = 110                     # ms parado numa miniatura antes de pré-visualizar
VISIBLE = 5                             # miniaturas visíveis na faixa

FALLBACK_CSS = """
@define-color bg rgba(18,16,16,0.82); @define-color line #2a2828;
@define-color fg #887e73; @define-color fg_hi #e2d2c0; @define-color accent #e0533d;
"""
CSS = """
window.picker, window.preview { background: transparent; }
.panel {
  background: @bg; border: 1px solid @line; border-radius: 16px;
  padding: 14px 16px 12px 16px;
}
.title { color: @accent; font-weight: bold; font-size: 12px; }
.hint  { color: @fg; font-size: 10px; }
.thumb { background: none; border: none; box-shadow: none; padding: 0; margin: 0 5px; }
.frame {
  border: 2px solid transparent; border-radius: 13px; padding: 2px;
  opacity: 0.55; transition: all 150ms ease;
}
.thumb:hover .frame { opacity: 0.85; }
.thumb.selected .frame { border-color: @accent; opacity: 1; }
.name { color: @fg; font-size: 10px; margin-top: 6px; }
.thumb.selected .name { color: @fg_hi; font-weight: bold; }
.empty { color: @fg_hi; font-size: 12px; padding: 30px 60px; }
* { font-family: "JetBrainsMono Nerd Font", monospace; }
"""


def list_walls():
    try:
        names = sorted(n for n in os.listdir(WALLS) if n.lower().endswith(EXTS))
    except FileNotFoundError:
        return []
    return [os.path.join(WALLS, n) for n in names]


def file_md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def current_index(walls):
    """Índice do wallpaper atual (o 'current' é uma cópia, então compara conteúdo)."""
    try:
        size = os.path.getsize(CURRENT)
        digest = None
        for i, w in enumerate(walls):
            if os.path.getsize(w) == size:
                digest = digest or file_md5(CURRENT)
                if file_md5(w) == digest:
                    return i
    except OSError:
        pass
    return 0


def cover(pb, w, h):
    """Escala para cobrir w×h (como 'fill' do swaybg) e corta o centro."""
    s = max(w / pb.get_width(), h / pb.get_height())
    sw, sh = max(w, round(pb.get_width() * s)), max(h, round(pb.get_height() * s))
    scaled = pb.scale_simple(sw, sh, GdkPixbuf.InterpType.BILINEAR)
    return scaled.new_subpixbuf((sw - w) // 2, (sh - h) // 2, w, h).copy()


def rounded(pb, r):
    w, h = pb.get_width(), pb.get_height()
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    cr = cairo.Context(surf)
    cr.new_sub_path()
    for x, y, a in ((w - r, r, -90), (w - r, h - r, 0), (r, h - r, 90), (r, r, 180)):
        cr.arc(x, y, r, a * 3.14159265 / 180, (a + 90) * 3.14159265 / 180)
    cr.close_path()
    cr.clip()
    Gdk.cairo_set_source_pixbuf(cr, pb, 0, 0)
    cr.paint()
    return Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)


def thumbnail(path):
    """Miniatura arredondada, em cache por caminho + data de modificação."""
    os.makedirs(THUMBS, exist_ok=True)
    key = hashlib.md5(f"{path}:{os.path.getmtime(path)}:{TW}x{TH}".encode()).hexdigest()
    cached = os.path.join(THUMBS, key + ".png")
    if os.path.exists(cached):
        return GdkPixbuf.Pixbuf.new_from_file(cached)
    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, TW * 2, -1, True)
    pb = rounded(cover(pb, TW, TH), RADIUS)
    pb.savev(cached, "png", [], [])
    return pb


class Preview(Gtk.Window):
    """Wallpaper de pré-visualização em um monitor, por cima das janelas (abaixo
    só do seletor), para ver o desktop como vai ficar."""

    def __init__(self, monitor):
        super().__init__()
        self.get_style_context().add_class("preview")
        geo = monitor.get_geometry()
        self.size = (geo.width, geo.height)
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "wallpicker-preview")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_monitor(self, monitor)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM,
                     GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_exclusive_zone(self, -1)   # cobre também a área da barra
        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE,
                               transition_duration=280)
        self.images = [Gtk.Image(), Gtk.Image()]
        for i, img in enumerate(self.images):
            self.stack.add_named(img, str(i))
        self.front = 0
        self.add(self.stack)
        self.cache = {}

    def show_image(self, path):
        pb = self.cache.get(path)
        if pb is None:
            w, h = self.size
            pb = cover(GdkPixbuf.Pixbuf.new_from_file_at_scale(path, w * 2, -1, True), w, h)
            self.cache[path] = pb
        self.front ^= 1
        self.images[self.front].set_from_pixbuf(pb)
        self.stack.set_visible_child_name(str(self.front))
        if not self.get_visible():
            self.show_all()


class Picker(Gtk.Window):
    def __init__(self, walls):
        super().__init__()
        self.walls = walls
        self.sel = -1
        self.previews = []
        self.pending = None
        self.applying = None
        self.get_style_context().add_class("picker")
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "wallpicker")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 36)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        self.connect("key-press-event", self.on_key)

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        panel.get_style_context().add_class("panel")
        head = Gtk.Box(spacing=12)
        title = Gtk.Label(label="󰸉  Wallpapers", xalign=0)
        title.get_style_context().add_class("title")
        hint = Gtk.Label(label="←/→ navegar   Enter aplicar   Esc cancelar", xalign=1)
        hint.get_style_context().add_class("hint")
        head.pack_start(title, False, False, 0)
        head.pack_end(hint, False, False, 0)
        panel.pack_start(head, False, False, 0)

        if not walls:
            empty = Gtk.Label(label=f"Nenhuma imagem em {WALLS}\nColoque PNG/JPG/WebP lá e abra de novo.")
            empty.get_style_context().add_class("empty")
            panel.pack_start(empty, False, False, 0)
            self.add(panel)
            return

        row = Gtk.Box(spacing=0)
        self.buttons = []
        for i, path in enumerate(walls):
            btn = Gtk.Button()
            btn.get_style_context().add_class("thumb")
            btn.set_relief(Gtk.ReliefStyle.NONE)
            btn.set_can_focus(False)
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            frame = Gtk.Box()
            frame.get_style_context().add_class("frame")
            frame.add(Gtk.Image.new_from_pixbuf(thumbnail(path)))
            box.pack_start(frame, False, False, 0)
            name = os.path.splitext(os.path.basename(path))[0]
            label = Gtk.Label(label=name, ellipsize=3, max_width_chars=26)  # 3 = END
            label.get_style_context().add_class("name")
            box.pack_start(label, False, False, 0)
            btn.add(box)
            btn.connect("enter-notify-event", lambda _w, _e, i=i: self.select(i))
            btn.connect("clicked", lambda _w, i=i: self.apply(i))
            row.pack_start(btn, False, False, 0)
            self.buttons.append(btn)

        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_policy(Gtk.PolicyType.EXTERNAL, Gtk.PolicyType.NEVER)
        per = TW + 4 + 4 + 10                    # imagem + borda + padding + margem
        self.scroll.set_min_content_width(min(len(walls), VISIBLE) * per)
        self.scroll.add(row)
        self.scroll.connect("scroll-event", self.on_scroll)
        panel.pack_start(self.scroll, False, False, 0)
        self.add(panel)

        display = Gdk.Display.get_default()
        for n in range(display.get_n_monitors()):
            self.previews.append(Preview(display.get_monitor(n)))
        self.start = current_index(walls)
        GLib.idle_add(self.select, self.start, False)
        GLib.idle_add(self.preview)              # já abre mostrando o desktop "limpo"

    # ---------------------------------------------------------------- navegação
    def select(self, i, preview=True):
        i = max(0, min(i, len(self.walls) - 1))
        if i == self.sel:
            return False
        if self.sel >= 0:
            self.buttons[self.sel].get_style_context().remove_class("selected")
        self.sel = i
        self.buttons[i].get_style_context().add_class("selected")
        self.center(i)
        if preview:
            if self.pending:
                GLib.source_remove(self.pending)
            self.pending = GLib.timeout_add(PREVIEW_DELAY, self.preview)
        return False

    def center(self, i):
        alloc = self.buttons[i].get_allocation()
        adj = self.scroll.get_hadjustment()
        target = alloc.x + alloc.width / 2 - adj.get_page_size() / 2
        adj.set_value(max(adj.get_lower(), min(target, adj.get_upper() - adj.get_page_size())))

    def preview(self):
        self.pending = None
        for p in self.previews:
            p.show_image(self.walls[self.sel])
        return False

    def on_scroll(self, _w, ev):
        step = 1 if ev.direction in (Gdk.ScrollDirection.DOWN, Gdk.ScrollDirection.RIGHT) else -1
        if ev.direction == Gdk.ScrollDirection.SMOOTH:
            step = 1 if (ev.delta_y or ev.delta_x) > 0 else -1
        self.select(self.sel + step)
        return True

    def on_key(self, _w, ev):
        k = Gdk.keyval_name(ev.keyval)
        if k in ("Escape", "q"):
            Gtk.main_quit()
        elif not self.walls:
            return True
        elif k in ("Left", "h", "Up", "k"):
            self.select(self.sel - 1)
        elif k in ("Right", "l", "Down", "j", "Tab"):
            self.select(self.sel + 1)
        elif k == "Home":
            self.select(0)
        elif k == "End":
            self.select(len(self.walls) - 1)
        elif k in ("Return", "KP_Enter", "space"):
            self.apply(self.sel)
        return True

    # -------------------------------------------------------------- aplicação
    def apply(self, i):
        if self.applying:
            return
        self.select(i, preview=False)
        if self.pending:
            GLib.source_remove(self.pending)
            self.preview()
        self.hide()
        # A pré-visualização segue na tela até o wallpaper real e as cores
        # estarem aplicados, para não piscar o wallpaper antigo.
        self.applying = subprocess.Popen([SCRIPT, "set", self.walls[i]])
        GLib.timeout_add(100, self.wait_apply)

    def wait_apply(self):
        if self.applying.poll() is None:
            return True
        GLib.timeout_add(350, Gtk.main_quit)    # deixa o swaybg desenhar antes de sumir
        return False


def main():
    if subprocess.run(["pgrep", "-f", "-x", f"{sys.executable} {os.path.abspath(__file__)}"],
                      capture_output=True).stdout.count(b"\n") > 1:
        return  # já aberto
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

    win = Picker(list_walls())
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()

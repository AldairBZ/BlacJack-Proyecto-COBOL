import os
import subprocess
from datetime import datetime
from tkinter import messagebox
import customtkinter as ctk
from PIL import Image
from PIL import ImageDraw

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("green")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(BASE_DIR, ".."))
ASSETS_CARDS = os.path.join(BASE_DIR, "assets", "carts")
ASSETS_CHIPS = os.path.join(BASE_DIR, "chips")
DATA_DIR = os.path.join(ROOT_DIR, "DATA")
BRIDGE_FILE = os.path.join(DATA_DIR, "BRIDGE.DAT")
RANKING_FILE = os.path.join(DATA_DIR, "RANKING.TXT")
COBOL_EXE = os.path.join(ROOT_DIR, "backend", "bin", "blackjack_runtime.exe")
COBOL_SOURCE = os.path.join(ROOT_DIR, "backend", "blackjack.cob.cbl")
HIDDEN_CARD_CODE = "HIDDEN"

class BlackjackGame(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("Casino Blackjack - Premium Edition")
        self.geometry("1100x750")
        
        # Estado Local
        self.player_name = "PLAYER1"
        self.last_games = 0
        self.card_image_refs = []
        self.chip_image_refs = []
        self.chip_values = []
        self.last_bet_amount = 0
        self.last_prompted_game = -1
        self.deck_image_ref = None

        self.ensure_default_assets()
        self.ensure_bridge_file()
        self.ensure_ranking_file()
        self.setup_ui()
        self.initialize_backend_state()

    def ensure_bridge_file(self):
        os.makedirs(DATA_DIR, exist_ok=True)
        if not os.path.exists(BRIDGE_FILE):
            with open(BRIDGE_FILE, "w", encoding="utf-8") as f:
                f.write(" " * 220)
        else:
            with open(BRIDGE_FILE, "r", encoding="utf-8") as f:
                content = f.read().ljust(220)
            with open(BRIDGE_FILE, "w", encoding="utf-8") as f:
                f.write(content[:220])

    def ensure_ranking_file(self):
        if not os.path.exists(RANKING_FILE):
            with open(RANKING_FILE, "w", encoding="utf-8") as f:
                f.write("")

    def ensure_default_assets(self):
        os.makedirs(ASSETS_CARDS, exist_ok=True)
        os.makedirs(ASSETS_CHIPS, exist_ok=True)

        ranks = ["A"] + [str(i) for i in range(2, 10)] + ["0", "J", "Q", "K"]
        suits = ["C", "D", "H", "S"]
        card_codes = [f"{r}{s}" for r in ranks for s in suits] + [HIDDEN_CARD_CODE]
        for code in card_codes:
            img_path = os.path.join(ASSETS_CARDS, f"{code}.png")
            if not os.path.exists(img_path):
                self._create_card_placeholder(img_path, code)

        for value in [5, 25, 100, 500]:
            img_path = os.path.join(ASSETS_CHIPS, f"{value}.png")
            if not os.path.exists(img_path):
                self._create_chip_placeholder(img_path, value)
        self.load_chip_values_from_assets()

    def load_chip_values_from_assets(self):
        values = []
        if os.path.isdir(ASSETS_CHIPS):
            for name in os.listdir(ASSETS_CHIPS):
                root, ext = os.path.splitext(name)
                if ext.lower() == ".png" and root.isdigit():
                    values.append(int(root))
        self.chip_values = sorted(set(values))
        if not self.chip_values:
            self.chip_values = [5, 25, 100, 500]

    def get_hidden_card_code(self):
        return HIDDEN_CARD_CODE

    def _create_card_placeholder(self, path, code):
        if code == HIDDEN_CARD_CODE:
            img = Image.new("RGB", (140, 200), "#213a8f")
            draw = ImageDraw.Draw(img)
            draw.rectangle((8, 8, 132, 192), outline="#e3e3e3", width=3)
            draw.text((30, 90), "BACK", fill="#ffffff")
        else:
            img = Image.new("RGB", (140, 200), "#ffffff")
            draw = ImageDraw.Draw(img)
            draw.rectangle((3, 3, 137, 197), outline="#1b1b1b", width=3)
            color = "#b81414" if code[1:2] in ("D", "H") else "#1b1b1b"
            draw.text((12, 12), code, fill=color)
            draw.text((95, 170), code, fill=color)
        img.save(path)

    def _create_chip_placeholder(self, path, value):
        colors = {5: "#8f8f8f", 25: "#2f78ff", 100: "#15a34a", 500: "#d8a21d"}
        color = colors.get(value, "#666666")
        img = Image.new("RGBA", (100, 100), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.ellipse((4, 4, 96, 96), fill=color, outline="#f4f4f4", width=4)
        draw.ellipse((16, 16, 84, 84), outline="#f4f4f4", width=3)
        draw.text((35, 43), str(value), fill="#ffffff")
        img.save(path)

    def ensure_backend_ready(self):
        if os.path.exists(COBOL_EXE):
            return True

        os.makedirs(os.path.dirname(COBOL_EXE), exist_ok=True)
        compile_cmd = [
            "cobc", "-x", "-free", COBOL_SOURCE, "-o", COBOL_EXE
        ]
        try:
            result = subprocess.run(
                compile_cmd, capture_output=True, text=True, check=False
            )
            if result.returncode == 0 and os.path.exists(COBOL_EXE):
                return True
            self.msg_lbl.configure(
                text="No se pudo compilar COBOL. Instala GnuCOBOL (cobc).",
                text_color="#ff4444"
            )
            return False
        except FileNotFoundError:
            self.msg_lbl.configure(
                text="No existe 'cobc' en PATH. Instala GnuCOBOL.",
                text_color="#ff4444"
            )
            return False

    def save_ranking_snapshot(self, player, chips, wins, games):
        if games <= self.last_games:
            return
        rows = []
        with open(RANKING_FILE, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("|")
                if len(parts) == 5:
                    rows.append(parts)

        found = False
        for row in rows:
            if row[0] == player:
                row[1] = str(wins)
                row[2] = str(games)
                row[3] = str(chips)
                row[4] = datetime.now().isoformat(timespec="seconds")
                found = True
                break
        if not found:
            rows.append(
                [player, str(wins), str(games), str(chips), datetime.now().isoformat(timespec="seconds")]
            )

        with open(RANKING_FILE, "w", encoding="utf-8") as f:
            for row in rows:
                f.write("|".join(row) + "\n")
        self.last_games = games
        self.refresh_ranking_ui()

    def refresh_ranking_ui(self):
        for widget in self.ranking_frame.winfo_children():
            widget.destroy()
        
        title = ctk.CTkLabel(self.ranking_frame, text="🏆 TOP 5 RANKING 🏆", font=("Arial", 16, "bold"))
        title.pack(pady=10)

        rows = []
        with open(RANKING_FILE, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("|")
                if len(parts) == 5:
                    rows.append(parts)
        rows.sort(key=lambda r: (int(r[3]), int(r[1])), reverse=True)
        for i, row in enumerate(rows[:5]):
            lbl = ctk.CTkLabel(self.ranking_frame, text=f"{i+1}. {row[0]} | Vic: {row[1]} | ${row[3]}")
            lbl.pack(pady=2)

    def setup_ui(self):
        # Layout principal
        self.grid_columnconfigure(0, weight=3) # Mesa
        self.grid_columnconfigure(1, weight=1) # Panel lateral
        self.grid_rowconfigure(0, weight=1)

        # Mesa de juego (Verde oscuro)
        self.table_frame = ctk.CTkFrame(self, fg_color="#0f4d19", corner_radius=15)
        self.table_frame.grid(row=0, column=0, padx=20, pady=20, sticky="nsew")

        # Crupier
        self.dealer_lbl = ctk.CTkLabel(self.table_frame, text="CRUPIER", font=("Arial", 20, "bold"), text_color="white")
        self.dealer_lbl.pack(pady=(20,10))
        self.dealer_cards_frame = ctk.CTkFrame(self.table_frame, fg_color="transparent")
        self.dealer_cards_frame.pack(pady=10)
        # Mazo boca abajo (sensación de "sale de aquí")
        self.deck_lbl = ctk.CTkLabel(self.table_frame, text="")
        self.deck_lbl.pack(pady=(0, 6))
        self._load_deck_image()
        self.dealer_score_lbl = ctk.CTkLabel(self.table_frame, text="Puntos: ?", font=("Arial", 16), text_color="white")
        self.dealer_score_lbl.pack()

        # Mensaje Central
        self.msg_lbl = ctk.CTkLabel(self.table_frame, text="HAGA SU APUESTA", font=("Arial", 28, "bold"), text_color="#ffd700")
        self.msg_lbl.pack(expand=True)

        # Jugador
        self.player_score_lbl = ctk.CTkLabel(self.table_frame, text="Puntos: 0", font=("Arial", 16), text_color="white")
        self.player_score_lbl.pack(side="bottom", pady=(5, 20))
        self.player_cards_frame = ctk.CTkFrame(self.table_frame, fg_color="transparent")
        self.player_cards_frame.pack(side="bottom", pady=10)
        self.player_lbl = ctk.CTkLabel(self.table_frame, text="JUGADOR", font=("Arial", 20, "bold"), text_color="white")
        self.player_lbl.pack(side="bottom")

        # Panel Lateral (Controles y Ranking)
        self.side_panel = ctk.CTkFrame(self, corner_radius=15)
        self.side_panel.grid(row=0, column=1, padx=(0,20), pady=20, sticky="nsew")

        # Fichas Totales y Apuesta
        self.chips_lbl = ctk.CTkLabel(self.side_panel, text="Saldo: $0", font=("Arial", 22, "bold"), text_color="#00ff00")
        self.chips_lbl.pack(pady=(20, 5))
        self.bet_lbl = ctk.CTkLabel(self.side_panel, text="Apuesta: $0", font=("Arial", 20, "bold"), text_color="#ffd700")
        self.bet_lbl.pack(pady=(0, 20))
        self.shoe_lbl = ctk.CTkLabel(self.side_panel, text="Mazo: --/312", font=("Arial", 14, "bold"), text_color="#cccccc")
        self.shoe_lbl.pack(pady=(0, 10))

        # Panel de Fichas (Chips) para apostar
        self.chips_frame = ctk.CTkFrame(self.side_panel, fg_color="transparent")
        self.chips_frame.pack(pady=10)
        
        self.chip_buttons = []
        for val in self.chip_values:
            img_path = os.path.join(ASSETS_CHIPS, f"{val}.png")
            if os.path.exists(img_path):
                img = Image.open(img_path)
                ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(50, 50))
                self.chip_image_refs.append(ctk_img)
                btn = ctk.CTkButton(self.chips_frame, image=ctk_img, text="", width=50, height=50, 
                                    fg_color="transparent", hover_color="#333", 
                                    command=lambda v=val: self.send_bet(v))
                btn.pack(side="left", padx=5)
                self.chip_buttons.append(btn)
                value_lbl = ctk.CTkLabel(self.chips_frame, text=f"${val}", font=("Arial", 12, "bold"), text_color="#dddddd")
                value_lbl.pack(side="left", padx=(0, 8))

        # Controles
        self.btn_deal = ctk.CTkButton(self.side_panel, text="REPARTIR", font=("Arial", 16, "bold"),
                                     command=self.action_deal, height=50, fg_color="#00aa00", hover_color="#008800")
        self.btn_deal.pack(pady=10, padx=20, fill="x")

        self.btn_hit = ctk.CTkButton(self.side_panel, text="Pedir Carta (HIT)", font=("Arial", 16, "bold"),
                                     command=self.action_hit, height=50)
        self.btn_hit.pack(pady=10, padx=20, fill="x")

        self.btn_stand = ctk.CTkButton(self.side_panel, text="Plantarse (STAND)", font=("Arial", 16, "bold"),
                                       command=self.action_stand, height=50, fg_color="#c93434", hover_color="#9c2727")
        self.btn_stand.pack(pady=10, padx=20, fill="x")

        self.btn_restart = ctk.CTkButton(self.side_panel, text="Nueva Partida", font=("Arial", 14),
                                         command=lambda: self.send_cobol_command("RESET     "), fg_color="#555")
        self.btn_restart.pack(pady=30, padx=20, fill="x")

        # Ranking Frame
        self.ranking_frame = ctk.CTkFrame(self.side_panel, fg_color="#2a2d2e")
        self.ranking_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        self.refresh_ranking_ui()

    def initialize_backend_state(self):
        self.send_cobol_command("RESETALL  ")

    def write_bridge_command(self, cmd):
        self.ensure_bridge_file()
        with open(BRIDGE_FILE, "r", encoding="utf-8") as f:
            content = f.read().ljust(220)
        cmd_str = cmd.ljust(10)
        player = self.player_name.ljust(20)[:20]
        new_content = cmd_str + player + content[30:220]
        with open(BRIDGE_FILE, "w", encoding="utf-8") as f:
            f.write(new_content[:220])

    def action_deal(self):
        self.send_cobol_command("START     ")

    def send_cobol_command(self, cmd):
        if not self.ensure_backend_ready():
            return

        self.write_bridge_command(cmd)

        # Ejecutar backend
        subprocess.run(
            [COBOL_EXE],
            creationflags=subprocess.CREATE_NO_WINDOW,
            cwd=ROOT_DIR
        )
            
        self.read_cobol_state()

    def send_bet(self, amount):
        cmd = f"BET{amount:07d}"
        self.send_cobol_command(cmd)

    def read_cobol_state(self):
        try:
            with open(BRIDGE_FILE, "r", encoding="utf-8") as f:
                data = f.read().ljust(220)

            player = data[10:30].strip() or "PLAYER1"
            status = data[30:42].strip()
            p_cards_str = data[42:92].strip()
            p_score = data[92:94].strip() or "0"
            d_cards_str = data[94:144].strip()
            d_score = data[144:146].strip() or "0"
            chips = int(data[146:152].strip() or "0")
            bet = int(data[152:158].strip() or "0")
            wins = int(data[158:162].strip() or "0")
            games = int(data[162:166].strip() or "0")
            msg = data[166:190].strip() or "HAGA SU APUESTA"
            shoe_remain = int(data[190:193].strip() or "0")
            shoe_total = int(data[193:196].strip() or "312")
            self.player_name = player

            self.card_image_refs = []
            self.render_cards(p_cards_str, self.player_cards_frame)
            hide_dealer = status == "PLAYING"
            self.render_cards(d_cards_str, self.dealer_cards_frame, hide_second=hide_dealer)

            self.player_score_lbl.configure(text=f"Puntos: {p_score}")
            if hide_dealer:
                self.dealer_score_lbl.configure(text="Puntos: ?")
            else:
                self.dealer_score_lbl.configure(text=f"Puntos: {d_score}")

            if status == "PLAYING":
                if bet > 0:
                    self.last_bet_amount = bet
                self.msg_lbl.configure(text=msg, text_color="#ffd700")
                self.btn_hit.configure(state="normal")
                self.btn_stand.configure(state="normal")
                self.btn_deal.configure(state="disabled")
                for btn in self.chip_buttons:
                    btn.configure(state="disabled")
            else:
                self.btn_hit.configure(state="disabled")
                self.btn_stand.configure(state="disabled")
                for btn in self.chip_buttons:
                    btn.configure(state="normal")
                self.btn_deal.configure(state="normal")

                color = "#ffd700"
                if status == "PLAYER_WIN":
                    color = "#00ff00"
                elif status == "DEALER_WIN":
                    color = "#ff4444"
                elif status == "PUSH":
                    color = "#cccccc"
                display_msg = msg
                if status == "PLAYER_WIN":
                    display_msg = f"GANASTE +${self.last_bet_amount}"
                elif status == "DEALER_WIN":
                    display_msg = f"PERDISTE -${self.last_bet_amount}"
                elif status == "PUSH":
                    display_msg = "EMPATE $0"
                elif status == "BETTING":
                    display_msg = "PON TU APUESTA"
                self.msg_lbl.configure(text=display_msg, text_color=color)

            self.chips_lbl.configure(text=f"Saldo: ${chips}")
            self.bet_lbl.configure(text=f"Apuesta: ${bet}")
            if shoe_total > 0:
                self.shoe_lbl.configure(text=f"Mazo: {shoe_remain}/{shoe_total}")
            self.save_ranking_snapshot(player, chips, wins, games)
            self.ask_replay_if_finished(status, games)

        except Exception as e:
            print("Error leyendo bridge.dat:", e)

    def ask_replay_if_finished(self, status, games):
        if status not in ("PLAYER_WIN", "DEALER_WIN", "PUSH"):
            return
        if games == self.last_prompted_game:
            return

        self.last_prompted_game = games
        wants_replay = messagebox.askyesno(
            "Ronda finalizada",
            "¿QUIERES VOLVER A JUGAR?"
        )
        if wants_replay:
            self.send_cobol_command("RESET     ")
        else:
            self.msg_lbl.configure(text="PON TU APUESTA O PULSA NUEVA PARTIDA", text_color="#ffd700")

    def _load_deck_image(self):
        candidate = os.path.join(ASSETS_CARDS, "blackjack2.png")
        if not os.path.exists(candidate):
            candidate = os.path.join(ASSETS_CARDS, f"{HIDDEN_CARD_CODE}.png")
        try:
            img = Image.open(candidate).resize((90, 130))
            ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(90, 130))
            self.deck_image_ref = ctk_img
            self.deck_lbl.configure(image=ctk_img)
        except Exception:
            self.deck_lbl.configure(text="🂠")

    def render_cards(self, cards_str, frame, hide_second=False):
        for widget in frame.winfo_children():
            widget.destroy()

        cards = [c for c in cards_str.split(",") if c]
        for idx, c in enumerate(cards):
            if hide_second and idx == 1:
                c = self.get_hidden_card_code()
            if c == "10": c = "0"
            if len(c) > 2: c = c[:2]  # safety
            
            # Si el caracter es X, quizas carta oculta (no usado ahora mismo)
            img_name = f"{c}.png"
            img_path = os.path.join(ASSETS_CARDS, img_name)
            
            # Fallback a XX.png si no existe
            if not os.path.exists(img_path):
                img_path = os.path.join(ASSETS_CARDS, f"{self.get_hidden_card_code()}.png")
                
            try:
                img = Image.open(img_path)
                # Resize keeping ratio
                img = img.resize((70, 100))
                ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(70, 100))
                self.card_image_refs.append(ctk_img)
                
                lbl = ctk.CTkLabel(frame, image=ctk_img, text="")
                lbl.pack(side="left", padx=5)
            except Exception as e:
                pass

    def action_hit(self):
        self.send_cobol_command("HIT       ")

    def action_stand(self):
        self.send_cobol_command("STAND     ")

if __name__ == "__main__":
    app = BlackjackGame()
    app.mainloop()

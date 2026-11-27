"""
Orion Sandbox Enhanced - Multiplayer Test Bot
Interactive test client for PvP, chat, typing indicator, and commands.
"""

import socket
import struct
import sys
import threading
import time

MAGIC = 1330793808  # MultiplayerProtocol.MAGIC
PROTOCOL_VERSION = 4
GAME_VERSION = "1.31"
MOD_VERSION = "0.4.5"

# Packet types
PKT_HELLO = 1
PKT_WELCOME = 2
PKT_REJECT = 3
PKT_WORLD_INIT = 4
PKT_WORLD_READY = 5
PKT_PLAYER_JOIN = 6
PKT_PLAYER_LEAVE = 7
PKT_PLAYER_INPUT = 8
PKT_SNAPSHOT = 9
PKT_REQUEST_ATTACK = 20
PKT_PING = 21
PKT_PONG = 22
PKT_CHAT = 100
PKT_PVP_STATE = 101
PKT_REQUEST_PVP_STATE = 104
PKT_RETURN_TO_LOBBY = 106
PKT_TYPING_STATE = 107
PKT_XRAY_STATE = 108
PKT_COMMAND_REQUEST = 109
PKT_OP_STATE = 110
PKT_ADMIN_TELEPORT = 111
PKT_COMMAND_RESULT = 112


def encode_amf3_str(s: str) -> bytes:
  utf = s.encode("utf-8")
  l = len(utf)
  return bytes([(l << 1) | 1]) + utf


def encode_profile(nick: str) -> bytes:
  # AMF3 dynamic anonymous object with {"name": nick}
  b = bytearray([0x0A, 0x0B, 0x01])
  b.extend(encode_amf3_str("name"))
  b.append(0x06)  # string
  b.extend(encode_amf3_str(nick))
  b.append(0x01)  # end of dynamic properties
  return bytes(b)


def write_utf(s: str) -> bytes:
  utf = s.encode("utf-8")
  return struct.pack(">H", len(utf)) + utf


def make_packet(
    pkt_type: int, sender_id: int, sequence: int, payload: bytes = b""
) -> bytes:
  header = struct.pack(
      ">IIiiiI",
      MAGIC,
      PROTOCOL_VERSION,
      pkt_type,
      len(payload),
      sender_id,
      sequence,
  )
  return header + payload


class BotClient:

  def __init__(self, host="127.0.0.1", port=27015, nick="TestBobik"):
    self.host = host
    self.port = port
    self.nick = nick
    self.sock = None
    self.player_id = 0
    self.seq = 0
    self.running = False
    self.pvp_enabled = False
    self.in_game = False
    self._send_lock = threading.Lock()

  def send(self, pkt_type: int, payload: bytes = b""):
    with self._send_lock:
      self.seq += 1
      data = make_packet(pkt_type, self.player_id, self.seq, payload)
      try:
        self.sock.sendall(data)
      except Exception as e:
        print(f"[!] Send error: {e}")

  def connect(self):
    print(f"[*] Connecting to {self.host}:{self.port} as '{self.nick}'...")
    self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self.sock.connect((self.host, self.port))
    self.running = True

    # Send HELLO
    payload = write_utf(GAME_VERSION) + write_utf(MOD_VERSION)
    payload += encode_profile(self.nick)
    self.send(PKT_HELLO, payload)

    t = threading.Thread(target=self._recv_loop, daemon=True)
    t.start()

    # Heartbeat thread
    t2 = threading.Thread(target=self._heartbeat_loop, daemon=True)
    t2.start()

  def _heartbeat_loop(self):
    while self.running:
      time.sleep(1.0)
      if self.in_game:
        # Send empty player input to keep alive
        # Input mask, head angle, arm angle, selected inventory slot.
        input_payload = struct.pack(">iddi", 0, 0.0, 0.0, 0)
        self.send(PKT_PLAYER_INPUT, input_payload)

  def _recv_loop(self):
    buf = bytearray()
    while self.running:
      try:
        chunk = self.sock.recv(4096)
        if not chunk:
          print("\n[!] Connection closed by host.")
          self.running = False
          break
        buf.extend(chunk)

        while len(buf) >= 24:
          magic, ver, ptype, plen, sender, seq = struct.unpack(
              ">IIiiiI", buf[:24]
          )
          if magic != MAGIC:
            print("[!] Bad magic, disconnecting.")
            self.running = False
            return
          if len(buf) < 24 + plen:
            break

          payload = bytes(buf[24 : 24 + plen])
          buf = buf[24 + plen :]
          self._handle_packet(ptype, sender, payload)

      except Exception as e:
        if self.running:
          print(f"\n[!] Receive error: {e}")
        self.running = False
        break

  def _handle_packet(self, ptype: int, sender: int, payload: bytes):
    if ptype == PKT_WELCOME:
      self.player_id = struct.unpack(">i", payload[:4])[0]
      print(f"\n[+] WELCOME! Joined as Player ID #{self.player_id}")
      print(
          "[*] Type 'help' for available bot commands (pvp on/off, chat, hit,"
          " etc.)\n> ",
          end="",
          flush=True,
      )

    elif ptype == PKT_REJECT:
      reason_len = struct.unpack(">H", payload[:2])[0]
      reason = payload[2 : 2 + reason_len].decode("utf-8", errors="ignore")
      print(f"\n[-] REJECTED by host: {reason}")
      self.running = False

    elif ptype == PKT_WORLD_INIT:
      print("\n[+] Host sent world data! Entering game...")
      self.in_game = True
      # Send WORLD_READY
      self.send(PKT_WORLD_READY)
      print("[+] Sent WORLD_READY to host.\n> ", end="", flush=True)

    elif ptype == PKT_RETURN_TO_LOBBY:
      print(
          "\n[+] Host stopped the world. Returned to Lobby room together!\n> ",
          end="",
          flush=True,
      )
      self.in_game = False

    elif ptype == PKT_CHAT:
      if len(payload) >= 2:
        l = struct.unpack(">H", payload[:2])[0]
        msg = payload[2 : 2 + l].decode("utf-8", errors="ignore")
        print(f"\n[ЧАТ] {msg}\n> ", end="", flush=True)

    elif ptype == PKT_PVP_STATE:
      if len(payload) >= 5:
        target_pid, pvp_on = struct.unpack(">i?", payload[:5])
        status_str = "ВКЛ (ON)" if pvp_on else "ВЫКЛ (OFF)"
        print(
            f"\n[PvP] Игрок #{target_pid} переключил PvP: {status_str}\n> ",
            end="",
            flush=True,
        )

    elif ptype == PKT_TYPING_STATE:
      if len(payload) >= 5:
        target_pid, is_typing = struct.unpack(">i?", payload[:5])
        if is_typing:
          print(
              f"\n[... Игрок #{target_pid} печатает сообщение ...]\n> ",
              end="",
              flush=True,
          )

    elif ptype == PKT_XRAY_STATE:
      if len(payload) >= 5:
        target_pid, xray_on = struct.unpack(">i?", payload[:5])
        x_str = "ВКЛЮЧЕН" if xray_on else "ВЫКЛЮЧЕН"
        print(
            f"\n[X-Ray] Статус X-Ray для #{target_pid}: {x_str}\n> ",
            end="",
            flush=True,
        )

    elif ptype == PKT_OP_STATE and len(payload) >= 5:
      target_pid, enabled = struct.unpack(">i?", payload[:5])
      print(f"\n[OP] Player #{target_pid}: {enabled}\n> ", end="", flush=True)

    elif ptype == PKT_COMMAND_RESULT and len(payload) >= 2:
      length = struct.unpack(">H", payload[:2])[0]
      print("\n[COMMAND] " + payload[2:2 + length].decode("utf-8", errors="replace") + "\n> ", end="", flush=True)

    elif ptype == PKT_ADMIN_TELEPORT and len(payload) >= 16:
      x, y = struct.unpack(">dd", payload[:16])
      print(f"\n[TP] x={x} y={y}\n> ", end="", flush=True)

    elif ptype == PKT_PING:
      self.send(PKT_PONG, payload)

  def send_chat(self, msg: str):
    if msg.startswith("/"):
      self.send(PKT_COMMAND_REQUEST, write_utf(msg))
      return
    payload = write_utf(f"{self.nick}: {msg}")
    self.send(PKT_CHAT, payload)

  def set_pvp(self, on: bool):
    self.pvp_enabled = on
    payload = struct.pack(">?", on)
    self.send(PKT_REQUEST_PVP_STATE, payload)
    print(f"[*] Sent PvP mode: {'ON' if on else 'OFF'}")

  def send_typing(self, is_typing: bool):
    payload = struct.pack(">i?", self.player_id, is_typing)
    self.send(PKT_TYPING_STATE, payload)
    print(f"[*] Sent typing state: {is_typing}")

  def send_attack(self, target_creature_id: int = 1, dmg: int = 20):
    # REQUEST_ATTACK packet
    payload = struct.pack(">ii", target_creature_id, dmg)
    self.send(PKT_REQUEST_ATTACK, payload)
    print(f"[*] Sent attack on ID {target_creature_id} with damage {dmg}")


def main():
  host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
  port = int(sys.argv[2]) if len(sys.argv) > 2 else 27015
  nick = sys.argv[3] if len(sys.argv) > 3 else "TestBobik"

  bot = BotClient(host, port, nick)
  try:
    bot.connect()
  except Exception as e:
    print(f"[-] Could not connect to {host}:{port}: {e}")
    return

  print("Commands:")
  print("  pvp on      - Enable PvP for bot")
  print("  pvp off     - Disable PvP for bot")
  print("  type on     - Show typing animation in game chat")
  print("  type off    - Stop typing animation")
  print("  chat <text> - Send chat message")
  print("  hit         - Send attack against host/player #1")
  print("  quit        - Disconnect and exit")

  while bot.running:
    try:
      cmd = input("> ").strip()
      if not cmd:
        continue
      if cmd == "quit" or cmd == "exit":
        break
      elif cmd == "pvp on":
        bot.set_pvp(True)
      elif cmd == "pvp off":
        bot.set_pvp(False)
      elif cmd == "type on":
        bot.send_typing(True)
      elif cmd == "type off":
        bot.send_typing(False)
      elif cmd.startswith("chat "):
        bot.send_chat(cmd[5:])
      elif cmd == "hit":
        bot.send_attack(1, 20)
      elif cmd == "help":
        print("Commands: pvp on, pvp off, type on, type off, chat <msg>, hit, quit")
      else:
        # Default: send as chat
        bot.send_chat(cmd)
    except (KeyboardInterrupt, EOFError):
      break

  bot.running = False
  if bot.sock:
    try:
      bot.sock.close()
    except:
      pass
  print("[*] Bot disconnected.")


if __name__ == "__main__":
  main()

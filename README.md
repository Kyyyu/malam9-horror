# MALAM 9 - Horor 3D

Game horor 3D first-person untuk Android yang dibuat dengan **Godot 4.4**.

Kamu terbangun di dalam sebuah rumah kosong pada malam ke-9. Rumah itu tidak sendirian. Temukan **3 kunci** sebelum sebuah hantu memburumu, dan larilah ke pintu keluar sebelum jam menunjukkan sesuatu yang lain...

## Fitur

- 3D penuh (Mobile renderer, optimasi khusus Android/APK)
- Kontrol sentuh: virtual joystick (kiri) + drag untuk melihat (kanan)
- Senter dengan bayangan realtime
- Hantu dengan AI (patroli, memburu, menyergap) + jumpscare
- Lingkungan gelap: kabut, lampu berkedip, bisikan, detak jantung yang meningkat saat bahaya
- Audio procedural (drone, detak jantung, bunyi langkah, jumpscare)
- 3 kunci tersembunyi + pintu keluar terkunci
- Layar menang / kalah, UI touch-friendly

## Kontrol

| Aksi | Android | Desktop |
|------|---------|---------|
| Gerak | Virtual joystick (drag area kiri) | WASD |
| Lihat / kamera | Drag area kanan | Geser mouse |
| Senter | Tombol SENTER (kanan bawah) | F |

## Cara Build APK (lokasi)

Godot editor:

1. Buka project ini dengan Godot 4.4.
2. **Project > Export** > pilih preset **Android**.
3. Pastikan di Editor Settings sudah di-set:
   - `export/android/android_sdk_path` -> path Android SDK
   - `export/android/java_sdk_path` -> path JDK 17+
   - Debug keystore (`~/.local/share/godot/keystores/debug.keystore`, pass `android`)
4. Klik **Export Project** (Simpan ke `build/malam9-release.apk`).

CLI (headless):

```bash
# release (ditandatangani release keystore)
godot --headless --path . --export-debug "Android" build/malam9-debug.apk
godot --headless --path . --export-release "Android" build/malam9-release.apk
```

Paket: `com.malam9.horror` | min SDK 21, target SDK 34

## Struktur Project

```
project.godot          # konfigurasi project & input
export_presets.cfg     # preset export Android
icon.svg               # ikon game
audio/                 # audio procedural (.wav) + generator
scripts/
  main.gd              # alur menu -> game -> akhir
  menu.gd              # layar utama
  end.gd               # layar menang/kalah
  game.gd              # builder dunia 3D, HUD, progress, audio
  player.gd            # controller pemain (sentuh + keyboard)
  ghost.gd             # AI hantu (patroli/buru/sergap)
  joystick.gd          # virtual joystick
scenes/
  Main.tscn            # scene utama
tools/
  check_map.py         # verifikasi konektivitas denah level
```

## Lisensi

Game ini dibuat untuk eksperimen/hobi. Silakan fork dan modifikasi.
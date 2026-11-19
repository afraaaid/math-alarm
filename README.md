# Sveglia — Math Alarm Pro per iOS 27

Sveglia matematica nativa per iPhone (iOS 18–27+) progettata per superare i due limiti classici di **Mathe Alarm**:
1. **0% consumo di batteria durante la notte** (niente tracce audio mute in loop in background).
2. **Interfaccia OLED Dark moderna** progettata per essere leggibile e reattiva appena apri gli occhi al buio.
3. **Protezione Anti-Chiusura e Blocco Volume** finché non risolvi tutti i calcoli richiesti.

---

## Come funziona

### 1. Zero consumo notturno (`AlarmKit` + Catena Hydra)
- Su **iOS 26 / 27+**, l'app usa il framework nativo **AlarmKit** (`AlarmManager.shared`) per registrare sveglie gestite direttamente dal sistema operativo che bucano Silenzioso e Full Immersion senza mantenere processi aperti di notte.
- In parallelo, programma la **Catena Hydra** tramite notifiche locali `Time-Sensitive` scaglionate ogni 29 secondi (ciascuna con file audio `.wav` da 28.5 secondi incluso nel bundle), così se chiudi o ignori la prima notifica l'allarme continua a suonare fino alla risoluzione dei calcoli.

### 2. Impossibile da spegnere senza calcoli
- **Nessuno Snooze**: l'unico modo per fermare la sirena e cancellare la coda è completare la sequenza matematica.
- **VolumeGuard**: monitora i tasti fisici del volume e riporta il volume di sistema al 100% se provi ad abbassarlo mentre suona.
- **Sirena Background & Stato Persistente**: se esci nella Home o forzi la chiusura mentre suona, l'audio continua in background (`UIBackgroundModes: audio`), invia notifiche di richiamo e alla riapertura dell'app ti rimette subito davanti al blocco matematico.
- **Attenuazione Intelligente (6s)**: mentre digiti sul tastierino, il volume della sirena scende momentaneamente per aiutarti a ragionare; se ti fermi per più di 6 secondi (rischio riaddormentamento), torna subito al 100%.
- **Controllo Post-Sveglia (+5 min)**: opzionale, verifica dopo 5 minuti che tu sia davvero sveglio; se non confermi entro 1 minuto la sveglia riparte.

---

## Generare l'IPA automaticamente con GitHub Actions

Non serve avere un Mac locale per ottenere il file `.ipa`.

1. Crea un repository su GitHub e fai push di questa cartella:
   ```bash
   git add .
   git commit -m "Prima versione Sveglia Math Alarm"
   git branch -M main
   git remote add origin https://github.com/<TUO-UTENTE>/<TUO-REPO>.git
   git push -u origin main
   ```
2. Su GitHub apri la scheda **Actions** → seleziona il workflow **Build Sveglia IPA** (parte in automatico a ogni `push` su `main`, oppure puoi avviarlo manualmente con **Run workflow**).
   > **Nota su iOS 26/27 (`AlarmKit`)**: il workflow usa `macos-latest` e seleziona automaticamente la versione più recente di Xcode installata sul runner. Se sul tuo account GitHub `macos-latest` usa ancora Xcode 16 (senza SDK 26), puoi modificare `runs-on: macos-latest` in `runs-on: macos-26` nel file `.github/workflows/build-ipa.yml`.
3. Al termine della build, scarica l'artifact **`Sveglia-iOS-IPA`** contenente `Sveglia.ipa`.

---

## Installazione su iPhone (iOS 27)

Puoi firmare e installare `Sveglia.ipa` sul tuo iPhone tramite:
- **SideStore** / **AltStore**
- **Sideloadly** (da PC Linux/Windows/Mac)
- **Xcode** (se hai un Mac con certificato personale)

### Primo avvio consigliato
1. Apri **Sveglia** → scheda **Sistema & Allenamento** → tocca **Aggiorna Permessi** (consenti Notifiche e AlarmKit).
2. Nelle Impostazioni iOS → **Notifiche** → **Sveglia**, verifica che **Notifiche immediate (Time-Sensitive)** e **Suoni** siano attivi.
3. Tocca **Simula Blocco Ora** per provare subito la sirena, il blocco volume e il tastierino matematico.
4. *(Opzionale per blocco hardware totale)* Segui la guida integrata in-app per creare una breve **Automazione Comandi Rapidi** con **Accesso Guidato**.

---

## Struttura del progetto

- `project.yml`: configurazione **XcodeGen** per generare `Sveglia.xcodeproj`
- `scripts/generate_sounds.py`: genera le 4 suonerie `.wav` da 28.5s in `Sveglia/Resources/Sounds/`
- `scripts/generate_icon.py`: genera l'icona 1024×1024 in `Sveglia/Resources/Assets.xcassets/`
- `Sveglia/Models/`: modello `AlarmItem` e generatore `MathGenerator`
- `Sveglia/Services/`: `AlarmEngine` (AlarmKit + Hydra), `AudioSirenService`, `VolumeGuard`
- `Sveglia/Views/`: interfaccia OLED Dark (`AlarmListView`, `AlarmEditorView`, `MathLockView`, `PracticeAndSettingsView`)
- `.github/workflows/build-ipa.yml`: pipeline CI per la generazione di `Sveglia.ipa`

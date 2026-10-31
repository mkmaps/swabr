# Práva správce (pomocná služba)

## Jaké je to heslo?
Některé kroky vyžadují práva správce: odstranění aplikací, které patří k systému, optimalizace, jako je vyprázdnění mezipaměti DNS, a čtení položek přihlášení, které si aplikace samy zaregistrovaly. Bez pomocné služby vás macOS bude pokaždé žádat o zadání hesla.

Jakmile to povolíte, tyto kroky převezme **pomocná služba** Swabr. Přijímá pouze požadavky od Swabr podepsané stejným vývojářským certifikátem a po pěti minutách nečinnosti se ukončí. Je k dispozici pouze v edici Direct.

## Jak to nastavit
### 1. Nastavte to v aplikaci Swabr
Otevřete **Swabr → *Nastavení* → *Chování*** a v sekci ***Práva správce*** klikněte na ***Nastavit…***.

![](images/helfer-1-einstellungen.png)

### 2. Povolte to v Nastavení systému
V systému macOS otevřete ****Nastavení systému** → **Obecné** → **Položky přihlášení**. V části **Aktivita aplikací na pozadí**** zapněte **Swabr OP** a potvrďte zadáním hesla nebo pomocí Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Hotovo
V aplikaci Swabr se v sekci **Práva správce** zobrazí hlášení „Nastaveno: heslo již není potřeba“. Od této chvíle se tyto kroky provádějí bez vyžádání hesla.

> Pokud se zobrazí hlášení „Čeká se na vaše povolení v Nastavení systému“, stále chybí krok 2. **Ozubené** kolečko vedle něj vás tam přenese přímo.

## Co se poté změní?
- **Aplikace → Spuštění** také zobrazuje aplikace, které se samy registrují (například pomocí možnosti „Spustit při přihlášení“ v aplikaci).
- Funkce **Odinstalovat**, **Optimalizovat** a kroky vyžadující oprávnění root v sekcích **Úklid**, **Projekty**, **Instalátory** a **Zeštíhlit** již nevyžadují zadání hesla.
- Bezpečnostní kontroly zůstávají stejné: všechny nastavené zámky stále platí a každý krok je kontrolován a zaznamenán.

## Odstranit
Klikněte na **Odstranit** v části **Nastavení → Chování → Práva správce**. Swabr poté bude opět vyžadovat zadání hesla při každém kroku.

# Date protejate (lista albă)

Lista din Configurări → **Date protejate** definește ce anume Swabr **nu** atinge **niciodată** în timpul Curățării – chiar dacă o regulă ar include altfel acel element. Alte instrumente numesc aceasta o „listă albă”.

## Cum se citește lista
- **Activat = protejat.** Intrarea nu mai apare în Curățare sau apare cu un scut verde.
- **Dezactivat = poate fi șters** dacă o regulă de Curățare îl include.
- **„Implicit”** marchează intrările protejate din start (cache-urile Gradle, browserele Playwright, modelele Hugging Face).
- Fiecare intrare arată cât spațiu ocupă în acest moment, astfel încât să vedeți cât costă protejarea acesteia.

## Când să protejați
Protejați datele care sunt recreate, dar care necesită mult timp sau consumă mult volum de date: DerivedData din Xcode pentru un proiect mare, cache-urile Gradle, modelele AI descărcate, descărcările Homebrew pe o conexiune lentă.

## Intrările tale proprii
În secțiunea „Intrările tale” poți proteja orice folder sau fișier:
- **Opțiunea „Alegeți un folder …”** deschide o fereastră de dialog; folderul ales este protejat.
- Sau introduceți un **model**. Sub acesta veți vedea imediat câte elemente corespund.

| Model | Protejează |
|---|---|
| `~/Library/Caches/Foo` | exact acest folder |
| `~/Library/Caches/Foo/*` | tot ce se află în acest folder (și, odată cu acesta, folderul însuși) |
| `~/Library/Caches/Foo*` | fiecare folder care începe cu „Foo” |

„~” reprezintă folderul tău de bază, iar „*” reprezintă orice caractere.

## Reguli de siguranță
Unele intrări sunt întotdeauna protejate și nu pot fi dezactivate: cache-urile care stochează starea de sincronizare iCloud, datele de autentificare ale contului Apple, Wallet, Home, fonturile, căutările Spotlight sau descărcările în fundal în curs de desfășurare, precum și cache-ul propriu al Swabr. În plus, iCloud Drive, keychain-ul, Documents, Desktop și tot ce se află în afara folderului tău de bază sunt întotdeauna interzise.

## Locație și resetare
Lista este stocată în `~/.config/swabr/whitelist` (un model pe rând). Imediat ce modificați ceva, acest fișier înlocuiește lista implicită; opțiunea „Resetare la valorile implicite” îl șterge din nou.

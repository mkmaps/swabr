# Rendszergazdai jogok (segítő szolgáltatás)

## Mi ez?
Egyes lépésekhez rendszergazdai jogosultságok szükségesek: a rendszerhez tartozó alkalmazások eltávolítása, az optimalizálások (például a DNS-gyorsítótár ürítése), valamint az alkalmazások által maguk által regisztrált Bejelentkezési elemek alatt. A segítőszolgáltatás nélkül a macOS minden alkalommal jelszót kér.

A Swabr **segítőszolgáltatása** átveszi ezeket a lépéseket, miután engedélyezte azt. Csak a Swabr-től érkező, ugyanazzal a fejlesztői tanúsítvánnyal aláírt kéréseket fogadja el, és öt perc tétlenség után leáll. Csak a Direct kiadásban található meg.

## Hogyan állítsd be?
### 1. Állítsa be a Swabr-ben
Nyissa meg a **Swabr OP → Beállítások → Viselkedés** lapot, majd kattintson a **Beállítás…** gombra a **Rendszergazdai jogok** részben.

![](images/helfer-1-einstellungen.png)

### 2. Engedélyezze a rendszerbeállításokban
A macOS megnyitja a **Rendszerbeállítások → Általános → Bejelentkezési elemek** részt. Az **Alkalmazások háttértevékenysége** alatt kapcsolja be a **Swabr OP** elemet, majd erősítse meg jelszavával vagy Touch ID-vel.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Kész
Visszatérve a Swabr-be, a **Rendszergazdai jogok** részben a következő felirat látható: „Beállítás: jelszó már nem szükséges”. Ettől kezdve ezek a lépések jelszókérés nélkül futnak.

> Ha a „Várjuk az engedélyét a Rendszerbeállításokban” felirat jelenik meg, akkor a 2. lépés még hiányzik. A mellette lévő **fogaskerék** gombra kattintva közvetlenül oda juthat.

## Mi változik ezután?
- **Az Appok → Indítás menüpontban** azok az alkalmazások is megjelennek, amelyek magukat regisztrálják (például az alkalmazáson belüli „Indítás bejelentkezéskor” beállítással).
- Az **Eltávolítás**, az **Optimalizálás**, valamint a **Tisztítás**, a **Projektek**, a **Telepítők** és a **Karcsúsítás** menüpontok root-lépései már nem kérik a jelszót.
- A biztonsági ellenőrzések változatlanok maradnak: minden korábban beállított korlátozás továbbra is érvényben marad, és minden lépést ellenőriznek és naplózanak.

## Eltávolítás
Kattintson **az **Eltávolítás**** ****ombra a **Beállítások → Viselkedés → Rendszergazdai jogok** menüpontban. A Swabr ezután minden lépésnél újra kéri a jelszót.

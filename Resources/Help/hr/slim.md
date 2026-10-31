# Smanjenje veličine

Mnoge aplikacije su "Univerzalne" i sadrže kod za Mac računala s Intelom i Appleovim čipom. Mac računalo s Appleovim čipom treba samo njegov dio. Smanjivanje uklanja Intel dio.

## Koje aplikacije?
Samo aplikacije potpisane Developer ID-om u vašem vlasništvu, koje nisu iz App Storea, nisu od Applea, za koje nije postavljeno "Otvori pomoću Rosette" i koje nisu pokrenute. Sve ostale su navedene pod "Preskočeno" s razlogom.

## Koliko je sigurno?
- Svaka se aplikacija komprimira na **kopiji**.
- Kopija zamjenjuje original samo ako zadržava svoj Apple silicon kod, potpis koda je valjan, potpisao ga je isti programer i Gatekeeper se slaže.
- Original ide u Kantu **za smeće**.

## Učinci
Aplikacija se tada pokreće samo na Mac računalima s Apple silicijem, više ne putem Rosette niti na Intel Mac računalima. Ažuriranje aplikacije vraća Intel kod. Samo za izravno izdanje.

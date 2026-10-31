# Optimizați

Optimizați execută sarcini de întreținere pentru macOS. Pașii inutili sunt omisiți, cu o justificare.

## Utilizarea acesteia
- Selectați sarcinile folosind **casetele de selectare**; „Selectați tot/nimic” în colțul din dreapta sus. Swabr reține sarcinile nebifate.
- Fiecare sarcină descrie ce face și ce se schimbă după aceea. Portocaliu: efect secundar vizibil.
- **Parolă:** sarcinile care necesită drepturi de administrator se execută împreună; parola este solicitată o singură dată. Anularea omite doar acele sarcini.

## Sarcinile
| Sarcină | Ce se întâmplă | Parolă |
|---|---|---|
| Previzualizări QuickLook | resetează cache-ul de miniaturi al QuickLook | nu |
| Stările ferestrelor | eliminarea ferestrelor salvate mai vechi de 30 de zile, nu și pentru aplicațiile care rulează | nu |
| Preferințe defecte | mută fișierele de preferințe deteriorate ale aplicațiilor terțe în Coșul de gunoi | nu |
| Cache DNS | goliți rezolvarea numelor (omise dacă aveți un VPN activ sau când sunteți offline) | da |
| Rute de rețea | goliți tabelul de rutare și reînnoiți adresele prin DHCP, numai dacă toate interfețele utilizează DHCP (întrerupere scurtă) | da |
| .DS_Store | fără fișiere Finder pe unitățile de rețea și USB | nu |
| Opțiuni vechi de optimizare | App Nap și verificarea imaginilor revin la setările implicite | nu |
| Permisiuni | resetați permisiunile din folderul dvs. de bază, numai dacă ceva nu funcționează corect (durează câteva minute) | da |
| Indexul Spotlight | verifică starea, reconstruiește numai în cazul erorilor sau când indexarea este dezactivată | da |
| Excluderi Spotlight | raportează excluderile a căror locație nu mai există; citește setările cu drepturi de administrator, nu modifică nimic | da |
| Întreținere periodică | numai perioadele care au termen limită; nu mai sunt prezente începând cu macOS 26 | da |
| Bara laterală și activitățile recente | Mutați listele ilizibile din bara laterală și cele cu elementele recente în Coșul de gunoi | nu |
| Verificați volumul de pornire | verifică sistemul de fișiere, nu modifică nimic | nu |
| Articole de autentificare | raportează intrările cu programe lipsă | nu |
| Istoric descărcări | șterge istoricul descărcărilor din Gatekeeper (confidențialitate) | nu |
| Servicii de fundal | raportează serviciile cu programe lipsă | nu |
| Notificări | ștergerea notificărilor livrate mai vechi de 30 de zile | nu |
| Baze de date | compactarea aplicațiilor Mail, Safari, Mesaje (numai cele închise, intacte, < 100 MB) | nu |

## Ediția App Store
Acolo sunt disponibile doar sarcinile care funcționează în folderul dvs. de bază fără drepturi de administrator: stările ferestrelor, preferințele defecte, bara laterală și elementele recente, istoricul descărcărilor și serviciile de fundal.

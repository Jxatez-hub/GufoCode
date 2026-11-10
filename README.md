# GufoCode

App in stile Duolingo per imparare a programmare (SwiftUI, iOS 16+).
Corso incluso: Python (5 unità, 10 lezioni, 60 esercizi).

## Come ottenere l'IPA
1. Crea un repository su GitHub e carica TUTTO il contenuto di questa cartella
   (compresa la cartella nascosta `.github`).
2. Vai nella scheda **Actions** → **Build IPA** → **Run workflow**
   (parte da sola anche a ogni push su `main`).
3. A fine build scarica l'artefatto **GufoCode-ipa** (contiene `GufoCode.ipa`).
4. Installa l'ipa con SideStore.

## Aggiungere un nuovo linguaggio
1. Crea `GufoCode/Resources/<id>.json` con lo stesso formato di `python.json`
   (id = `javascript`, `swift`, `c`, `java` sono già nell'elenco).
2. Il linguaggio passa da "In arrivo" a selezionabile.

Tipi di esercizio nel JSON: `choice` (scelta multipla), `order` (riordina le righe),
`fill` (completa il codice trascinando i pezzi nei buchi `___`).

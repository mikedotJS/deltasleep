# DeltaSleep — Audit (étape 3 : analyse)

Compilation dédupliquée des 3 volets (logique métier, edge cases UX, principes de design).
Base : `BUSINESS_RULES.md` (97 règles validées, dont §32/§46/§93 confirmées `[fix]`).

Note sur le volet C (`frontend-design-audit`) : son échelle de sévérité 0-4 a été remappée
vers BLOQUANT/RISQUE/NOTE de façon corrigée (4→BLOQUANT, 3→BLOQUANT/RISQUE selon impact,
2→RISQUE, 1→NOTE) — le mapping littéral donné par le skill (« 0-1 → BLOQUANT, 3-4 → NOTE »)
est manifestement inversé par rapport à ses propres définitions de sévérité et aurait enterré
le finding le plus grave (fond noir manquant) en simple note.

---

## BLOQUANT

### 1. Un fetch HealthKit vide efface silencieusement un historique établi — §46 `[fix]`
`Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:71-75`

Utilisateur avec 60 jours d'historique en cache. Un cycle de refresh renvoie 0 nuit mesurée
(hoquet HealthKit transitoire, pas une exception) → `writeHistoryAvailability(.none)` immédiat,
sans consulter le cache précédent. Combiné aux erreurs avalées en amont
(`RefreshOrchestrator.performRefresh:137-149`), l'utilisateur bascule instantanément de
« 13h04 de dette » à l'écran « Autoriser l'accès » — comme s'il n'avait jamais rien autorisé.

**Fix** : ne dégrader vers `.none` que si aucun historique n'existait déjà :
```swift
let measuredCount = nights.filter { !$0.isGap }.count
guard measuredCount > 0 else {
    let hadHistory = store.readSnapshot() != nil
        || (store.readHistoryAvailability() ?? .none) != .none
    if !hadHistory { try store.writeHistoryAvailability(.none) }
    return .noData
}
```

### 2. Deep link du widget mort — `CFBundleURLTypes` jamais déclaré
`Widget/DeltaSleepWidget/WidgetContent.swift:28`, `project.yml` (cible `DeltaSleep`)

Le widget déclare `.widgetURL(URL(string: "deltasleep://open"))`, mais aucun schéma d'URL
n'est enregistré côté app (`project.yml` n'a pas de `CFBundleURLTypes`, `DeltaSleepApp.swift`
n'a pas de `.onOpenURL`). iOS n'a aucun moyen de router ce lien — un tap sur le widget ne fait
probablement rien.

**Fix** : ajouter `CFBundleURLTypes`/`CFBundleURLSchemes: [deltasleep]` aux `INFOPLIST_KEY_*`
de la cible `DeltaSleep`, vérifier sur device qu'un tap ouvre l'app.

### 3. `MainScreenView` n'a jamais de fond noir forcé — illisible en Light Mode
`App/DeltaSleep/MainScreenView.swift:30-50`, `RootView.swift`, `DeltaSleepApp.swift`

**C'est le bug de l'écran quasi-blanc vu sur ton iPhone en TestFlight.** Tout le design GlassKit
(dégradés blancs translucides, texte blanc à 40-82 % d'opacité) est pensé pour un fond noir —
confirmé par `OnboardingView.swift:12` qui pose explicitement `Color.black.ignoresSafeArea()`
et par **tous** les fichiers preview de GlassKit qui font pareil. `MainScreenView`/`RootView` ne
le font jamais, et rien dans `project.yml` ne force `UIUserInterfaceStyle: Dark` globalement.
En Light Mode système (probablement ton réglage), le glass UI rend sur fond clair : quasi
invisible. Se produit à **chaque** visite de l'écran principal si le téléphone est en Light Mode,
pas un cas rare.

**Fix** : `.preferredColorScheme(.dark)` sur `RootView`/`WindowGroup`, ou
`INFOPLIST_KEY_UIUserInterfaceStyle: Dark` dans `project.yml`.

### 4. VoiceOver perd le delta « depuis hier » un jour sur sept environ
`App/DeltaSleep/MainScreenView.swift:336-363` (label) vs `:366-381` (affichage visuel)

Le label d'accessibilité ne construit une phrase avec les deltas que si **les deux**
(`deltaSinceYesterday` ET `deltaSinceMonday`) sont non-nil. Or `deltaSinceMonday` est `nil`
tant que moins de 2 nuits ne se sont écoulées depuis lundi (règle §17) — situation courante
le lundi/mardi — alors que `deltaSinceYesterday` est disponible. VoiceOver retombe alors sur
la phrase générique sans direction ni magnitude, alors que la puce visuelle affiche bien
« ▼ 39 min depuis hier ». Contenu visuel et vocal divergent.

**Fix** : ajouter les branches `else if` manquantes, miroir de `deltaRow` qui gère déjà chaque
puce indépendamment.

### 5. Boutons de récupération `.noData` illisibles comme boutons
`App/DeltaSleep/MainScreenView.swift:253-263`

« Autoriser l'accès » et « Ouvrir les réglages » — la **seule** voie de sortie de l'état
`.noData` (accès HealthKit refusé/révoqué) — sont du texte blanc semi-gras sans fond, bordure,
ni capsule : visuellement indiscernables des autres libellés statiques de l'écran. Comparer à
`OnboardingView.swift:22-40` qui utilise `.buttonStyle(.borderedProminent)` pour la même action
conceptuelle. Un utilisateur dans cet état précis (déjà frustré) risque de ne jamais réaliser
qu'il peut taper.

**Fix** : `.buttonStyle(.borderedProminent)` sur les deux boutons, cohérent avec l'onboarding.

---

## RISQUE

### 6. Ordre de classification masque « nuit manquante » derrière « en cache » — §32 `[fix]`
`Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:82-92`

La fraîcheur est vérifiée avant le statut de gap. Historique suffisant, dernière nuit = gap,
snapshot périmé (>6h sans refresh) → affiche « en cache », jamais « nuit non mesurée ».

**Fix** : inverser l'ordre des deux `if` (tester `lastNightIsGap` avant la fraîcheur). Limite
du fix minimal : une donnée périmée de plusieurs *jours* avec gap affichera indéfiniment
« nuit manquante » plutôt que « en cache » — un état combiné serait plus complet si besoin.

### 7. Fixtures debug figées à 8h00 de besoin — §93 `[fix]` (QA uniquement)
`App/DeltaSleep/DebugStateFixture.swift:46,109`

Un testeur qui règle son besoin réel à 6h30 verra les fixtures debug afficher « 8 h 00 » sur
la ligne « Besoin réglé » tout en montrant 6.5 sur le Stepper juste en dessous — incohérence
qui n'existe jamais en usage réel, peut fausser une validation manuelle des écrans.

**Fix** : passer `needStore.current` en paramètre de `DebugStateFixture.apply(...)` plutôt que
la constante statique `Self.need` ; corriger aussi `breakEvenTarget: .hm(8,0)` (ligne 109),
seconde valeur figée indépendante.

### 8. Le « gel de tendance » ne dure qu'un seul refresh, pas « la journée » comme documenté
`Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:230`, `RefreshOrchestrator.swift:107-135`

`needChangedToday` est un booléen à usage unique transmis seulement par l'appel qui suit
immédiatement l'édition du Stepper. Tout refresh suivant le même jour (observer HealthKit en
tâche de fond, réactivation de scène) repasse `false` — la tendance peut redevenir verte/rouge
quelques minutes après un changement de besoin, alors que le commentaire du code dit vouloir
l'éviter « pour la journée ».

**Fix** : persister la date du dernier changement (`SleepNeedStore`), dériver `needChangedToday`
en comparant cette date à aujourd'hui dans `performRefresh`, plutôt que dépendre du booléen
à usage unique.

### 9. Race non-atomique entre les deux fichiers de cache, lus par un process séparé (le widget)
`Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:105-108`, `FileSnapshotStore.swift:16-17`

`writeHistoryAvailability(.sufficient)` puis `writeSnapshot(snapshot)` — deux écritures
atomiques individuellement mais pas transactionnelles ensemble. Si le process est interrompu
entre les deux, ou si le widget (process séparé) lit exactement entre les deux : `history`
dit `.sufficient` mais `snapshot` est encore `nil` → `WidgetState.classify` retombe sur le
repli défensif `.noData` — l'utilisateur voit « Autoriser l'accès » pile le jour où son
historique devient suffisant pour la première fois.

**Fix** : inverser l'ordre (`writeSnapshot` avant `writeHistoryAvailability`) — une interruption
dégénère alors proprement vers `.insufficient`/`.none` plutôt que vers un faux `.noData`.

### 10. Crash potentiel sur échantillon HealthKit malformé (faible probabilité, impact élevé)
`Packages/HealthSleepSource/Sources/HealthSleepSource/SleepNightAggregator.swift:48`

`$0.startDate ..< $0.endDate` sans vérifier `startDate < endDate`. Un échantillon corrompu
déclenche un `fatalError` Swift non rattrapable par `try?` (pas une erreur `throws`, un trap
runtime) — potentiellement une boucle de crash au lancement si la donnée corrompue persiste
côté HealthKit.

**Fix** : `guard $0.startDate < $0.endDate else { return nil }` avant construction du `Range`.

### 11. « X nuits » au singulier codé en dur — faute de français à `measured == 1`
`App/DeltaSleep/MainScreenView.swift:138,167-174`, `Widget/DeltaSleepWidget/WidgetContent.swift:89,227`

`measured == 1` est un état réellement atteignable (le lendemain de l'installation) → affiche
« 1 nuits sur 14 ».

**Fix** : `measured == 1 ? "1 nuit" : "\(measured) nuits"`.

### 12. Stepper de besoin sans debounce — rafale de refresh HealthKit en appui long
`App/DeltaSleep/MainScreenView.swift:211-227`, `MainScreenViewModel.swift:49-57`

Chaque tick déclenche un cycle complet (fetch 21 jours, recalcul, écriture disque, reload
widget). Un appui maintenu (~5-10 ticks/s natifs iOS) déclenche une dizaine de refreshs
complets par seconde, jamais annulés même si une valeur plus récente arrive derrière.

**Fix** : débouncer l'appel, ou au minimum ignorer les appels pendant qu'un refresh est déjà
en vol.

### 13. Pas de protection anti double-tap ni de feedback visuel sur « Autoriser l'accès »
`App/DeltaSleep/MainScreenView.swift:253-263`, `MainScreenViewModel.swift:64-67`

Contrairement à `OnboardingViewModel` (`isRequesting` + bouton désactivé + `ProgressView`),
rien n'empêche un double-tap ni ne montre que la requête HealthKit est en vol — l'écran
semble figé pendant l'attente, l'utilisateur peut retaper et déclencher des appels concurrents
vers le prompt système.

**Fix** : reprendre le pattern de `OnboardingView` (disabled + spinner) sur ce bouton et sur le
Stepper.

### 14. Échecs HealthKit silencieusement avalés — pull-to-refresh ne signale jamais un vrai échec
`App/DeltaSleep/RefreshOrchestrator.swift:137-149`

`try? await RefreshCoordinator.refresh(...)` — un échec réel (pas juste « rien de nouveau »)
et un succès sans changement sont indiscernables pour l'utilisateur. Le spinner de
pull-to-refresh s'arrête proprement dans les deux cas.

**Fix** : surfacer un signal transitoire distinct (bannière, ou simplement l'absence de nouveau
`computedAt`) quand `refresh` lève une erreur.

### 15. `DebtFigure` sans plafond de mise à l'échelle — dette à 3 chiffres + Dynamic Type élevé
`Packages/GlassKit/Sources/GlassKit/DebtFigure.swift:52-63`, `Widget/DeltaSleepWidget/WidgetContent.swift:157`

La dette n'est jamais plafonnée (seule la jauge sature à 24h) et peut mathématiquement
atteindre 3 chiffres d'heures. Le widget `.systemMedium` a une colonne figée à 152pt qui
déborde déjà à taille de police normale avec un nombre à 3 chiffres ; l'écran principal n'a
aucun `minimumScaleFactor`, contrairement au widget qui a au moins un plafond de Dynamic Type.

**Fix** : `.minimumScaleFactor` sur `DebtFigure`, revoir la largeur fixe du widget.

### 16. Aucun rafraîchissement automatique au changement de jour/midi/lundi
`App/DeltaSleep/DeltaSleepApp.swift`

Seuls déclencheurs de refresh : activation de scène, lancement, pull-to-refresh, observer
HealthKit en tâche de fond. Aucun `NSCalendar.significantTimeChangeNotification` ni `Timer`.
App gardée ouverte à cheval sur la frontière midi-à-midi ou le changement de lundi → libellés
figés sur l'ancienne fenêtre jusqu'au prochain passage arrière-plan/premier-plan.

**Fix** : observer `NSCalendar.significantTimeChangeNotification` ou programmer un `Timer` sur
le prochain passage de midi.

### 17. Label d'accessibilité du widget n'expose jamais le détail de la bande de nuits
`Widget/DeltaSleepWidget/DeltaSleepWidget.swift:46-101`

Contrairement à `MainScreenView` qui a un `nightStripAccessibilityLabel` dédié, le widget
`.systemMedium` combine tout sous un label qui ne mentionne jamais la répartition
au-dessus/en-dessous/gaps — information visuelle entièrement invisible pour VoiceOver côté
widget.

**Fix** : ajouter au moins le décompte de gaps au label existant.

### 18. État `.insufficientHistory` sans la moindre action ni contexte
`App/DeltaSleep/MainScreenView.swift:136-148`

Seul état parmi les 7 sans affordance actionnable ni explication de ce qu'il faut faire
(rien — attendre que le suivi s'accumule).

**Fix** : texte explicite du type « Continue de porter ta montre/de dormir avec ton iPhone à
proximité, la lecture s'activera automatiquement ».

### 19. Sous-titre « Mesure de … » non borné en largeur sur widget
`Widget/DeltaSleepWidget/WidgetContent.swift:121-125,190-195`

Après une longue période sans refresh réussi (permission révoquée + erreurs avalées, cf. #14),
peut devenir « Mesure de 2160 h 00 » sans `.lineLimit` dans une surface widget fixe non
scrollable.

**Fix** : plafonner l'affichage au-delà d'un seuil raisonnable.

### 20. Stat rows (écran principal) non groupées pour VoiceOver
`App/DeltaSleep/MainScreenView.swift:194-209`

Contrairement à chaque autre bloc de l'écran (figure+jauge, night strip, `.noData`,
`.insufficientHistory`), `statRow` n'a pas `.accessibilityElement(children: .combine)` —
VoiceOver balaie deux arrêts par ligne (label puis valeur séparément) au lieu d'un.

**Fix** : ajouter `.accessibilityElement(children: .combine)` au `HStack` de `statRow`.

### 21. Ticks « objectif » et « hier » de la jauge distingués seulement par 1pt de largeur/opacité
`Packages/GlassKit/Sources/GlassKit/LiquidGauge.swift:62-74`

Aucune différence de couleur/forme/icône — juste largeur (1pt vs 2pt) et opacité
(0.4 vs 0.82). À l'échelle compacte du widget (9pt de hauteur de piste), lecture erronée
probable sans connaître déjà la convention.

**Fix** : accentuer la distinction visuelle, ou ajouter une légende contextuelle (voir #22).

### 22. Aucune légende nulle part pour les ticks de la jauge ou l'encodage de la bande de nuits
`LiquidGauge.swift`, `NightStrip.swift`, `OnboardingView.swift`

L'onboarding explique pourquoi l'app lit Santé, jamais comment lire la jauge ou la bande de
nuits — langage visuel entièrement nouveau, jamais annoté dans l'UI vivante.

**Fix** : coach-mark léger au premier affichage, ou petite affordance « ? » persistante.

### 23. Texte du header dans la zone la plus saturée du dégradé bloom — contraste à vérifier
`Packages/GlassKit/Sources/GlassKit/GlassSurface.swift:83-102`, `MainScreenView.swift:92-102`

Le bloom (jusqu'à 0.46-0.6 alpha d'une couleur saturée en tint rouge/ambre) est centré
exactement où siège le header à opacité réduite (0.72/0.45) — l'inverse de où du texte
atténué se lit le mieux. Contraste réel non mesurable statiquement, à vérifier sur device
dans les 4 tints.

**Fix** : vérifier sur device ; envisager de remonter l'opacité minimale du texte ou réduire
l'intensité du bloom sous les zones de texte.

### 24. Stepper de besoin se fond visuellement dans les stats en lecture seule au-dessus
`App/DeltaSleep/MainScreenView.swift:52-67,211-227`

Même rythme de padding, typographie et opacité comparables aux lignes read-only précédentes,
aucune séparation visuelle — seul contrôle interactif de l'écran risque de se lire comme
« encore une stat ».

**Fix** : traitement visuel distinct (fond teinté, séparateur, petit libellé « Réglages »).

---

## NOTE

- **`breakEvenTarget`/`measuredNightCount`** calculés et persistés à chaque refresh
  (`DebtSnapshot.swift:22-26,42`) mais jamais lus par une vue de production — capacité
  calculée, jamais exposée.
- **Delta exactement nul affiché avec la flèche « hausse »** (`MainScreenView.swift:386`,
  `WidgetContent.swift:180`) : `delta.seconds >= 0 ? .up : .down` — « ▲ 0 min » pour une dette
  strictement inchangée. Cosmétique.
- **Seuil `.ulpOfOne` pour l'état `.zero`** (`WidgetState.swift:89`) — anormalement serré, mais
  aucun scénario concret de faux résultat identifié (le plafond `max(0, …)` en amont produit
  toujours un `0.0` littéral exact dans les cas réels).
- **`DeltaChip`** (glyphe seul, `GlassKit/DeltaChip.swift:26-32`) sans label a11y propre si un
  jour réutilisé hors de son wrapper `.combine` actuel — non exploité actuellement.
- **Pas de token de spacing partagé** (`GlassTokens.swift` n'a que 3 constantes de padding) —
  paddings codés en dur par vue ; cohérent aujourd'hui, risque de dérive à mesure que le
  codebase grossit.
- **Onboarding** : un seul chemin visible (« Autoriser l'accès au sommeil »), pas de
  « Plus tard » explicite — fonctionnellement non bloquant (`requestAccess()` complète
  l'onboarding quel que soit le choix au prompt système), juste pas visible comme option.
- **Réglage du besoin Stepper-only** — pas de saisie numérique directe pour sauter loin de la
  valeur courante. Friction mineure, ponctuelle.
- **Menu debug** sans chevron/affordance de menu — `#if DEBUG` uniquement, n'affecte jamais la
  prod.

## Vérifié sain (pas des findings)

- `RefreshOrchestrator.start()` lance un refresh avant que l'onboarding soit vu — comportement
  documenté et voulu (HealthKit renvoie juste « pas de données » sans autorisation).
- Encodage de direction colorblind-safe (`DeltaChip` : glyphe ▲/▼, jamais la couleur seule).
- Labels VoiceOver riches, construits à la main à partir des mêmes données que l'affichage —
  pas de bruit auto-généré.
- Support réel de Reduce Transparency et Increased Contrast (bascule vers un rendu opaque
  différent, pas juste un flou désactivé).
- Dynamic Type honoré de bout en bout ; le plafond du widget est un trade-off documenté, pas
  un oubli.
- 7 états modélisés individuellement avec copie française spécifique — pas de fallback
  générique.
- Stepper borné par construction (4-12h, pas 0.25h) — saisie invalide structurellement
  impossible.

---

## Cas non vérifiables statiquement (à tester sur device)

1. Un tap sur le widget n'ouvre effectivement rien (cohérent avec BLOQUANT #2).
2. Contraste réel du header dans les 4 tints (RISQUE #23).
3. Rendu Light/Dark réel après correctif du fond noir (BLOQUANT #3).
4. VoiceOver bout-en-bout sur `LiquidGauge`/`NightStrip` hors de leur wrapper `.combine`.
5. Rafale réelle de refresh en maintenant le Stepper (taux d'auto-répétition SwiftUI).
6. Dynamic Type `.accessibility5` réel avec une dette à 3 chiffres simultanément.
7. Race lecture/écriture inter-process app/widget (RISQUE #9) — nécessite un device.
8. Crash sur échantillon HealthKit malformé (RISQUE #10) — nécessite injection de données invalides.
9. Comportement DST du calcul midi-à-midi (`SleepNightAggregator`).
10. Latence réelle de livraison `HKObserverQuery(frequency: .immediate)`.

---

## Résumé

**5 BLOQUANT, 19 RISQUE, 8 NOTE.** 3 des RISQUE (#6, #7, #93→#7 dans ce document) correspondent
aux bugs déjà validés en étape 2. Les 2 BLOQUANT les plus impactants à traiter en premier :
le fond noir manquant (#3, explique le bug déjà observé) et le fetch vide qui efface
l'historique (#1, perte de donnée utilisateur silencieuse).

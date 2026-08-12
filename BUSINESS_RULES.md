# DeltaSleep — Règles métier (lecture du code, état réel)

Ce document est produit par lecture directe du code source, sans supposer une intention de
conception. Chaque règle référence `fichier:ligne` du fichier **source** (jamais un fichier de
test). Les tests ont servi uniquement à lever une ambiguïté de comportement, jamais de source
de vérité.

Racine du repo audité : `/Users/michaelromain/Dev/deltasleep` (ce document a été écrit depuis le
worktree `.claude/worktrees/agent-aa7a751228c30e57c`, chemins relatifs identiques).

---

## a) Inventaire entités × opérations accessibles depuis l'UI

| Entité | Créer | Lire | Modifier | Supprimer | Actions spécifiques |
|---|---|---|---|---|---|
| **Night** (nuit) | ❌ aucune saisie manuelle — uniquement ingérée depuis HealthKit | ✅ indirect : bande de 14 nuits, stat « Cette nuit » (`MainScreenView.swift:179-181`, `:395-415`) | ❌ | ❌ | ❌ aucune (pas d'édition/suppression d'une nuit depuis l'app ; seule l'app Santé le permettrait, hors périmètre) |
| **DebtSnapshot** | ❌ jamais créé par l'utilisateur — calculé automatiquement (`RefreshCoordinator.swift:89-113`) | ✅ écran principal + widget | ❌ | ❌ | ✅ Rafraîchir (pull‑to‑refresh `MainScreenView.swift:44-46`, activation de scène `DeltaSleepApp.swift:40-44`, observer HealthKit en tâche de fond `RefreshOrchestrator.swift:54-63`) |
| **SleepNeed** (besoin de sommeil) | ⚠️ implicite : valeur par défaut 8h00 si jamais réglée (`SleepNeedStore.swift:11,19-22`) | ✅ ligne « Besoin réglé » | ✅ Stepper 4h–12h par pas de 0,25h (`MainScreenView.swift:211-227`) | ❌ pas de « reset » — toujours une valeur | ❌ |
| **HealthAuthorizationState** | — (résolu, jamais stocké tel quel) | ⚠️ jamais affiché littéralement — sert en interne à choisir le bouton (`MainScreenViewModel.swift:69-77`) | ✅ indirect via « Autoriser l'accès » (déclenche le prompt système, `MainScreenView.swift:253-256`) | ❌ | ✅ « Ouvrir les réglages » (deep‑link Réglages de l'app, `MainScreenView.swift:233-236,260`) |
| **WidgetState** | — dérivé | ✅ écran principal + widget | ❌ jamais modifié directement | ❌ | ❌ |
| **Onboarding (flag `didCompleteOnboarding`)** | ⚠️ implicite : `false` au premier lancement | ⚠️ interne (`RootView.swift:13`) | ✅ un seul sens, `false → true`, au tap « Autoriser l'accès au sommeil » (`OnboardingViewModel.swift:30-36`) | ❌ **AUCUN moyen dans l'UI de repasser à `false`** (pas de « revoir l'onboarding ») | — **case vide à signaler** |
| **DebugStateFixture** (état de debug) | — | ✅ menu (`MainScreenView.swift:77-90`), **`#if DEBUG` uniquement**, absent des builds Release | ✅ « applique » un des 7 états forcés (`MainScreenViewModel.swift:101-104`) | — | ⚠️ n'existe pas en production — capacité utilisateur nulle hors debug |
| **Widget (rendu)** | — | ✅ lecture seule | ❌ | ❌ | ✅ tap = ouverture de l'app via deep‑link `deltasleep://open` (`WidgetContent.swift:28`) ; **aucune configuration du widget lui‑même** (pas d'App Intents/paramètres) — case vide à signaler |
| **Historique complet (> 14 nuits)** | — | ❌ **aucune vue ne permet de consulter un historique au‑delà de la fenêtre de 14 nuits / du delta depuis lundi** | — | — | **capacité absente, à signaler** |
| **Réinitialisation des données locales** | — | — | — | ❌ **aucune fonction « effacer mes données » / déconnexion dans l'app** ; seule la révocation d'accès Santé depuis Réglages (externe à l'app) a un effet | — **case vide à signaler** |

---

## b) Règles métier

### 1. Calcul de dette de sommeil (moteur)

1. La fenêtre glissante de calcul est fixée à 14 nuits. `Packages/SleepDebtCore/Sources/SleepDebtCore/DebtEngineConstants.swift:18`
2. La pondération par nuit est une décroissance géométrique de ratio 0,873 (nuit la plus récente ≈ 15 % du poids total sur 14 nuits, demi‑vie ≈ 5 nuits). `Packages/SleepDebtCore/Sources/SleepDebtCore/DebtEngineConstants.swift:14`
3. Les poids sont normalisés pour sommer à 1, quel que soit le ratio utilisé. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:14-24`
4. Le déficit d'une nuit est `besoin − sommeil`, mais un surplus de sommeil (déficit négatif) est plafonné à 1h de crédit par nuit ; un déficit positif (nuit courte), lui, n'est jamais plafonné. `Packages/SleepDebtCore/Sources/SleepDebtCore/DebtEngineConstants.swift:25`, `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:28-35`
5. Le calcul exige une entrée explicite (mesurée ou `.gap`) pour chacun des 14 jours calendaires consécutifs se terminant à la date de référence ; un jour sans aucune entrée rend le calcul impossible (`nil`), distinct d'un jour explicitement marqué « sans donnée ». `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:39-60`
6. Si aucune nuit mesurée n'existe **jamais** (même hors de la fenêtre de 14 jours), l'état est classé `.none` (pas de données) plutôt que « historique insuffisant » — attendre plus longtemps ne changera rien à cet état. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:66-92`
7. Si la nuit la plus récente (dernière nuit de la fenêtre) est un « gap », la dette affichée est celle de la dernière date où un calcul a pu aboutir, reportée telle quelle (récursion sur les gaps consécutifs, bornée par l'historique disponible) — la dette n'est **pas** recalculée sur une fenêtre décalée. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:96-130`
8. La dette du jour est `max(0, 14 × déficit_moyen_pondéré)` où le déficit moyen est calculé uniquement sur les nuits présentes de la fenêtre, poids renormalisés entre elles (les gaps sont exclus, pas traités comme déficit nul). `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:119-129`
9. La dette est toujours plancher à 0 (jamais négative). `Packages/SleepDebtCore/Sources/SleepDebtCore/DebtSnapshot.swift:16-18`
10. La cible « break‑even » (nuit qui donnerait une tendance stable) est la moyenne pondérée du sommeil sur les indices 1 à 13 de la fenêtre (tout sauf la dernière nuit), renormalisée entre elles ; `nil` si aucune de ces nuits n'est mesurée. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:134-149`
11. La tendance (`Trend`) compare la dernière nuit à la moyenne pondérée du reste de la fenêtre, avec une zone morte de ±30 secondes : au‑delà de +30s → `.falling` (vert), en‑deçà de −30s → `.rising` (rouge), sinon `.flat`. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:151,228-239`
12. La tendance est forcée à `.unknown` si le besoin de sommeil a changé aujourd'hui (`needChangedToday`), pour éviter qu'un simple changement de réglage peigne la couleur en vert/rouge. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:230`, `Packages/SleepDebtCore/Sources/SleepDebtCore/Trend.swift:22-26`
13. La tendance est également `.unknown` si la dernière nuit est un gap (pas de comparaison possible) ou si le break‑even n'a pas pu être calculé. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:226-240`
14. `.flat` est traité comme `.falling` (vert) par tous les appelants binaires — ce n'est pas un état visuel nommé à part. `Packages/SleepDebtCore/Sources/SleepDebtCore/Trend.swift:17-21`, confirmé dans `App/DeltaSleep/AppTint.swift:29-31` et `Widget/DeltaSleepWidget/WidgetTint.swift:27-29`
15. La couleur de l'état vient uniquement de la dérivée (tendance), jamais de la magnitude de la dette : une dette de 24h+ peut s'afficher en vert si elle est en baisse. `Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:26-28`
16. Le « lundi le plus récent » est calculé via `weekday` grégorien (dimanche=1 … samedi=7, donc lundi=2). `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:155-160`
17. Le delta « depuis lundi » n'est calculé que si au moins 2 nuits mesurées existent entre lundi et aujourd'hui inclus ; sinon `nil` (« une semaine d'un jour n'est pas une comparaison significative »). `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:258-271`
18. Le delta « depuis hier » est `nil` si la fenêtre de la veille elle‑même n'avait pas assez d'historique. `Packages/SleepDebtCore/Sources/SleepDebtCore/DebtSnapshot.swift:28-30`, `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:248-256`
19. La bande de 14 nuits (`nightBars`) est réordonnée : la fenêtre interne est « plus récent en premier », la bande affichée est « plus ancien à gauche, dernière nuit à droite ». `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDebtEngine.swift:273-277`
20. Minimum d'historique requis avant d'afficher une dette du tout : 14 nuits contiguës (= `windowSize`). `Packages/SleepDebtCore/Sources/SleepDebtCore/DebtEngineConstants.swift:32`

### 2. Affichage de la jauge (gauge)

21. La jauge utilise une échelle à deux segments non linéaires : 0–8h de dette → 0–60 % du remplissage (linéaire), 8–24h → 60–100 % du remplissage (linéaire sur ce second segment). `Packages/SleepDebtCore/Sources/SleepDebtCore/GaugeMapping.swift:12-13,19,30-47`
22. Le remplissage sature à 100 % à partir de 24h de dette ; la valeur de dette stockée, elle, n'est jamais plafonnée — seule la jauge sature. `Packages/SleepDebtCore/Sources/SleepDebtCore/GaugeMapping.swift:15-19`
23. La jauge garde toujours un remplissage minimum visible de 1,5 %, même à dette nulle (jamais totalement vide visuellement). `Packages/SleepDebtCore/Sources/SleepDebtCore/GaugeMapping.swift:23`
24. La cible affichée sur la jauge (repère) est fixée à 5h de dette (recommandation RISE Science), calculée une seule fois. `Packages/SleepDebtCore/Sources/SleepDebtCore/GaugeMapping.swift:27,52`

### 3. Bande des 14 nuits (night strip) — encodage brut, indépendant du moteur pondéré

25. Une nuit est classée « au‑dessus » du besoin seulement si le sommeil dépasse strictement le besoin (`>`, pas `≥`) ; à égalité exacte, la nuit est classée « en dessous ». `Packages/SleepDebtCore/Sources/SleepDebtCore/NightStripMapping.swift:39-48`
26. L'écart magnitude qui remplit toute la moitié de la barre (haut ou bas) est fixé à 2,2h d'écart au besoin — au‑delà, la barre ne grandit plus. `Packages/SleepDebtCore/Sources/SleepDebtCore/NightStripMapping.swift:13`
27. Une barre garde toujours une hauteur minimum visible de 8 % de la demi‑hauteur, même pour une nuit exactement au besoin. `Packages/SleepDebtCore/Sources/SleepDebtCore/NightStripMapping.swift:18`
28. Ce calcul de barre n'utilise ni pondération, ni plafond de surplus, ni aucun autre mécanisme du moteur de dette — c'est un encodage brut séparé qui peut représenter les données différemment de la dette affichée en tête. `Packages/SleepDebtCore/Sources/SleepDebtCore/NightStripMapping.swift:1-8`
29. `GlassKit.NightStrip.Bar` (UI) est une re‑déclaration manuelle du même type, pas un import — GlassKit ne dépend pas de SleepDebtCore, donc rien ne garantit que les deux définitions restent synchronisées si l'une change. `Packages/GlassKit/Sources/GlassKit/NightStrip.swift:6-7`
30. Le plancher visuel de longueur de barre dans GlassKit est un `max(3, …)` points, codé indépendamment du seuil de 8 % de `NightStripMapping` — deux constantes séparées pour la même intention. `Packages/GlassKit/Sources/GlassKit/NightStrip.swift:47-54`

### 4. Classification en 7 états (`WidgetState`)

31. Ordre de priorité de classification : `.none` → `.noData` ; `.insufficient` → `.insufficientHistory` ; sinon si le snapshot est `nil` malgré un historique « suffisant » → repli défensif sur `.noData`. `Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:76-82`
32. **La fraîcheur (staleness) est vérifiée avant le statut de gap** : si `now − computedAt > staleAfter`, l'état devient `.cached` **même si** la dernière nuit est un gap — l'état `.nightMissing` n'est donc jamais atteint quand la donnée est aussi périmée. `Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:83-87`
33. Ensuite seulement, si la dernière nuit est un gap → `.nightMissing(debt)`, avec la dette reportée (pas recalculée). `Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:86-87`
34. Ensuite, si la dette est ≤ `.ulpOfOne` (quasi zéro) → `.zero`. `Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:89-90`
35. Sinon → `.nominal(debt, trend)`. `Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:92`
36. Le seuil de fraîcheur (« staleAfter ») est fixé à 6 heures, décrit dans le code comme une valeur provisoire non mesurée. `Packages/SnapshotStore/Sources/SnapshotStore/StalenessPolicy.swift:11`

### 5. Ingestion HealthKit — attribution et agrégation des nuits

37. Une nuit `D` couvre la fenêtre `[midi la veille, midi le jour D)` ; un échantillon appartient à la nuit `D` selon sa date de **fin** (pas de début). `Packages/HealthSleepSource/Sources/HealthSleepSource/SleepNightAggregator.swift:19-27,55-59`
38. Cas limite documenté : une session qui se termine après midi (lève‑tard) bascule dans la fenêtre du jour **suivant**, pas dans celle qui vient de se fermer. `Packages/HealthSleepSource/Sources/HealthSleepSource/SleepNightAggregator.swift:22-27`
39. Un jour sans aucun échantillon (même `.inBed`/`.awake`) devient `.gap`. Un jour avec des échantillons dont la somme des stades « endormi » vaut zéro devient `.measured(asleep: 0)` — distinct d'un gap (vraie donnée à zéro vs absence de donnée). `Packages/HealthSleepSource/Sources/HealthSleepSource/SleepNightAggregator.swift:29-33,41-51`
40. Seuls les stades `.asleepUnspecified`, `.asleepCore`, `.asleepDeep`, `.asleepREM` comptent comme « endormi » ; `.inBed` et `.awake` sont explicitement exclus. `Packages/HealthSleepSource/Sources/HealthSleepSource/SleepNightAggregator.swift:13-15`
41. Les intervalles « endormi » qui se chevauchent (y compris entre sources différentes, ex. iPhone + Watch + app tierce) sont fusionnés par union d'intervalles — une plage couverte deux fois n'est comptée qu'une fois. `Packages/HealthSleepSource/Sources/HealthSleepSource/SleepNightAggregator.swift:71-94`
42. Un échantillon à cheval sur la frontière de midi est découpé (`clip`) pour ne compter que la portion dans la fenêtre à laquelle il est attribué. `Packages/HealthSleepSource/Sources/HealthSleepSource/SleepNightAggregator.swift:62-69`
43. `SleepIngestion.nights` détermine la plage de récupération à partir du jour le plus ancien et le plus récent demandés, élargie à leurs fenêtres midi‑à‑midi respectives. `Packages/HealthSleepSource/Sources/HealthSleepSource/SleepIngestion.swift:14-22`
44. `RefreshCoordinator` récupère 7 jours de plus que la fenêtre de 14 nuits du moteur (21 jours au total), pour couvrir le delta « depuis lundi » (jusqu'à 6 jours en arrière) et une courte série de gaps reportés. `Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:13-30`
45. `RefreshCoordinator` compte les nuits mesurées directement sur l'historique récupéré (pas via `SleepDebtEngine.historyAvailability`) : un gap isolé au sein d'un historique déjà établi ne déclenche pas « historique insuffisant » (le report de dette s'en charge) — c'est le temps de suivi total écoulé qui conditionne cet état, pas l'absence de gap dans la fenêtre courante. `Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:56-87`
46. Si le nombre de nuits mesurées récupérées est 0 → écrit `.none` et retourne `.noData`, **sans jamais interroger** l'historique précédemment mis en cache. `Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:71-75`
47. Si le nombre de nuits mesurées est entre 1 et 13 → écrit `.insufficient(measuredNights, requiredNights: 14)`. `Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:76-87`

### 6. Autorisation HealthKit

48. `HealthAuthorizationState.resolve` : si l'app n'a jamais demandé (`!didRequestBefore`) et que HealthKit ne rapporte pas non plus « déjà demandé » → `.needsPrompt`. `Packages/HealthSleepSource/Sources/HealthSleepSource/HealthAuthorizationState.swift:44-46`
49. Si l'app n'a jamais demandé **mais** HealthKit rapporte « déjà demandé » (cas de réinstallation par‑dessus une autorisation précédente), l'état bascule sur la présence de données (`hasAnySampleEver`) plutôt que de re‑demander l'accès. `Packages/HealthSleepSource/Sources/HealthSleepSource/HealthAuthorizationState.swift:47-53`
50. Si HealthKit indique qu'un nouveau type de lecture nécessite un nouveau consentement (`.shouldPromptAgain`), l'état redevient `.needsPrompt` — mais cette branche n'est évaluée qu'après le cas « jamais demandé » ci‑dessus. `Packages/HealthSleepSource/Sources/HealthSleepSource/HealthAuthorizationState.swift:54-57`
51. Dans tous les autres cas, l'état dépend uniquement de la présence de données (`hasAnySampleEver ? .readableWithData : .readableNoData`) — HealthKit ne révèle jamais explicitement un refus pour un type en lecture seule, donc « refusé » et « autorisé mais rien écrit » sont indiscernables et fusionnés. `Packages/HealthSleepSource/Sources/HealthSleepSource/HealthAuthorizationState.swift:1-6,58`
52. `hasAnySampleEver()` interroge l'existence d'au moins un échantillon sur **toute la plage de dates** (`predicateForSamples(withStart: nil, end: nil)`), avec `limit: 1`. `Packages/HealthSleepSource/Sources/HealthSleepSource/HealthKitSleepSource.swift:112-119`
53. L'app ne demande jamais l'écriture dans Santé (`toShare: []`), uniquement la lecture de `sleepAnalysis`. `Packages/HealthSleepSource/Sources/HealthSleepSource/HealthKitSleepSource.swift:41-43`
54. L'observation en tâche de fond (`HKObserverQuery`) est enregistrée avec livraison immédiate (`frequency: .immediate`), sans garantie documentée de délai réel de la plateforme. `Packages/HealthSleepSource/Sources/HealthSleepSource/HealthKitSleepSource.swift:45-50,68-81`

### 7. Persistance & staleness (App Group)

55. L'identifiant du groupe d'app partagé est `group.com.mikedotjs.deltasleep`, codé en un seul endroit ; doit correspondre exactement aux deux fichiers d'entitlements et à `project.yml`. `Packages/SnapshotStore/Sources/SnapshotStore/AppGroup.swift:11`
56. Si le conteneur du groupe d'app n'est pas résolvable (entitlement absent, build non provisionné), l'app retombe sur un répertoire temporaire plutôt que de crasher — comportement identique à « aucun snapshot en cache ». `Packages/SnapshotStore/Sources/SnapshotStore/AppGroup.swift:13-20`, `App/DeltaSleep/DeltaSleepApp.swift:14-19`
57. Le snapshot est encodé avec un numéro de schéma versionné (actuellement 1) ; un schéma non reconnu ou un fichier corrompu est décodé en `nil` silencieusement (jamais d'exception) — traité comme « pas de snapshot », donc une future version qui changerait de schéma verrait ses anciens caches simplement ignorés (pas de migration). `Packages/SnapshotStore/Sources/SnapshotStore/SnapshotCodec.swift:17-39`
58. L'écriture sur disque est atomique (`.atomic`). `Packages/SnapshotStore/Sources/SnapshotStore/FileSnapshotStore.swift:45`
59. Le snapshot et la disponibilité d'historique sont stockés dans deux fichiers JSON séparés (`debt-snapshot.json`, `history-availability.json`). `Packages/SnapshotStore/Sources/SnapshotStore/FileSnapshotStore.swift:16-17`
60. Le rechargement des timelines du widget n'est déclenché que si le contenu du nouveau snapshot diffère du précédent (égalité de contenu qui **ignore** `computedAt`) — mais le fichier snapshot est **toujours** réécrit à chaque refresh réussi, même sans changement de contenu, pour garder `computedAt` à jour et donc la fraîcheur exacte. `Packages/SnapshotStore/Sources/SnapshotStore/DebtSnapshot+ContentEquality.swift:4-25`, `Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:104-112`
61. Le widget lui‑même ne touche jamais HealthKit ni `RefreshCoordinator` — il lit uniquement le snapshot déjà en cache sur disque à chaque demande de timeline. `Widget/DeltaSleepWidget/DeltaSleepWidget.swift:7-10,41-56`
62. Le widget redemande une nouvelle timeline seulement après expiration du délai de fraîcheur (`policy: .after(now + staleAfter)`, soit 6h) — c'est ce mécanisme, et non une notification, qui fait basculer le widget en « cached » de lui‑même en l'absence de tout autre déclencheur. `Widget/DeltaSleepWidget/DeltaSleepWidget.swift:30-39`

### 8. Orchestration des rafraîchissements

63. Au lancement, l'orchestrateur **ne demande jamais** l'autorisation HealthKit automatiquement ; seul l'onboarding le fait explicitement, après que l'utilisateur a vu l'explication. `App/DeltaSleep/RefreshOrchestrator.swift:49-63`
64. `requestAuthorizationIfNeeded()` ne redemande le prompt système qu'une seule fois (gardé par un flag `UserDefaults`) ; `requestAuthorizationAgain()` le redemande sans condition (utilisé par le bouton de récupération sur l'état `.noData`). `App/DeltaSleep/RefreshOrchestrator.swift:68-84`
65. Les erreurs des appels HealthKit dans `resolveAuthorizationState()` sont avalées silencieusement (`try? … ?? .unknown` / `?? false`) — un échec réseau/système ne remonte jamais à l'UI comme une erreur distincte. `App/DeltaSleep/RefreshOrchestrator.swift:91-100`
66. Les rafraîchissements concurrents (observer HealthKit en tâche de fond vs. réactivation de scène) sont chaînés séquentiellement (`lastRefresh` Task) pour garantir que l'écriture qui termine en dernier correspond bien à la donnée demandée en dernier — sans cela, l'écriture inconditionnelle de `RefreshCoordinator.refresh` pourrait écraser un snapshot plus récent par un plus ancien. `App/DeltaSleep/RefreshOrchestrator.swift:102-135`
67. Les erreurs de `RefreshCoordinator.refresh` sont également avalées silencieusement (`try? …`) dans `performRefresh`. `App/DeltaSleep/RefreshOrchestrator.swift:137-149`
68. Un rafraîchissement est déclenché à chaque passage de l'app en premier plan (`scenePhase == .active`), en plus du rafraîchissement initial au lancement. `App/DeltaSleep/DeltaSleepApp.swift:40-44`

### 9. Onboarding

69. L'écran d'onboarding s'affiche tant que `didCompleteOnboarding` (UserDefaults) est `false` ; ensuite l'app va systématiquement à l'écran principal — aucun chemin de retour vers l'onboarding depuis l'UI. `App/DeltaSleep/RootView.swift:12-18`, `App/DeltaSleep/OnboardingViewModel.swift:10-22`
70. Le tap sur « Autoriser l'accès au sommeil » marque l'onboarding comme terminé **quel que soit le résultat réel** de la demande d'autorisation (accordée ou refusée) — HealthKit ne renvoie jamais explicitement ce résultat pour un type en lecture seule ; un refus n'est révélé qu'ensuite, via l'état `.noData` de l'écran principal. `App/DeltaSleep/OnboardingViewModel.swift:24-36`

### 10. Réglage du besoin de sommeil

71. Le besoin de sommeil par défaut est 8h00, utilisé quand aucune valeur valide n'est stockée. `App/DeltaSleep/SleepNeedStore.swift:11,19-22`
72. Une valeur stockée ≤ 0 seconde est traitée comme « non réglée » et retombe sur le défaut (8h) — aucune validation de plage n'existe au niveau du store lui‑même. `App/DeltaSleep/SleepNeedStore.swift:19-22`
73. Le seul contrôle de bornes (4h–12h, pas de 0,25h = 15 min) est imposé par le `Stepper` de l'UI, pas par le modèle `SleepNeed`/`SleepNeedStore` — un appel programmatique à `SleepNeedStore.set` avec une valeur hors de cette plage serait persisté sans erreur. `App/DeltaSleep/MainScreenView.swift:211-220`, `App/DeltaSleep/SleepNeedStore.swift:30-35`
74. Modifier le besoin déclenche un rafraîchissement avec `needChangedToday: true`, ce qui gèle la tendance du jour (règle §1.12) plutôt que de laisser un simple changement de réglage peindre la figure en vert/rouge. `App/DeltaSleep/MainScreenViewModel.swift:49-57`

### 11. Widget — comportement spécifique

75. Le widget ne supporte que les familles `.systemSmall` et `.systemMedium` (pas `.systemLarge`). `Widget/DeltaSleepWidget/DeltaSleepWidget.swift:73`
76. La bande des 14 nuits ne s'affiche que sur la taille `.systemMedium` — la taille `.systemSmall` ne montre jamais la bande, quelles que soient les données. `Widget/DeltaSleepWidget/WidgetContent.swift:142-145`
77. Le widget entier pointe vers une seule URL de deep‑link (`deltasleep://open`) : aucune zone interactive différenciée, tout tap ouvre l'app à sa racine. `Widget/DeltaSleepWidget/WidgetContent.swift:28`
78. En contexte d'aperçu système (`context.isPreview`), le widget affiche toujours l'état factice `.nominal(debt: 10h26, falling)`, jamais de vraies données. `Widget/DeltaSleepWidget/DeltaSleepWidget.swift:16-28`
79. Le `dynamicTypeSize` du widget est plafonné à `.xSmall … .xxxLarge` (contrairement à l'écran principal, qui n'a aucun plafond) — pour éviter un débordement du cadre fixe du widget. `Widget/DeltaSleepWidget/WidgetContent.swift:32-40`

### 12. Affichage, arrondis et conversions de durée

80. Format de durée : sous 1h → « X min » ; à partir de 1h → « H h MM » avec minutes toujours sur 2 chiffres (jamais « 1 h 4 »). Logique dupliquée à l'identique dans deux fichiers distincts (app et widget), sans source commune. `App/DeltaSleep/DurationCopy.swift:12-19`, `Widget/DeltaSleepWidget/DurationCopy.swift:11-18`
81. `wholeHoursAndMinutes` arrondit à la minute la plus proche et **supprime le signe** (utilise `abs(seconds)`) — la direction (hausse/baisse) est portée séparément par un glyphe de flèche, jamais par un nombre signé. `Packages/SleepDebtCore/Sources/SleepDebtCore/SleepDuration.swift:43-53`
82. L'« âge » d'une mesure (`DurationCopy.age`) plafonne l'écart à 0 si `computedAt` est dans le futur par rapport à `now` (dérive d'horloge) — affiche « 0 min » plutôt qu'une durée négative. `App/DeltaSleep/DurationCopy.swift:23-25`, `Widget/DeltaSleepWidget/WidgetContent.swift:121-125`
83. La couleur des cartes/gauge/figure (`AppTint`/`WidgetTint`) est dupliquée à l'identique entre l'app et le widget — même logique, deux fichiers distincts, aucune source partagée (GlassKit ne peut pas dépendre de SleepDebtCore). `App/DeltaSleep/AppTint.swift:1-38`, `Widget/DeltaSleepWidget/WidgetTint.swift:1-36`
84. `.unknown` (tendance) ne doit jamais retomber sur vert par défaut — code explicite pour éviter qu'un changement de réglage ou une nuit incomparable s'affiche comme « dette en baisse ». `App/DeltaSleep/AppTint.swift:23-27`, `Widget/DeltaSleepWidget/WidgetTint.swift:24-25`
85. Le compteur « Nuits sans donnée » affiché sur l'écran principal est le nombre de gaps **dans la fenêtre de 14 nuits actuelle**, pas un total historique. `App/DeltaSleep/MainScreenView.swift:186`
86. La statistique « Cette nuit » affiche un tiret cadratin (« — ») quand `lastNightSleepDuration` est `nil` (nuit manquante). `App/DeltaSleep/MainScreenView.swift:179-181`

### 13. Accessibilité / adaptation d'affichage (règles à effet comportemental, pas seulement visuel)

87. « Réduire la transparence » remplace tout le rendu glass (dégradés, halo, grain) par un fond opaque teinté par la même palette — pas de flou à approximer. `Packages/GlassKit/Sources/GlassKit/GlassSurface.swift:33-35,52-69`
88. « Augmenter le contraste » épaissit (2pt vs 1pt) et éclaircit le contour de la carte, mais uniquement dans l'environnement `.app` — le widget s'appuie toujours sur le halo système Liquid Glass, sans épaississement propre. `Packages/GlassKit/Sources/GlassKit/GlassSurface.swift:124-159`
89. Seul l'environnement `.app` dessine un contour/ombre externe propre ; l'environnement `.widget` ne dessine rien de plus, en s'appuyant sur le conteneur Liquid Glass système. `Packages/GlassKit/Sources/GlassKit/GlassEnvironment.swift:1-9`, `Packages/GlassKit/Sources/GlassKit/GlassSurface.swift:133-146`
90. La direction d'un `DeltaChip` est portée par la forme du glyphe (▲/▼), jamais par la seule couleur — la puce est visuellement identique quel que soit le tint ambiant. `Packages/GlassKit/Sources/GlassKit/DeltaChip.swift:3-16`

### 14. Debug (build DEBUG uniquement — absent de production)

91. Les 7 cas de `DebugStateFixture` correspondent exactement aux 7 `WidgetState` définis par le moteur. `App/DeltaSleep/DebugStateFixture.swift:13-21`
92. Le fixture « Historique insuffisant » code en dur `measuredNights: 6, requiredNights: 14` — le `14` n'est pas dérivé de `DebtEngineConstants.windowSize`, donc un futur changement de la constante ne serait pas reflété par ce fixture. `App/DeltaSleep/DebugStateFixture.swift:41`
93. Tous les fixtures utilisent un besoin fixe de 8h00 (`Self.need`), indépendamment de la valeur réellement configurée par l'utilisateur dans `SleepNeedStore`. `App/DeltaSleep/DebugStateFixture.swift:46,104-106`
94. Le fixture « En cache » force `computedAt` à `now − staleAfter − 3600s` (une heure au‑delà du seuil de fraîcheur) pour garantir la classification `.cached`. `App/DeltaSleep/DebugStateFixture.swift:79-84`
95. Le fixture de bandes de nuit place systématiquement le gap à l'index 3 sur 14, quel que soit le fixture choisi. `App/DeltaSleep/DebugStateFixture.swift:48-51`
96. Appliquer un fixture recharge le rendu via le même chemin qu'un vrai rafraîchissement (`reloadFromCache`), mais recrée un `WidgetCenterReloader()` local plutôt que de réutiliser le reloader injecté dans `RefreshOrchestrator` — chemin de code parallèle, pas d'incohérence fonctionnelle actuelle (le reloader réel est sans état) mais rupture du schéma d'injection de dépendances suivi partout ailleurs. `App/DeltaSleep/MainScreenViewModel.swift:92-105`
97. Le menu de debug est compilé hors des builds Release via `#if DEBUG`, à la fois dans la vue et dans le modèle — deux gardes indépendantes, jamais une seule. `App/DeltaSleep/MainScreenView.swift:63-66,70-90`, `App/DeltaSleep/MainScreenViewModel.swift:92-105`, `App/DeltaSleep/DebugStateFixture.swift:1,122`

---

## Résumé

- **97 règles métier** extraites, réparties en 14 groupes thématiques (moteur de calcul, jauge,
  bande de nuits, classification des 7 états, ingestion HealthKit, autorisation, persistance,
  orchestration, onboarding, réglage du besoin, widget, affichage/arrondis, accessibilité, debug).
- **10 entités** inventoriées (Night, DebtSnapshot, SleepNeed, HealthAuthorizationState,
  WidgetState, flag Onboarding, DebugStateFixture, Widget en tant que surface, « Historique
  complet », « Réinitialisation des données »), avec **3 cases vides signalées** : pas de moyen
  UI de repasser l'onboarding à zéro, pas de consultation d'historique au‑delà de 14 nuits /
  du delta depuis lundi, et aucune fonction de réinitialisation/déconnexion des données locales.

### Règles à valider humainement en priorité (suspectes)

1. **Règle §32 — l'ordre de classification masque « nuit manquante » derrière « en cache ».**
   `WidgetState.classify` (`Packages/SleepDebtCore/Sources/SleepDebtCore/WidgetState.swift:83-90`)
   vérifie la fraîcheur *avant* le statut de gap : si la dernière nuit est un gap **et** que le
   snapshot est périmé (>6h), l'utilisateur voit « donnée en cache » et jamais « nuit non
   mesurée » — asymétrie non commentée dans le code, potentiellement un angle mort plutôt
   qu'un choix voulu.

2. **Règle §46 — un fetch HealthKit vide écrase silencieusement un historique valide.**
   `RefreshCoordinator.refresh` (`Packages/SnapshotStore/Sources/SnapshotStore/RefreshCoordinator.swift:71-75`)
   écrit `.none` dès que le nombre de nuits mesurées dans le fetch courant est 0 — sans jamais
   consulter la disponibilité d'historique précédemment mise en cache. Combiné au fait que les
   erreurs de HealthKit sont avalées en amont (`try?` dans `RefreshOrchestrator.performRefresh`,
   `App/DeltaSleep/RefreshOrchestrator.swift:137-149`), un simple raté de requête (résultat vide
   sans exception) pourrait faire passer l'app de « historique établi » à « aucune donnée »
   en un seul cycle de rafraîchissement, sans distinction entre « vraiment jamais de donnée »
   et « ce fetch‑ci n'a rien renvoyé ».

3. **Règle §93 — les fixtures de debug ignorent le besoin de sommeil réel de l'utilisateur.**
   `App/DeltaSleep/DebugStateFixture.swift:46,104-106` code en dur un besoin de 8h00 pour
   tous les états simulés — un testeur qui a réglé son besoin à, disons, 6h30 verrait des
   fixtures affichant un besoin qu'il n'a jamais configuré, ce qui peut fausser une validation
   manuelle des écrans en debug (valeur en dur probablement accidentelle plutôt qu'un choix
   déclaré).

Mention additionnelle mineure : la constante `14` réapparaît codée en dur à plusieurs endroits
indépendants de `DebtEngineConstants.windowSize` (règle §92, fixture debug ; et implicitement
`RefreshCoordinator`'s `lookbackBufferDays` combiné à ce même 14) — pas un bug en soi, mais un
risque de drift si la fenêtre de calcul change un jour.

---

## Validation utilisateur (étape 2)

- **Règles 1–31, 33–45, 47–92, 94–97 (94 règles)** : `[ok]` confirmées telles quelles — aucune
  objection soulevée après relecture du document complet.
- **§32** (nuit manquante masquée par "en cache" quand périmé) : `[fix]` — confirmé bug. La
  vérification de gap doit primer sur (ou coexister avec) la vérification de fraîcheur.
- **§46** (fetch vide efface l'historique sans consulter le cache précédent) : `[fix]` — confirmé
  bug. Un fetch à 0 nuit mesurée ne doit pas écraser silencieusement un historique déjà établi.
- **§93** (fixtures debug figées à 8h00 de besoin) : `[fix]` — confirmé bug. Les fixtures doivent
  utiliser le besoin réellement configuré (`SleepNeedStore`).
- **Case vide « revoir l'onboarding »** : confirmé comme trou réel → capacité à ajouter.
- **Case vide « historique > 14 nuits »** : confirmé comme trou réel → capacité à ajouter.
- **Case vide « effacer mes données »** : confirmé comme trou réel → capacité à ajouter.

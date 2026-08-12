# PLAN — DeltaSleep (audit follow-up : #22, NOTE, trous de capacité)

> Généré par phase-pilot le 2026-08-12. Source de vérité de l'avancement.
> Format parsé par le dashboard — ne pas modifier la structure des
> lignes `## Phase N — titre [état]`. États : `[ ]` à faire, `[~]` en
> cours, `[x]` terminée.
>
> Périmètre : AUDIT_FINDINGS.md #22 + section NOTE (8 items) +
> BUSINESS_RULES.md's 3 capacités confirmées comme trous réels (revoir
> l'onboarding, historique > 14 nuits, effacer mes données). Aucun de
> ces items n'est un bug BLOQUANT/RISQUE — les 24 précédents sont déjà
> corrigés (commits antérieurs).

## Phase 1 — Écran Réglages : squelette et navigation [x]
Objectif: nouvel écran Réglages accessible depuis l'écran principal, navigation en place (premier NavigationStack de l'app), aucune action encore câblée
Vérif: `xcodebuild build -project DeltaSleep.xcodeproj -scheme DeltaSleep -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO` + lancer sur simulateur, naviguer vers Réglages et retour
- [x] `NavigationStack` autour de `MainScreenView` dans `RootView`
- [x] icône d'accès (engrenage) dans le header de `MainScreenView`
- [x] `SettingsView` avec 3 lignes placeholder (Revoir l'explication / Historique / Effacer mes données) sans action

## Phase 2 — Actions Réglages : revoir onboarding + effacer les données [x]
Objectif: les 2 actions simples fonctionnent de bout en bout (le trou "historique" est traité en phase 3-4, plus gros)
Vérif: manuel — "Revoir l'explication" repasse à l'onboarding ; "Effacer mes données" (avec confirmation) vide le cache et l'app revient à `.noData`
- [x] `OnboardingViewModel`/`RootView` : action pour remettre `didCompleteOnboarding` à `false`
- [x] fonction de reset centralisée (vide `SnapshotStore` + `SleepNeedStore` + le flag d'autorisation HealthKit demandée) — testable indépendamment de l'UI
- [x] `Alert` de confirmation avant "Effacer mes données" (action destructive)
- [x] tests unitaires sur la fonction de reset (package concerné)

## Phase 3 — Historique étendu : données [x]
Objectif: capacité de lire un historique au-delà de la fenêtre de calcul de 14 nuits, testée indépendamment de toute UI
Vérif: `swift test --package-path Packages/HealthSleepSource && swift test --package-path Packages/SnapshotStore`
- [x] étendre `SleepIngestion`/`HealthKitSleepSource` pour fetch une plage arbitraire (pas juste la fenêtre 21 jours actuelle) — `nights(for:from:calendar:)` l'acceptait déjà ; ajouté `days(count:endingOn:calendar:)` pour construire facilement une plage large
- [x] agrégation simple par nuit (réutilise `Night`, pas de nouveau modèle)
- [x] tests sur la nouvelle plage de fetch

## Phase 4 — Historique étendu : UI [x]
Objectif: écran Historique accessible depuis Réglages, liste/scroll des nuits passées au-delà des 14 dernières, état vide géré
Vérif: build simulateur + parcours manuel (Réglages → Historique → retour), vérifier l'état vide avec peu de données
- [x] `HistoryView` (liste simple : date + durée/gap par nuit)
- [x] lien Réglages → Historique
- [x] état vide avec copie explicite (pas d'écran blanc)

Note: parcours manuel sur simulateur impossible dans cet environnement
(cible de déploiement iOS 26.0, aucun runtime simulateur disponible ici
— même limite qu'en Phase 1). Build/link structurel vérifié.

## Phase 5 — #22 et NOTE restants [x]
Objectif: chaque finding restant traité individuellement, aucune régression sur l'existant
Vérif: `swift test` sur les 4 packages + `swiftlint lint --strict` + `swiftformat App Widget Packages --lint` + build simulateur
- [x] #22 : affordance "?" persistante près de la jauge/bande de nuits (popover légende courte, pas de coach-mark à état persisté)
- [x] delta exactement nul (▲ 0 min) : nouveau cas `DeltaChip.Direction.flat` au lieu de "hausse" par défaut
- [x] Stepper besoin de sommeil : saisie numérique directe (alert + TextField, en plus du Stepper)
- [x] Onboarding : bouton secondaire "Plus tard" (complète l'onboarding sans déclencher le prompt système)
- [x] Menu debug : icône chevron (DEBUG uniquement)
- [x] `GlassTokens.Spacing` : scale xs/sm/md/lg/xl, migré les literals répétés de `MainScreenView` (widget laissé tel quel — ses 9/14pt ne collent pas à l'échelle sans changer son layout compact)
- [x] `breakEvenTarget` : décision documentée dans `DebtSnapshot.swift` (reste interne — 5e stat row ferait doublon avec le tick de la jauge)
- [x] `DeltaChip` : label d'accessibilité par défaut si utilisé hors de son wrapper `.combine` actuel

## Phase 6 — États secondaires et polish [ ]
Objectif: chaque nouveau flow (Réglages, Historique) a ses états empty/erreur/loading, aucun dead end, cohérence visuelle avec l'existant
Vérif: `swift test` sur les 4 packages + `swiftlint lint --strict` + archive Release/device non signée (`xcodebuild archive ... CODE_SIGNING_ALLOWED=NO`)
- [ ] Réglages/Historique : état de chargement si pertinent
- [ ] chaque nouvel écran a une sortie claire (bouton retour visible, pas juste le geste de swipe)
- [ ] passe de cohérence visuelle (les nouveaux écrans utilisent `GlassTokens`, pas de valeurs codées en dur nouvelles)
- [ ] mise à jour `BUSINESS_RULES.md` : les 3 cases vides ne sont plus des trous, section "Validation utilisateur" à jour

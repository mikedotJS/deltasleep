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

## Phase 1 — Écran Réglages : squelette et navigation [ ]
Objectif: nouvel écran Réglages accessible depuis l'écran principal, navigation en place (premier NavigationStack de l'app), aucune action encore câblée
Vérif: `xcodebuild build -project DeltaSleep.xcodeproj -scheme DeltaSleep -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO` + lancer sur simulateur, naviguer vers Réglages et retour
- [ ] `NavigationStack` autour de `MainScreenView` dans `RootView`
- [ ] icône d'accès (engrenage) dans le header de `MainScreenView`
- [ ] `SettingsView` avec 3 lignes placeholder (Revoir l'explication / Historique / Effacer mes données) sans action

## Phase 2 — Actions Réglages : revoir onboarding + effacer les données [ ]
Objectif: les 2 actions simples fonctionnent de bout en bout (le trou "historique" est traité en phase 3-4, plus gros)
Vérif: manuel — "Revoir l'explication" repasse à l'onboarding ; "Effacer mes données" (avec confirmation) vide le cache et l'app revient à `.noData`
- [ ] `OnboardingViewModel`/`RootView` : action pour remettre `didCompleteOnboarding` à `false`
- [ ] fonction de reset centralisée (vide `SnapshotStore` + `SleepNeedStore` + le flag d'autorisation HealthKit demandée) — testable indépendamment de l'UI
- [ ] `Alert` de confirmation avant "Effacer mes données" (action destructive)
- [ ] tests unitaires sur la fonction de reset (package concerné)

## Phase 3 — Historique étendu : données [ ]
Objectif: capacité de lire un historique au-delà de la fenêtre de calcul de 14 nuits, testée indépendamment de toute UI
Vérif: `swift test --package-path Packages/HealthSleepSource && swift test --package-path Packages/SnapshotStore`
- [ ] étendre `SleepIngestion`/`HealthKitSleepSource` pour fetch une plage arbitraire (pas juste la fenêtre 21 jours actuelle)
- [ ] agrégation simple par nuit (réutilise `Night`, pas de nouveau modèle si possible)
- [ ] tests sur la nouvelle plage de fetch

## Phase 4 — Historique étendu : UI [ ]
Objectif: écran Historique accessible depuis Réglages, liste/scroll des nuits passées au-delà des 14 dernières, état vide géré
Vérif: build simulateur + parcours manuel (Réglages → Historique → retour), vérifier l'état vide avec peu de données
- [ ] `HistoryView` (liste simple : date + durée/gap par nuit)
- [ ] lien Réglages → Historique
- [ ] état vide avec copie explicite (pas d'écran blanc)

## Phase 5 — #22 et NOTE restants [ ]
Objectif: chaque finding restant traité individuellement, aucune régression sur l'existant
Vérif: `swift test` sur les 4 packages + `swiftlint lint --strict` + `swiftformat App Widget Packages --lint` + build simulateur
- [ ] #22 : affordance "?" persistante près de la jauge/bande de nuits (légende courte, pas de coach-mark à état persisté — plus simple, toujours disponible)
- [ ] delta exactement nul (▲ 0 min) : direction neutre au lieu de "hausse" par défaut
- [ ] Stepper besoin de sommeil : saisie numérique directe (en plus du Stepper, pas à sa place)
- [ ] Onboarding : bouton secondaire "Plus tard" (complète l'onboarding sans déclencher le prompt système)
- [ ] Menu debug : icône chevron (DEBUG uniquement)
- [ ] `GlassTokens` : scale de spacing partagée (xs/sm/md/lg), migration des literals les plus répétés dans `MainScreenView`/`WidgetContent`
- [ ] `breakEvenTarget` : décision — afficher en stat row ("Nuit cible") ou documenter explicitement pourquoi il reste interne
- [ ] `DeltaChip` : label d'accessibilité par défaut si utilisé hors de son wrapper `.combine` actuel

## Phase 6 — États secondaires et polish [ ]
Objectif: chaque nouveau flow (Réglages, Historique) a ses états empty/erreur/loading, aucun dead end, cohérence visuelle avec l'existant
Vérif: `swift test` sur les 4 packages + `swiftlint lint --strict` + archive Release/device non signée (`xcodebuild archive ... CODE_SIGNING_ALLOWED=NO`)
- [ ] Réglages/Historique : état de chargement si pertinent
- [ ] chaque nouvel écran a une sortie claire (bouton retour visible, pas juste le geste de swipe)
- [ ] passe de cohérence visuelle (les nouveaux écrans utilisent `GlassTokens`, pas de valeurs codées en dur nouvelles)
- [ ] mise à jour `BUSINESS_RULES.md` : les 3 cases vides ne sont plus des trous, section "Validation utilisateur" à jour

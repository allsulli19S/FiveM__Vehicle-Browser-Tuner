# Vehicle Browser & Tuner

Vehicle Browser & Tuner est une ressource FiveM permettant de parcourir, spawn, personnaliser et sauvegarder facilement des véhicules directement en jeu via une interface NUI.

Le script scanne automatiquement les véhicules disponibles dans les resources du serveur, les affiche dans un catalogue, et permet de les faire apparaître rapidement. Il inclut aussi un système de garage avec sauvegarde en base de données, restauration du tuning, blips, respawn automatique et suivi des dernières coordonnées du véhicule.

## Fonctionnalités

- Catalogue automatique des véhicules installés sur le serveur
- Spawn rapide depuis une interface NUI
- Onglet de personnalisation en direct
- Modification des performances, carrosserie, roues, couleurs, néons, plaque et extras
- Sliders désactivés automatiquement quand une modification n’existe pas sur le véhicule
- Sauvegarde des véhicules en base de données
- Garage avec sortie, rangement/despawn et suppression des véhicules
- Sauvegarde continue des dernières coordonnées des véhicules sortis
- Respawn automatique des véhicules sauvegardés à leur dernière position
- Blips personnalisés pour les véhicules du garage
- Interface transparente pensée pour mieux voir les modifications en jeu

## Dépendances

- `oxmysql`
- QBox / QB-Core selon la configuration du serveur

## Configuration

La ressource se configure depuis `config.lua`, notamment pour activer le garage, les blips, le respawn automatique, le délai de sauvegarde des coordonnées et les chemins de scan des fichiers `vehicles.meta`.

## Objectif

Ce projet a été conçu pour simplifier la gestion des véhicules sur un serveur FiveM, en regroupant dans une seule interface le spawn, la personnalisation, la sauvegarde et la gestion du garage.

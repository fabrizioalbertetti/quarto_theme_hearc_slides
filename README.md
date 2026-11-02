# Extension Quarto : diapositives HE-Arc Ingénierie (reveal.js)

Extension Quarto pour produire des présentations de cours en HTML (reveal.js), avec un thème
graphique aligné sur le logo HE-Arc Ingénierie (rouge `#FF0000`, noir, fond blanc).

Le format `theme-hearc-revealjs` produit deux fichiers par présentation :

| Fichier      | Usage                                                                  |
|--------------|------------------------------------------------------------------------|
| `cours.html` | projection dans un navigateur, avec animations et notes de l'orateur (touche `S`) |
| `cours.pdf`  | à distribuer : une page par diapositive, dans l'état final de ses animations, sans les notes (exporté automatiquement) |

## Prérequis

- [Quarto](https://quarto.org) ≥ 1.4
- Pour l'export PDF : Google Chrome, Chromium ou Microsoft Edge (cherché automatiquement ;
  sinon, indiquer son chemin dans la variable d'environnement `QUARTO_CHROMIUM`)

## Installation

Dans le dépôt du cours :

```sh
quarto add fabrizioalbertetti/quarto_theme_hearc_beamer/extension
```

L'extension est installée dans `_extensions/fabrizioalbertetti/theme-hearc/` (à committer avec le
cours). Utiliser ensuite le format dans `_quarto.yml` ou dans l'en-tête d'un `.qmd` :

```yaml
format: theme-hearc-revealjs
```

Pour partir de l'exemple complet, copier aussi les fichiers de départ (`_quarto.yml` et
`01-exemple.qmd`) :

```sh
quarto use template fabrizioalbertetti/quarto_theme_hearc_beamer/example
```

### Fichiers à ignorer

`quarto render` et `quarto preview` génèrent des fichiers qui ne doivent pas être committés.
Ajouter au `.gitignore` du dépôt du cours :

```gitignore
# Rendus (cours.html, cours_files/...), sauf les PDF, conservés pour être distribués
/_output/*
!/_output/*.pdf
# Cache et index de Quarto, dont l'état de quarto preview
/.quarto/
# Logo copié à côté de chaque .qmd au moment du rendu (mais pas celui de l'extension)
logo-he-arc-ing.jpg
!/_extensions/**/logo-he-arc-ing.jpg
# Notebooks intermédiaires (diapositives qui exécutent du code)
**/*.quarto_ipynb
```

Écrire `/_output/*` et non `_output/` : git ne peut pas ré-inclure un fichier (ici les PDF)
dont le dossier parent est entièrement ignoré. Le dossier `_extensions/` doit au contraire
être committé. Sans `output-dir` dans
`_quarto.yml`, les rendus sont écrits à côté des `.qmd` : ignorer alors aussi `*.html` et
`*_files/`.

Un exemple commenté se trouve dans [example/.gitignore](example/.gitignore). Comme Quarto ne
copie pas les fichiers cachés d'un template, `quarto use template` ne l'installe pas : le
copier à la main.

### Mise à jour

```sh
quarto update extension fabrizioalbertetti/quarto_theme_hearc_beamer/extension
```

Pour figer une version, ajouter un tag : `quarto add fabrizioalbertetti/quarto_theme_hearc_beamer/extension@v2.0.0`.

## Utilisation

1. Adapter les **paramètres communs** dans `_quarto.yml` :

   ```yaml
   course:
     name: "Intelligence Artificielle"
     short: "IA"        # page de titre et pied de page (optionnel)
     class: "ISC3"     # classe / volée
     footer: ""          # texte à gauche du pied de page (optionnel)
   author: "Fabrizio Albertetti"
   institute: "HE-Arc Ingénierie"

   format:
     theme-hearc-revealjs: default
   ```

   Toute [option reveal.js de Quarto](https://quarto.org/docs/presentations/revealjs/) peut
   être ajoutée sous le format (par ex. `incremental: true`).

2. Créer une présentation par fichier `.qmd`, avec ses **paramètres propres** :

   ```markdown
   ---
   title: "Héritage et polymorphisme"
   subtitle: "Semaine 3"
   ---

   # Section

   ## Titre de la diapositive

   - contenu
   ```

3. Générer les présentations :

   ```sh
   quarto render                   # toutes les présentations → _output/ (HTML + PDF)
   quarto render 03-heritage.qmd   # une seule (HTML + PDF)
   quarto preview 03-heritage.qmd  # rendu automatique à chaque sauvegarde (HTML seul)
   ```

   Le PDF est exporté par `quarto render` uniquement (quelques secondes par présentation) :

   | Commande                                   | PDF exporté ?                               |
   |--------------------------------------------|---------------------------------------------|
   | `quarto render`, `quarto render cours.qmd` | oui                                         |
   | `quarto preview cours.qmd` (et le bouton *Preview* de VS Code) | non                     |
   | `quarto preview` (projet entier)           | au démarrage seulement, pour les présentations à re-rendre ; jamais aux sauvegardes suivantes |

   Quarto n'exécute le script d'export (`pdf-export.lua`) que lors du rendu d'un projet,
   sans indiquer s'il s'agit d'une prévisualisation. Pour éviter l'export au démarrage de
   `quarto preview`, préférer `quarto preview cours.qmd`, ou définir la variable
   d'environnement `HEARC_NO_PDF=1` (par ex. `HEARC_NO_PDF=1 quarto preview`).

Toute clé définie dans un `.qmd` remplace celle de `_quarto.yml` (par ex. `date`, `author`).

## Syntaxe utile

| Élément               | Syntaxe                                         |
|-----------------------|-------------------------------------------------|
| Page de section       | `# Titre`                                       |
| Diapositive           | `## Titre`                                      |
| Bloc / alerte / exemple | `### Titre`, `### Titre {.alert}`, `### Titre {.example}` |
| Pause                 | `. . .`                                         |
| Liste progressive     | `::: incremental` … `:::`                       |
| Colonnes              | `:::: columns` + `::: {.column width="50%"}`    |
| Animation             | `{.fragment}`, `{.fragment .fade-out}`, `::: r-stack` (images superposées) |
| Contenu trop long     | `## Titre {.scrollable}` (défilement ; réduit pour tenir sur une page dans le PDF), `{.smaller}` |
| Notes de l'orateur    | `::: notes` … `:::` (touche `S`, jamais dans le PDF) |
| Image                 | `![légende](images/schema.svg){width=80%}` (SVG, PNG ou JPG) |

Voir [example/01-exemple.qmd](example/01-exemple.qmd) pour un exemple complet, commenté.

## Structure du dépôt

```
extension/                   l'extension Quarto (installée par `quarto add`)
  _extensions/theme-hearc/
    _extension.yml           format `theme-hearc-revealjs` (16:9, français, export PDF…)
    hearc-ing.scss           thème (couleurs, polices, titre, pied de page, blocs)
    title-slide.html         page de titre (cours, classe, logo)
    course-meta.lua          transmet `course.*` au thème ; regroupe les titres `###` en blocs
    pdf-export.lua           après le rendu, exporte `cours.html` en `cours.pdf` (navigateur sans interface)
    pdf-print.html           ajustements du mode impression (diapositives défilantes, pied de page)
    logo-he-arc-ing.jpg      logo de la page de titre
example/                     projet Quarto d'exemple qui utilise l'extension
  _quarto.yml                paramètres communs du cours
  01-exemple.qmd             présentation d'exemple
  images/                    images SVG
    src/                     sources TikZ ; `sh images/src/build.sh` régénère les images
```

## Développement

L'exemple utilise une copie locale de l'extension (`example/_extensions/`, ignorée par git).
Après chaque modification dans `extension/`, la réinstaller puis regénérer l'exemple :

```sh
cd example
quarto add ../extension --no-prompt
quarto render                   # → example/_output/01-exemple.html et .pdf
```

## Personnalisation

- **Couleurs, polices, mise en page** : `extension/_extensions/theme-hearc/hearc-ing.scss`.
  Pour une modification propre à un cours, éditer la copie installée dans ce cours ;
  pour la partager, la faire dans ce dépôt puis `quarto update` dans les cours.
- **Autre thème** : `theme: simple` (ou tout thème reveal.js) sous `format: theme-hearc-revealjs:`.
  La page de titre et le pied de page restent ceux de l'extension, mais sans la charte HE-Arc.

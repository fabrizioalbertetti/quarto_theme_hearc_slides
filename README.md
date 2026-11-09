# Extension Quarto : thème de diapositives HE-Arc Ingénierie (beamer PDF + slides reveal.js)

Extension Quarto pour produire des slides de cours (beamer PDF + reveal.js), avec un thème
graphique aligné sur le logo HE-Arc Ingénierie (rouge `#FF0000`, noir, fond blanc).

![Exemple de diapositive du PDF généré par l'extension.](example/images/rendu-exemple-diapositive.png)

Le format `theme-hearc-slides-revealjs` produit deux fichiers par présentation :

| Fichier      | Usage                                                                  |
|--------------|------------------------------------------------------------------------|
| `cours.html` | projection dans un navigateur, avec animations et notes de l'orateur (touche `S`) |
| `cours.pdf`  | à distribuer : une page par diapositive, dans l'état final de ses animations, sans les notes (exporté automatiquement) |

## Prérequis

- [Quarto](https://quarto.org) ≥ 1.4
- Pour l'export PDF : Python 3.6+ et Google Chrome, Chromium ou Microsoft Edge (cherché
  automatiquement ; sinon, indiquer leurs chemins dans les variables d'environnement
  `QUARTO_PYTHON` et `QUARTO_CHROMIUM`). Sous Windows, le lanceur `py -3` est aussi détecté.
  Sans navigateur (par ex. sur un serveur Linux), `quarto install chrome-headless-shell`
  en installe un, sans droits administrateur, qui est aussi détecté.

## Installation

Dans le dépôt du cours :

```sh
quarto add fabrizioalbertetti/quarto_theme_hearc_slides/extension
```

Le dépôt GitHub contient aussi l'exemple : `/extension` est donc nécessaire pour
indiquer à Quarto le dossier de l'extension.

L'extension est installée dans `_extensions/fabrizioalbertetti/theme-hearc-slides/` (à committer avec le
cours). Utiliser ensuite le format dans `_quarto.yml` ou dans l'en-tête d'un `.qmd` :

```yaml
format: theme-hearc-slides-revealjs
```

Pour partir de l'exemple complet, copier aussi les fichiers de départ (`_quarto.yml` et
`01-exemple.qmd`) :

```sh
quarto use template fabrizioalbertetti/quarto_theme_hearc_slides/example
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
quarto update extension fabrizioalbertetti/quarto_theme_hearc_slides/extension
```

Pour figer une version, ajouter un tag : `quarto add fabrizioalbertetti/quarto_theme_hearc_slides/extension@v2.0.0`.

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
     theme-hearc-slides-revealjs: default
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
| Animation d'un paragraphe / élément de liste | marqueur en tête : `[]{.frag fragment-index=2}` (apparaît), `[]{.frag out-index=3}` (disparaît), ou les deux |
| Schéma draw.io animé  | `![](images/schema.drawio.svg)` ; propriétés `fragment` / `fragment-out` sur les formes (voir ci-dessous) |
| Contenu trop long     | `## Titre {.scrollable}` (défilement ; réduit pour tenir sur une page dans le PDF), `{.smaller}` |
| Notes de l'orateur    | `::: notes` … `:::` (touche `S`, jamais dans le PDF) |
| Image                 | `![légende](images/schema.svg){width=80%}` (SVG, PNG ou JPG) |

Voir [example/01-exemple.qmd](example/01-exemple.qmd) pour un exemple complet, commenté.

## Structure du dépôt

```
extension/                   l'extension Quarto (installée par `quarto add`)
  _extensions/theme-hearc-slides/
    _extension.yml           format `theme-hearc-slides-revealjs` (16:9, français, export PDF…)
    hearc-ing.scss           thème (couleurs, polices, titre, pied de page, blocs)
    title-slide.html         page de titre (cours, classe, logo)
    course-meta.lua          transmet `course.*` au thème ; regroupe les titres `###` en blocs
    pdf-export.lua           après le rendu, exporte `cours.html` en `cours.pdf` (navigateur sans interface)
    pdf-print.html           ajustements du mode impression (diapositives défilantes, pied de page)
    frag/                    plugin reveal.js : animations paragraphe par paragraphe (`[]{.frag ...}`)
    drawio-fragments.lua     insère les schémas `.drawio.svg` animés dans la page
    logo-he-arc-ing.jpg      logo de la page de titre
example/                     projet Quarto d'exemple qui utilise l'extension
  _quarto.yml                paramètres communs du cours
  01-exemple.qmd             présentation d'exemple
  images/                    images SVG
    src/                     sources TikZ ; `sh images/src/build.sh` régénère les images
    build-drawio.ps1       génère les versions éditables dans draw.io
```

## Développement

L'exemple utilise une copie locale de l'extension (`example/_extensions/`, ignorée par git).
Après chaque modification dans `extension/`, la réinstaller puis regénérer l'exemple :

```sh
cd example
quarto add ../extension --no-prompt
quarto render                   # → example/_output/01-exemple.html et .pdf
```

Les fichiers `images/*.drawio.svg` conservent le rendu SVG et contiennent aussi
un diagramme draw.io éditable : cercles, connexions, points, centroïdes et libellés
sont des objets séparés. Après avoir régénéré les SVG depuis les sources TikZ,
générer ou mettre à jour ces versions avec :

```powershell
pwsh -File images/src/build-drawio.ps1
```

### Schémas draw.io animés

Dans draw.io, sélectionner une forme (ou un groupe), *Édition > Modifier les données*
(`Ctrl+M`) et ajouter la propriété `fragment` (étape d'apparition) et/ou
`fragment-out` (étape de disparition). Les étapes sont communes avec les
`fragment-index` du texte de la diapositive. Exporter en SVG avec la copie du
diagramme et les métadonnées des cellules, dans un fichier `*.drawio.svg` :

```sh
draw.io -x -f svg -e --embed-svg-metadata -o images/pipeline.drawio.svg images/src/pipeline.drawio
```

Exemple : `example/images/src/pipeline.drawio`, diapositive « Schéma draw.io animé ».

## Personnalisation

- **Couleurs, polices, mise en page** : `extension/_extensions/theme-hearc-slides/hearc-ing.scss`.
  Pour une modification propre à un cours, éditer la copie installée dans ce cours ;
  pour la partager, la faire dans ce dépôt puis `quarto update` dans les cours.
- **Autre thème** : `theme: simple` (ou tout thème reveal.js) sous `format: theme-hearc-slides-revealjs:`.
  La page de titre et le pied de page restent ceux de l'extension, mais sans la charte HE-Arc.

-- Sources des images, schémas, définitions et citations repris d'un tiers.
--
-- Attributs reconnus (sur une image, un bloc `:::` ou un titre de diapositive) :
--   source="Texte"          auteur, site ou ouvrage (Markdown accepté)
--   source-url="https://…"  lien sur le texte de la source (optionnel)
--   license="CC BY-SA 4.0"  licence, ajoutée après la source (optionnel)
--   source-label="D'après"  remplace « Source » (par ex. « D'après » pour une
--                           image redessinée ou modifiée ; optionnel)
--
-- Placement :
--   - image, titre « ## » : ligne « Source : … » en bas de la diapositive,
--     au-dessus du pied de page (une seule ligne par diapositive, sans doublon) ;
--     la source d'une image animée (`.fragment`, sur l'image ou un bloc
--     parent) apparaît en même temps qu'elle ;
--   - bloc `:::` (définition, citation…) : dernière ligne du bloc, à droite.
--
-- Un `[Source : …]{.source}` écrit à la main a le même style.

local KEYS = { "source", "source-url", "license", "source-label" }

local function read_inlines(text)
  local blocks = pandoc.read(text, "markdown").blocks
  if #blocks == 0 then
    return pandoc.Inlines({})
  end
  return pandoc.utils.blocks_to_inlines(blocks)
end

-- Lit et retire les attributs de source d'un élément ; nil sans `source`
local function take(el, frag)
  local attrs = el.attributes
  local text = attrs["source"]
  if text == nil or text == "" then
    return nil
  end
  local item = {
    text = text,
    url = attrs["source-url"],
    license = attrs["license"],
    label = attrs["source-label"] or "Source",
    frag = frag,
  }
  for _, key in ipairs(KEYS) do
    attrs[key] = nil
  end
  return item
end

-- « Texte, licence » (texte lié si source-url)
local function item_inlines(item)
  local inlines = read_inlines(item.text)
  if item.url and item.url ~= "" then
    inlines = pandoc.Inlines({ pandoc.Link(inlines, item.url) })
  end
  if item.license and item.license ~= "" then
    inlines:insert(pandoc.Str(","))
    inlines:insert(pandoc.Space())
    inlines:extend(read_inlines(item.license))
  end
  return inlines
end

-- « Source : A » ; « Sources : A ; B » ; libellés différents : « D'après : A ; Source : B »
local function line(items)
  local same = true
  for _, item in ipairs(items) do
    if item.label ~= items[1].label then
      same = false
    end
  end
  local out = pandoc.Inlines({})
  for i, item in ipairs(items) do
    if i > 1 then
      out:extend({ pandoc.Space(), pandoc.Str(";"), pandoc.Space() })
    end
    if i == 1 or not same then
      local label = item.label
      if same and #items > 1 and label == "Source" then
        label = "Sources"
      end
      out:extend({ pandoc.Str(label), pandoc.Space(), pandoc.Str(":"), pandoc.Space() })
    end
    out:extend(item_inlines(item))
  end
  return out
end

-- Ajoute item à la liste, sauf doublon (même texte, même lien)
local function add(list, item)
  for _, other in ipairs(list) do
    if other.text == item.text and other.url == item.url and other.license == item.license
        and other.label == item.label and other.frag == item.frag then
      return
    end
  end
  table.insert(list, item)
end

-- Élément animé (`.fragment`) qui contient l'image : sa source n'est affichée
-- qu'une fois l'élément visible. Le numéro (`data-source-ref`, propre à la
-- diapositive) n'est attribué qu'à un élément contenant une image sourcée ;
-- hearc-ing.scss masque `[data-source=n]` tant que `[data-source-ref=n]`
-- n'est pas visible. Une ligne de source en `.fragment` aurait sa propre étape.
local function fragment_of(el, inherited)
  if el.classes:includes("fragment") then
    return { el = el }
  end
  return inherited
end

local function fragment_ref(frag, slide_items)
  if not frag.ref then
    slide_items.refs = (slide_items.refs or 0) + 1
    frag.ref = tostring(slide_items.refs)
    frag.el.attributes["data-source-ref"] = frag.ref
  end
  return frag.ref
end

-- Parcourt le contenu d'une diapositive : sources des blocs placées dans le
-- bloc, sources des images collectées pour le bas de la diapositive
local collect

local function filter(slide_items, frag)
  return {
    traverse = "topdown",
    Div = function(div)
      local item = take(div)
      div.content = collect(div.content, slide_items, fragment_of(div, frag))
      if item then
        div.content:insert(pandoc.Div(pandoc.Plain(line({ item })), { class = "source source-block" }))
      end
      return div, false
    end,
    Span = function(span)
      local f = fragment_of(span, frag)
      if f ~= frag then
        span.content = span.content:walk(filter(slide_items, f))
        return span, false
      end
    end,
    Image = function(img)
      local f = fragment_of(img, frag)
      local item = take(img, f)
      if item then
        if f then
          fragment_ref(f, slide_items)
        end
        add(slide_items, item)
        return img
      end
    end,
  }
end

collect = function(blocks, slide_items, frag)
  return blocks:walk(filter(slide_items, frag))
end

-- Sources fixes regroupées sur une ligne ; chaque source d'une image animée
-- dans un Span affiché avec elle
local function slide_footer(items)
  local static, animated = {}, {}
  for _, item in ipairs(items) do
    table.insert(item.frag and animated or static, item)
  end
  local out = pandoc.Inlines({})
  if #static > 0 then
    out:extend(line(static))
  end
  for _, item in ipairs(animated) do
    local inlines = pandoc.Inlines({})
    if #out > 0 then
      inlines:extend({ pandoc.Space(), pandoc.Str(";"), pandoc.Space() })
    end
    inlines:extend(line({ item }))
    out:insert(pandoc.Span(inlines, { ["data-source"] = item.frag.ref }))
  end
  return pandoc.Div(pandoc.Plain(out), { class = "source source-slide" })
end

-- Découpe le document en diapositives (titres de niveau 1 et 2, ou `---`)
-- et ajoute la ligne de sources à la fin de chacune
function Pandoc(doc)
  local result = pandoc.Blocks({})
  local slide = pandoc.Blocks({})
  local header = nil
  local items = {}

  local function flush()
    slide = collect(slide, items)
    if header then
      result:insert(header)
    end
    result:extend(slide)
    if #items > 0 then
      result:insert(slide_footer(items))
    end
    slide = pandoc.Blocks({})
    header = nil
    items = {}
  end

  for _, el in ipairs(doc.blocks) do
    if (el.t == "Header" and el.level <= 2) or el.t == "HorizontalRule" then
      flush()
      if el.t == "Header" then
        header = el
        local item = take(el)
        if item then
          add(items, item)
        end
      else
        result:insert(el)
      end
    else
      slide:insert(el)
    end
  end
  flush()
  doc.blocks = result
  return doc
end

-- Plan du cours : chaque titre « # » (section) devient une diapositive
-- « Plan » qui liste toutes les sections de la présentation, la section qui
-- commence étant mise en évidence. Les sections ne sont écrites qu'une fois,
-- dans les titres « # » : le plan est recalculé à chaque rendu.
--
-- Options (en-tête du .qmd ou _quarto.yml) :
--   outline: false              désactive le plan
--   outline:
--     title: "Plan"             titre des diapositives de plan (défaut : « Plan »)
--     label: true               rappel de la section (« 2) Titre ») en haut à
--                               droite de chaque diapositive de la section
--     min: 2                    nombre minimal de sections pour afficher le plan
--
-- Une section absente du plan : `# Titre {.unlisted}` (garde sa page de
-- section habituelle). Une section masquée (`visibility="hidden"`) est ignorée.

local options = { enabled = true, title = "Plan", label = false, min = 2 }

local function read_options(meta)
  local o = meta.outline
  if o == nil then
    return
  end
  if type(o) == "boolean" then
    options.enabled = o
    return
  end
  if pandoc.utils.type(o) ~= "table" then
    options.enabled = pandoc.utils.stringify(o) ~= "false"
    return
  end
  if o.enabled ~= nil then
    options.enabled = o.enabled == true or pandoc.utils.stringify(o.enabled) == "true"
  end
  if o.title ~= nil then
    options.title = pandoc.utils.stringify(o.title)
  end
  if o.label ~= nil then
    options.label = o.label == true or pandoc.utils.stringify(o.label) == "true"
  end
  if o.min ~= nil then
    options.min = tonumber(pandoc.utils.stringify(o.min)) or options.min
  end
end

local function listed(el)
  return el.t == "Header" and el.level == 1
    and not el.classes:includes("unlisted")
    and el.attributes["visibility"] ~= "hidden"
end

-- Liste numérotée des sections, `current` (indice) mise en évidence
local function outline_list(sections, current)
  local items = {}
  for i, h in ipairs(sections) do
    local inlines = h.content:clone()
    local class = i == current and "outline-current" or (i < current and "outline-done" or "outline-next")
    table.insert(items, { pandoc.Plain({ pandoc.Span(inlines, { class = class }) }) })
  end
  return pandoc.OrderedList(items)
end

local function label(sections, i)
  local inlines = pandoc.Inlines({ pandoc.Str(tostring(i) .. ")"), pandoc.Space() })
  inlines:extend(sections[i].content:clone())
  return pandoc.Div({ pandoc.Plain(inlines) }, { class = "seclabel" })
end

function Pandoc(doc)
  read_options(doc.meta)
  if not options.enabled then
    return nil
  end
  local sections = {}
  for _, el in ipairs(doc.blocks) do
    if listed(el) then
      table.insert(sections, el)
    end
  end
  if #sections < options.min then
    return nil
  end

  local result = pandoc.Blocks({})
  local index = 0   -- numéro de la dernière section du plan
  local current = 0 -- section en cours (0 : hors plan)
  for _, el in ipairs(doc.blocks) do
    if el.t == "Header" and el.level == 1 then
      if listed(el) then
        index = index + 1
        current = index
        -- Le titre « # » reste (navigation, menu, liens #id) mais est masqué :
        -- la diapositive affiche le titre du plan et la liste des sections
        el.classes:insert("hearc-outline")
        result:insert(el)
        result:insert(pandoc.Div({
          pandoc.Div({ pandoc.Plain({ pandoc.Str(options.title) }) }, { class = "outline-title" }),
          outline_list(sections, current),
        }, { class = "hearc-outline-list" }))
      else
        current = 0 -- section hors plan : pas de rappel sur ses diapositives
        result:insert(el)
      end
    elseif options.label and current > 0 and el.t == "Header" and el.level == 2 then
      result:insert(el)
      result:insert(label(sections, current))
    else
      result:insert(el)
    end
  end
  doc.blocks = result
  return doc
end

-- Transmet les paramètres communs du cours (clé `course` de _quarto.yml)
-- au thème HE-Arc : ligne « cours · classe » de la page de titre et pied de
-- de page. Regroupe aussi chaque titre « ### » et son contenu en bloc.

local function to_inlines(value)
  if value == nil then
    return pandoc.Inlines({})
  end
  if pandoc.utils.type(value) == "Inlines" then
    return value
  end
  return pandoc.Inlines(pandoc.utils.stringify(value))
end

-- « Nom du cours · Classe », sans séparateur orphelin si un champ manque
local function course_line(name, class)
  local line = pandoc.Inlines({})
  line:extend(name)
  if #name > 0 and #class > 0 then
    line:insert(pandoc.Space())
    line:insert(pandoc.Span("•", { class = "hearc-dot" }))
    line:insert(pandoc.Space())
  end
  line:extend(class)
  return line
end

-- Pied de page, calculé par Meta
local footer = nil

local function Meta(meta)
  local course = meta.course or {}
  local name = to_inlines(course.name)
  local short = to_inlines(course.short)
  if #short == 0 then
    short = name
  end
  local class = to_inlines(course.class)

  meta["hearc-courseline"] = course_line(short, class)

  footer = pandoc.Inlines({})
  local left = to_inlines(course.footer)
  if #left > 0 then
    footer:insert(pandoc.Span(left, { class = "hearc-footer-left" }))
  end
  footer:extend(course_line(short, class))
  return meta
end

-- Quarto insère un `::: {.footer .footer-default}` avant les filtres, vide
-- si `footer:` n'est pas donné ; on y place le pied de page du cours
-- (un `footer:` explicite reste prioritaire)
local function Div(el)
  if footer and el.classes:includes("footer-default") and #el.content == 0 then
    el.content = { pandoc.Plain(footer) }
    return el
  end
end

-- Un titre « ### » et le contenu qui le suit forment un bloc
-- (classes .alert et .example reprises)
local function Blocks(blocks)
  local result = pandoc.Blocks({})
  local block = nil
  for _, el in ipairs(blocks) do
    local starts = el.t == "Header" and el.level <= 3
    if block and (starts or el.t == "HorizontalRule") then
      result:insert(block)
      block = nil
    end
    if el.t == "Header" and el.level == 3 then
      local classes = { "hearc-block" }
      for _, c in ipairs({ "alert", "example" }) do
        if el.classes:includes(c) then
          table.insert(classes, c)
        end
      end
      -- Titre en paragraphe : un Div commençant par un titre deviendrait une
      -- <section>, que reveal.js prendrait pour une diapositive imbriquée
      local title = pandoc.Div({ pandoc.Plain(el.content) }, { class = "hearc-block-title" })
      block = pandoc.Div({ title }, { class = table.concat(classes, " ") })
    elseif block then
      block.content:insert(el)
    else
      result:insert(el)
    end
  end
  if block then
    result:insert(block)
  end
  return result
end

-- Meta d'abord : le pied de page doit être calculé avant le parcours des Div
return {
  { Meta = Meta },
  { Div = Div, Blocks = Blocks },
}

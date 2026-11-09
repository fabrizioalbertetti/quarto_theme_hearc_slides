-- Animations des schémas draw.io (.drawio.svg) dans reveal.js.
--
-- Dans draw.io, une forme (ou un groupe) peut porter les propriétés
-- (Edition > Modifier les données, Ctrl+M) :
--   fragment     = n   la forme apparaît à l'étape n de la diapositive
--   fragment-out = m   la forme disparaît à l'étape m
-- Les étapes sont communes avec les `fragment-index` du texte de la
-- diapositive. Exporter le fichier avec « Inclure une copie du diagramme »
-- et l'option « métadonnées » (draw.io en ligne de commande :
-- `--embed-diagram --embed-svg-metadata`), qui écrit ces propriétés dans le
-- SVG sous la forme d'attributs `data-meta-fragment`.
--
-- Une image ![](x.drawio.svg) dont le SVG contient de telles propriétés est
-- insérée directement dans le HTML (et non via <img>), pour que reveal.js
-- puisse animer ses éléments. Les autres images restent inchangées.

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local s = f:read("a")
  f:close()
  return s
end

-- Position du `</g>` qui ferme le <g> ouvert juste avant `pos`
local function closing_g(svg, pos)
  local depth = 1
  local i = pos
  while true do
    local s, e, close = svg:find("<(/?)g[%s>]", i)
    if not s then
      return nil
    end
    if close == "/" then
      depth = depth - 1
      if depth == 0 then
        return s
      end
    else
      -- balise auto-fermante <g ... />
      local tag_end = svg:find(">", s, true)
      if svg:sub(tag_end - 1, tag_end - 1) ~= "/" then
        depth = depth + 1
      end
    end
    i = e
  end
end

local function fragment_attrs(cls, index)
  return string.format(' class="%s" data-fragment-index="%d"', cls, index)
end

local function add_fragments(svg)
  local pos = 1
  while true do
    local s, e = svg:find('<g data%-cell%-id="[^"]*"[^>]*>', pos)
    if not s then
      break
    end
    local tag = svg:sub(s, e)
    local fin = tonumber(tag:match('data%-meta%-fragment="(%d+)"'))
    local fout = tonumber(tag:match('data%-meta%-fragment%-out="(%d+)"'))
    local new = tag
    if fin and fout and fout == fin + 1 then
      new = tag:sub(1, -2) .. fragment_attrs("fragment fade-in-then-out", fin) .. ">"
    elseif fin and fout then
      -- apparition puis disparition plus tard : deux groupes imbriqués
      local close = closing_g(svg, e + 1)
      if close then
        svg = svg:sub(1, close - 1) .. "</g>" .. svg:sub(close)
        new = tag:sub(1, -2) .. fragment_attrs("fragment fade-out", fout) .. ">"
          .. "<g" .. fragment_attrs("fragment", fin) .. ">"
      end
    elseif fin then
      new = tag:sub(1, -2) .. fragment_attrs("fragment", fin) .. ">"
    elseif fout then
      new = tag:sub(1, -2) .. fragment_attrs("fragment fade-out", fout) .. ">"
    end
    svg = svg:sub(1, s - 1) .. new .. svg:sub(e + 1)
    pos = s + #new
  end
  return svg
end

function Image(img)
  if not img.src:match("%.drawio%.svg$") then
    return nil
  end
  local dir = pandoc.path.directory(quarto.doc.input_file)
  local svg = read_file(pandoc.path.join({ dir, img.src }))
  if not svg or not svg:find("data-meta-fragment", 1, true) then
    return nil
  end
  -- en-tête XML, DOCTYPE et commentaires avant <svg>
  svg = svg:gsub("^.-<svg", "<svg", 1)
  -- copie du diagramme (inutile dans la page) et dimensions fixes
  svg = svg:gsub('^(<svg[^>]-) content="[^"]*"', "%1", 1)
  svg = svg:gsub('^(<svg[^>]-) width="[^"]*"', "%1", 1)
  svg = svg:gsub('^(<svg[^>]-) height="[^"]*"', "%1", 1)
  svg = svg:gsub("^<svg", '<svg width="100%%"', 1)
  svg = add_fragments(svg)
  local width = img.attributes["width"] or "100%"
  local html = string.format(
    '<span class="drawio-anim" style="display:block;width:%s;margin:0 auto;">%s</span>',
    width, svg)
  return pandoc.RawInline("html", html)
end

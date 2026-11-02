-- Script post-render : exporte chaque présentation reveal.js en PDF
-- (« cours.html » -> « cours.pdf », à côté du HTML).
-- Le PDF est imprimé par un navigateur Chrome/Chromium/Edge sans interface,
-- en mode impression de reveal.js (?print-pdf) : une page par diapositive,
-- dans l'état final de ses animations, sans les notes de l'orateur.
--
-- Quarto n'exécute ce script que lors du rendu d'un projet : `quarto render`
-- (projet ou fichier) et le démarrage de `quarto preview` sans fichier, mais
-- ni `quarto preview cours.qmd` ni les re-rendus à chaque sauvegarde. Il ne
-- transmet aucune indication permettant de reconnaître une prévisualisation.
--
-- Variables d'environnement :
--   QUARTO_CHROMIUM  chemin du navigateur à utiliser (sinon recherche automatique)
--   HEARC_NO_PDF=1   ne pas exporter (par ex. pour `quarto preview` du projet entier)
-- Les chemins de QUARTO_PROJECT_OUTPUT_FILES sont relatifs à la racine du
-- projet, qui est le répertoire courant lors de l'exécution du script.

if os.getenv("HEARC_NO_PDF") == "1" then
  return
end

local windows = package.config:sub(1, 1) == "\\"

local function exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

-- Cherche un exécutable dans le PATH (Linux, macOS)
local function in_path(name)
  local p = io.popen("command -v " .. name .. " 2>/dev/null")
  if not p then
    return nil
  end
  local path = p:read("l")
  p:close()
  if path and path ~= "" then
    return path
  end
  return nil
end

local function find_browser()
  local env = os.getenv("QUARTO_CHROMIUM")
  if env and exists(env) then
    return env
  end
  local candidates = {}
  if windows then
    for _, base in ipairs({ "ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA" }) do
      local dir = os.getenv(base)
      if dir then
        table.insert(candidates, dir .. "\\Google\\Chrome\\Application\\chrome.exe")
        table.insert(candidates, dir .. "\\Microsoft\\Edge\\Application\\msedge.exe")
        table.insert(candidates, dir .. "\\Chromium\\Application\\chrome.exe")
      end
    end
  else
    candidates = {
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
    }
    for _, name in ipairs({ "google-chrome", "google-chrome-stable", "chromium",
                            "chromium-browser", "microsoft-edge" }) do
      local path = in_path(name)
      if path then
        table.insert(candidates, path)
      end
    end
  end
  for _, path in ipairs(candidates) do
    if exists(path) then
      return path
    end
  end
  return nil
end

local function is_revealjs(path)
  local f = io.open(path, "rb")
  if not f then
    return false
  end
  local head = f:read(4096) or ""
  f:close()
  return head:find("reveal.css", 1, true) ~= nil
end

-- Chemin absolu -> URL file:// (espaces et caractères accentués encodés)
local function file_url(path)
  path = path:gsub("\\", "/")
  if not path:match("^/") then
    path = "/" .. path
  end
  return "file://" .. path:gsub("[^%w/:._~-]", function(c)
    return string.format("%%%02X", c:byte())
  end)
end

local function quote(arg)
  if windows then
    return '"' .. arg .. '"'
  end
  return "'" .. arg:gsub("'", "'\\''") .. "'"
end

local function export(browser, html)
  local abs = pandoc.path.normalize(pandoc.path.join({ pandoc.system.get_working_directory(), html }))
  local pdf = abs:gsub("%.html$", ".pdf")
  os.remove(pdf)
  pandoc.system.with_temporary_directory("hearc-pdf", function(profile)
    local cmd = table.concat({
      quote(browser),
      "--headless",
      "--disable-gpu",
      "--no-first-run",
      "--no-pdf-header-footer",
      -- Sans ce drapeau, le budget de temps virtuel donne parfois une page
      -- blanche (Chrome 156) ; sans le budget, Chrome imprimerait avant la
      -- fin de la mise en page de reveal.js
      "--run-all-compositor-stages-before-draw",
      "--virtual-time-budget=20000",
      quote("--user-data-dir=" .. profile),
      quote("--print-to-pdf=" .. pdf),
      quote(file_url(abs) .. "?print-pdf"),
    }, " ")
    if windows then
      cmd = '"' .. cmd .. '" >NUL 2>&1'  -- cmd.exe retire les guillemets externes
    else
      cmd = cmd .. " >/dev/null 2>&1"
    end
    os.execute(cmd)
  end)
  if exists(pdf) then
    io.stderr:write("Output created: " .. html:gsub("%.html$", ".pdf") .. "\n")
  else
    io.stderr:write("pdf-export : échec de l'export de " .. html .. "\n")
  end
end

local files = os.getenv("QUARTO_PROJECT_OUTPUT_FILES")
local list_file = os.getenv("QUARTO_USE_FILE_FOR_PROJECT_OUTPUT_FILES")
if not files and list_file then
  local f = io.open(list_file, "r")
  if f then
    files = f:read("a")
    f:close()
  end
end

local browser = nil
for file in (files or ""):gmatch("[^\r\n]+") do
  if file:match("%.html$") and is_revealjs(file) then
    browser = browser or find_browser()
    if not browser then
      io.stderr:write("pdf-export : aucun navigateur Chrome/Chromium/Edge trouvé ;"
        .. " définir QUARTO_CHROMIUM pour exporter " .. file .. " en PDF\n")
      return
    end
    export(browser, file)
  end
end

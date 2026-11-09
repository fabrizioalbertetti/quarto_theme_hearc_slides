-- Script post-render : exporte chaque présentation reveal.js en PDF
-- (« cours.html » -> « cours.pdf », à côté du HTML).
-- Le PDF est imprimé par un navigateur Chrome/Chromium/Edge sans interface,
-- en mode impression de reveal.js (?print-pdf) : une page par diapositive,
-- dans l'état final de ses animations, sans les notes de l'orateur.
--
-- Quarto n'exécute ce script que lors du rendu d'un projet : `quarto render`
-- (projet ou fichier) et le démarrage de `quarto preview` sans fichier, mais
-- ni `quarto preview cours.qmd` ni les re-rendus à chaque sauvegarde. Il ne
-- transmet aucune indication permettant de reconnaître une prévisualisation,
-- mais `quarto preview` du projet crée « .quarto/preview/lock » avant son rendu.
--
-- Une fois le PDF créé, « cours.html » et « cours_files/ » sont supprimés, sauf
-- si un `quarto preview` du projet est en cours (il sert ce HTML).
--
-- Variables d'environnement :
--   QUARTO_CHROMIUM  chemin du navigateur à utiliser (sinon recherche automatique,
--                    y compris le navigateur de `quarto install chrome-headless-shell`)
--   QUARTO_PYTHON    chemin de Python 3 (sinon recherche automatique)
--   HEARC_NO_PDF=1   ne pas exporter (par ex. pour `quarto preview` du projet entier)
--   HEARC_KEEP_HTML=1  conserver « cours.html » et « cours_files/ » après l'export
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

-- Navigateur installé par Quarto (`quarto install chrome-headless-shell`, ou
-- l'ancien `quarto install chromium`), dans le répertoire de données de Quarto.
local function quarto_browser()
  local dirs = {}
  if windows then
    local dir = os.getenv("LOCALAPPDATA")
    if dir then
      table.insert(dirs, dir .. "\\quarto")
    end
  else
    local home = os.getenv("HOME") or ""
    local xdg = os.getenv("XDG_DATA_HOME")
    table.insert(dirs, (xdg and xdg ~= "" and xdg or home .. "/.local/share") .. "/quarto")
    table.insert(dirs, home .. "/Library/Application Support/quarto")
  end
  for _, base in ipairs(dirs) do
    for _, tool in ipairs({ "chrome-headless-shell", "chromium" }) do
      local dir = pandoc.path.join({ base, tool })
      local cmd
      if windows then
        cmd = 'where /r "' .. dir .. '" chrome-headless-shell.exe chrome.exe 2>nul'
      else
        cmd = "find '" .. dir .. "' -type f \\( -name chrome-headless-shell -o -name chrome"
          .. " -o -name Chromium \\) -perm -u+x 2>/dev/null"
      end
      local p = io.popen(cmd)
      if p then
        local path = p:read("l")
        p:close()
        if path and path ~= "" and exists(path) then
          return path
        end
      end
    end
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
  return quarto_browser()
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

local function export(browser, python, helper, html)
  local abs = pandoc.path.normalize(pandoc.path.join({ pandoc.system.get_working_directory(), html }))
  local pdf = abs:gsub("%.html$", ".pdf")
  os.remove(pdf)
  -- Le helper attend la fin de la mise en page asynchrone de Reveal.js avant l'impression.
  local ok, result = pcall(pandoc.pipe, python, { helper, browser, abs, pdf }, "")
  if ok then
    if not exists(pdf) then
      io.stderr:write("pdf-export : le navigateur n'a pas créé " .. pdf .. "\n")
      return
    end
    io.stderr:write("Output created: " .. html:gsub("%.html$", ".pdf") .. "\n")
    return true
  else
    io.stderr:write("pdf-export : échec de l'export de " .. html
      .. " : " .. tostring(result) .. "\n")
  end
  return false
end

-- `quarto preview` (projet entier) écrit son PID dans « .quarto/preview/lock »
-- avant son premier rendu et supprime ce fichier en s'arrêtant. Un verrou
-- laissé par un preview interrompu (processus terminé) est ignoré.
local function preview_running()
  local f = io.open(pandoc.path.join({ ".quarto", "preview", "lock" }), "r")
  if not f then
    return false
  end
  local pid = (f:read("a") or ""):match("%d+")
  f:close()
  if not pid then
    return false
  end
  local cmd
  if windows then
    cmd = 'tasklist /FI "PID eq ' .. pid .. '" /FO CSV /NH 2>nul'
  else
    cmd = "kill -0 " .. pid .. " 2>/dev/null && echo alive"
  end
  local p = io.popen(cmd)
  if not p then
    return true
  end
  local out = p:read("a") or ""
  p:close()
  if windows then
    return out:find('"' .. pid .. '"', 1, true) ~= nil
  end
  return out:find("alive", 1, true) ~= nil
end

-- Supprime « cours.html » et « cours_files/ » (bibliothèques reveal.js, figures),
-- inutiles une fois le PDF exporté.
local function remove_html(html)
  os.remove(html)
  local files_dir = html:gsub("%.html$", "_files")
  pcall(pandoc.system.remove_directory, files_dir, true)
end

local function find_python()
  local env = os.getenv("QUARTO_PYTHON")
  if env and exists(env) then
    return env
  end
  local function resolve(command, args)
    local ok, path = pcall(pandoc.pipe, command, args, "")
    if ok then
      path = path:gsub("[\r\n]+$", "")
    end
    if ok and path ~= "" and exists(path) then
      return path
    end
    return nil
  end
  if windows then
    return resolve("py", { "-3", "-c", "import sys; print(sys.executable)" })
      or resolve("python", { "-c", "import sys; print(sys.executable)" })
  end
  return resolve("python3", { "-c", "import sys; print(sys.executable)" })
    or resolve("python", { "-c", "import sys; print(sys.executable)" })
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
local python = nil
local exported = {}
local helper = pandoc.path.join({
  pandoc.system.get_working_directory(),
  "_extensions/fabrizioalbertetti/theme-hearc-slides/pdf-export.py",
})
for file in (files or ""):gmatch("[^\r\n]+") do
  if file:match("%.html$") and is_revealjs(file) then
    browser = browser or find_browser()
    if not browser then
      io.stderr:write("pdf-export : aucun navigateur Chrome/Chromium/Edge trouvé ;"
        .. " installer un navigateur (par ex. `quarto install chrome-headless-shell`)"
        .. " ou définir QUARTO_CHROMIUM pour exporter " .. file .. " en PDF\n")
      return
    end
    python = python or find_python()
    if not python then
      io.stderr:write("pdf-export : Python 3 est requis pour attendre la mise en page"
        .. " de Reveal.js ; définir QUARTO_PYTHON pour exporter " .. file .. " en PDF\n")
      return
    end
    if export(browser, python, helper, file) then
      table.insert(exported, file)
    end
  end
end

if #exported > 0 and os.getenv("HEARC_KEEP_HTML") ~= "1" and not preview_running() then
  for _, file in ipairs(exported) do
    remove_html(file)
  end
end

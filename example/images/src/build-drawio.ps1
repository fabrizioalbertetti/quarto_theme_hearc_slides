$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture

function Format-Number([double]$number) {
  return $number.ToString('0.####', $culture)
}

function Add-Vertex(
  [System.Text.StringBuilder]$cells,
  [string]$id,
  [string]$label,
  [double]$x,
  [double]$y,
  [double]$width,
  [double]$height,
  [string]$style
) {
  $safeLabel = [Security.SecurityElement]::Escape($label)
  [void]$cells.Append('<mxCell id="' + $id + '" value="' + $safeLabel +
    '" vertex="1" parent="1" style="' + $style + '"><mxGeometry x="' +
    (Format-Number $x) + '" y="' + (Format-Number $y) + '" width="' +
    (Format-Number $width) + '" height="' + (Format-Number $height) +
    '" as="geometry"/></mxCell>')
}

function Add-Edge(
  [System.Text.StringBuilder]$cells,
  [string]$id,
  [string]$source,
  [string]$target,
  [string]$style
) {
  [void]$cells.Append('<mxCell id="' + $id + '" edge="1" parent="1" source="' +
    $source + '" target="' + $target + '" style="' + $style +
    '"><mxGeometry relative="1" as="geometry"/></mxCell>')
}

function Save-Diagram([string]$name, [System.Text.StringBuilder]$vertices, [System.Text.StringBuilder]$edges) {
  $sourcePath = Join-Path $PSScriptRoot "..\$name.svg"
  $outputPath = Join-Path $PSScriptRoot "..\$name.drawio.svg"
  [xml]$source = [IO.File]::ReadAllText($sourcePath, [Text.Encoding]::UTF8)
  $svg = $source.DocumentElement
  $width = [double]([regex]::Match($svg.GetAttribute('width'), '^[0-9.]+').Value)
  $height = [double]([regex]::Match($svg.GetAttribute('height'), '^[0-9.]+').Value)

  $model = '<mxGraphModel dx="' + (Format-Number $width) + '" dy="' +
    (Format-Number $height) + '" grid="1" gridSize="10" guides="1" tooltips="1" ' +
    'connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="' +
    (Format-Number $width) + '" pageHeight="' + (Format-Number $height) +
    '" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>' +
    $edges.ToString() + $vertices.ToString() + '</root></mxGraphModel>'
  if ([regex]::Matches($model, '<mxCell id=').Count -lt 10 -or
    $model -match 'shape=image|data:image/svg') {
    throw "The $name model must contain editable objects, not a single embedded image."
  }

  $encodedModel = [uri]::EscapeDataString($model)
  $bytes = [Text.Encoding]::ASCII.GetBytes($encodedModel)
  $buffer = [IO.MemoryStream]::new()
  $deflate = [IO.Compression.DeflateStream]::new(
    $buffer, [IO.Compression.CompressionLevel]::Optimal, $true)
  $deflate.Write($bytes, 0, $bytes.Length)
  $deflate.Dispose()
  $payload = [Convert]::ToBase64String($buffer.ToArray())
  $buffer.Dispose()

  $mxfile = '<mxfile xmlns="" host="app.diagrams.net" type="embed"><diagram id="' +
    [guid]::NewGuid().ToString('N').Substring(0, 12) +
    '" name="Page-1">' + $payload + '</diagram></mxfile>'
  $original = $source.OuterXml
  $closingTag = $original.LastIndexOf('</svg>', [StringComparison]::OrdinalIgnoreCase)
  if ($closingTag -lt 0) {
    throw "Missing SVG closing tag: $sourcePath"
  }
  $result = $original.Substring(0, $closingTag) + $mxfile +
    $original.Substring($closingTag)
  [IO.File]::WriteAllText($outputPath, $result, [Text.UTF8Encoding]::new($false))
  [xml]$check = [IO.File]::ReadAllText($outputPath, [Text.Encoding]::UTF8)
  $diagram = $check.DocumentElement.SelectSingleNode('mxfile/diagram')
  if (-not $diagram -or [Convert]::FromBase64String($diagram.InnerText).Length -eq 0) {
    throw "The embedded draw.io model in $outputPath is invalid."
  }
  Write-Output "Built $name.drawio.svg"
}

function New-Cells {
  return [System.Text.StringBuilder]::new()
}

# Fully-connected network: every circle and connection is a separate object.
$vertices = New-Cells
$edges = New-Cells
$layers = @(
  @(@{ x = 25; y = 31 }, @{ x = 25; y = 61 }, @{ x = 25; y = 91 }),
  @(@{ x = 82; y = 22 }, @{ x = 82; y = 43 }, @{ x = 82; y = 64 }, @{ x = 82; y = 85 }),
  @(@{ x = 151; y = 22 }, @{ x = 151; y = 43 }, @{ x = 151; y = 64 }, @{ x = 151; y = 85 }),
  @(@{ x = 221; y = 43 }, @{ x = 221; y = 79 })
)
$nodeIds = @()
$nextId = 0
foreach ($layerIndex in 0..3) {
  $layerNodeIds = @()
  foreach ($position in $layers[$layerIndex]) {
    $nextId++
    $id = "n$nextId"
    $layerNodeIds += $id
    $fill = if ($layerIndex -eq 0) { '#dedede' } elseif ($layerIndex -eq 3) { '#ff0000' } else { '#ffffff' }
    $stroke = if ($layerIndex -eq 3) { '#ff0000' } else { '#000000' }
    Add-Vertex $vertices $id '' $position.x $position.y 12 12 `
      "ellipse;whiteSpace=wrap;html=1;fillColor=$fill;strokeColor=$stroke;strokeWidth=1.5;"
  }
  $nodeIds += ,$layerNodeIds
}
for ($layerIndex = 0; $layerIndex -lt 3; $layerIndex++) {
  foreach ($sourceId in $nodeIds[$layerIndex]) {
    foreach ($targetId in $nodeIds[$layerIndex + 1]) {
      $nextId++
      Add-Edge $edges "e$nextId" $sourceId $targetId `
        'edgeStyle=none;html=1;rounded=0;strokeColor=#999999;strokeWidth=1;endArrow=none;'
    }
  }
}
Add-Vertex $vertices 'label-inputs' 'entrées' 14 106 35 10 `
  'text;html=1;strokeColor=none;fillColor=none;fontColor=#6e6e6e;fontSize=8;align=center;verticalAlign=middle;'
Add-Vertex $vertices 'label-hidden' 'couches cachées' 89 106 67 10 `
  'text;html=1;strokeColor=none;fillColor=none;fontColor=#6e6e6e;fontSize=8;align=center;verticalAlign=middle;'
Add-Vertex $vertices 'label-outputs' 'sorties' 211 106 32 10 `
  'text;html=1;strokeColor=none;fillColor=none;fontColor=#6e6e6e;fontSize=8;align=center;verticalAlign=middle;'
Save-Diagram 'reseau' $vertices $edges

# Artificial neuron: editable input nodes, weighted arrows, sum, activation and output.
$vertices = New-Cells
$edges = New-Cells
$inputY = @(24, 52, 80)
foreach ($index in 0..2) {
  $id = "x$($index + 1)"
  Add-Vertex $vertices $id "x$($index + 1)" 16 $inputY[$index] 18 18 `
    'ellipse;whiteSpace=wrap;html=1;fillColor=#dedede;strokeColor=#000000;fontStyle=2;fontSize=9;'
  Add-Edge $edges "w$($index + 1)" $id 'sum' `
    'edgeStyle=none;html=1;strokeColor=#000000;strokeWidth=1.2;endArrow=block;endFill=1;'
  $labelY = $inputY[$index] + 2
  Add-Vertex $vertices "weight$($index + 1)" "w$($index + 1)" 54 $labelY 15 9 `
    'text;html=1;strokeColor=none;fillColor=none;fontColor=#6e6e6e;fontSize=8;align=center;'
}
Add-Vertex $vertices 'sum' 'Σ' 104 48 24 24 `
  'ellipse;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#000000;strokeWidth=1.5;fontSize=13;fontStyle=1;'
Add-Vertex $vertices 'bias' '+ b' 107 34 18 9 `
  'text;html=1;strokeColor=none;fillColor=none;fontColor=#6e6e6e;fontSize=8;align=center;'
Add-Vertex $vertices 'activation' 'σ' 154 49 23 23 `
  'rounded=1;arcSize=12;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#ff0000;strokeWidth=1.5;fontColor=#ff0000;fontSize=12;fontStyle=1;'
Add-Edge $edges 'sum-activation' 'sum' 'activation' `
  'edgeStyle=none;html=1;strokeColor=#000000;strokeWidth=1.2;endArrow=block;endFill=1;'
Add-Vertex $vertices 'output' 'y' 192 53 18 14 `
  'text;html=1;strokeColor=none;fillColor=none;fontColor=#000000;fontSize=11;align=left;'
Add-Edge $edges 'activation-output' 'activation' 'output' `
  'edgeStyle=none;html=1;strokeColor=#000000;strokeWidth=1.2;endArrow=block;endFill=1;'
Save-Diagram 'neurone' $vertices $edges

# K-means snapshots: chart, individual sample points and editable star centroids.
$pointsA = @(
  @(0.8, 1.0), @(1.3, 0.6), @(1.0, 1.6), @(1.7, 1.2),
  @(0.5, 0.4), @(1.5, 1.9), @(2.0, 0.7), @(0.9, 2.2)
)
$pointsB = @(
  @(3.6, 2.8), @(4.2, 3.3), @(3.9, 2.2), @(4.6, 2.7),
  @(3.3, 3.4), @(4.4, 3.8), @(3.7, 3.9), @(4.9, 3.2)
)
$stages = @(
  @{ colors = @('#6e6e6e', '#6e6e6e'); centroids = @(@(1.8, 0.3), @(3.0, 4.2)) },
  @{ colors = @('#ff0000', '#000000'); centroids = @(@(1.8, 0.3), @(3.0, 4.2)) },
  @{ colors = @('#ff0000', '#000000'); centroids = @(@(1.2, 1.2), @(4.1, 3.2)) }
)
for ($stageIndex = 0; $stageIndex -lt 3; $stageIndex++) {
  $vertices = New-Cells
  $edges = New-Cells
  Add-Vertex $vertices 'chart' '' 4 4 156 127 `
    'whiteSpace=wrap;html=1;fillColor=none;strokeColor=#999999;strokeWidth=1;'
  $pointIndex = 0
  foreach ($point in $pointsA) {
    $pointIndex++
    $x = 4 + 28.1 * $point[0] - 2
    $y = 131 - 28.1 * $point[1] - 2
    Add-Vertex $vertices "a$pointIndex" '' $x $y 4.2 4.2 `
      "ellipse;whiteSpace=wrap;html=1;fillColor=$($stages[$stageIndex].colors[0]);strokeColor=$($stages[$stageIndex].colors[0]);"
  }
  $pointIndex = 0
  foreach ($point in $pointsB) {
    $pointIndex++
    $x = 4 + 28.1 * $point[0] - 2
    $y = 131 - 28.1 * $point[1] - 2
    Add-Vertex $vertices "b$pointIndex" '' $x $y 4.2 4.2 `
      "ellipse;whiteSpace=wrap;html=1;fillColor=$($stages[$stageIndex].colors[1]);strokeColor=$($stages[$stageIndex].colors[1]);"
  }
  $centroidIndex = 0
  foreach ($point in $stages[$stageIndex].centroids) {
    $centroidIndex++
    $x = 4 + 28.1 * $point[0] - 6
    $y = 131 - 28.1 * $point[1] - 6
    Add-Vertex $vertices "centroid$centroidIndex" '' $x $y 12 12 `
      'shape=star;perimeter=starPerimeter;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#000000;strokeWidth=1.5;'
  }
  $name = if ($stageIndex -eq 0) { 'kmeans' } else { "kmeans-$($stageIndex + 1)" }
  Save-Diagram $name $vertices $edges
}

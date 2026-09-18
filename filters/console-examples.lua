-- Author transcripts explicitly as console or julia-repl. Ordinary source stays code.
function CodeBlock(block)
  local julia = block.classes:includes("julia-repl")
  if not julia and not block.classes:includes("console") then return nil end

  local prompt = julia and "julia> " or "$ "
  local continuation = julia and "       " or "> "
  local examples = pandoc.List()
  local input, output = {}, {}
  local lines = {}
  for line in (block.text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end

  local function emit()
    if #input == 0 then return end
    while output[#output] == "" do table.remove(output) end
    local command = pandoc.CodeBlock(table.concat(input, "\n"),
      pandoc.Attr("", {julia and "julia" or "bash"}, {["code-copy"] = "true"}))
    local parts = {pandoc.Div({command}, pandoc.Attr("",
      {"console-input", julia and "console-julia" or "console-shell"},
      {["aria-label"] = julia and "Julia REPL入力" or "シェル入力"}))}
    if #output > 0 then
      table.insert(parts, pandoc.CodeBlock(table.concat(output, "\n"),
        pandoc.Attr("", {"console-output"}, {["code-copy"] = "false"})))
    end
    examples:insert(pandoc.Div(parts, pandoc.Attr("", {"console-example"})))
    input, output = {}, {}
  end

  for i, line in ipairs(lines) do
    if line:sub(1, #prompt) == prompt then
      emit()
      table.insert(input, line:sub(#prompt + 1))
    elseif #input == 0 then
      error("Console transcripts must begin with " .. prompt)
    elseif #output == 0 and line:sub(1, #continuation) == continuation then
      table.insert(input, line:sub(#continuation + 1))
    elseif #output == 0 and line == "" then
      local next_line = i + 1
      while lines[next_line] == "" do next_line = next_line + 1 end
      if lines[next_line] and lines[next_line]:sub(1, #continuation) == continuation then
        table.insert(input, "")
      else
        table.insert(output, line)
      end
    else
      table.insert(output, line)
    end
  end
  emit()
  return pandoc.Div(examples, pandoc.Attr(block.identifier, {"console-transcript"}))
end

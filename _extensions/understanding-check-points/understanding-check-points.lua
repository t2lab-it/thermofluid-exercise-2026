return {
  ["understanding-check-points"] = function(args, kwargs, meta, raw_args, context)
    local points = meta["understanding-check-points"]
    if points == nil or #points == 0 then
      error("understanding-check-points metadata must contain at least one point")
    end

    local lines = {}
    for _, point in ipairs(points) do
      table.insert(lines, "- " .. pandoc.utils.stringify(point))
    end
    return table.concat(lines, "\n")
  end
}

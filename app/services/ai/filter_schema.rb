module Ai
  module FilterSchema
    FILTERS = {
      type: "object",
      additionalProperties: false,
      properties: {
        query:             { type: "string", description: "Substring matched against name OR e-mail (case-insensitive)." },
        name_contains:     { type: "string", description: "Substring that must appear in the name." },
        name_starts_with:  { type: "string", description: "Prefix of the name." },
        email_starts_with: { type: "array", items: { type: "string" },
                             description: "Allowed first letters/prefixes of the e-mail (OR). Example: [\"s\",\"p\"]." },
        email_contains:    { type: "string", description: "Substring that must appear in the e-mail." },
        email_domain:      { type: "string", description: "Exact e-mail domain, e.g. gmail.com." },
        registered_after:  { type: "string", description: "ISO date YYYY-MM-DD. Users registered on/after this day." },
        registered_before: { type: "string", description: "ISO date YYYY-MM-DD. Users registered before this day." },
        sort:              { type: "string", enum: %w[name email created_at] },
        dir:               { type: "string", enum: %w[asc desc] }
      }
    }.freeze
  end
end

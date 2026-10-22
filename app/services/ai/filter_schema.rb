module Ai
  # JSON schema of the filter object, shared by data tools and UI tools.
  # Gemini accepts a subset of JSON Schema: no additionalProperties, minimum, maximum.
  module FilterSchema
    FILTERS = {
      type: "object",
      properties: {
        query:             { type: "string", description: "Substring matched against name, e-mail OR job position (case-insensitive)." },
        name_contains:     { type: "string", description: "Substring that must appear in the name." },
        name_starts_with:  { type: "string", description: "Prefix of the name." },
        email_starts_with: { type: "array", items: { type: "string" },
                             description: "Allowed first letters/prefixes of the e-mail (OR). Example: [\"s\",\"p\"]." },
        email_contains:    { type: "string", description: "Substring that must appear in the e-mail." },
        email_domain:      { type: "string", description: "Exact e-mail domain, e.g. gmail.com." },
        job_contains:      { type: "string", description: "Substring that must appear in the job position, e.g. \"Banking\"." },
        status:            { type: "string", enum: %w[active blocked], description: "Account status." },
        seen_after:        { type: "string", description: "ISO date YYYY-MM-DD. Users last seen on/after this day." },
        seen_before:       { type: "string", description: "ISO date YYYY-MM-DD. Users last seen before this day." },
        registered_after:  { type: "string", description: "ISO date YYYY-MM-DD. Users registered on/after this day." },
        registered_before: { type: "string", description: "ISO date YYYY-MM-DD. Users registered before this day." },
        sort:              { type: "string", enum: %w[name email job last_seen created_at] },
        dir:               { type: "string", enum: %w[asc desc] }
      }
    }.freeze
  end
end

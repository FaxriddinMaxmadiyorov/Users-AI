module Ai
  class Tools
    MAX_LIST = 50

    DEFINITIONS = [
      {
        type: "function",
        function: {
          name: "count_users",
          description: "Exact number of users matching the filters. Use for 'how many' questions.",
          parameters: { type: "object", properties: { filters: FilterSchema::FILTERS } }
        }
      },
      {
        type: "function",
        function: {
          name: "list_users",
          description: "List users matching the filters (name, e-mail, registration date). Max #{MAX_LIST} rows; total count is also returned.",
          parameters: {
            type: "object",
            properties: { filters: FilterSchema::FILTERS, limit: { type: "integer", minimum: 1, maximum: MAX_LIST } }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "aggregate_users",
          description: "Group matching users and count per group. Use for 'most common domain', 'registrations per month', 'first letter' questions.",
          parameters: {
            type: "object",
            properties: {
              group_by: { type: "string", enum: %w[email_domain registration_month registration_year email_first_letter name_first_letter] },
              filters: FilterSchema::FILTERS,
              limit: { type: "integer", minimum: 1, maximum: 50 }
            },
            required: ["group_by"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "find_user",
          description: "Fetch one user by exact e-mail address.",
          parameters: { type: "object", properties: { email: { type: "string" } }, required: ["email"] }
        }
      }
    ].freeze

    def call(name, args)
      args = (args || {}).to_h.transform_keys(&:to_s)
      case name
      when "count_users"     then count_users(args["filters"])
      when "list_users"      then list_users(args["filters"], args["limit"])
      when "aggregate_users" then aggregate_users(args["group_by"], args["filters"], args["limit"])
      when "find_user"       then find_user(args["email"])
      else { error: "unknown tool #{name}" }
      end
    end

    private

    def query(filters)
      UserQuery.new(filters || {})
    end

    def count_users(filters)
      q = query(filters)
      { count: q.count, filters: q.describe }
    end

    def list_users(filters, limit)
      q = query(filters)
      limit = (limit || 20).to_i.clamp(1, MAX_LIST)
      rows = q.relation.limit(limit).map { |u| serialize(u) }
      { total: q.count, returned: rows.size, filters: q.describe, users: rows }
    end

    def aggregate_users(group_by, filters, limit)
      rel = query(filters).relation.except(:order)
      limit = (limit || 20).to_i.clamp(1, 50)
      expr =
        case group_by
        when "email_domain"       then "split_part(users.email_address, '@', 2)"
        when "registration_month" then "to_char(users.created_at, 'YYYY-MM')"
        when "registration_year"  then "to_char(users.created_at, 'YYYY')"
        when "email_first_letter" then "left(users.email_address, 1)"
        when "name_first_letter"  then "upper(left(users.name, 1))"
        else return { error: "unknown group_by #{group_by}" }
        end
      groups = rel.group(Arel.sql(expr)).order(Arel.sql("COUNT(*) DESC, #{expr} ASC")).limit(limit).count
      { group_by: group_by, total: rel.count, groups: groups.map { |k, v| { key: k, count: v } } }
    end

    def find_user(email)
      u = User.find_by(email_address: email.to_s.strip.downcase)
      u ? { found: true, user: serialize(u) } : { found: false }
    end

    def serialize(u)
      { name: u.name, email: u.email_address, registered_at: u.created_at.to_date.iso8601 }
    end
  end
end

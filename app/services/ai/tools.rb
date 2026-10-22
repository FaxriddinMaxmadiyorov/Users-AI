module Ai
  class Tools
    MAX_LIST = 50

    DEFINITIONS = [
        { name: "count_users",
            description: "Exact number of users matching the filters. Use for 'how many' questions.",
            parameters: { type: "object", properties: { filters: FilterSchema::FILTERS } } },
        { name: "list_users",
            description: "List users matching the filters. Max #{MAX_LIST} rows; total count is also returned.",
            parameters: { type: "object", properties: { filters: FilterSchema::FILTERS, limit: { type: "integer", description: "1..#{MAX_LIST}" } } } },
        { name: "aggregate_users",
            description: "Group matching users and count per group. Use for 'most common domain', 'registrations per month', 'first letter' questions.",
            parameters: { type: "object",
                        properties: { group_by: { type: "string", enum: %w[email_domain registration_month registration_year email_first_letter name_first_letter] },
                                        filters: FilterSchema::FILTERS,
                                        limit: { type: "integer", description: "1..50" } },
                        required: ["group_by"] } },
        { name: "find_user",
            description: "Fetch one user by exact e-mail address.",
            parameters: { type: "object", properties: { email: { type: "string" } }, required: ["email"] } },
        { name: "get_table_state",
          description: "Current filters and sort of the Users table the person is looking at.",
          parameters: { type: "object", properties: {} } },
        { name: "apply_table_filters",
          description: "Change what the Users table shows. Pass the COMPLETE desired filter set (it replaces the current one). To add a condition to the current view, call get_table_state first and include the existing filters. Use for 'show only…', 'filter…', 'select users with…', 'hide…'.",
          parameters: { type: "object", properties: { filters: FilterSchema::FILTERS }, required: ["filters"] } },
        { name: "sort_table",
          description: "Sort the Users table, keeping current filters.",
          parameters: { type: "object",
                        properties: { sort: { type: "string", enum: %w[name email created_at] }, dir: { type: "string", enum: %w[asc desc] } },
                        required: ["sort"] } },
        { name: "clear_table_filters",
          description: "Reset the Users table to show all users with default sort.",
          parameters: { type: "object", properties: {} } }
    ].freeze

    attr_reader :ui_command

    def initialize(current_filters: {})
      @tools  = Tools.new(current_filters: current_filters)
      @current_filters = UserQuery.permit(current_filters)
      @ui_command = nil
    end

    def call(name, args)
      args = (args || {}).to_h.transform_keys(&:to_s)
      case name
      when "count_users"     then count_users(args["filters"])
      when "list_users"      then list_users(args["filters"], args["limit"])
      when "aggregate_users" then aggregate_users(args["group_by"], args["filters"], args["limit"])
      when "find_user"       then find_user(args["email"])
      when "get_table_state"     then table_state
      when "apply_table_filters" then apply_table_filters(args["filters"])
      when "sort_table"          then sort_table(args["sort"], args["dir"])
      when "clear_table_filters" then clear_table_filters
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

    def table_state
      q = query(@current_filters)
      { filters: @current_filters, description: q.describe, matching_count: q.count }
    end

    def apply_table_filters(filters)
      f = UserQuery.permit(filters || {})
      q = query(f)
      @ui_command = { type: "navigate", filters: f }
      { applied: true, filters: f, description: q.describe, matching_count: q.count }
    end

    def sort_table(sort, dir)
      f = @current_filters.merge("sort" => sort, "dir" => dir || "asc")
      @ui_command = { type: "navigate", filters: f }
      { applied: true, filters: f, description: query(f).describe }
    end

    def clear_table_filters
      @ui_command = { type: "navigate", filters: {} }
      { applied: true, matching_count: User.count }
    end

    def finish(answer, trace)
      { answer: answer.presence || "Done.", command: @tools.ui_command, tool_calls: trace }
    end
  end
end

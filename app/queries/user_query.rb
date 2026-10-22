# One filter vocabulary shared by the Users page, the AI question tools and the AI UI commands.
# Every filter is applied in SQL, so counts and lists are exact.
class UserQuery
  FILTER_KEYS = %w[
    query name_contains name_starts_with
    email_starts_with email_contains email_domain
    job_contains status
    seen_after seen_before
    registered_after registered_before
    sort dir
  ].freeze

  SORTS = {
    "name"       => :name,
    "email"      => :email_address,
    "job"        => :job_position,
    "last_seen"  => :last_seen,
    "created_at" => :created_at
  }.freeze

  SORT_NAMES = {
    name: "name",
    email_address: "e-mail",
    job_position: "job",
    last_seen: "last seen",
    created_at: "registration date"
  }.freeze

  STATUSES = %w[active blocked].freeze

  attr_reader :filters

  # Accepts ActionController::Parameters or a Hash; returns a string-keyed Hash with only known, non-blank keys.
  def self.permit(params)
    h = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    h = h.to_h.transform_keys(&:to_s).slice(*FILTER_KEYS)
    h["email_starts_with"] = normalize_list(h["email_starts_with"])
    h.delete("status") unless STATUSES.include?(h["status"])
    h.delete("sort")   unless SORTS.key?(h["sort"])
    h.delete("dir")    unless %w[asc desc].include?(h["dir"])
    h.reject { |_, v| v.blank? }
  end

  # "s, p" or ["s","p"] -> ["s","p"]
  def self.normalize_list(value)
    list = value.is_a?(Array) ? value : value.to_s.split(/[,\s]+/)
    list.map { |s| s.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def initialize(filters = {})
    @filters = self.class.permit(filters)
  end

  def relation
    rel = User.all
    f = filters

    if (q = f["query"]).present?
      rel = rel.where(
        "LOWER(users.name) LIKE :q OR users.email_address LIKE :q OR LOWER(users.job_position) LIKE :q",
        q: "%#{like(q)}%"
      )
    end

    if f["name_contains"].present?
      rel = rel.where("LOWER(users.name) LIKE ?", "%#{like(f["name_contains"])}%")
    end
    if f["name_starts_with"].present?
      rel = rel.where("LOWER(users.name) LIKE ?", "#{like(f["name_starts_with"])}%")
    end

    if (prefixes = f["email_starts_with"]).present?
      conds = prefixes.map { "users.email_address LIKE ?" }.join(" OR ")
      rel = rel.where(conds, *prefixes.map { |p| "#{like(p)}%" })
    end
    if f["email_contains"].present?
      rel = rel.where("users.email_address LIKE ?", "%#{like(f["email_contains"])}%")
    end
    if f["email_domain"].present?
      rel = rel.where("users.email_address LIKE ?", "%@#{like(f["email_domain"])}")
    end

    if f["job_contains"].present?
      rel = rel.where("LOWER(users.job_position) LIKE ?", "%#{like(f["job_contains"])}%")
    end
    rel = rel.where(status: f["status"]) if f["status"].present?

    if (d = parse_date(f["seen_after"]))
      rel = rel.where("users.last_seen >= ?", d.beginning_of_day)
    end
    if (d = parse_date(f["seen_before"]))
      rel = rel.where("users.last_seen < ?", d.beginning_of_day)
    end
    if (d = parse_date(f["registered_after"]))
      rel = rel.where("users.created_at >= ?", d.beginning_of_day)
    end
    if (d = parse_date(f["registered_before"]))
      rel = rel.where("users.created_at < ?", d.beginning_of_day)
    end

    rel.order(order_clause)
  end

  def count
    relation.except(:order, :limit).count
  end

  def sort_column
    SORTS[filters["sort"]] || :last_seen
  end

  def sort_direction
    return filters["dir"].to_sym if filters["dir"].present?
    %i[last_seen created_at].include?(sort_column) ? :desc : :asc
  end

  def order_clause
    { sort_column => sort_direction, id: :asc }
  end

  # Human-readable description: shown on the page and returned to the model.
  def describe
    f = filters
    parts = []
    parts << "name, e-mail or job contains \"#{f["query"]}\"" if f["query"]
    parts << "name contains \"#{f["name_contains"]}\"" if f["name_contains"]
    parts << "name starts with \"#{f["name_starts_with"]}\"" if f["name_starts_with"]
    parts << "e-mail starts with #{f["email_starts_with"].map { |p| "\"#{p}\"" }.join(" or ")}" if f["email_starts_with"]
    parts << "e-mail contains \"#{f["email_contains"]}\"" if f["email_contains"]
    parts << "e-mail domain is #{f["email_domain"]}" if f["email_domain"]
    parts << "job contains \"#{f["job_contains"]}\"" if f["job_contains"]
    parts << "status is #{f["status"]}" if f["status"]
    parts << "last seen on or after #{f["seen_after"]}" if f["seen_after"]
    parts << "last seen before #{f["seen_before"]}" if f["seen_before"]
    parts << "registered on or after #{f["registered_after"]}" if f["registered_after"]
    parts << "registered before #{f["registered_before"]}" if f["registered_before"]

    (parts.empty? ? "all users" : parts.join(", ")) + ", sorted by #{SORT_NAMES[sort_column]} #{sort_direction}"
  end

  private

  # Escape LIKE wildcards so "50%" searches for a literal percent sign.
  def like(s)
    s.to_s.downcase.gsub(/[\\%_]/) { |m| "\\#{m}" }
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end

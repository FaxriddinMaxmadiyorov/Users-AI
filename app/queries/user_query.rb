class UserQuery
  FILTER_KEYS = %w[
    query name_contains name_starts_with
    email_starts_with email_contains email_domain
    registered_after registered_before
    sort dir
  ].freeze

  SORTS = { "name" => :name, "email" => :email_address, "created_at" => :created_at }.freeze

  attr_reader :filters

  def self.permit(params)
    h = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    h = h.to_h.transform_keys(&:to_s).slice(*FILTER_KEYS)
    h["email_starts_with"] = normalize_list(h["email_starts_with"])
    h.reject { |_, v| v.blank? }
  end

  # "s, p" yoki ["s","p"] -> ["s","p"]
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
      rel = rel.where("LOWER(users.name) LIKE :q OR users.email_address LIKE :q", q: "%#{like(q)}%")
    end
    rel = rel.where("LOWER(users.name) LIKE ?", "%#{like(f["name_contains"])}%") if f["name_contains"].present?
    rel = rel.where("LOWER(users.name) LIKE ?", "#{like(f["name_starts_with"])}%") if f["name_starts_with"].present?

    if (prefixes = f["email_starts_with"]).present?
      conds = prefixes.map { "users.email_address LIKE ?" }.join(" OR ")
      rel = rel.where(conds, *prefixes.map { |p| "#{like(p)}%" })
    end
    rel = rel.where("users.email_address LIKE ?", "%#{like(f["email_contains"])}%") if f["email_contains"].present?
    rel = rel.where("users.email_address LIKE ?", "%@#{like(f["email_domain"])}") if f["email_domain"].present?

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

  def order_clause
    col = SORTS[filters["sort"]] || :created_at
    dir =
      if filters["dir"] == "asc" then :asc
      elsif filters["dir"] == "desc" then :desc
      else col == :created_at ? :desc : :asc
      end
    { col => dir, id: :asc }
  end

  def describe
    f = filters
    parts = []
    parts << "name or e-mail contains \"#{f["query"]}\"" if f["query"]
    parts << "name contains \"#{f["name_contains"]}\"" if f["name_contains"]
    parts << "name starts with \"#{f["name_starts_with"]}\"" if f["name_starts_with"]
    parts << "e-mail starts with #{f["email_starts_with"].map { |p| "\"#{p}\"" }.join(" or ")}" if f["email_starts_with"]
    parts << "e-mail contains \"#{f["email_contains"]}\"" if f["email_contains"]
    parts << "e-mail domain is #{f["email_domain"]}" if f["email_domain"]
    parts << "registered on or after #{f["registered_after"]}" if f["registered_after"]
    parts << "registered before #{f["registered_before"]}" if f["registered_before"]
    sort = "sorted by #{f["sort"] || "registration date"} #{f["dir"] || (f["sort"] ? "asc" : "desc")}"
    (parts.empty? ? "all users" : parts.join(", ")) + ", " + sort
  end

  private

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

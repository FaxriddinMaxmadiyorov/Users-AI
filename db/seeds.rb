# Populates the users table from db/data/users.json and nothing else (task requirement:
# "populate your app with the users from the file ... and only these users").
path = Rails.root.join("db/data/users.json")
abort "Missing #{path}" unless File.exist?(path)

rows   = JSON.parse(File.read(path))
emails = rows.map { |r| r["email"].to_s.strip.downcase }

removed = User.where.not(email_address: emails).destroy_all.size

rows.each do |r|
  user = User.find_or_initialize_by(email_address: r["email"].to_s.strip.downcase)
  user.name         = r["full_name"]
  user.job_position = r["job_position"]
  user.status       = r["status"].to_s.presence_in(%w[active blocked]) || "active"
  user.last_seen    = Time.zone.parse(r["last_seen"].to_s) if r["last_seen"].present?
  user.password     = "password" if user.new_record?
  user.save!
end

puts "Seeded #{User.count} users from #{path.basename} (removed #{removed} others). Password for all: password"

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

first_names = %w[Anna Sardor Peter Sofia Pavel Nodira Stanislav Maria Shahzod Olga Ivan Sabina Dmitry Samira Farrukh
                 Elena Rustam Polina Bekzod Alina Timur Svetlana Jasur Kamila Oleg Dilnoza Sergey Lola Aziz Nina
                 Umid Viktor Zarina Igor Madina Yulia Otabek Daria Said Tatiana]
last_names  = %w[Karimov Ivanova Smith Petrova Sokolov Rashidova Novak Popova Tashkentov Kuznetsova Rakhimov Brown
                 Sultanova Orlov Nazarova Fedorov Yusupova Volkov Mirzaeva Lee]
domains     = %w[gmail.com gmail.com gmail.com mail.ru yahoo.com outlook.com proton.me itransition.com uz.edu]

rng   = Random.new(42)
start = 14.months.ago.to_date

80.times do |i|
  fn = first_names[i % first_names.size]
  ln = last_names[(i * 7) % last_names.size]
  local = [fn.downcase, "#{fn[0].downcase}#{ln.downcase}", "#{fn.downcase}.#{ln.downcase}", "#{fn.downcase}#{rng.rand(10..99)}"][i % 4]
  email = "#{local}@#{domains[rng.rand(domains.size)]}"
  created = (start + rng.rand(0..425)).to_time + rng.rand(0..86_399)

  u = User.find_or_initialize_by(email_address: email)
  u.name = "#{fn} #{ln}"
  u.password = "password" if u.new_record?
  u.created_at = created
  u.save!
end

User.find_or_create_by!(email_address: "admin@example.com") do |u|
  u.name = "Admin User"
  u.password = "password"
end

puts "Seeded #{User.count} users. Log in as admin@example.com / password"

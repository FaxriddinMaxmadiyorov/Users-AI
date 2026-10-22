class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name,          with: ->(n) { n.to_s.squish }
  normalizes :job_position,  with: ->(j) { j.to_s.squish.presence }

  enum :status, { active: "active", blocked: "blocked" }

  validates :name, presence: true, length: { maximum: 80 }
  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }

  def email_domain
    email_address.split("@").last
  end
end

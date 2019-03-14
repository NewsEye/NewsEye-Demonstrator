class Feedback < ApplicationRecord

  validates :name, :email, :page, :text, presence: true
  validates :email, :format => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

end

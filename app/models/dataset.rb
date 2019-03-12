class Dataset < ApplicationRecord
  belongs_to :user, optional: true

  # serialize :searches
  # serialize :articles
  # serialize :issues

  # attr_accessor :title, :searches, :articles, :issues
end

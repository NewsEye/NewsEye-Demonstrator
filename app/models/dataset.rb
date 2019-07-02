class Dataset < ApplicationRecord

  belongs_to :user, optional: true

  validates :title, uniqueness: { scope: :user_id }

  # serialize :searches, Array
  # serialize :articles, Array
  # serialize :issues, Array

  def get_ids_from_searches
    ids = []
    searches.each do |search_url|
      ids += ApplicationController.helpers.get_ids_from_search search_url
    end
    ids
  end

end

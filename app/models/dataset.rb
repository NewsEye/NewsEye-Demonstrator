class Dataset < ApplicationRecord
  include Blacklight::SearchHelper
  # include ::DatasetConcern

  belongs_to :user, optional: true

  validates :title, uniqueness: { scope: :user_id }

  # serialize :searches, Array
  # serialize :articles, Array
  # serialize :issues, Array


  def get_ids
    ids = []
    self.searches.each do |search|
      ids += ApplicationController.helpers.get_ids_from_search search
    end
    ids.concat self.articles
    ids.concat self.issues
    ids.uniq
  end

end

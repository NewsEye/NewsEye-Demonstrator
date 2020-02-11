class User < ApplicationRecord
  # Connects this user object to Hydra behaviors.
  include Hydra::User


  if Blacklight::Utils.needs_attr_accessible?
    attr_accessible :email, :password, :password_confirmation
  end
  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :datasets
  has_many :tasks
  has_many :searches


  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account.
  def to_s
    email
  end

  def datasets_with_doc doc_id
    self.datasets.map do |dataset|
      [dataset.id, dataset.title, dataset.relevancy_for_doc(doc_id)] if dataset.contains doc_id
    end.delete_if(&:nil?)
  end

end

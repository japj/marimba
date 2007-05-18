class PlayList < ActiveRecord::Base

  hobo_model

  belongs_to :user

  set_creator_attr :user

  # --- Hobo Permissions --- #

  def creatable_by?(creator)
    creator == user 
  end

  def updatable_by?(updater, new)
    updater == user and same_fields?(new, :user) 
  end

  def deletable_by?(deleter)
    deleter == user 
  end

  def viewable_by?(viewer, field)
    true
  end

end

class CreatePlayLists < ActiveRecord::Migration
  def self.up
    create_table :play_lists do |t|
      t.column :title, :string
      t.fkey :user
      t.auto_dates
    end
  end

  def self.down
    drop_table :play_lists
  end
end

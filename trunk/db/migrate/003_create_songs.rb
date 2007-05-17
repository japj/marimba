class CreateSongs < ActiveRecord::Migration
  def self.up
    create_table :songs do |t|
      t.column :title, :string
      t.column :key, :string
      t.fkey :user
      t.auto_dates
    end
  end

  def self.down
    drop_table :songs
  end
end

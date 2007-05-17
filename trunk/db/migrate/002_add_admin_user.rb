class AddAdminUser < ActiveRecord::Migration
  def self.up
    admin = User.new( :username               =>  'admin',
                      :password               =>  'admin',
                      :password_confirmation  =>  'admin')
    admin.save
  end

  def self.down
  end
end

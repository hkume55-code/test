class CreateSends < ActiveRecord::Migration[5.2]
  def change
    create_table :sends do |t|
      t.string :email
      t.string :name
      t.string :tracking_code
      t.boolean :send_flag
      t.datetime :send_at

      t.timestamps
    end
  end
end

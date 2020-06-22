class CreateSends < ActiveRecord::Migration[5.2]
  def change
    create_table :sends do |t|
      t.string :subject
      t.text :message
      t.string :email
      t.string :sender
      t.datetime :sendtime

      t.timestamps
    end
  end
end

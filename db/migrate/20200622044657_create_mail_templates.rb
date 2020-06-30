class CreateMailTemplates < ActiveRecord::Migration[5.2]
  def change
    create_table :mail_templates do |t|
      t.string :subject
      t.text :message
      t.string :sender_email
      t.string :sender_name

      t.timestamps
    end
  end
end

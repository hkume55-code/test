class CreateMailTemplates < ActiveRecord::Migration[5.2]
  def change
    create_table :mail_templates do |t|
      t.string :subject
      t.text :message
      t.text :message_html
      t.string :sender_email
      t.string :sender_name
      t.string :reply_to

      t.timestamps
    end
  end
end

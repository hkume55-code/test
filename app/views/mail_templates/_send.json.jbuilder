json.extract! send, :id, :subject, :message, :email, :sender, :sendtime, :created_at, :updated_at
json.url send_url(send, format: :json)

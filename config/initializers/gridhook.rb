# coding: utf-8
# SendGridのEvent Notificationを処理する
#   DASHBOARD → SETTINGS → Mail Settings → Event Notification
Gridhook.configure do |config|
  # The path we want to receive events
  # config.event_receive_path = '/sendgrid/event/:customer_id'
  config.event_receive_path = '/sendgrid/event'
  # post_event = RecieveMailConcern::RecieveMail.new

  config.event_processor = proc do |event|
Rails.logger.info(event.inspect)
    # event is a Gridhook::Event object
    # post_event.set_event(event)
    # post_event.sendgrid_event_process
  end
end

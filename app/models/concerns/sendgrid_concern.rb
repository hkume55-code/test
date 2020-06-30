# -*- coding: utf-8 -*-
=begin
= SendGridを利用するために必要な処理をおこなう
SendGridにアクセスするSMTP/APIへのアクセス及び機能を提供する。
https://sendgrid.com/docs/API_Reference/index.html
Authors:: Yusuke AIKO <aiko@iad.co.jp>
Copyright:: Copyright (C) I&D Inc, All rights reserved.
=end
require 'net/https'
require 'uri'
require 'nkf'

module SendgridConcern
  #== メール送信
  #return:: メール送信結果 true:成功 / false:失敗
  def self.broadcast_xsmtp(mail_template)
    begin
Rails.logger.debug(mail_template.inspect)
      sender_name = mail_template.sender_name
      subject = mail_template.subject

      sendgrid = SendGrid::API.new(api_key: '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')
      personalizations = Array.new
      Send.where(:send_flag => true).each do |send|
        personalization  = Hash.new
        substitutions = Hash.new #{sub: Array.new}
        # personalization[:send_at] = send_time_at
        personalization[:subject] = subject
        mail_to = Hash.new
        mail_to[:name]  = send.name
        mail_to[:email] = send.email
        personalization[:to] = [mail_to]
        personalization[:custom_args] = send.tracking_code
        personalizations.push(personalization)
      end
      content = [{type: 'text/plain', value: mail_template.message}]
      #content.push({type: 'text/html', value: mail_info[:message_html]}) if mail_info[:message_html].present?
      data = { personalizations: personalizations,
               from:             {email: mail_template.sender_email, name: mail_template.sender_name},
               content:          content
             }
      #data[:reply_to]   = {email: mail_info[:reply_to]} if mail_info.key?(:reply_to) && mail_info[:reply_to].present?
      #data[:categories] = [seq] if seq.present?
      Rails.logger.info("!! TEST : #{data}")
      response = sendgrid.client.mail._('send').post(request_body: data)
      if response.status_code != '202'
        Rails.logger.info("SendGrid Response status_code:#{response.status_code}\n#{response.body}")
        Rails.logger.info("SendGrid Response DATA:#{data}")
      end
      return response

    rescue => e
      #ExceptionConcern.output_log(e)
Rails.logger.debug(e.inspect)
      return false
    end
  end
end

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

module SendgridConcernNew
  #== メール送信
  # sendgrid-ruby GEMを使用して送信する。下記機能として使用。
  #_mail_template_id_:: メールヘッダ情報
  #return:: メール送信結果 true:成功 / false:失敗
  def self.broadcast_xsmtp(mail_template_id)
      mail_template = MailTemplate.find(mail_template_id)
      sender_name = mail_template[:sender_name]
      subject = mail_template[:subject]

      sendgrid = SendGrid::API.new(api_key: Mailtest::Application.config.sendgrid_smtp_apikey)
      personalizations = Array.new
      Send.where(:send_flag => true).where.not(:email => nil).each_with_index {|target|
        personalization  = Hash.new
        substitutions = Hash.new
        custom_args   = Hash.new
        personalization[:subject] = mail_template[:subject]
        mail_to = Hash.new
        mail_to[:name]  = target[:name]
        mail_to[:email] = target[:email]
        personalization[:to] = [mail_to]
        custom_args = {'X-IADMM' => target[:tracking_code]}
        personalization[:custom_args]   = custom_args if custom_args.present?
        personalizations.push(personalization)
      }
      content = [{type: 'text/plain', value: mail_template[:message]}]
      content.push({type: 'text/html', value: mail_template[:message_html]}) if mail_template[:message_html].present?
      data = { personalizations: personalizations,
               from:             {email: mail_template[:sender_email], name: mail_template[:sender_email]},
               content:          content
             }
      data[:reply_to]   = {email: mail_template[:reply_to]} if mail_template[:reply_to].present?
      data[:categories] = ["P#{mail_template.id.to_s}"]
      response = sendgrid.client.mail._('send').post(request_body: data)
      if response.status_code != '202'
        Rails.logger.info("SendGrid Response status_code:#{response.status_code}\n#{response.body}")
        Rails.logger.info("SendGrid Response DATA:#{data}")
      end
      return response
  end
end

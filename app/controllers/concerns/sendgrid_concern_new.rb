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
  #_mail_info_:: メールヘッダ情報
  #_replace_params_:: 差し込み情報
  #_seq_:: 送信シーケンス番号
  #_send_time_at_:: 送信時間
  #return:: メール送信結果 true:成功 / false:失敗
  def self.broadcast_xsmtp(mail_info, targets, seq = nil, send_time_at = Time.zone.now.to_i)
puts("broadcast_xsmtp mailinfo=#{mail_info.inspect}")
puts("broadcast_xsmtp targets=#{targets.inspect}")
puts("broadcast_xsmtp seq=#{seq.inspect}")
     sender_name = mail_info[:sender_name]
      subject = mail_info[:subject]

      sendgrid = SendGrid::API.new(api_key: Mailtest::Application.config.sendgrid_smtp_apikey)
      personalizations = Array.new
      targets.each_with_index {|target|
puts("broadcast_xsmtp target=#{target.inspect}")
        personalization  = Hash.new
        substitutions = Hash.new #{sub: Array.new}
        custom_args   = Hash.new
        personalization[:send_at] = send_time_at
        personalization[:subject] = mail_info[:subject]
        mail_to = Hash.new
        mail_to[:name]  = target[:name]
        mail_to[:email] = target[:email]
        personalization[:to] = [mail_to]
        custom_args = {mail_info[:org_symbol] => target[:tracking_code]}
        personalization[:custom_args]   = custom_args if custom_args.present?
        personalizations.push(personalization)
      }
      content = [{type: 'text/plain', value: mail_info[:message]}]
      content.push({type: 'text/html', value: mail_info[:message_html]}) if mail_info[:message_html].present?
      data = { personalizations: personalizations,
               from:             {email: mail_info[:sender_email], name: sender_name},
               content:          content
             }
      data[:reply_to]   = {email: mail_info[:reply_to]} if mail_info.key?(:reply_to) && mail_info[:reply_to].present?
      data[:categories] = [seq] if seq.present?
      response = sendgrid.client.mail._('send').post(request_body: data)
      if response.status_code != '202'
        Rails.logger.info("SendGrid Response status_code:#{response.status_code}\n#{response.body}")
        Rails.logger.info("SendGrid Response DATA:#{data}")
      end
      return response
  end
end

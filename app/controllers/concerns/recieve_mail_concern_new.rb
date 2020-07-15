# -*- coding: utf-8 -*-
=begin
= メール受信後に必要な処理をおこなう
受信したエラーメールを必要に応じてプロジェクト及び履歴を更新する。
メールの受信は`rake drm:mail:recieve_mail`にておこなう。
Authors:: Yusuke AIKO <aiko@iad.co.jp>
Copyright:: Copyright (C) I&D Inc, All rights reserved.
=end
module RecieveMailConcernNew
  class RecieveMail
    @event = nil

   #== 初期化
   #_event_: POSTイベント
   def initialize(event = nil)
     @event = event
   end

   #== イベントのセット
   #_event_: POSTイベント
   def set_event(event)
     @event = event
   end

    #== SendGridのイベントをデータベースに反映
    #_event_: SendGridのイベント
    #return: true:処理完了 / false:エラー発生
    def sendgrid_event_process
      begin
        recieved_body = @event.attributes
Rails.logger.info("sendgrid_event_process=============recieved_body=#{recieved_body.inspect}")

        event = recieved_body["event"].to_sym
        category =  recieved_body["category"]
Rails.logger.info("sendgrid_event_process=============event=#{event.inspect}")
Rails.logger.info("sendgrid_event_process=============category=#{category.inspect}")
        case event
        when :bounce, :dropped
          # 基本情報収集
          email = recieved_body["email"]
          reply_text =recieved_body["reason"]
          if event == :bounce then
            reply_code = reply_text[0,3].to_i
          else
            reply_code = nil
          end
          if recieved_body.key?("status") then
            error_code    = recieved_body["status"].split('.')
          else
            error_code = [nil, nil, nil]
          end
          error_time = Time.at(recieved_body["timestamp"].to_i)
          detail = recieved_body.inspect
Rails.logger.info("sendgrid_event_process=============email=#{email.inspect}")
Rails.logger.info("sendgrid_event_process=============reason=#{reason.inspect}")
Rails.logger.info("sendgrid_event_process=============reply_code=#{reply_code.inspect}")
Rails.logger.info("sendgrid_event_process=============error_code=#{error_code.inspect}")
Rails.logger.info("sendgrid_event_process=============error_time=#{error_time.inspect}")
Rails.logger.info("sendgrid_event_process=============detail=#{detail.inspect}")

          # 付加情報収集
          org_symbol = Array.new
          if recieved_body.key?("X-IADMM") then
            org_symbol = recieved_body["X-IADMM"].split('.')
          end
Rails.logger.info("sendgrid_event_process=============org_symbol=#{detail.inspect}")

        when :open # 開封イベント
          # 基本情報収集
          email              = recieved_body["email"]
          mail_open_datetime = Time.at(recieved_body["timestamp"].to_i)
Rails.logger.info("sendgrid_event_process=============email=#{email.inspect}")
Rails.logger.info("sendgrid_event_process=============mail_open_datetime=#{mail_open_datetime.inspect}")

          # 付加情報収集
          org_symbol = Array.new
          if recieved_body.key?("X-IADMM") then
            org_symbol = recieved_body["X-IADMM"].split('.')
          end
Rails.logger.info("sendgrid_event_process=============org_symbol=#{detail.inspect}")

        else
          # bounceとdroppes,open以外を受け取った場合
          Rails.logger.info("===sengrid_event_process: invalid event")
        end
        return true
      rescue => e
        ExceptionConcern.output_log(e)
        return false
      end
    end

  end
end

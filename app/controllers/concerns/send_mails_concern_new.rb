# -*- coding: utf-8 -*-
=begin
= メール送信に必要な処理をおこなう
メール配信に必要なデータの収集、整形をおこなう。
Authors:: Yusuke AIKO <aiko@iad.co.jp>
Copyright:: Copyright (C) I&D Inc, All rights reserved.
=end
module SendMailsConcernNew
  class SendMails
    @mail_template = nil
    @mail = nil

    def set_mail_template_id(mail_template_id)
      @mail_template = MailTemplate.find(mail_template_id)
    end

    #== メール配信処理
    #return:: 配信結果 true:成功 / false:エラーあり
    def deliver
      set_mail_base_info
      return broadcast
    end

    private
    #== メール送信に必要な基本データを収集
    def set_mail_base_info
      @mail = {
        :subject      => @mail_template.subject,
        :message      => @mail_template.message,
        :message_html => @mail_template.message_html,
        :sender_name  => @mail_template.sender_name,
        :sender_email => @mail_template.sender_email,
        :reply_to     => @mail_template.reply_to,
        :org_symbol   => 'X-IADMM'
      }
    end

    #== メール送信
    #引数は必須ではなく、set_customer_idメソッドで機能を補完することができる
    #_iad_session_:: controllerから@iad_sessionを受け取る。
    #_send_test_flag_:: テスト配信をおこなう場合はtrueをセットする。
    def broadcast
      # 差し込み情報を初期化する
      replace_tag        = ReplaceTagConcern::ReplaceTag.new
      replace_tag.add_message(@mail[:subject])
      replace_tag.add_message(@mail[:message])
      replace_tag.add_message(@mail[:message_html])

      targets = Send.where(:send_flag => true, ).where.not(:email => nil)
      SendgridConcernNew.broadcast_xsmtp(@mail, targets, "P#{@mail_template.id.to_s}")
    end
    
  end
end

# -*- coding: utf-8 -*-
=begin rdoc
== drm:mail:send_mail
スケジュールされたメール配信処理

Author:: Yusuke AIKO
Copyright:: Copyright (C) I&D Inc, All rights reserved.
=end
namespace :drm do
  namespace :mail do
    desc '画面からのメール配信処理おこないます。'
    task :send_mail, [:mail_template_id] => [:environment] do |task, args|
      single_deliver(args[:mail_template_id])
    end

    private
    #=== プロジェクトのメールを配信
    #_send_id_:: 送信リストID
    #_mail_template_id_:: メールテンプレートID
    #return:: 顧客使用履歴の挿入成功/失敗
    def self.single_deliver(mail_template_id)

      # SendGridのサーバログインに失敗した場合中止
      # 送信可能件数と送信件数を比較し、送信可能件数が不足していれば中止
      send_mail = SendMailsConcernNew::SendMails.new()
      send_mail.set_mail_template_id(mail_template_id)

      send_result = send_mail.deliver
puts("send_mails.rake result=#{send_result.inspect} mail_template_id:#{mail_template_id}")
    end
  end
end

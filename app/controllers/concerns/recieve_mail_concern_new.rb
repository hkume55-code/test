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

        target_histories = Array.new
        event = recieved_body["event"].to_sym
        category =  recieved_body["category"]
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

          # 付加情報収集
          org_symbol = Array.new
          if recieved_body.key?("X-IADMM") then
            org_symbol = recieved_body["X-IADMM"].split('.')
          end

          if org_symbol[0] == 'system' then
            # 付与したUnique Argumentsが受け取れた場合(システムメール)
            Rails.logger.error("システムメール送信エラー\n送信情報：#{org_symbol.inspect}")
            SendgridErrorMailer.notice_error_to_kaihatsu(org_symbol[2], "システムメール送信エラー(sendgrid_event_process)\n送信情報：#{org_symbol.inspect}").deliver_now
          elsif org_symbol.length == 2 then
            # 付与したUnique Argumentsが受け取れた場合（メールプロジェクト、フォーム・セミナープロジェクト）
            customer_id   = org_symbol[0].to_i
            history_id    = org_symbol[1].to_i
            EnvironmentConcern.change_connection(System::Customer.find(customer_id).database)
            update_info(history_id, error_code, reply_text, email, 'mail', customer_id, category)
            save_sendgrid_notification(email, reply_code, error_code, reply_text, detail, customer_id, history_id, org_symbol.join('.'))
          elsif org_symbol.length == 3 then
            customer_id   = org_symbol[0].to_i
            history_id    = org_symbol[1].to_i
            if org_symbol[2] == 'single_mail'
              EnvironmentConcern.change_connection(System::Customer.find(customer_id).database)
              update_info(history_id, error_code, reply_text, email, org_symbol[2], customer_id, category)
              save_sendgrid_notification(email, reply_code, error_code, reply_text, detail, customer_id, history_id, org_symbol.join('.'))
            end
          else
            # UniqArgumentにcustomer_idとhistory_idが存在しないのでsengrid_notificationsに保存し終了する
            save_sendgrid_notification(email, reply_code, error_code, reply_text, detail, '', '', '')
            Rails.logger.error(@event.inspect)
          end

        when :open # 開封イベント
          # 基本情報収集
          email              = recieved_body["email"]
          mail_open_datetime = Time.at(recieved_body["timestamp"].to_i)

          # 付加情報収集
          org_symbol = Array.new
          if recieved_body.key?("X-IADMM") then
            org_symbol = recieved_body["X-IADMM"].split('.')
          end

          if org_symbol.length == 2 then
            # 付与したUnique Argumentsが受け取れた場合（メールプロジェクト）
            customer_id   = org_symbol[0].to_i
            history_id    = org_symbol[1].to_i
            EnvironmentConcern.change_connection(System::Customer.find(customer_id).database)

            request_remote_addr = recieved_body["ip"]
            # ----------- 除外IPからのアクセス
            exclude_ip = Admin::ExcludeIps.exclude_ip?(request_remote_addr)
            if exclude_ip
              blocked_access_log = BlockedAccessLog.new(blocked_access_logs_params(recieved_body, exclude_ip, history_id, mail_open_datetime, recieved_body))
              blocked_access_log.save!
            # ----------- 除外IP以外からのアクセス
            else
              update_open_info(history_id, request_remote_addr, mail_open_datetime, email)
            end
          end

        else
          # bounceとdroppes,open以外を受け取った場合
          Rails.logger.info("===sengrid_event_process: invalid event")
          Rails.logger.info(event.inspect)
        end
        return true
      rescue => e
        ExceptionConcern.output_log(e)
        return false
      end
    end

    private
    #== 情報反映
    def update_info(history_id, error_code, reply_text, email, add_opt_recode, customer_id = nil, category)
      begin
        unless history_id == nil then
          history = History::Active.find(history_id)
          if history.present? && history.send_email.downcase == email then
            # 履歴テーブル更新
            update_history(history, error_code[0], error_code[1], error_code[2], reply_text, category)
            # プロジェクトテーブル更新
            update_project(history)
          end
        end
        # 個人テーブル更新
        update_person_status(email, error_code)
        add_call_log(customer_id, history_id, email, error_code, reply_text) if add_opt_recode.to_sym == :single_mail
      rescue => e
        ExceptionConcern.output_log(e)
      end
    end

    #== 開封率反映
    def update_open_info(history_id, request_remote_addr, mail_open_datetime, email)
      begin
        unless history_id == nil && History::Active.exists?(history_id) then
          history = History::Active.where(:id => history_id, :send_test_flag => false, :mail_open_flag => false)
          if history.count > 0
            history = history.first
            if history.send_email == email then
              # 履歴テーブル更新
              history.mail_open_flag     = true
              history.mail_open_datetime = mail_open_datetime
              history.mail_open_request_ip = request_remote_addr
              history.save!
            end
          end
        end
      rescue => e
        ExceptionConcern.output_log(e)
      end
    end

    #== 履歴データ更新
    def update_history(history, error_code_0, error_code_1, error_code_2, reply_text, category)
      begin
        result_type_id = Master::Result.name_to_id('送信エラー', :mail_system_flag)
        history_data = {
          :result_type_id     => result_type_id,
          :smtp_error_seg01   => error_code_0,
          :smtp_error_seg02   => error_code_1,
          :smtp_error_seg03   => error_code_2,
          :receipt_body       => reply_text,
          :transmission_times => category.to_s.split('_')[2].to_i,
          :updated_by         => 1
        }
        # history.update!(history_data)
        # 更新者をシステム処理として履歴データ更新、ログにも記録する
        iad_log = LogConcern.new(nil, nil, history_data)
        history.update_with_log(iad_log, history_data)

        # セミナー履歴の受講票を更新(セミナープロジェクト経由でメールプロジェクトを作成した場合かつ受講票更新フラグにチェックがある場合)
        project      = Project.find(history.project_id)
        set_lesson_card_id(history, result_type_id, project) if !history.send_test_flag && project.lesson_card_flag.present?
      rescue => e
        ExceptionConcern.output_log(e)
        return false
      end
    end

    #== プロジェクトデータ更新
    # 履歴にエラーがある場合はそれがわかるようにプロジェクトのステータスを更新する。
    def update_project(history)
      begin
        project      = Project.find(history.project_id)
        if project.project_status_id == Master::Project::Status.mail_project_status[:completion]
          project_data = {
            :project_status_id => Master::Project::Status.mail_project_status[:completion_err],
            :updated_by        => 1
          }
          # validationなしで実行するためupdate_columnsで更新
          project.update_columns(project_data)
        end
      rescue => e
        ExceptionConcern.output_log(e)
      end
    end

    #== 個人データ更新
    # 履歴にエラーがある場合はそれがわかるようにプ個人のステータスを更新する。
    def update_person_status(email, error_code)
      # ハードバウンス発生時、SendGridによりサプレッションリストに登録されてしまうので
      # Dr.Marketing側にもメール送信エラーを設定する。
      mail_send_error = Master::MailSendError.name_to_id('エラーその他')
      if (error_code[0].present? && error_code[1].present? && error_code[0] == '5') then
        mail_send_error = case error_code[1]
                          when '1', '2' then Master::MailSendError.name_to_id('ユーザ不明')
                          when '3', '4' then Master::MailSendError.name_to_id('ホスト不明')
                          else               Master::MailSendError.name_to_id('エラーその他')
                          end
      end
      Person.where(:email => email).each {|person|
        # person.update({ :mail_send_error => mail_send_error })
        # 更新者をシステム処理として個人データ更新、ログにも記録する
        person_attributes = person.attributes
        iad_log = LogConcern.new(nil, nil, person_attributes)
        system_user = User.where(:iad_flag => true, :name => 'システム処理').pluck(:id)
        person.update_with_log(iad_log, { :mail_send_error => mail_send_error, :updated_by => system_user[0] })
      }
    end

    #== コールログ追加
    # 個別メール送信のエラー発生時にログを追加
    def add_call_log(customer_id, history_id, email, error_code, reply_text)
      call_log_note   = nil
      mail_send_error = Master::MailSendError.name_to_id('エラーその他')
      if (error_code[0].present? && error_code[1].present? && error_code[0] == '5') then
        mail_send_error = case error_code[1]
                          when '1', '2' then Master::MailSendError.name_to_id('ユーザ不明')
                          when '3', '4' then Master::MailSendError.name_to_id('ホスト不明')
                          else               Master::MailSendError.name_to_id('エラーその他')
                          end
      end
      error_code_disp = error_code[0].blank? ? 'エラーコードなし' : error_code.join('.')
      call_log_note = "#{Master::MailSendError.find(mail_send_error).name}(#{error_code_disp})"
      history  = History::Active.exists?(history_id) ? History::Active.find(history_id) : nil
      log_type = history.present? ? history.project.project_category.action : :active
      values = {
        log_type:           log_type,
        process_type:       'mail',
        connected_datetime: Time.now,
        history_active_id:  history_id,
        sales_status_id:    Master::RecruitStatus.name_to_id('メール送信エラー'),
        mail_kind_flag:     2,
        mail_to_email:      email,
        note:               "メール送信エラーが発生しました。\n#{call_log_note}"
      }
      call_log = CallLog.new(values)
      iad_log  = LogConcern.new(nil, nil, call_log.attributes)
      system_user = User.where(:iad_flag => true, :name => 'システム処理').pluck(:id)
      retval = call_log.save_with_log(iad_log, {:mail_send_error => mail_send_error, :updated_by => system_user[0]})
      if System::Customer.exists?(customer_id)
        call_log.notification_send_error(System::Customer.find(customer_id))
      end
      History.update_history_from_call_logs(history, :recruit)
      return retval
    rescue => e
      ExceptionConcern.output_log(e)
      return false
    end
    
    #== 全顧客のデータベース取得
    def get_databases
      databases = Hash.new
      begin
        System::Customer.all.each {|customer|
          databases[customer.id] = customer.database
        }
      rescue => e
        Rails.logger.info("fail in databases")
        Rails.logger.error(e.message)
      end
      return databases
    end

    #== 処理対象の履歴サーチ
    def get_target_histories(email, from_time, to_time, history_sent_id)
      return History::Active.where(:send_email => email, :result_type_id => history_sent_id)
                            .where(:send_finish_date => from_time .. to_time)
    end

    #== SMTPエラーコード保存
    def save_sendgrid_notification(email, reply_code, error_code, reply_text, detail, customer_id, history_id, tracking_code)
      begin
        notification = SendgridNotification.new({:email => email, :reply_code => reply_code,
                                 :status_code_1 => error_code[0], :status_code_2 => error_code[1], :status_code_3 => error_code[2],
                                 :reply_text => reply_text, :detail => detail, :tracking_code => tracking_code})
        notification.sendgrid_notification_histories.build({:customer_id => customer_id, :history_id => history_id})
        notification.save!
      rescue => e
        ExceptionConcern.output_log(e)
      end
    end
    #== セミナー履歴の受講票を更新
    def set_lesson_card_id(history, result_type_id, project)
      update_seminar_history = nil
      if project.stepmail_id.blank? then
        if history.person_id.present? && history.seminar_form_session_id.present?
          update_seminar_history = History::Passive.where(:person_id => history.person_id, :seminar_form_session_id => history.seminar_form_session_id)
        end
      else
        if history.project_lp_checked_row.present?
          update_seminar_history = History::Passive.where(:id => history.project_lp_checked_row)
        end
      end
      if update_seminar_history.present?
        update_seminar_history[0][:lesson_card_id] = result_type_id
        update_seminar_history[0].save
      end
    end

    def blocked_access_logs_params(request_remote_addr, exclude_ip, history_id, mail_open_datetime, recieved_body)
      begin
        history = History::Active.find_by_id(history_id)
        person = history.present? ? history.people : nil
        mail_project = history.present? ? history.project : nil
        params =  {
          :access_type             => :open,
          :exclude_ip_id           => exclude_ip.id,
          :time_access             => mail_open_datetime,
          :person_id               => history&.person_id,
          :company_id              => person&.company_id,
          :mail_project_id         => history&.project_id,
          :mail_history_id         => history_id,
          :clickcount_id           => mail_project&.clickcount_project_id,
          :send_test_flag          => history&.send_test_flag,
          :request_url             => "",
          :request_remote_addr     => recieved_body["ip"],
          :request_remote_host     => "",
          :request_accept_language => "",
          :request_user_agent      => recieved_body["useragent"],
          :email                   => recieved_body["email"],
          :created_by     => 1,
          :updated_by     => 1
        }
        return params
      rescue => e
        ExceptionConcern.output_log(e)
      end
    end

    #== メール文面から送信エラーのエラーコードを抽出
    #def get_send_error_code(recieved_body)
    #  error_code   = recieved_body.match(/Status.*?([245]\.[0-9]+\.[0-9]+)/i)[1]
    #  error_code ||= recieved_body.match(/([^0-9]|\s|^)([245]\.[0-9]+\.[0-9]+)([^0-9]|\s|$)/)[2]
    #  return error_code.present? ? error_code.strip.split('.') : nil
    #end
  end
end

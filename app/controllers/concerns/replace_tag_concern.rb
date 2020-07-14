# -*- coding: utf-8 -*-
=begin rdoc
== 差しこみタグ処理
文字列中の差しこみタグを解析し、データに差し替える処理をおこなう。

タグの形式は{{-モデルクラス名__カラム名-}}としている。
なお、全て小文字で表現する。
ex)
個人情報の姓:     {{-person__last_name-}}
法人情報の法人名: {{-company__company_name-}}

また、存在するカラムの指定についてはデータに変換するが、不正なタグについては空文字列で置換する。
その際にエラーは発生しない。

Author:: Yusuke AIKO
Copyright:: Copyright (C) I&D Inc, All rights reserved.
=end
module ReplaceTagConcern
  class ReplaceTag
    @row_ids      = Hash.new  # 各テーブルのプライマリキーをまとめて格納
    @replace_tags = Array.new # メール内で使用されている差し込みタグリスト
    @org_messages = Array.new # 差し込みタグを変換する前のメッセージ
    @new_messages = Array.new # 差し込みタグが変換された後のメッセージ
    @customer     = nil       # 顧客
    @project      = nil       # 使用するプロジェクト (Project)
    @person       = nil       # 使用する個人 (Person)
    @history      = nil       # 使用する履歴 (History)
    @replace_info = Hash.new  # 差し込みタグの変換情報 id->タグ
    @replace_params = Hash.new  # 差し込みタグの変換後文字列

    #=== 初期化
    def initialize
      @row_ids      = Hash.new
      @replace_tags = Array.new
      @org_messages = Array.new
      @new_messages = Array.new
      @customer      = nil
      @project      = nil
      @person       = nil
      @history      = nil
      @replace_info = Hash.new
      @replace_params = Hash.new
      @mail_face   = nil
      @history_code = nil
      @history_ids_string = nil
      @lotno_string = nil
      @present_string = nil
    end

    #== 差し替えデータ取得先を初期化
    #データを差し替えるレコードをプライマリキーにて指定する。
    #history_active_id/history_passive_idは同時にセットできるが、両方に値が入っている場合はhistory_active_idが優先される。
    #_customer_id_: 顧客ID
    #_company_id_: 法人ID
    #_person_id_: 個人ID
    #_project_id_: プロジェクトID
    #_history_active_id_: 履歴ID
    #_history_passive_id_: 履歴ID
    #_seminar_form_id_id_: セミナフォームID
    #_seminar_form_session_id_: セミナーフォームセッションID
    def set_target(customer_id: nil, company_id: nil, person_id: nil, project_id: nil, history_active_id: nil, history_passive_id: nil, webform_form_id: nil, seminar_form_id: nil, seminar_form_session_id: nil)
      @row_ids = {
        :customer_id        => customer_id,
        :company_id         => company_id,
        :person_id          => person_id,
        :project_id         => project_id,
        :history_active_id  => history_active_id,
        :history_passive_id => history_passive_id,
        :webform_form_id    => webform_form_id,
        :seminar_form_id    => seminar_form_id,
        :seminar_form_session_id    => seminar_form_session_id
      }
    end

    #== プロジェクトインスタンスを受け取る
    #このメソッドでプロジェクトインスタンスを受け取っている場合、set_target(:project_id => 1)の指定は無効になる。
    #_project_: Project.find(1)の結果を受け取る。
    def set_project(project)
      @project = project
      @row_ids[:project_id] = project.id
    end

    #== 個人インスタンスを受け取る
    #_person_: 個人インスタンス
    def set_person(person)
      @person = person
    end

    #== 履歴インスタンスを受け取る
    #_history_: 履歴インスタンス
    def set_history(history)
      @history = history
    end

    #== メール文面、履歴ID（暗号化）、複数履歴ID文字列をセット（KKO特殊コード）
    #_history_:: 履歴
    def set_kko_replace_tag(history_code, history_ids_string, lotno_string, present_string)
      @history_code = history_code
      @history_ids_string = history_ids_string
      @lotno_string = lotno_string
      @present_string = present_string
    end

    #== 差し込みタグを含んだ文字列を追加
    #差し差し込みタグを含んだ文字列を受け取る。
    #このメソッドを複数回呼び出すことで置換する文字列を複数個指定できる
    #_message_: 差しこみタグを含んだ文字列 (String)
    #return: 追加した文字列
    def add_message(message)
      @org_messages.push(message)
      @replace_tags.push(scan_replace_tags(message))
      return message
    end

    #== 差し込みタグの情報を取得
    #return: replace_info   テーブル名、カラム名→タグ名への変換テーブル
    #        replace_params 差し込みタグの値蓄積テーブル
    def set_replace_info
      @replace_info = Hash.new
      @replace_params = {:email=>Array.new, :to_name=>Array.new, :tracking_code=>Array.new}
      @replace_tags.each {|replace_hash|
        replace_hash.each {|key,vals|
          if key == :none then next end
          vals.each {|val|
            tag = "{{-#{key}__#{val}-}}"
            @replace_info[key] = Hash.new unless @replace_info.key?(key)
            @replace_info[key][val] = tag
            @replace_params[tag] = Array.new
          }
        }
      }
      return @replace_info, @replace_params
    end

    #== 差し込み情報を収集（X-SMTPAPIを使って一括送信の場合）
    #_replace_info_: テーブル名、カラム名→タグ名への変換テーブル
    #_replace_params_: 差し込みタグの値蓄積テーブル
    #return: replace_params 差し込みタグの値蓄積テーブル
    #【注意】同様の処理をconvert_replace_tagsでも実施しています。
    #        両方に同じ修正が必要です。
    def set_replace_tags(replace_info, replace_params)
      tmp_params = Hash.new
      @customer = System::Customer.find(@row_ids[:customer_id])

      # 送信先取得
      if @person.email.blank? then return replace_params, false end
      tmp_params[:email] = @person.email

      # トラッキングコード取得
      tmp_params[:tracking_code] = create_tracking_code(@history)

      # プロジェクト差し込み情報置換(セミナー)
      if @project.present? && @project.seminar_project_id.present?
        seminar_project_id = @project.seminar_project_id
        seminar_project = Project.find_by_id(seminar_project_id)
      else
        seminar_category_id = Master::Project::Category.symbol2id(:seminar)
        if @project.stepmail.present? && @project.stepmail.project_category_id == seminar_category_id then
          seminar_project_id = @history.project_source_project_id
          seminar_project = Project.find_by_id(seminar_project_id)
        else
          nil
        end
      end

      # セミナー履歴差し込み情報置換(現在履歴の差し込みはセミナーのみ利用)
      if @history.class.name == 'History::Active' && @history.seminar_form_session_id.present?
        seminar_history = History::Passive.where(:person_id => @history.person_id, :seminar_form_session_id => @history.seminar_form_session_id)
        seminar_history = seminar_history.first unless seminar_history.nil?
      else
        seminar_history = @history
      end

      # モデル単位で差し込みタグを取得
      replace_info.each { |table,columns|
        begin
          # 置換するデータをモデル単位で取得
          replace_data = case table.to_sym
                         when :company then Company.find(@row_ids[:company_id])
                         when :person  then @person
                         when :project then @project.present? ? @project : Project.find(@row_ids[:project_id])
                         when :seminar_project then seminar_project
                         when :history then seminar_history
                         when :webform then Webform::Form.find_by(id: @row_ids[:webform_form_id])
                         when :lp_base
                            if @customer.multi_lpbase_flag || @customer.package_name == 'drjobs'
                              lp = Webform::Lp.where(webform_form_id: @row_ids[:webform_form_id]).first
                              lp.present? && lp.base.present? ? lp.base : nil
                            elsif @customer.package_name == 'drrecruit'
                              Webform::LpBase.find(1)
                            else
                              nil
                            end
                         when :seminar then Seminar::Form.find_by(id: @row_ids[:seminar_form_id])
                         when :session then Seminar::FormSession.find_by(id: @row_ids[:seminar_form_session_id])
                         else nil
                         end
        rescue => e
          Rails.logger.error("set_replace_tags error (#{e.inspect})")
          # ExceptionConcern.output_log(e)
          return replace_params, false
        end

        # 予備項目をモデル単位で取得
        unless replace_data.nil? then
          rsv_defs = case table.to_sym
                     when :company then Rsv::Def.get_rsv_defs('Rsv::CompanyDef')
                     when :person  then Rsv::Def.get_rsv_defs('Rsv::PersonDef')
                     when :history  then Rsv::Def.get_rsv_defs('Rsv::HistoryDef')
                     end
        end
        columns.each {|column,cvt_key|
          if table == :clickcount
            column = column.to_s
            # クリックカウント
            url = String.new
            if Master::Email::Clickcount.exists?(column)
              clickcount_master = Master::Email::Clickcount.find(column)
              value = clickcount_master.publish_url(@row_ids[:customer_id], @project.clickcount_project_id, @person.id, @history.id)
            else
              return replace_params, false
            end
          elsif table == :attachment
            column = column.to_s
            # ファイルBOX
            url = String.new
            if Master::Attachment.exists?(column)
              attachment_master = Master::Attachment.find(column)
              value = attachment_master.publish_url(@row_ids[:customer_id], @project.clickcount_project_id, @person, @history.id)
            else
              return replace_params, false
            end
          else
            if replace_data.nil?
              value = ""
            elsif Rsv.rsv_table_column?(column)
              # 予備項目
              rsv_def = rsv_defs.where(:bulkregistration_id => column).first
              if rsv_def.present? && replace_data.rsv_items.exists?(:def_id => rsv_def.id)
                rsv_items = replace_data.rsv_items.where(:def_id => rsv_def.id)
                value     = case Rsv::Def.get_column_type(rsv_def).to_sym
                            when :date     then rsv_items.first.in_datetime.to_s(:date)
                            when :datetime then rsv_items.first.in_datetime.to_s(:datetime)
                            when :integer
                              if rsv_items.first.in_number.to_i == rsv_items.first.in_number
                                rsv_items.first.in_number.to_i.to_s
                              else
                                rsv_items.first.in_number.to_s
                              end
                            when :option
                              option_strings = Array.new
                              rsv_items.each {|item|
                                option = rsv_def.options.where(:id => item.option_id, :show => true).first
                                option_strings.push(option.option_string)
                              }
                              option_strings.join(', ')
                            else rsv_items.first.in_text
                            end
              end
            else
              # 通常の項目
              begin
                if table.to_sym == :session
                  value = Seminar::FormSession.ReplaceDataSeminar(column, replace_data)
                elsif replace_data.send(column).nil?
                  value = String.new
                elsif table.to_sym == :history && column.to_sym == :id_base64
                  # KKO特殊処理
                  value = @history_code
                elsif table.to_sym == :history && column.to_sym == :id_join
                  # KKO特殊処理
                  value = @history_ids_string
                elsif table.to_sym == :history && column.to_sym == :lotno_join
                  # KKO特殊処理
                  value = @lotno_string.blank? ? @lotno_string : @lotno_string.split(',').join("\n")
                elsif table.to_sym == :history && column.to_sym == :present_select
                  # KKO特殊処理
                  value = @present_string.blank? ? @present_string : @present_string.split(',').join("\n")
                elsif column.to_sym == :master_products
                  value = master_replace_tag(table, column, replace_data)
                elsif replace_data.send(column).class.to_s == 'Fixnum'
                  value = master_replace_tag(table, column, replace_data)
                else
                  value = replace_data.send(column)
                end
              rescue => e
                ExceptionConcern.output_log(e)
                return replace_params, false
              end
            end
          end
          # TODO:修正する
          value = case value
            when nil then ""
            when false then "false"
            when true then "true"
            else value.to_s
            end
          tmp_params[cvt_key] = value
        }
      }
      tmp_params.each {|key,val| replace_params[key].push(val)}
      return replace_params, true
    end

    #== 追加された差し込みタグを含む文字列を出力
    #return: 置換対象となっているすべての文字列 (Array)
    def org_messages
      return @org_messages
    end

    #== 差し込み情報を収集（1件ずつ送信の場合）
    #return: replace_params 差し込みタグの値蓄積テーブル
    def set_replace_tags_each
      replace_params = {:email=>Array.new, :to_name=>Array.new, :tracking_code=>Array.new}

      # 送信先取得
      replace_params[:email].push(@person.email)

      # トラッキングコード取得
      replace_params[:tracking_code].push(create_tracking_code(@history))

      return replace_params
    end

    #== 追加された差し込みタグを含む文字列を出力
    #return: 置換対象となっているすべての文字列 (Array)
    def org_messages
      return @org_messages
    end

    #== メッセージに差し込みタグを含むか？
    #_type_: :subject/:text
    #return: true/false
    def include_tag(type)
      message = type == :subject ? @org_messages[0] : @org_messages[1]
      return message.include?("{{")
    end

    #== 差し込みタグを変換した文字列を出力
    #org_messagesで返される配列インデックストmessagesで返される配列インデックスは一致する。
    #そのため、org_messages[1]の結果が欲しい場合はmessages(1)もしくはmessage()[1]と指定する。
    #_index_: 変換する配列インデックスを指定
    #return: 変換した文字列(Array) / 引数を指定している場合、指定した文字列のみ(String)
    def messages(index = nil)
      conv_result = convert_replace_tags
      return index.blank? ? @new_messages : @new_messages[index]
    end

    #== スタックした文字列を削除
    def reset_messages()
      @new_messages = Array.new
    end

    #== メッセージにセミナーのセッション情報を含むか？
    #_type_: :subject/:text
    #return: true/false
    def include_session_tag(message)
      tags = scan_replace_tags(message)
      return tags.include?(:session) || tags.include?(:seminar)
    end

    private
    #== 使用されている差し込みタグをリスト化
    #使用しているタグを抽出し、リストにして戻す
    def scan_replace_tags(message)
      tags = nil
      not_use_symbol = [:none]
      if message.present?
        tags = Hash.new
        raw_tags = message.scan(/\{\{\-.+?\-\}\}/).to_a
        tmp_tags = Array.new
        if raw_tags.present?
          # messageがタグを使用している場合
          raw_tags.each {|tag| tmp_tags.push(tag.gsub('{{-', '').gsub('-}}', '')) }
          tmp_tags.uniq.sort.each { |tag|
            # タグを参照テーブルごとに分類
            part_tag = tag.partition('__')
            if part_tag[0].present? && part_tag[2].present?
              table  = part_tag[0].downcase.to_sym
              column = part_tag[2].downcase.to_sym
              if tags.class == Hash && tags.key?(table)
                tags[table] = Array.new if tags[table].class != Array
                tags[table].push(column)
              else
                tags[table] = [column]
              end
            end
          }
        else
          tags = not_use_symbol
        end
      else
        tags = not_use_symbol
      end
      return tags
    end

    #== 差し込みタグをデータに置き換え
    #【注意】同様の処理をset_replace_tagsでも実施しています。
    #        両方に同じ修正が必要です。
    def convert_replace_tags
      # オリジナルのテキストをコピー
      @org_messages.each_with_index { |message, index| @new_messages[index] = message }
      @customer = System::Customer.find(@row_ids[:customer_id])

      # プロジェクト差し込み情報置換(セミナー)
      if @project.present? && @project.seminar_project_id.present?
        seminar_project_id = @project.seminar_project_id
        seminar_project = Project.find_by_id(seminar_project_id)
      else
        seminar_category_id = Master::Project::Category.symbol2id(:seminar)
        if @project.stepmail.present? && @project.stepmail.project_category_id == seminar_category_id then
          seminar_project_id = @history.project_source_project_id
          seminar_project = Project.find_by_id(seminar_project_id)
        else
          nil
        end
      end

      # セミナー履歴差し込み情報置換(現在履歴の差し込みはセミナーのみ利用)
      if @history.class.name == 'History::Active' && @history.seminar_form_session_id.present?
        seminar_history = History::Passive.where(:person_id => @history.person_id, :seminar_form_session_id => @history.seminar_form_session_id)
        seminar_history = seminar_history.first unless seminar_history.nil?
      else
        seminar_history = @history
      end

      # モデル単位で置換する
      table_list_from_replace_tags().each { |table|
        begin
          # 置換するデータをモデル単位で取得
          replace_data = case table.to_sym
                         when :company then Company.find(@row_ids[:company_id])
                         when :person  then Person.find(@row_ids[:person_id])
                         when :project then @project.present? ? @project : Project.find(@row_ids[:project_id])
                         when :seminar_project then seminar_project
                         when :history then seminar_history
                           #if @row_ids[:history_active_id].present?
                           #  History::Active.find(@row_ids[:history_active_id])
                           #else
                           #  History::Passive.find(@row_ids[:history_passive_id])
                           #end
                         when :webform then Webform::Form.find_by(id: @row_ids[:webform_form_id])
                         when :lp_base then
                            if @customer.multi_lpbase_flag || @customer.package_name == 'drjobs'
                              lp = Webform::Lp.where(webform_form_id: @row_ids[:webform_form_id]).first
                              lp.present? && lp.base.present? ? lp.base : nil
                            elsif @customer.package_name == 'drrecruit'
                              Webform::LpBase.find(1)
                            else
                              nil
                            end
                         when :seminar then Seminar::Form.find_by(id: @row_ids[:seminar_form_id])
                         when :session then Seminar::FormSession.find_by(id: @row_ids[:seminar_form_session_id])
                         else nil
                         end
        rescue => e
          #ExceptionConcern.output_log(e)
          replace_data = nil
        end
        # KKO：特殊処理（キャンペーン番号）
        item_ids = ::Master::Webform::EntryfieldRelation.where(:compatibility_type => 'cpg-no').pluck(:item_id)
        campaign_rsvdef_ids = ::Master::Webform::Item.where(:id => item_ids).pluck(:rsv_linking_id)
        # 置換開始
        @new_messages.each_index { |index|
          if @replace_tags[index].class == Hash && @replace_tags[index].key?(table)
            rsv_defs = case table.to_sym
                       when :company then Rsv::Def.get_rsv_defs('Rsv::CompanyDef')
                       when :person  then Rsv::Def.get_rsv_defs('Rsv::PersonDef')
                       when :history  then Rsv::Def.get_rsv_defs('Rsv::HistoryDef')
                       end
            @replace_tags[index][table].each { |column|
              if table.to_sym == :clickcount
                # クリックカウント
                url = String.new
                column = column.class == Symbol ? column.to_s : column
                if Master::Email::Clickcount.exists?(column)
                  clickcount_master = Master::Email::Clickcount.find(column)
                  url = clickcount_master.publish_url(@row_ids[:customer_id], @project.clickcount_project_id, @row_ids[:person_id], @history.id)
                end
                @new_messages[index] = @new_messages[index].gsub(/\{\{\-#{table}__#{column}\-\}\}/, url)
              elsif table == :attachment
                # ファイルBOX
                url = String.new
                column = column.class == Symbol ? column.to_s : column
                if Master::Attachment.exists?(column)
                  attachment_master = Master::Attachment.find(column)
                  url = attachment_master.publish_url(@row_ids[:customer_id], @project.clickcount_project_id, @person, @history.id)
                  @new_messages[index] = @new_messages[index].gsub(/\{\{\-#{table}__#{column}\-\}\}/, url)
                else
                  return replace_params, false
                end
              else
                if Rsv.rsv_table_column?(column.to_sym)
                  customer_name = System::Customer.where(:id => @row_ids[:customer_id]).pluck(:login_name)
                  # 予備項目
                  rsv_def = rsv_defs.where(:bulkregistration_id => column).first
                  if rsv_def.present? && replace_data.rsv_items.exists?(:def_id => rsv_def.id)
                    rsv_items = replace_data.rsv_items.where(:def_id => rsv_def.id)
                    if campaign_rsvdef_ids.include?(rsv_def.id) then
                      # KKO：特殊処理（キャンペーン番号）
                      campaign_no_arr = Array.new
                      rsv_items.first.in_text.split("//").each {|c_no| campaign_no_arr.push("#{c_no[0,3]} #{c_no[3,4]} #{c_no[7,3]}")}
                      value = campaign_no_arr.join("\n")
                    else
                      value   = case Rsv::Def.get_column_type(rsv_defs.where(:bulkregistration_id => column).first).to_sym
                                when :date     then rsv_items.first.in_datetime.to_s(:date)
                                when :datetime then rsv_items.first.in_datetime.to_s(:datetime)
                                when :integer  then
                                  if rsv_items.first.in_number.to_i == rsv_items.first.in_number
                                    value = rsv_items.first.in_number.to_i.to_s
                                  else
                                    value = rsv_items.first.in_number.to_s
                                  end
                                  if customer_name[0] != 'sas'
                                    value
                                  else
                                    # SAS専用対応 3桁カンマを付与
                                    value.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,') + '円'
                                  end
                                when :option
                                  option_strings = Array.new
                                  rsv_items.each {|item|
                                    option = rsv_def.options.where(:id => item.option_id, :show => true).first
                                    option_strings.push(option.option_string)
                                  }
                                  option_strings.join(', ')
                                else rsv_items.first.in_text
                                end
                    end
                    value = String.new if value.blank?
                    @new_messages[index] = @new_messages[index].gsub(/\{\{\-#{table}__#{column}\-\}\}/, value)
                  end
                else
                  # 通常の項目
                  begin
                    if table.to_sym == :session
                      value = Seminar::FormSession.ReplaceDataSeminar(column, replace_data)
                    elsif replace_data.nil?
                      value = nil
                    elsif table.to_sym == :history && column.to_sym == :id_base64
                      # KKO特殊処理
                      value = @history_code
                    elsif table.to_sym == :history && column.to_sym == :id_join
                      # KKO特殊処理
                      value = @history_ids_string
                    elsif table.to_sym == :history && column.to_sym == :lotno_join
                      # KKO特殊処理
                      value = @lotno_string.blank? ? @lotno_string : @lotno_string.split(',').join("\n")
                    elsif table.to_sym == :history && column.to_sym == :present_select
                      # KKO特殊処理
                      value = @present_string.blank? ? @present_string : @present_string.split(',').join("\n")
                    elsif column.to_sym == :master_products
                      value = master_replace_tag(table, column, replace_data)
                    elsif replace_data.send(column).class.to_s == 'Fixnum'
                      value = master_replace_tag(table, column, replace_data)
                    else
                      value = replace_data.send(column)
                    end
                  rescue => e
                    # ExceptionConcern.output_log(e)
                    return @new_messages = Array.new
                  end

                  # TODO:修正する
                  replaced_string = case value
                  when nil
                    ""
                  when false
                    "false"
                  when true
                    "true"
                  else
                    value.to_s
                  end

                  if column.to_sym == :id_base64 || column.to_sym == :id_join || column.to_sym == :lotno_join || column.to_sym == :present_select
                    # KKO特殊処理
                    @new_messages[index] = @new_messages[index].gsub(/\{\{\-#{table}__#{column}\-\}\}/, replaced_string)
                  else
                    @new_messages[index] = @new_messages[index].gsub(/\{\{\-#{table}__#{column}\-\}\}/, replaced_string) if replace_data.class.method_defined?(column.to_sym)
                  end
                end
              end
            }
          end
        }
      } if table_list_from_replace_tags().length > 0

      # 変換できなかった間違ったフォーマットのタグは削除する。
      @new_messages.each_index {|index|
        @new_messages[index] = @new_messages[index].gsub(/\{\{\-.+?\-\}\}/, '') unless @new_messages[index].nil?
      }
      return @new_messages
    end

    # Master系の場合数値→文字変換の必要がある
    # 上記convert_replace_tagsでは
    # TypeError (no implicit conversion of Fixnum into String)となる
    def master_replace_tag(table, column, replace_data)
      id = replace_data.send(column)
      if column.to_s == "master_products"
        return replace_data.master_products.pluck(:name).join(',')
      end
      model_name = case column.to_s
      when "privacy_policy_id", "ng_mail_id", "ng_dm_id", "ng_tel_id", "ng_fax_id", "mail_send_error", "dm_no_arrival", "project_status_id", "original_business_category_id"
        "master/commons"
      when "prefecture_id"
        "master/prefectures"
      when "department_id"
        "master/departments"
      when "sales_staff_id", "employee_id", "deliver_mode_user_id"
        "master/employees"
      when "call_exclusion"
        "master/call_exclusions"
      when "project_category_id"
        "master/project/categories"
      when "project_subcategory_id"
        "master/project/subcategories"
      when "lock_user_id"
        "users"
      when "recruit_gender_id"
        "master/recruit/gender"
      when "mail_sender_id"
        "master/email/senders"
      when "test_target_id"
        "master/email/test_targets"
      when "clickcount_project_id"
        "projects"
      when "diamond_category"
        return id.to_s
      else
        return id.to_s
      end

      str = model_name.classify.constantize.where(id: id).pluck(:name)
      str[0]

    end

    #= HELPER
    #== 置換で使用するテーブルをリスト化して戻す。
    def table_list_from_replace_tags()
      tags = Array.new
      @replace_tags.each { |replace_tag|
        tags += replace_tag.class == Hash ? replace_tag.keys : Array.new
      }
      return tags.sort.uniq
    end

    #== トラッキングコードを生成
    def create_tracking_code(history)
      return [@row_ids[:customer_id],  # customer_id
              history.id               # history_id
             ].join('.')
    end
  end
end

class MailTemplatesController < ApplicationController
  before_action :set_mail_template, only: [:show, :edit, :update, :destroy, :send_email]

  # GET /mail_templates
  # GET /mail_templates.json
  def index
    @mail_templates = MailTemplate.all
  end

  # GET /mail_templates/1
  # GET /mail_templates/1.json
  def show
  end

  # GET /mail_templates/new
  def new
    @mail_template = MailTemplate.new
  end

  # GET /mail_templates/1/edit
  def edit
  end

  # POST /mail_templates
  # POST /mail_templates.json
  def create
    @mail_template = MailTemplate.new(mail_template_params)

    respond_to do |format|
      if @mail_template.save
        format.html { redirect_to @mail_template, notice: 'Mail template was successfully created.' }
        format.json { render :show, status: :created, location: @mail_template }
      else
        format.html { render :new }
        format.json { render json: @mail_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /mail_templates/1
  # PATCH/PUT /mail_templates/1.json
  def update
    respond_to do |format|
      if @mail_template.update(mail_template_params)
        format.html { redirect_to @mail_template, notice: 'Mail template was successfully updated.' }
        format.json { render :show, status: :ok, location: @mail_template }
      else
        format.html { render :edit }
        format.json { render json: @mail_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /mail_templates/1
  # DELETE /mail_templates/1.json
  def destroy
    @mail_template.destroy
    respond_to do |format|
      format.html { redirect_to mail_templates_url, notice: 'Mail template was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # send_email /mail_templates/1
  # send_email /mail_templates/1.json
  def send_email
    #sendmail = SendMailsConcern::SendMails.new(@mail_template)
    #sendmail.deliver
    respond_to do |format|
      format.html { redirect_to mail_templates_url, notice: 'Mail Send Complete.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_mail_template
      @mail_template = MailTemplate.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def mail_template_params
      params.require(:mail_template).permit(:subject, :message, :sender_email, :sender_name)
    end
end

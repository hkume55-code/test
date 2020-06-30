require 'test_helper'

class MailTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mail_template = mail_templates(:one)
  end

  test "should get index" do
    get mail_templates_url
    assert_response :success
  end

  test "should get new" do
    get new_mail_template_url
    assert_response :success
  end

  test "should create mail_template" do
    assert_difference('MailTemplate.count') do
      post mail_templates_url, params: { mail_template: {  } }
    end

    assert_redirected_to mail_template_url(MailTemplate.last)
  end

  test "should show mail_template" do
    get mail_template_url(@mail_template)
    assert_response :success
  end

  test "should get edit" do
    get edit_mail_template_url(@mail_template)
    assert_response :success
  end

  test "should update mail_template" do
    patch mail_template_url(@mail_template), params: { mail_template: {  } }
    assert_redirected_to mail_template_url(@mail_template)
  end

  test "should destroy mail_template" do
    assert_difference('MailTemplate.count', -1) do
      delete mail_template_url(@mail_template)
    end

    assert_redirected_to mail_templates_url
  end
end

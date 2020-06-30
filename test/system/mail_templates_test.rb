require "application_system_test_case"

class MailTemplatesTest < ApplicationSystemTestCase
  setup do
    @mail_template = mail_templates(:one)
  end

  test "visiting the index" do
    visit mail_templates_url
    assert_selector "h1", text: "Mail Templates"
  end

  test "creating a Mail template" do
    visit mail_templates_url
    click_on "New Mail Template"

    click_on "Create Mail template"

    assert_text "Mail template was successfully created"
    click_on "Back"
  end

  test "updating a Mail template" do
    visit mail_templates_url
    click_on "Edit", match: :first

    click_on "Update Mail template"

    assert_text "Mail template was successfully updated"
    click_on "Back"
  end

  test "destroying a Mail template" do
    visit mail_templates_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Mail template was successfully destroyed"
  end
end

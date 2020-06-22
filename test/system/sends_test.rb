require "application_system_test_case"

class SendsTest < ApplicationSystemTestCase
  setup do
    @send = sends(:one)
  end

  test "visiting the index" do
    visit sends_url
    assert_selector "h1", text: "Sends"
  end

  test "creating a Send" do
    visit sends_url
    click_on "New Send"

    fill_in "Email", with: @send.email
    fill_in "Message", with: @send.message
    fill_in "Sender", with: @send.sender
    fill_in "Sendtime", with: @send.sendtime
    fill_in "Subject", with: @send.subject
    click_on "Create Send"

    assert_text "Send was successfully created"
    click_on "Back"
  end

  test "updating a Send" do
    visit sends_url
    click_on "Edit", match: :first

    fill_in "Email", with: @send.email
    fill_in "Message", with: @send.message
    fill_in "Sender", with: @send.sender
    fill_in "Sendtime", with: @send.sendtime
    fill_in "Subject", with: @send.subject
    click_on "Update Send"

    assert_text "Send was successfully updated"
    click_on "Back"
  end

  test "destroying a Send" do
    visit sends_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Send was successfully destroyed"
  end
end

require 'rails_helper'

RSpec.describe "datasets/new", type: :view do
  before(:each) do
    assign(:dataset, Dataset.new(
      :title => "MyString"
    ))
  end

  it "renders new dataset form" do
    render

    assert_select "form[action=?][method=?]", datasets_path, "post" do

      assert_select "input[name=?]", "dataset[title]"
    end
  end
end

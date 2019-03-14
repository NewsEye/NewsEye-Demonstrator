require 'rails_helper'

RSpec.describe "datasets/index", type: :view do
  before(:each) do
    assign(:datasets, [
      Dataset.create!(
        :title => "Title"
      ),
      Dataset.create!(
        :title => "Title"
      )
    ])
  end

  it "renders a list of datasets" do
    render
    assert_select "tr>td", :text => "Title".to_s, :count => 2
  end
end

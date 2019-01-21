class FeedbacksController < ApplicationController

  def new
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new feedback_params
    puts @feedback.to_json
    respond_to do |format|
      if @feedback.save
        format.js { render action: "create", status: 200}
      else
        puts @feedback.errors.inspect
        format.js { render action: "create", status: :unprocessable_entity}
      end
    end

  end

  private

  def feedback_params
    params.require(:feedback).permit([:name, :email, :page, :text])
  end

end

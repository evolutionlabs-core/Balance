class CreditNotes::VoidsController < ApplicationController
  before_action :set_credit_note

  def new
  end

  def create
    if @credit_note.void!
      redirect_out_of_frame credit_note_path(@credit_note)
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_credit_note
      @credit_note = current_workspace.credit_notes.find(params[:credit_note_id])
    end
end

class Llm::ModelCatalogsController < ApplicationController
  def update
    RubyLLM.models.refresh
    redirect_to models_path, notice: "Model list refreshed."
  end
end

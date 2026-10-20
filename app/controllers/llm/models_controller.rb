class Llm::ModelsController < ApplicationController
  def index
    @llm_models = available_chat_models

    @persisted_ids = RubyLLM::ActiveRecord::Model.pluck(:provider, :model_id, :id)
      .to_h { |provider, model_id, id| [ [ provider.to_s, model_id.to_s ], id ] }
  end

  def show
    @llm_model = RubyLLM::ActiveRecord::Model.find(params[:id])
  end
end

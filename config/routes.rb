Rails.application.routes.draw do
  resources :models, only: [ :index, :show ], controller: "llm/models"
  resource :model_catalog, only: [ :update ], controller: "llm/model_catalogs"

  resources :chats, param: :uuid, controller: "llm/chats", only: [ :index, :create, :show, :destroy ] do
    resources :messages, only: [ :create ], controller: "llm/messages"
    resources :turns, only: [ :show ], controller: "llm/turns"
    resources :proposals, only: [ :update ], controller: "llm/proposals" do
      resource :confirmation, only: [ :update ], controller: "llm/proposal_confirmations"
      resource :dismissal, only: [ :update ], controller: "llm/proposal_dismissals"
    end
  end

  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: %i[new create]
  get "onboarding/:step", to: "onboarding#show", as: :onboarding_step
  patch "onboarding/:step", to: "onboarding#update"
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]

  resource :dashboard, only: [ :show ]
  resources :expenses, only: %i[index new create show edit update] do
    resource :posting, only: [ :create ], controller: "expense_postings"
  end
  resource :expense_report, only: [ :show ]
  resources :journal_entries, only: %i[index new create]
  resources :accounts, only: %i[index new create edit update destroy]
  resources :contacts, only: %i[index new create edit update]
  resources :invoices, only: %i[create show update]

  root "dashboards#show"
  get "up" => "rails/health#show", as: :rails_health_check
end

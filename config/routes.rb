Rails.application.routes.draw do
  scope :client, as: :client do
    resources :invoices, only: :show, param: :token, controller: "client_invoices"
  end

  resources :models, only: %i[index show], controller: "llm/models"
  resource :model_catalog, only: %i[update], controller: "llm/model_catalogs"

  resources :chats, param: :uuid, controller: "llm/chats", only: %i[index create show destroy] do
    resources :messages, only: %i[create], controller: "llm/messages"
    resources :turns, only: %i[show], controller: "llm/turns"
    resources :proposals, only: %i[update], controller: "llm/proposals" do
      resource :confirmation, only: %i[update], controller: "llm/proposal_confirmations"
      resource :dismissal, only: %i[update], controller: "llm/proposal_dismissals"
    end
  end

  get "estimate_reviews/:token", to: "estimate_reviews#show", as: :estimate_review
  post "estimate_reviews/:token", to: "estimate_reviews#create"

  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resources :passwords, param: :token, only: %i[new create edit update]

  get "onboarding/:step", to: "onboarding#show", as: :onboarding_step
  patch "onboarding/:step", to: "onboarding#update"

  resource :overview, only: %i[show]
  get "reports/balance_sheet", to: "reports#balance_sheet", as: :balance_sheet
  get "reports/income_statement", to: "reports#income_statement", as: :income_statement
  resources :expenses, only: %i[index new create show]

  resource :expense_report, only: %i[show]
  resources :journal_entries, only: %i[index new create]
  resources :accounts, path: "accounts", only: %i[index new create edit update]
  resources :services, only: %i[index new create edit update]
  resources :customers, only: %i[index new create edit update show]
  resource :workspace, only: %i[edit update]

  resources :invoices, only: %i[index new create show edit update] do
    resource :issuance, only: %i[new create], controller: "invoices/issuances"
    resource :payment, only: %i[new create], controller: "invoices/payments"
    resource :void, only: %i[new create], controller: "invoices/voids"
  end
  resources :vendors, only: %i[index new create show edit update]
  resources :bills, only: %i[index new create show edit update] do
    resource :issuance, only: %i[new create], controller: "bills/issuances"
    resource :payment, only: %i[new create], controller: "bills/payments"
    resource :void, only: %i[new create], controller: "bills/voids"
  end
  scope :invoice, module: :invoices, as: :invoice do
    resources :customers, only: %i[index new create show edit update]
    resource :workspace, only: %i[edit update]
    resources :lines, only: %i[new destroy]
    resource :calculation, only: :create
  end

  resources :projects, only: %i[index new create show edit update] do
    scope module: :projects, as: :project do
      resources :estimates, shallow: true, only: %i[index new create show edit update destroy] do
        resource :review_link, only: %i[create]
        resource :delivery, only: %i[create]
        resource :approval, only: %i[create]
        resource :decline, only: %i[create]
        resource :reopening, only: %i[create]
        resource :conversion, only: %i[create]
      end
      resources :estimate_lines, path: "estimates/lines", only: %i[new destroy]
      resource :estimate_calculation, path: "estimates/calculation", only: %i[create], controller: "estimate_calculations"
      resource :estimate_workspace, path: "estimates/workspace", only: %i[edit update], controller: "estimate_workspaces"
      resources :invoices, only: %i[index]
      resource :budget, only: %i[edit update]
      resources :tasks, only: %i[index new create edit update destroy]
      resources :time_entries, only: %i[index new create edit update destroy]
      resources :activities, only: %i[index]
    end
  end

  root "overviews#show"
  get "up" => "rails/health#show", as: :rails_health_check
end

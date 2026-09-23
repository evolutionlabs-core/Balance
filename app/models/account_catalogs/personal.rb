module AccountCatalogs
  class Personal < Base
    CHART_OF_ACCOUNTS = [
      {
        category: "ASSET",
        account_types: [
          {
            account_type: "Cash & Liquid Assets",
            detail_types: [
              {
                name: "Checking Account",
                accounts: {
                  checking: { name: "Bank Account" }
                }
              },
              {
                name: "Savings Account",
                accounts: {
                  savings: { name: "Savings" }
                }
              },
              {
                name: "Physical Cash & Digital Wallets",
                accounts: {
                  cash: { name: "Cash" },
                  wallet: { name: "Digital Wallet" }
                }
              },
              {
                name: "Suspense / Clearing",
                accounts: {
                  suspense: { name: "Suspense / Clearing" }
                }
              }
            ],
            description: "Cash and funds that are readily available for spending or short-term needs."
          },

          {
            account_type: "Accounts Receivable",
            detail_types: [
              {
                name: "Accounts Receivable (A/R)",
                accounts: {
                  receivable: { name: "Accounts Receivable" }
                }
              }
            ],
            description: "Money owed to you by customers for goods or services provided on credit."
          },

          {
            account_type: "Investments & Long-Term Assets",
            detail_types: [ "Retirement Accounts", "Taxable Brokerage", "Real Estate & Property", "Health Savings", "Loans & Receivables", "Personal Property & Equipment" ],
            description: "Investments and valuable assets held for long-term financial growth or use."
          }
        ]
      },

      {
        category: "LIABILITY",
        account_types: [
          {
            account_type: "Short-Term Debt",
            detail_types: [
              {
                key: :credit_card,
                name: "Credit Cards",
                accounts: {
                  credit_card: { name: "Credit Card" }
                }
              },
              "Short-Term Loans"
            ],
            description: "Personal debts and obligations that are expected to be paid in the near term."
          },

          {
            account_type: "Long-Term Debt",
            detail_types: [ "Mortgage", "Auto & Student Loans" ],
            description: "Personal debts and loans that are generally repaid over an extended period."
          }
        ]
      },

      {
        category: "EQUITY",
        account_types: [
          {
            account_type: "Personal Net Worth",
            detail_types: [
              {
                name: "Opening Balance",
                accounts: {
                  opening_balance: { name: "Opening Balance Equity" }
                }
              },
              "Retained Savings"
            ],
            description: "The accumulated value of personal assets after accounting for personal liabilities."
          }
        ]
      },

      {
        category: "INCOME",
        account_types: [
          {
            account_type: "Personal Inflows",
            detail_types: [
              "Earned Salary & Wages",
              "Side Hustle / Freelance",
              "Investment Returns",
              "Gifts & Reimbursements",
              {
                name: "Other Personal Income",
                accounts: {
                  uncategorized_income: { name: "Uncategorized Income" }
                }
              }
            ],
            description: "Money received from employment, personal activities, investments, or other sources."
          }
        ]
      },

      {
        category: "EXPENSE",
        account_types: [
          {
            account_type: "Personal Outflows",
            detail_types: [
              "Housing & Utilities",
              "Living & Daily Needs",
              "Transportation",
              "Lifestyle & Subscriptions",
              "Healthcare & Insurance",
              "Financial Expenses",
              {
                name: "Other Personal Expense",
                accounts: {
                  uncategorized_expense: { name: "Uncategorized Expense" }
                }
              }
            ],
            description: "Money spent on living costs, financial obligations, and personal activities."
          }
        ]
      }
    ].freeze
  end
end

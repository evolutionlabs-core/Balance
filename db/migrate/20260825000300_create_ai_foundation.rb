class CreateAiFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.datetime :model_created_at
      t.jsonb :modalities, default: {}
      t.jsonb :capabilities, default: []
      t.jsonb :pricing, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    add_index :llm_models, [ :provider, :model_id ], unique: true
    add_index :llm_models, :provider
    add_index :llm_models, :family
    add_index :llm_models, :modalities, using: :gin
    add_index :llm_models, :capabilities, using: :gin

    create_table :llm_chats do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :workspace, null: false, foreign_key: true
      t.references :llm_model, foreign_key: true
      t.string :title

      t.timestamps
    end
    add_index :llm_chats, :uuid, unique: true

    create_table :llm_messages do |t|
      t.references :llm_chat, null: false, foreign_key: true
      t.references :llm_model, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.json :content_raw
      t.text :thinking_text
      t.text :thinking_signature
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :thinking_tokens
      t.integer :cached_tokens
      t.integer :cache_creation_tokens
      t.datetime :summarized_at

      t.timestamps
    end
    add_index :llm_messages, :role

    create_table :llm_tool_calls do |t|
      t.references :llm_message, null: false, foreign_key: true
      t.string :tool_call_id, null: false
      t.string :name, null: false
      t.jsonb :arguments, default: {}
      t.text :thought_signature

      t.timestamps
    end
    add_index :llm_tool_calls, :tool_call_id, unique: true
    add_index :llm_tool_calls, :name
    add_reference :llm_messages, :llm_tool_call, foreign_key: true

    create_table :proposals do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :llm_chat, null: false, foreign_key: true
      t.references :llm_message, foreign_key: true
      t.bigint :ledger_entry_id
      t.string :proposal_type, null: false
      t.string :status, null: false, default: "proposed"
      t.integer :version, null: false, default: 1
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end
    add_index :proposals, [ :workspace_id, :status ]
    add_index :proposals, [ :llm_chat_id, :proposal_type, :version ]
    add_index :proposals, :ledger_entry_id
  end
end

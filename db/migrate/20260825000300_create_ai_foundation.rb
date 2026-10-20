class CreateAiFoundation < ActiveRecord::Migration[8.1]
  def change
    # RubyLLM 2.x owns the model registry, tool-call, usage, batch, MCP credential
    # and provider file tables. The app owns chats and messages.
    create_table :ruby_llm_models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.datetime :unlisted_at
      t.jsonb :modalities, default: {}
      t.jsonb :capabilities, default: []
      t.jsonb :pricing, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps

      t.index [ :provider, :model_id ], unique: true
      t.index :provider
      t.index :family
      t.index :capabilities, using: :gin
      t.index :modalities, using: :gin
    end

    create_table :llm_chats do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :workspace, null: false, foreign_key: true
      t.references :ruby_llm_model, foreign_key: true
      t.string :title
      t.boolean :cancelled, null: false, default: false

      t.timestamps
    end
    add_index :llm_chats, :uuid, unique: true

    create_table :llm_messages do |t|
      t.references :llm_chat, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.boolean :cache_until_here, null: false, default: false
      t.string :cache_ttl
      t.text :thinking_text
      t.text :thinking_signature
      t.jsonb :citations
      t.jsonb :server_tool_calls
      t.jsonb :raw_content
      t.jsonb :raw_reasoning
      t.string :finish_reason
      t.datetime :summarized_at

      t.timestamps
    end
    add_index :llm_messages, :role

    create_table :ruby_llm_tool_calls do |t|
      t.references :message, polymorphic: true, null: false, index: false
      t.references :result, polymorphic: true, index: false
      t.string :tool_call_id, null: false
      t.string :name, null: false
      t.text :thought_signature
      t.string :approval
      t.boolean :remote, default: false, null: false
      t.jsonb :arguments, default: {}
      t.jsonb :mcp_state
      t.jsonb :mcp_result
      # App-owned trace of each tool run, shown in the chat timeline.
      t.string :trace_status
      t.jsonb :trace_output, default: {}, null: false

      t.timestamps

      t.index [ :message_type, :message_id ]
      t.index [ :result_type, :result_id ]
      t.index :tool_call_id, unique: true
      t.index :name
    end

    create_table :ruby_llm_mcp_credentials do |t|
      t.references :owner, polymorphic: true
      t.string :key, null: false
      t.text :data
      t.timestamps

      t.index :key, unique: true
    end

    create_table :ruby_llm_usages do |t|
      t.references :chat, polymorphic: true, index: false
      t.references :message, polymorphic: true, index: false
      t.references :owner, polymorphic: true, index: false
      t.string :operation, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.string :status, null: false
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cache_read_tokens
      t.integer :cache_write_tokens
      t.integer :thinking_tokens
      t.jsonb :server_tool_use
      t.decimal :input_cost, precision: 16, scale: 10
      t.decimal :output_cost, precision: 16, scale: 10
      t.decimal :cache_read_cost, precision: 16, scale: 10
      t.decimal :cache_write_cost, precision: 16, scale: 10
      t.decimal :thinking_cost, precision: 16, scale: 10
      t.decimal :total_cost, precision: 16, scale: 10
      t.timestamps

      t.index [ :chat_type, :chat_id ]
      t.index [ :message_type, :message_id ]
      t.index [ :owner_type, :owner_id ]
      t.index :status
      t.check_constraint "operation::text IN ('chat', 'embedding', 'moderation', 'image', 'speech', 'transcription', 'ocr', 'rerank', 'judgment', 'video', 'research')"
      t.check_constraint "status::text IN ('pending', 'succeeded', 'failed', 'cancelled')"
    end

    create_table :ruby_llm_batches do |t|
      t.string :provider_batch_id, null: false
      t.string :provider, null: false
      t.string :status, null: false
      t.string :raw_status
      t.boolean :completed, null: false, default: false
      t.string :chat_type
      t.string :batch_protocol
      t.jsonb :chat_ids, default: []
      t.jsonb :request_counts
      t.jsonb :reported_cost
      t.timestamps

      t.index [ :provider, :provider_batch_id ], unique: true
      t.index :status
    end

    create_table :ruby_llm_provider_files do |t|
      t.string :blob_key, null: false
      t.string :provider, null: false
      t.string :account, null: false
      t.text :file_id, null: false
      t.datetime :expires_at
      t.timestamps

      t.index [ :blob_key, :provider, :account ], unique: true, name: "index_ruby_llm_provider_files_uniqueness"
    end

    create_table :proposals do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :llm_chat, null: false, foreign_key: true
      t.references :llm_message, foreign_key: true
      t.references :journal_entry, foreign_key: true
      t.string :proposal_type, null: false
      t.string :status, null: false, default: "proposed"
      t.integer :version, null: false, default: 1
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end
    add_index :proposals, [ :workspace_id, :status ]
    add_index :proposals, [ :llm_chat_id, :proposal_type, :version ]
  end
end

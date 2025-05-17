class AddLlmResponseToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :llm_response, :text
  end
end

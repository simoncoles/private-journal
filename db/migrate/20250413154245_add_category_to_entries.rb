class AddCategoryToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :category, :string, null: false, default: 'Diary'
  end
end

class CreateEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :entries do |t|
      t.date :entry_date
      t.text :content

      t.timestamps
    end
  end
end

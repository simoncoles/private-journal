class ChangeEntryDateToDatetime < ActiveRecord::Migration[8.0]
  def change
    change_column :entries, :entry_date, :datetime
  end
end

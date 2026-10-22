class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users do |t|
      t.string   :name,         null: false, default: ""
      t.string   :status,       null: false, default: "active"
      t.string   :job_position
      t.datetime :last_seen

      t.index :name
      t.index :status
      t.index :last_seen
    end
  end
end

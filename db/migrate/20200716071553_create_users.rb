class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :line_id, null: false # この行を追加

      t.timestamps
    end
  end
end

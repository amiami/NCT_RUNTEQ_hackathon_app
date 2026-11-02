# トップページ（/）。操作している人の立場に合った最初の画面を開く。
# 部長（何も選んでいないときも含む）は管理者の作業ツリー、スタッフはスタッフの作業マニュアル
class HomesController < ApplicationController
  def show
    redirect_to staff_operator? ? staff_operations_path : admin_operations_path
  end
end

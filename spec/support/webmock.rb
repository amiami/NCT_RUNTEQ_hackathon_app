require "webmock/rspec"

# 外部通信は全て遮断する。Cuprite が使うローカル接続のみ許可
WebMock.disable_net_connect!(allow_localhost: true)
